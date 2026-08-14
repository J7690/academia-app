#!/bin/bash
# Point d'entree du conteneur de rendu.
#
# L'ORDRE EST LE FOND DE L'AFFAIRE : on SONDE avant de se declarer pret, et on
# ne reclame une tache qu'apres. Un Pod qui accepte du travail sans avoir prouve
# qu'il sait rendre est exactement ce qui a produit, le 11/08, 1245 images par
# seconde annoncees sur des captures de 10 Ko -- du vide compte tres vite.
#
# CE SCRIPT NE DECIDE PAS DE LA VIE DE LA MACHINE. Il dit ce qu'il est et ce
# qu'il fait ; Supabase decide. C'est la separation qui manquait a
# `agent_pod.sh`, lequel deduisait « occupe » d'une ecriture disque ou d'une
# session SSH ouverte, et empechait ainsi toute extinction.
#
# IL PARLE DES LA PREMIERE SECONDE, et c'est nouveau. Le 12/08, un pod a tourne
# six minutes en `RUNNING` sans qu'on sache s'il tirait encore ses 9,68 Go, s'il
# avait demarre, ou s'il etait bloque : le seul rapport prevu arrivait APRES la
# sonde. Desormais chaque etape est annoncee, donc le silence lui-meme devient
# un diagnostic.
set -u

# EXPORT, ET PAS SEULEMENT AFFECTATION. `: "${VAR:=defaut}"` cree une variable
# de SHELL ; elle n'entre dans l'environnement que si elle y etait deja. Or
# POD_ID est DERIVE de RUNPOD_POD_ID : il n'y etait pas.
#
# Mesure du 12/08 dans le conteneur :
#     dans le shell        : POD_ID=simule-1234
#     dans l'environnement : 0 occurrence
#     vu par python        : None
#     worker_pod.py        : « variable manquante : POD_ID » -> sortie immediate
#
# Consequence observee sur un vrai pod : la sonde reussissait, la machine se
# declarait PRETE, le worker mourait en une seconde, RunPod relancait le
# conteneur -- et le journal montrait « demarre » toutes les quinze secondes.
# Une machine parfaitement saine qui ne travaillait jamais, en facturant.
export POD_ID="${POD_ID:-${RUNPOD_POD_ID:-}}"    # RunPod ne l'attribue qu'APRES
export SUPABASE_URL="${SUPABASE_URL:-}"
export POD_JETON="${POD_JETON:-}"
export SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"
export VERSION_MOTEUR_ATTENDUE="${VERSION_MOTEUR_ATTENDUE:-${VERSION_MOTEUR:-dev}}"
# Au-dela, la sonde est consideree bloquee. Mesure locale du 12/08 : elle rend
# son verdict en 17 s, GPU absent compris. Cent-vingt secondes laissent une
# marge large sans jamais laisser une machine muette facturer.
: "${SONDE_DELAI:=120}"

journal() { echo "$(date -Is) [entree] $*"; }

# Raconte une etape a Supabase. Ne bloque JAMAIS le demarrage : une machine qui
# rend mais ne sait pas le dire vaut mieux qu'une machine qui ne rend pas.
raconter() {
  [ -n "$SUPABASE_URL" ] && [ -n "$POD_ID" ] && [ -n "$POD_JETON" ] || return 0
  curl -s --max-time 20 -X POST "$SUPABASE_URL/rest/v1/rpc/gpu_pod_journal" \
    -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
    -H "Content-Type: application/json" \
    -d "$(jq -nc --arg p "$POD_ID" --arg j "$POD_JETON" --arg e "$1" --arg d "${2:-}" \
             '{p_pod_id:$p, p_jeton:$j, p_etape:$e, p_detail:$d}')" >/dev/null 2>&1 || true
}

journal "image ${VERSION_MOTEUR:-dev}, moteur attendu ${VERSION_MOTEUR_ATTENDUE}"
raconter "demarre" "image ${VERSION_MOTEUR:-dev}"

