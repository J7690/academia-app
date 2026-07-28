# Instructions Windsurf — Vision v2, étape 2c : formule affichée une seule fois

**Date** : 25 juillet 2026
**Serveur** : `lws-nexiom` **UNIQUEMENT**.

## Où on en est — l'objectif de vitesse est ATTEINT

| | Temps de rendu | Durée vidéo | Ratio |
|---|---|---|---|
| Préréglage par défaut | 119,5 s | 51,2 s | 2,33× |
| **Préréglage `veryfast`** | **75,5 s** | **51,1 s** | **1,48×** |

Objectif annoncé : sous 2×. **Atteint.** Projection sur un cours réel de 2 min 35 :
**environ 3 min 40 de rendu**, contre 12 à 20 minutes avec Remotion.

## Ce qui a été corrigé depuis ton dernier rapport

Ton contrôle a bien fonctionné : `COUCHE VISUELLE : False` signalait que mon filtre
supprimait **la mauvaise couche**. Le motif cherchait `</span></span>`, or ces deux
balises n'apparaissent qu'**après** la partie visible de la formule : le filtre emportait
donc tout, et la formule aurait purement et simplement disparu.

Le motif se termine désormais sur `</math></span>`, qui délimite sans ambiguïté la fin de
la couche MathML. Vérifié sur la structure réelle produite par KaTeX.

Rappel du contexte : KaTeX produit une couche visuelle **et** une couche MathML, et c'est
sa feuille de style qui masque la seconde. Deux protections sont en place — la feuille de
style est chargée depuis le disque (aucune dépendance réseau), et la couche MathML est
retirée du HTML.

## RÈGLES ABSOLUES

1. Agis **uniquement** sur `lws-nexiom`.
2. **Ne modifie AUCUN fichier du dépôt Git**, ne committe rien.
3. **Ne touche pas à Supabase**, ne redémarre aucun service.
4. **Rapporte la sortie brute, sans interpréter.**
5. Si un contrôle échoue, **arrête-toi** (comme tu viens de le faire — c'était juste).

---

## ÉTAPE 1 — Copier le module corrigé

```powershell
scp academia_bobodo_backend/whiteboard_vision/whiteboard_page_builder.py lws-nexiom:/opt/whiteboard-worker/vision_engine/
```

## ÉTAPE 2 — Vérifier les deux couches

```bash
ssh lws-nexiom "cd /opt/whiteboard-worker/vision_engine
export NODE_PATH=/opt/whiteboard-worker/node_modules
python3 -c \"
from whiteboard_page_builder import _katex_css_url, _default_katex
print('CSS KATEX :', _katex_css_url() or 'ABSENTE')
out = _default_katex(r'\\\\Delta = b^2 - 4ac')
print('MATHML RETIRE  :', 'katex-mathml' not in out)
print('COUCHE VISUELLE:', 'katex-html' in out)
print('EXTRAIT :', out[:120])
\""
```

**Les deux doivent être `True`.** Si `COUCHE VISUELLE` est encore `False`, **STOP +
rapport** avec l'extrait affiché.

## ÉTAPE 3 — Refaire le cours et vérifier à l'image

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
p, d = write_page(sb, Path('/tmp/cours3.html'))
print('DUREE', d)
\" | tee /tmp/plan3.txt
DUR=\$(grep '^DUREE' /tmp/plan3.txt | awk '{print \$2}')
echo \"=== enregistrement de \$DUR s ===\"
time python3 -c \"
import logging; logging.basicConfig(level=logging.INFO)
from pathlib import Path
from whiteboard_video_capture import record_page
print('SORTIE :', record_page(Path('/tmp/cours3.html'), Path('/tmp/cours3.mp4'), float('\$DUR')))
\"
echo '=== duree finale ==='
ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1 /tmp/cours3.mp4
echo '=== images de controle ==='
rm -f /tmp/e_*.png
for t in 10 20 30 42; do ffmpeg -y -v error -ss \$t -i /tmp/cours3.mp4 -frames:v 1 /tmp/e_\$t.png; done
ls /tmp/e_*.png
echo '=== FIN ==='"
```

```powershell
scp lws-nexiom:/tmp/e_*.png .
```

---

## RAPPORT À RENDRE

1. Étape 2 : les quatre lignes (chemin CSS, MathML retiré, couche visuelle, extrait).
2. Étape 3 : le `time` réel et la durée `ffprobe`.
3. Confirmation que les **quatre PNG** sont rapatriées à la racine du dépôt.
4. Statut final.

Puis **arrête-toi**. Si la formule n'apparaît qu'une fois, l'étape 2 est close et on
branche Vision v2 sur le worker — c'est-à-dire en production.
