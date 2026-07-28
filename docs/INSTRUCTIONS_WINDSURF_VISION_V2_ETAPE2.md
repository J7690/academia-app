# Instructions Windsurf — Vision v2, étape 2 : le cahier continu

**Date** : 25 juillet 2026
**Serveur** : `lws-nexiom` **UNIQUEMENT**.

## Où on en est

L'étape 1 est validée : on sait filmer une page animée et la caler au millième
(écart mesuré < 2 % sur trois points de contrôle).

**Étape 2 — la vraie mise en scène.** Un nouveau module construit **UNE page HTML unique**
contenant tout le cours, qui défile comme un cahier :

- écriture **mot par mot**, chaque mot ayant son propre délai (tout en CSS, rien en
  JavaScript — c'est ce qui permet d'enregistrer en temps réel) ;
- la caméra **se pose avant qu'on écrive et ne bouge plus** pendant l'écriture et
  l'annotation (29 paliers d'immobilité sur 40 intervalles dans le test) ;
- annotations **ciblées sur les mots** (`emphasis_target`) : cercle et souligné tracés
  puis effacés, surlignage persistant ;
- **rappel pédagogique** : remontée vers une notion vue plus haut, ré-annotation, retour ;
- lignes de cahier, marge rouge, bandeau fixe avec masque en dégradé.

Vérifié en local : 41 keyframes de défilement strictement croissantes, dans [0 %, 100 %],
défilement de 0 à 3 687 px.

**Aucun fichier existant n'est modifié** : le moteur actuel continue de tourner.

## RÈGLES ABSOLUES

1. Agis **uniquement** sur `lws-nexiom`.
2. **Ne modifie AUCUN fichier du dépôt Git**, ne committe rien.
3. **Ne touche pas à Supabase**, ne redémarre aucun service.
4. Ne supprime rien.
5. **Rapporte la sortie brute, sans interpréter.**

---

## ÉTAPE 1 — Copier le nouveau module et la police

```powershell
scp academia_bobodo_backend/whiteboard_vision/whiteboard_page_builder.py lws-nexiom:/opt/whiteboard-worker/vision_engine/
```

La page cherche la police manuscrite à un chemin absolu. On la met à disposition :

```bash
ssh lws-nexiom "mkdir -p /opt/whiteboard-worker/vision_engine/fonts
cp /opt/whiteboard-engine-remotion/public/fonts/Caveat.ttf /opt/whiteboard-worker/vision_engine/fonts/ 2>/dev/null || echo 'Caveat.ttf introuvable a la source'
ls -la /opt/whiteboard-worker/vision_engine/fonts/"
```

## ÉTAPE 2 — Construire la page à partir d'un VRAI storyboard

```bash
ssh lws-nexiom "cd /opt/whiteboard-worker/vision_engine
python3 -c \"
import json, logging
from pathlib import Path
logging.basicConfig(level=logging.INFO)
from whiteboard_page_builder import write_page, plan, _font_url
sb = json.loads(Path('test_storyboard.json').read_text(encoding='utf-8'))
sb['writing_style'] = 'handwriting'
print('POLICE :', _font_url() or 'ABSENTE')
planned, kf, total, doc_h, recalls = plan(sb)
print(f'blocs={len(planned)} duree={total:.1f}s hauteur={doc_h:.0f}px keyframes={len(kf)} rappels={len(recalls)}')
p, d = write_page(sb, Path('/tmp/cours.html'))
print('PAGE :', p, f'{d:.1f}s')
\""
```

**À rapporter** : la ligne `POLICE :` (doit être un chemin `file://…`, pas `ABSENTE`),
et la ligne `blocs=… duree=…`.

## ÉTAPE 3 — Filmer la page, puis extraire des images réparties

```bash
ssh lws-nexiom "cd /opt/whiteboard-worker/vision_engine
export NODE_PATH=/opt/whiteboard-worker/node_modules
DUR=\$(python3 -c \"
import json
from pathlib import Path
from whiteboard_page_builder import plan
sb=json.loads(Path('test_storyboard.json').read_text(encoding='utf-8'))
sb['writing_style']='handwriting'
print(round(plan(sb)[2],1))
\")
echo \"DUREE PLANIFIEE : \$DUR s\"
echo '=== enregistrement ==='
time python3 -c \"
import logging; logging.basicConfig(level=logging.INFO)
from pathlib import Path
from whiteboard_video_capture import record_page
print('SORTIE :', record_page(Path('/tmp/cours.html'), Path('/tmp/cours.mp4'), float('\$DUR')))
\"
echo '=== duree finale ==='
ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1 /tmp/cours.mp4
echo '=== images de controle ==='
rm -f /tmp/c_*.png
for t in 4 12 22 32 44; do ffmpeg -y -v error -ss \$t -i /tmp/cours.mp4 -frames:v 1 /tmp/c_\$t.png; done
ls /tmp/c_*.png
echo '=== FIN ==='"
```

```powershell
scp lws-nexiom:/tmp/c_*.png .
```

**Ce qui compte** : le rapport entre le `time` réel et la durée de la vidéo. Objectif
annoncé : **sous 2× le temps réel**.

---

## RAPPORT À RENDRE

1. Étape 2 : la ligne `POLICE :` et la ligne `blocs=…`.
2. Étape 3 : la `DUREE PLANIFIEE`, le `time` réel, la durée `ffprobe`, et toutes les
   lignes `[capture]`.
3. Confirmation que les **cinq PNG** sont rapatriées à la racine du dépôt.
4. Statut final.

Puis **arrête-toi**. Claude regarde les images : écriture en cours, caméra qui descend,
annotations sur les bons mots.