if [ -z "$POD_ID" ] || [ -z "$POD_JETON" ]; then
  journal "ATTENTION POD_ID ou POD_JETON absent — la sonde tournera mais son"
  journal "          rapport ne pourra pas etre remonte, et aucune tache ne"
  journal "          sera reclamee. Machine inutile : le dire plutot que de"
  journal "          facturer en silence."
fi

# ── 0. LE MOTEUR SE TIRE AU DEMARRAGE ─────────────────────────────────────
#
# POURQUOI, ET C'EST LA DECISION LA PLUS STRUCTURANTE DE CE FICHIER.
#
# Tant que le moteur est CUIT dans l'image, corriger une ligne de Python exige
# de reconstruire plusieurs gigaoctets et de les republier. Le 13/08, un rendu
# est mort sur un chemin errone de quatorze caracteres ; le reparer aurait
# demande un poste de developpeur allume, Docker demarre et une publication.
# Une chaine qui ne peut se reparer que depuis une machine precise n'est pas
# autonome -- c'est une chaine avec un homme dedans.
#
# On separe donc ce qui bouge de ce qui ne bouge pas :
#   l'image   Blender, Chromium, Node, ffmpeg, EGL -- change quelques fois par an
#   le moteur les fichiers Python -- change tous les jours
#
# Le moteur est desormais une archive deposee dans Supabase Storage. La mettre
# a jour, c'est televerser un fichier : depuis n'importe ou, sans image, sans
# Docker, sans ce poste-ci.
#
# DEUX REGLES QUI EVITENT DE TRANSFORMER CE CONFORT EN PANNE :
#   1. On n'ECRASE le moteur embarque qu'apres avoir verifie que l'archive est
#      complete. Une extraction a moitie faite laisserait une machine muette.
#   2. La VERSION annoncee est celle REELLEMENT installee, lue dans l'archive
#      -- jamais l'etiquette de l'image. C'est la sonde qui la comparera a ce
#      que Supabase attend, et qui refusera la machine en cas d'ecart. Sans
#      cela, un moteur non tire passerait pour un moteur a jour.
MOTEUR_TIRE="non"
if [ -n "$SUPABASE_URL" ] && [ "${MOTEUR_DISTANT:-1}" = "1" ]; then
  CIBLE="$SUPABASE_URL/storage/v1/object/public/studio-moteur/moteur-${VERSION_MOTEUR_ATTENDUE}.tar.gz"
  raconter "moteur_tirage" "$VERSION_MOTEUR_ATTENDUE"
  if curl -fsS --max-time 120 -H "apikey: ${SUPABASE_ANON_KEY}" \
          "$CIBLE" -o /tmp/moteur.tar.gz 2>/dev/null; then
    rm -rf /tmp/moteur.neuf && mkdir -p /tmp/moteur.neuf
    # `--no-same-owner` N'EST PAS UN DETAIL. Une archive fabriquee sur un poste
    # Windows porte un uid inconnu du conteneur (mesure : 197609) ; `tar`, lance
    # en root, tente de le restituer, echoue sur CHAQUE entree et sort en code 2
    # -- alors meme que tous les fichiers sont correctement extraits.
    #
    # Mesure du 14/08 : le moteur etait bien telecharge (81 766 octets), bien
    # deplie, et l'amorcage annoncait « moteur_archive_incomplete » puis
    # repliait sur le moteur embarque. Un echec parfaitement faux, et signale
    # comme tel -- ce qui l'a rendu visible plutot que silencieux.
    if tar -xzf /tmp/moteur.tar.gz -C /tmp/moteur.neuf --no-same-owner 2>/dev/null \
       && [ -f /tmp/moteur.neuf/worker_pod.py ] \
       && [ -f /tmp/moteur.neuf/executer_capsule.py ] \
       && [ -f /tmp/moteur.neuf/generateur_scenes.py ]; then
      cp -a /tmp/moteur.neuf/. /opt/moteur/
      MOTEUR_TIRE="oui"
      # La version REELLE, lue dans ce qu'on vient d'installer.
      if [ -f /opt/moteur/VERSION ]; then
        VERSION_MOTEUR="$(tr -d ' \n\r' < /opt/moteur/VERSION)"
        export VERSION_MOTEUR
      fi
      journal "moteur tire — version installee ${VERSION_MOTEUR:-inconnue}"
      raconter "moteur_installe" "${VERSION_MOTEUR:-inconnue}"
    else
      journal "ARCHIVE MOTEUR INCOMPLETE — le moteur embarque est conserve"
      raconter "moteur_archive_incomplete" "$VERSION_MOTEUR_ATTENDUE"
    fi
  else
    # On ne meurt pas : le moteur embarque peut suffire. Mais la sonde
    # comparera les versions, et refusera la machine si elles different.
    journal "MOTEUR NON TIRE — repli sur le moteur embarque ${VERSION_MOTEUR:-dev}"
    raconter "moteur_non_tire" "$CIBLE"
  fi
