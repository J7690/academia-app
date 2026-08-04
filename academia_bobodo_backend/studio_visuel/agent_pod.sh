#!/bin/bash
# Agent de presence d'un pod GPU RunPod.
#
# Il declare toutes les 60 secondes si la machine SERT A QUELQUE CHOSE. Le
# veilleur cote Supabase eteint celles qui ne servent plus.
#
# POURQUOI CE N'EST PAS « EST-CE QUE QUELQU'UN PARLE ». Le silence ne prouve
# rien : une installation apt/pip ne sollicite pas le GPU, et un rendu de
# quarante minutes ne produit aucune connexion. Prendre le silence pour de
# l'inactivite ferait tuer des machines en plein travail.
#
# « Occupee » vaut pour l'une quelconque de ces CINQ preuves :
#   gpu          : le GPU calcule (utilisation > SEUIL_GPU %)
#   rendu        : un processus de production tourne (blender / comfyui / ffmpeg)
#   installation : un telechargement ou une installation est en cours
#   ecriture     : le disque ecrit massivement -- filet pour l'imprevu
#   session      : quelqu'un est connecte en SSH
# Aucune des cinq -> `rien`, et le compteur d'inactivite commence a courir.
#
# Le jeton n'a aucun pouvoir au-dela du battement de coeur. Meme vole, il ne
# permet que de maintenir SA propre machine en vie -- ce que borne de toute
# facon `max_lifetime_minutes`.
#
# Variables attendues : POD_ID, POD_JETON, SUPABASE_URL, SUPABASE_ANON_KEY
# Usage : nohup /workspace/agent_pod.sh > /workspace/agent.log 2>&1 &

set -u
INTERVALLE=${INTERVALLE:-60}
SEUIL_GPU=${SEUIL_GPU:-10}

for variable in POD_ID POD_JETON SUPABASE_URL SUPABASE_ANON_KEY; do
  if [ -z "${!variable:-}" ]; then
    echo "$(date -Is) variable manquante : $variable" >&2
    exit 1
  fi
done

echo "$(date -Is) agent demarre pour $POD_ID (intervalle ${INTERVALLE}s)"

while true; do
  activite="rien"
  occupe="false"

  # 1. Le GPU calcule-t-il ?
  charge=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)
  if [ -n "${charge:-}" ] && [ "$charge" -ge "$SEUIL_GPU" ] 2>/dev/null; then
    activite="gpu"; occupe="true"
  fi

  # 2. Un processus de production tourne-t-il ? Un encodage ffmpeg ou une
  #    passe de compositing peuvent tres bien laisser le GPU a zero.
  if [ "$occupe" = "false" ] && pgrep -f 'blender|ComfyUI/main.py|ffmpeg' >/dev/null 2>&1; then
    activite="rendu"; occupe="true"
  fi

  # 3. INSTALLE-T-ELLE QUELQUE CHOSE ? Cette question a coute 17 Go et une
  #    machine. Un telechargement de modele, un `apt` ou un `pip` ne sollicitent
  #    ni le GPU ni aucun processus de rendu : l'agent declarait « rien », le
  #    veilleur constatait l'inactivite, et supprimait une machine en plein
  #    travail d'installation.
  #    Une machine qui prepare son environnement travaille tout autant qu'une
  #    machine qui calcule.
  if [ "$occupe" = "false" ] && pgrep -f 'wget|curl|apt-get|dpkg|pip|git-remote|tar ' >/dev/null 2>&1; then
    activite="installation"; occupe="true"
  fi

  # 4. Le disque ecrit-il massivement ? Filet pour tout ce que la liste
  #    ci-dessus ne nomme pas -- une decompression, une copie, un outil qu'on
  #    n'a pas prevu. Mieux vaut garder une machine de trop que perdre une
  #    heure de telechargement.
  if [ "$occupe" = "false" ] && [ -r /proc/diskstats ]; then
    secteurs_avant=$(awk '{s+=$10} END {print s+0}' /proc/diskstats)
    sleep 3
    secteurs_apres=$(awk '{s+=$10} END {print s+0}' /proc/diskstats)
    # 3 Mo en trois secondes : au-dessus, il se passe reellement quelque chose.
    if [ $((secteurs_apres - secteurs_avant)) -gt 6000 ] 2>/dev/null; then
      activite="ecriture"; occupe="true"
    fi
  fi

  # 5. Quelqu'un travaille-t-il dessus ? C'est ce qui protege le prototypage.
  if [ "$occupe" = "false" ] && [ -n "$(who 2>/dev/null)" ]; then
    activite="session"; occupe="true"
  fi

  reponse=$(curl -s --max-time 20 -X POST \
    "$SUPABASE_URL/rest/v1/rpc/gpu_pod_heartbeat" \
    -H "apikey: $SUPABASE_ANON_KEY" \
    -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"p_pod_id\":\"$POD_ID\",\"p_jeton\":\"$POD_JETON\",\"p_busy\":$occupe,\"p_activite\":\"$activite\"}" \
    2>/dev/null)

  echo "$(date -Is) activite=$activite occupe=$occupe reponse=${reponse:-aucune}"

  # Le serveur annonce l'extinction : on s'arrete proprement au lieu d'etre
  # coupe au milieu d'une ecriture de fichier.
  case "${reponse:-}" in
    *terminating*|*terminated*)
      echo "$(date -Is) extinction annoncee par le serveur, arret de l'agent"
      exit 0 ;;
  esac

  sleep "$INTERVALLE"
done
