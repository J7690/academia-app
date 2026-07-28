# Instructions Windsurf — Vision v2, étape 1b : caler la durée au cordeau

**Date** : 25 juillet 2026
**Serveur** : `lws-nexiom` **UNIQUEMENT**.

## Où on en est

L'enregistrement fonctionne : l'animation a bien tourné pendant la capture (barre verte à
~45 % à mi-parcours). **Le principe de Vision v2 est validé.**

Reste un défaut : le fichier dure **11,4 s** pour 10 s demandées. Playwright commence à
filmer dès l'ouverture du navigateur, donc avant le chargement de la page. Le contrôle de
durée a d'ailleurs bien joué son rôle en signalant l'écart (14 %).

Le code ajoute désormais un **rognage** : on ne garde que les dernières secondes utiles,
puis on encode directement en MP4 lisible sur mobile. Cette étape vérifie que le calage
est exact — et une simple durée ne suffit pas à le prouver, il faut vérifier que
l'animation est **à la bonne position** aux bons instants.

## RÈGLES ABSOLUES

1. Agis **uniquement** sur `lws-nexiom`.
2. **Ne modifie AUCUN fichier du dépôt Git**, ne committe rien.
3. **Ne touche pas à Supabase**, ne redémarre aucun service.
4. Ne supprime rien : le moteur actuel doit continuer de tourner.
5. **Rapporte la sortie brute, sans interpréter.**

---

## ÉTAPE 1 — Copier le fichier corrigé

```powershell
scp academia_bobodo_backend/whiteboard_vision/whiteboard_video_capture.py lws-nexiom:/opt/whiteboard-worker/vision_engine/
```

## ÉTAPE 2 — Rejouer le test, puis mesurer TROIS points

La page de test fait grandir une barre verte **linéairement** de 0 à 100 % en 10 s. Après
rognage, la barre doit donc occuper **25 % à t=2,5 s**, **50 % à t=5 s**, **75 % à
t=7,5 s**. Ces trois points prouvent le calage bien mieux qu'une durée seule.

```bash
ssh lws-nexiom "cd /opt/whiteboard-worker/vision_engine
export NODE_PATH=/opt/whiteboard-worker/node_modules
echo '=== enregistrement + rognage ==='
time python3 -c \"
import logging; logging.basicConfig(level=logging.INFO)
from pathlib import Path
from whiteboard_video_capture import record_page
out = record_page(Path('/tmp/anim_test.html'), Path('/tmp/anim_v2.mp4'), 10.0)
print('SORTIE :', out)
\"
echo '=== duree finale ==='
ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1 /tmp/anim_v2.mp4
echo '=== trois points de controle ==='
for t in 2.5 5 7.5; do ffmpeg -y -v error -ss \$t -i /tmp/anim_v2.mp4 -frames:v 1 /tmp/v2_t\$t.png; done
ls -la /tmp/v2_t*.png
echo '=== FIN ==='"
```

Puis rapatrie les trois images :
```powershell
scp lws-nexiom:/tmp/v2_t2.5.png lws-nexiom:/tmp/v2_t5.png lws-nexiom:/tmp/v2_t7.5.png .
```

**Attendu** :
- `duration` entre **9,2 et 10,8 s** ;
- aucune exception Python (si la durée était hors tolérance, le code lève une erreur
  volontairement — dans ce cas, colle le message complet) ;
- le `time` réel autour de 15-30 s.

---

## RAPPORT À RENDRE

1. La sortie complète de l'étape 2, y compris les lignes de journal `[capture]`
   (elles indiquent la durée brute, l'amorce rognée et l'écart final).
2. La durée `ffprobe`.
3. Confirmation que les **trois PNG** sont rapatriées à la racine du dépôt.
4. Statut final.

Puis **arrête-toi**. Claude mesure la position de la barre sur les trois images : si elle
est à 25 / 50 / 75 %, le calage est exact et on passe au cahier continu.
