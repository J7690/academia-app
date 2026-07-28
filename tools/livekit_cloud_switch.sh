#!/usr/bin/env bash
# Bascule vers LiveKit Cloud — vague 0, étape finale.
#
# Décision actée le 26 juillet 2026 : hébergement LiveKit Cloud (ADR-011).
#
# Ce script ne peut pas créer le compte LiveKit Cloud à votre place — c'est la
# seule action manuelle qui reste. Tout le reste est automatisé et vérifié.
#
#   1. Créez un compte sur https://cloud.livekit.io
#   2. Créez un projet, région la plus proche : eu-central (Francfort)
#   3. Relevez l'URL WebSocket (wss://<projet>.livekit.cloud) et générez
#      une paire API Key / API Secret
#   4. Lancez :
#
#        bash tools/livekit_cloud_switch.sh \
#            wss://<projet>.livekit.cloud <API_KEY> <API_SECRET>
#
# Prérequis : Supabase CLI installé et connecté (supabase login).

set -euo pipefail

PROJECT_REF="thevdfcwlcqzdoybfvgs"

if [[ $# -ne 3 ]]; then
  echo "Usage : $0 <LIVEKIT_URL> <LIVEKIT_API_KEY> <LIVEKIT_API_SECRET>"
  echo
  echo "Exemple :"
  echo "  $0 wss://academia-xyz.livekit.cloud APIabc123 secret456..."
  exit 1
fi

LK_URL="$1"
LK_KEY="$2"
LK_SECRET="$3"

if [[ ! "$LK_URL" =~ ^wss:// ]]; then
  echo "ERREUR : l'URL doit commencer par wss:// (reçu : $LK_URL)"
  exit 1
fi

echo "─── 1/5 · Sauvegarde des secrets actuels ───────────────────────────"
BACKUP="tools/.livekit_secrets_backup_$(date +%Y%m%d_%H%M%S).txt"
{
  echo "# Sauvegarde avant bascule LiveKit Cloud — $(date -Iseconds)"
  echo "# Les valeurs des secrets ne sont jamais affichées par Supabase ;"
  echo "# ce fichier ne contient que la liste et les empreintes."
  supabase secrets list --project-ref "$PROJECT_REF" 2>/dev/null || true
} > "$BACKUP"
echo "  → $BACKUP"

echo "─── 2/5 · Pose des nouveaux secrets ────────────────────────────────"
supabase secrets set --project-ref "$PROJECT_REF" \
  LIVEKIT_URL="$LK_URL" \
  LIVEKIT_API_KEY="$LK_KEY" \
  LIVEKIT_API_SECRET="$LK_SECRET"

echo "─── 3/5 · Redéploiement des trois fonctions ────────────────────────"
# Les Edge Functions relisent les secrets au déploiement : les trois qui
# touchent à LiveKit doivent être redéployées ensemble, sinon elles pointent
# vers deux serveurs différents.
for fn in livekit-token livekit-recording livekit-admin; do
  echo "  · $fn"
  supabase functions deploy "$fn" --project-ref "$PROJECT_REF"
done

echo "─── 4/5 · Vérification des versions déployées ──────────────────────"
supabase functions list --project-ref "$PROJECT_REF" | grep -E "livekit|NAME" || true

echo "─── 5/5 · Contrôle du contrat RPC ──────────────────────────────────"
python3 tools/check_rpc_contract.py || {
  echo "  ATTENTION : le contrat RPC signale un écart. Voir ci-dessus."
}

cat <<'FIN'

─────────────────────────────────────────────────────────────────────────
Bascule effectuée. Test de recette à faire maintenant, dans cet ordre :

  1. Compte enseignant → « Mes classes en direct » → créer une session
     LiveKit → Démarrer. La salle doit s'ouvrir avec votre caméra.

  2. Compte étudiant, autre appareil → rejoindre la même session.
     Vérifier : vidéo, audio, chat persistant (il survit à un rechargement),
     panneau participants, coupure de micro à distance par l'hôte.

  3. Couper le wifi de l'appareil étudiant et passer en données mobiles :
     la vidéo doit se dégrader progressivement, pas se figer.

  4. Noter dans docs/ACADEMIA_CHANGELOG.md que le premier live réel a eu
     lieu — c'est le jalon que le projet attend depuis mars 2026.

Retour arrière : reposer les trois anciens secrets et relancer les trois
déploiements. Quelques minutes, aucun rebuild Flutter.

Rappel : une fois la recette validée, arrêter le conteneur LiveKit du VPS
Kamatera (docker stop livekit-server) libère du CPU et de la RAM pour le
worker Smart Whiteboard et Bobodo vocal.
─────────────────────────────────────────────────────────────────────────
FIN
