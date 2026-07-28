# Instructions Windsurf — Vision v2, étape 1c : calage exact

**Date** : 25 juillet 2026
**Serveur** : `lws-nexiom` **UNIQUEMENT**.

## Où on en est

La durée est désormais exacte (10,000 s pour 10,0 demandées) — mais les trois points de
contrôle ont révélé un décalage : la barre était à 33,7 / 59,3 / 84,6 % au lieu de
25 / 50 / 75 %. **Un écart constant de ~9,3 %**, soit 0,93 s d'avance à chaque instant.

Diagnostic : le fichier brut comporte une amorce (avant le chargement de la page) **mais
aussi une traîne** (le temps que la vidéo soit finalisée après la fin de l'animation).
Rogner « les 10 dernières secondes » faisait donc démarrer 0,93 s trop loin dans
l'animation.

Correctif : `record_scene.js` **mesure** maintenant l'amorce réelle (temps entre le début
de l'enregistrement et le démarrage des animations) et la communique ; on coupe
exactement là, au lieu de se caler sur la fin.

## RÈGLES ABSOLUES

1. Agis **uniquement** sur `lws-nexiom`.
2. **Ne modifie AUCUN fichier du dépôt Git**, ne committe rien.
3. **Ne touche pas à Supabase**, ne redémarre aucun service.
4. Ne supprime rien : le moteur actuel doit continuer de tourner.
5. **Rapporte la sortie brute, sans interpréter.**

---

## ÉTAPE 1 — Copier les deux fichiers corrigés

```powershell
scp academia_bobodo_backend/whiteboard_vision/record_scene.js ^
    academia_bobodo_backend/whiteboard_vision/whiteboard_video_capture.py ^
    lws-nexiom:/opt/whiteboard-worker/vision_engine/
```

## ÉTAPE 2 — Rejouer le test et remesurer les trois points

```bash
ssh lws-nexiom "cd /opt/whiteboard-worker/vision_engine
export NODE_PATH=/opt/whiteboard-worker/node_modules
node --check record_scene.js && echo 'SYNTAXE JS OK'
echo '=== enregistrement + rognage ==='
time python3 -c \"
import logging; logging.basicConfig(level=logging.INFO)
from pathlib import Path
from whiteboard_video_capture import record_page
print('SORTIE :', record_page(Path('/tmp/anim_test.html'), Path('/tmp/anim_v3.mp4'), 10.0))
\"
echo '=== duree finale ==='
ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1 /tmp/anim_v3.mp4
echo '=== trois points de controle ==='
for t in 2.5 5 7.5; do ffmpeg -y -v error -ss \$t -i /tmp/anim_v3.mp4 -frames:v 1 /tmp/v3_t\$t.png; done
ls -la /tmp/v3_t*.png
echo '=== FIN ==='"
```

```powershell
scp lws-nexiom:/tmp/v3_t2.5.png lws-nexiom:/tmp/v3_t5.png lws-nexiom:/tmp/v3_t7.5.png .
```

**Point important à rapporter** : la ligne de journal
`[capture] enregistre en ... s, amorce mesuree X.XX s` — c'est la mesure qui remplace
l'estimation, et je veux voir sa valeur.

---

## RAPPORT À RENDRE

1. Toutes les lignes `[capture]` (amorce mesurée, point de coupe, écart final).
2. La durée `ffprobe`.
3. Confirmation que les **trois PNG v3** sont rapatriées à la racine du dépôt.
4. Statut final.

Puis **arrête-toi**. Si la barre tombe à 25 / 50 / 75 %, le calage est exact et on passe
au cahier continu — la vraie mise en scène.
