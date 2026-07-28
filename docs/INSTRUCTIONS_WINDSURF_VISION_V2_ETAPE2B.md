# Instructions Windsurf — Vision v2, étape 2b : formules + vitesse

**Date** : 25 juillet 2026
**Serveur** : `lws-nexiom` **UNIQUEMENT**.

## Où on en est

Le cahier continu fonctionne : écriture manuscrite Caveat, lignes de cahier, marge rouge,
défilement de la caméra, titres en bulle, écriture visible **en cours** sur les images de
contrôle. **La mise en scène est là.**

Deux défauts relevés sur ces images, tous deux corrigés :

**1. Les formules affichaient le LaTeX brut** — `x = \frac{-b \pm \sqrt{\Delta}}{2a}`
au lieu de la formule composée. Le module de page acceptait un moteur de rendu de
formules mais n'en recevait aucun. Il utilise désormais KaTeX par défaut, celui que le
moteur Vision sait déjà appeler.

**2. Le rendu prenait 2,33× le temps réel** (1 min 59 pour 51 s de vidéo). Décomposition :

| | Temps | Nature |
|---|---|---|
| Enregistrement | 53 s | incompressible (c'est le temps réel) |
| Encodage + lancement | 66 s | **compressible** |

Le réencodage était donc plus coûteux que la capture elle-même. Préréglage `veryfast`
appliqué : projection **≈ 1,5× le temps réel**, soit sous l'objectif annoncé de 2×.

## RÈGLES ABSOLUES

1. Agis **uniquement** sur `lws-nexiom`.
2. **Ne modifie AUCUN fichier du dépôt Git**, ne committe rien.
3. **Ne touche pas à Supabase**, ne redémarre aucun service.
4. Ne supprime rien.
5. **Rapporte la sortie brute, sans interpréter.**

---

## ÉTAPE 1 — Copier les deux fichiers corrigés

```powershell
scp academia_bobodo_backend/whiteboard_vision/whiteboard_page_builder.py ^
    academia_bobodo_backend/whiteboard_vision/whiteboard_video_capture.py ^
    lws-nexiom:/opt/whiteboard-worker/vision_engine/
```

## ÉTAPE 2 — Vérifier que KaTeX est bien appelé

```bash
ssh lws-nexiom "cd /opt/whiteboard-worker/vision_engine
export NODE_PATH=/opt/whiteboard-worker/node_modules
python3 -c \"
from whiteboard_page_builder import _default_katex
out = _default_katex(r'x = \\\\frac{-b \\\\pm \\\\sqrt{\\\\Delta}}{2a}')
print('LONGUEUR :', len(out))
print('KATEX PRESENT :', 'katex' in out)
print(out[:160])
\""
```
Attendu : `KATEX PRESENT : True` et du HTML commençant par `<span class="katex"`.
Si `False`, **STOP + rapport** : les formules resteraient en LaTeX brut.

## ÉTAPE 3 — Refaire le cours complet et CHRONOMÉTRER

```bash
ssh lws-nexiom "cd /opt/whiteboard-worker/vision_engine
export NODE_PATH=/opt/whiteboard-worker/node_modules
python3 -c \"
import json, logging
from pathlib import Path
logging.basicConfig(level=logging.INFO)
from whiteboard_page_builder import write_page
sb = json.loads(Path('test_storyboard.json').read_text(encoding='utf-8'))
sb['writing_style'] = 'handwriting'
p, d = write_page(sb, Path('/tmp/cours2.html'))
print('DUREE', d)
\" | tee /tmp/plan.txt
DUR=\$(grep '^DUREE' /tmp/plan.txt | awk '{print \$2}')
echo \"=== enregistrement de \$DUR s ===\"
time python3 -c \"
import logging; logging.basicConfig(level=logging.INFO)
from pathlib import Path
from whiteboard_video_capture import record_page
print('SORTIE :', record_page(Path('/tmp/cours2.html'), Path('/tmp/cours2.mp4'), float('\$DUR')))
\"
echo '=== duree finale ==='
ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1 /tmp/cours2.mp4
echo '=== images de controle ==='
rm -f /tmp/d_*.png
for t in 8 20 30 40; do ffmpeg -y -v error -ss \$t -i /tmp/cours2.mp4 -frames:v 1 /tmp/d_\$t.png; done
ls /tmp/d_*.png
echo '=== FIN ==='"
```

```powershell
scp lws-nexiom:/tmp/d_*.png .
```

**Le chiffre décisif** : le `time` réel divisé par la durée de la vidéo.
Objectif : **sous 2×**. Précédemment 2,33×.

---

## RAPPORT À RENDRE

1. Étape 2 : `KATEX PRESENT` et le début du HTML.
2. Étape 3 : la durée planifiée, le `time` réel, la durée `ffprobe`, les lignes `[capture]`.
3. Confirmation que les **quatre PNG** sont rapatriées.
4. Statut final.

Puis **arrête-toi**. Si les formules sont composées et le ratio sous 2×, l'étape 2 est
validée et on branche le tout sur le worker.
