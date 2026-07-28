# Instructions Windsurf — Vision v2 : ralentir l'écriture et la caméra

**Date** : 25 juillet 2026
**Serveur** : `lws-nexiom` **UNIQUEMENT**.

## Les remarques du propriétaire et ce qu'elles révèlent

**« Les écritures sont trop rapides »** et **« encore des écritures qui s'écrivent sur
d'autres »** ont, selon toute vraisemblance, **la même cause**.

Le code place désormais les blocs en flux naturel — vérifié : plus aucun positionnement
à une hauteur calculée. Dans ce mode, deux blocs ne *peuvent pas* se chevaucher, et la
mesure dans le navigateur l'a confirmé (0 chevauchement sur 14 blocs, 45 px d'écart
minimal). Or sur les captures, le texte apparaît **dédoublé et flou**, alors que le reste
de l'image est net : c'est la signature d'un **filé de mouvement**, la caméra défilant
assez vite pour que l'image capte deux positions du même texte.

Deux réglages, donc :

| Réglage | Avant | Après |
|---|---|---|
| Écriture (normale) | 20 car/s | **12 car/s** |
| Écriture (lente, définitions) | 13 car/s | **8 car/s** |
| Durée d'un mouvement de caméra | 0,9 s | **1,8 s** |
| Courbe du défilement | linéaire | **amortie** (départ et arrêt en douceur) |

Repère retenu : un adulte lit environ 15 caractères par seconde à voix haute. Un
professeur qui écrit au tableau va plus lentement encore, car l'élève doit suivre du
regard *et* comprendre. On se cale donc **sous** le rythme de lecture.

Effet : le cours de test passe de 52 à 63 secondes. C'est voulu.

## Ce qui n'est PAS corrigé par ce lot

**« L'audio et l'écriture ne disent pas la même chose au même moment. »**

Ce n'est pas un réglage, c'est une limite de conception : le générateur produit **une
narration par scène** (une phrase de professeur) alors qu'une scène contient **plusieurs
blocs** écrits l'un après l'autre. La voix commente donc la scène entière pendant qu'on
écrit trois ou quatre choses différentes. Les caler à la seconde près est impossible en
l'état.

Le correctif demande une **narration par bloc** — donc une évolution du générateur, puis
une piste audio découpée par bloc. C'est le prochain chantier, à traiter à part.

## RÈGLES ABSOLUES

1. Agis **uniquement** sur `lws-nexiom`.
2. **Ne modifie AUCUN fichier du dépôt Git**, ne committe rien.
3. **Ne touche pas à Supabase**, ne supprime rien.
4. **Rapporte la sortie brute, sans interpréter.**

---

## ÉTAPE 1 — Copier le module

```powershell
scp academia_bobodo_backend/whiteboard_vision/whiteboard_page_builder.py lws-nexiom:/opt/whiteboard-worker/vision_engine/
```

## ÉTAPE 2 — Vérifier les nouveaux réglages

```bash
ssh lws-nexiom "cd /opt/whiteboard-worker/vision_engine
export NODE_PATH=/opt/whiteboard-worker/node_modules
python3 -c \"
from whiteboard_page_builder import CPS, SCROLL_SEC
print('RYTHME :', CPS)
print('CAMERA :', SCROLL_SEC, 's')
\""
```
Attendu : `{'slow': 8, 'normal': 12, 'fast': 17}` et `1.8 s`.

## ÉTAPE 3 — Rendu de contrôle

```bash
ssh lws-nexiom "cd /opt/whiteboard-worker/vision_engine
export NODE_PATH=/opt/whiteboard-worker/node_modules
time python3 -c \"
import json, logging
from pathlib import Path
logging.basicConfig(level=logging.INFO)
from whiteboard_vision_v2 import render_storyboard_v2
sb = json.loads(Path('test_storyboard.json').read_text(encoding='utf-8'))
sb['writing_style'] = 'handwriting'
narr = [{'scene_index': i, 'audio_path': None, 'duration_sec': d}
        for i, d in enumerate([12.0, 8.0, 20.0, 6.0])]
print('SORTIE :', render_storyboard_v2(sb, Path('/tmp/v2lent'), narr, None))
\"
ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1 /tmp/v2lent/cours_muet.mp4
echo '=== images PENDANT un mouvement de camera (test du file) ==='
rm -f /tmp/r_*.png
for t in 18 19 20 30 45; do ffmpeg -y -v error -ss \$t -i /tmp/v2lent/cours_muet.mp4 -frames:v 1 /tmp/r_\$t.png; done
ls /tmp/r_*.png
echo '=== FIN ==='"
```

```powershell
scp lws-nexiom:/tmp/r_*.png .
```

Les trois images rapprochées (18, 19, 20 s) servent à vérifier qu'il n'y a plus de
traînée pendant un déplacement.

---

## RAPPORT À RENDRE

1. Étape 2 : les deux lignes de réglages.
2. Étape 3 : les lignes `[vision2]`, le `time` réel, la durée.
3. Confirmation que les **cinq PNG** sont rapatriées.
4. Statut final.

Puis **arrête-toi**.
