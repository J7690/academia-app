#!/bin/bash
# Publie le moteur dans Supabase Storage — la mise a jour SANS image.
#
# CE QUE CE SCRIPT REMPLACE.
# Avant lui, corriger une ligne de Python du moteur demandait : un poste de
# developpeur allume, Docker demarre, une reconstruction de plusieurs
# gigaoctets, une publication au registre, puis une bascule de version. Le
# 13/08, un rendu est mort sur un chemin errone de quatorze caracteres, et
# c'etait la procedure a suivre pour le reparer.
#
# Desormais : ce script fabrique une archive du moteur et la depose dans
# Storage. `entree.sh` la tire au demarrage de chaque machine. Une correction
# se publie en quelques secondes, depuis n'importe ou.
#
# IL S'EXECUTE SUR LWS, ET C'EST DELIBERE. La cle de service vit deja dans
# /opt/whiteboard-worker/.env, sur cette machine, pour le preparateur. La faire
# transiter ailleurs pour televerser un fichier serait l'exposer sans raison.
#
#   scp <fichiers>  lws-nexiom:/opt/studio_visuel/
#   ssh lws-nexiom "/opt/studio_visuel/publier_moteur.sh 1.3.0"
#
# L'archive porte un fichier VERSION. `entree.sh` le lit et annonce CETTE
# version, pas l'etiquette de l'image : c'est ce qui permet a la sonde de
# refuser une machine dont le moteur n'a pas ete tire.
set -euo pipefail

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  echo "usage: $0 <version>   (ex: 1.3.0)" >&2
  exit 2
fi

SOURCE="${STUDIO_SOURCE:-/opt/studio_visuel}"
ENV_FICHIER="${STUDIO_ENV:-/opt/whiteboard-worker/.env}"
BUCKET="studio-moteur"

# On lit l'environnement sans jamais l'afficher : `set -a` exporte ce que le
# fichier definit, et rien n'est echo. Un `grep` sur ce fichier ecrirait des
# secrets dans les journaux de systemd.
if [ -f "$ENV_FICHIER" ]; then
  set -a; . "$ENV_FICHIER"; set +a
fi
: "${SUPABASE_URL:?SUPABASE_URL absente}"
CLE="${SUPABASE_SERVICE_KEY:-${SUPABASE_SERVICE_ROLE_KEY:-}}"
: "${CLE:?cle de service absente}"

# LA LISTE EST EXPLICITE, PAS UN `*.py`. Le dossier contient aussi des bancs
# d'essai, des diagnostics et des moteurs abandonnes (cf. CLAUDE.md §10) : les
# embarquer alourdirait l'archive et brouillerait ce qui fait foi.
FICHIERS=(
  worker_pod.py executer_capsule.py generateur_scenes.py academia_scene.py
  academia3d.py academia3d_style.py composer_scene.py
  style_reference.py generateur_ia.py montage.py sound_design.py narration.py
)

ATELIER="$(mktemp -d)"
trap 'rm -rf "$ATELIER"' EXIT

manquants=()
for f in "${FICHIERS[@]}"; do
  if [ -f "$SOURCE/$f" ]; then
    cp "$SOURCE/$f" "$ATELIER/$f"
  else
    manquants+=("$f")
  fi
done

# ON REFUSE DE PUBLIER UN MOTEUR INCOMPLET. Une archive amputee s'installerait
# tres bien et ne casserait qu'au rendu, une heure et une machine plus tard.
if [ "${#manquants[@]}" -gt 0 ]; then
  echo "REFUS : fichiers absents de $SOURCE : ${manquants[*]}" >&2
  exit 1
fi

if [ -d "$SOURCE/contours" ]; then
  cp -a "$SOURCE/contours" "$ATELIER/contours"
fi

echo "$VERSION" > "$ATELIER/VERSION"
ARCHIVE="$ATELIER/moteur-$VERSION.tar.gz"
# `--owner=0 --group=0 --numeric-owner` : l'archive doit s'extraire chez
# n'importe qui. Une archive fabriquee sur un poste Windows porte un uid que le
# conteneur ne connait pas ; `tar` echoue alors sur chaque entree et sort en
# code 2 — bien que l'extraction ait reussi. Mesure du 14/08 : le pod a annonce
# « moteur_archive_incomplete » sur une archive parfaitement valide.
tar --owner=0 --group=0 --numeric-owner \
    -czf "$ARCHIVE" -C "$ATELIER" --exclude='moteur-*.tar.gz' .

TAILLE=$(stat -c%s "$ARCHIVE")
echo "archive : moteur-$VERSION.tar.gz — $((TAILLE / 1024)) Ko, ${#FICHIERS[@]} fichiers"

# `x-upsert` : republier la meme version doit remplacer, pas echouer. Une
# version qu'on ne peut pas corriger obligerait a en inventer une nouvelle a
# chaque coquille.
CODE=$(curl -s -o /tmp/publier_moteur.reponse -w '%{http_code}' \
  -X POST "$SUPABASE_URL/storage/v1/object/$BUCKET/moteur-$VERSION.tar.gz" \
  -H "apikey: $CLE" -H "Authorization: Bearer $CLE" \
  -H "Content-Type: application/gzip" -H "x-upsert: true" \
  --data-binary "@$ARCHIVE")

if [ "$CODE" != "200" ] && [ "$CODE" != "201" ]; then
  echo "ECHEC televersement (HTTP $CODE) : $(head -c 300 /tmp/publier_moteur.reponse)" >&2
  exit 1
fi

# ON RELIT CE QU'ON VIENT D'ECRIRE. « 200 » dit que le serveur a accepte la
# requete, pas que l'objet est lisible ni qu'il fait la bonne taille -- et le
# 05/08, une vidange noire et muette a ete livree a un etudiant comme « prete »
# sur la foi d'un message de succes.
RELU=$(curl -s -o "$ATELIER/relu.tar.gz" -w '%{http_code}' \
  -H "apikey: $CLE" \
  "$SUPABASE_URL/storage/v1/object/public/$BUCKET/moteur-$VERSION.tar.gz")
TAILLE_RELUE=$(stat -c%s "$ATELIER/relu.tar.gz" 2>/dev/null || echo 0)

if [ "$RELU" != "200" ] || [ "$TAILLE_RELUE" != "$TAILLE" ]; then
  echo "ECHEC verification : HTTP $RELU, $TAILLE_RELUE octets relus contre $TAILLE envoyes" >&2
  exit 1
fi
if ! tar -tzf "$ATELIER/relu.tar.gz" >/dev/null 2>&1; then
  echo "ECHEC verification : l'archive relue n'est pas lisible" >&2
  exit 1
fi

echo "PUBLIE ET RELU : moteur-$VERSION.tar.gz ($TAILLE octets, archive valide)"
echo
echo "Pour que les machines le prennent, basculer le reglage :"
echo "  update app.studio_config set valeur='$VERSION' where cle='version_moteur';"