fi
export MOTEUR_TIRE

# ── 1. La sonde, SOUS DELAI ───────────────────────────────────────────────
# Sans `timeout`, un Chromium qui ne rend pas la main bloque le conteneur pour
# toujours : la machine facture, ne dit rien, et rien ne peut la distinguer
# d'une image encore en cours de tirage.
raconter "sonde_lancee"
cd /opt/rendu
RAPPORT=$(SONDE_SORTIE=/workspace/sonde timeout "$SONDE_DELAI" node /opt/rendu/sonde_pret.js 2>&1)
CODE=$?
echo "$RAPPORT"

if [ "$CODE" -eq 124 ]; then
  journal "SONDE BLOQUEE — delai de ${SONDE_DELAI}s depasse"
  raconter "sonde_bloquee" "delai ${SONDE_DELAI}s"
else
  raconter "sonde_finie" "code $CODE"
fi

# ── 2. Le rapport, reussi ou non ──────────────────────────────────────────
# Un echec silencieux de readiness est pire qu'un echec franc : la machine
# facturerait sans jamais rien rendre, et personne ne saurait pourquoi.
if [ -n "$SUPABASE_URL" ] && [ -n "$POD_ID" ] && [ -n "$POD_JETON" ]; then
  CORPS=$(jq -nc --arg p "$POD_ID" --arg j "$POD_JETON" \
            --argjson r "$(echo "$RAPPORT" | jq -c . 2>/dev/null || echo '{}')" \
            '{p_pod_id:$p, p_jeton:$j, p_rapport:$r}' 2>/dev/null)
  if [ -n "$CORPS" ]; then
    REP=$(curl -s --max-time 30 -X POST "$SUPABASE_URL/rest/v1/rpc/gpu_pod_readiness" \
      -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
      -H "Content-Type: application/json" -d "$CORPS" 2>&1)
    journal "readiness remontee — $(echo "$REP" | head -c 120)"
  else
    journal "rapport illisible — readiness non remontee"
    raconter "readiness_illisible"
  fi
fi

if [ "$CODE" -ne 0 ]; then
  journal "SONDE ECHOUEE — cette machine ne reclamera aucune tache"
  raconter "inapte" "code $CODE"
  # On ne meurt PAS : le controleur doit pouvoir lire l'etat et decider de
  # remplacer la machine. Un conteneur qui s'arrete brutalement laisse un Pod
  # « RUNNING » que plus personne n'interroge.
  while true; do sleep 300; raconter "inapte_en_attente"; done
fi

journal "PRETE — reclamation des taches"
raconter "prete"

# PAS D'`exec` : on veut pouvoir DIRE que le worker est mort. Avec `exec`, le
# shell disparait, et une sortie immediate du worker ne laisse aucune trace --
# c'est exactement ce qui a rendu la boucle de redemarrage du 12/08 muette.
python3 /opt/moteur/worker_pod.py
CODE_WORKER=$?
journal "WORKER TERMINE — code $CODE_WORKER"
raconter "worker_termine" "code $CODE_WORKER"

# On ne meurt pas : un conteneur qui s'arrete laisse un Pod « RUNNING » que
# plus personne n'interroge, et RunPod le relance en boucle sans que rien ne
# l'explique.
while true; do sleep 300; raconter "worker_absent" "code $CODE_WORKER"; done
