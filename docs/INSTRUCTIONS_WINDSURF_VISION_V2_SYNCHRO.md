# Instructions Windsurf — Vision v2 : synchro voix/écriture, chevauchements, écriture continue

**Date** : 25 juillet 2026
**Serveur** : `lws-nexiom` **UNIQUEMENT**.

## Les trois défauts signalés par le propriétaire, et leur cause

**1. La voix et l'écriture ne sont pas synchronisées.**
L'écriture allait à vitesse fixe, et la scène durait le plus long des deux : soit le
texte finissait bien avant la voix (écran figé pendant qu'on parle), soit l'inverse.
→ La vitesse d'écriture de chaque scène est maintenant **calée sur la durée de sa
narration** : le professeur écrit pendant qu'il parle, et les deux finissent ensemble.
Seule la part « écriture » est étirée ; les annotations gardent leur durée, sinon le
geste deviendrait illisible.

**2. Des écritures se superposent.**
Les blocs étaient placés à une hauteur **estimée** en Python (« environ 30 caractères par
ligne »). Sur du contenu réel — un diagramme, une définition longue — l'estimation était
fausse, d'où les chevauchements visibles sur tes captures.
→ Les blocs s'empilent désormais **naturellement** (ils ne peuvent donc plus se
chevaucher), et leurs positions réelles sont **mesurées dans le navigateur** avant le
tournage. La caméra vise juste, sur des chiffres et non des approximations.

**3. L'écriture arrive bloc par bloc, pas comme une main qui écrit.**
Chaque bloc apparaissait d'un coup en fondu, avant que ses mots ne se révèlent : l'œil
percevait « un bloc », pas une main.
→ Le fondu de bloc est supprimé. Seuls les mots se révèlent, l'un après l'autre. Les
encadrés colorés se teintent progressivement pendant l'écriture au lieu d'apparaître.

## Nouveau : le rendu se fait en DEUX passes

1. page construite, ouverte dans le navigateur pour **relever les positions réelles** ;
2. page reconstruite avec les mouvements de caméra calculés sur ces mesures, puis filmée.

Si la mesure échoue, on retombe sur les positions estimées : moins précis, mais l'étudiant
a sa vidéo.

## RÈGLES ABSOLUES

1. Agis **uniquement** sur `lws-nexiom`.
2. **Ne modifie AUCUN fichier du dépôt Git**, ne committe rien.
3. **Ne touche pas à Supabase**, ne supprime rien.
4. **Rapporte la sortie brute, sans interpréter.**

---

## ÉTAPE 1 — Copier les trois fichiers

```powershell
scp academia_bobodo_backend/whiteboard_vision/whiteboard_page_builder.py ^
    academia_bobodo_backend/whiteboard_vision/whiteboard_vision_v2.py ^
    academia_bobodo_backend/whiteboard_vision/measure_page.js ^
    lws-nexiom:/opt/whiteboard-worker/vision_engine/
```

Empreintes attendues :
```
4e73f712602ce42d327542162f5b12f6  whiteboard_page_builder.py
cf3bb2b182449d3d748c175a11161c0c  whiteboard_vision_v2.py
5e7d6478278bf5f62313d5a99abf597c  measure_page.js
```

## ÉTAPE 2 — Vérifier la mesure des positions

```bash
ssh lws-nexiom "cd /opt/whiteboard-worker/vision_engine
export NODE_PATH=/opt/whiteboard-worker/node_modules
md5sum whiteboard_page_builder.py whiteboard_vision_v2.py measure_page.js
node --check measure_page.js && echo 'SYNTAXE JS OK'
python3 -c \"
import json, logging
from pathlib import Path
logging.basicConfig(level=logging.INFO)
from whiteboard_page_builder import write_page
sb = json.loads(Path('test_storyboard.json').read_text(encoding='utf-8'))
sb['writing_style'] = 'handwriting'
p, d = write_page(sb, Path('/tmp/mesure.html'))
print('PAGE', p, d)
\"
echo '=== mesure des positions reelles ==='
node measure_page.js /tmp/mesure.html | head -c 600
echo
echo '=== FIN ==='"
```

Attendu : une liste JSON de blocs avec leurs `top` et `height` réels, et un `docHeight`.
Les `top` doivent être **strictement croissants** (preuve qu'il n'y a plus de
chevauchement). Si la sortie est vide → **STOP + rapport**.

## ÉTAPE 3 — Rendu complet avec les deux passes

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
print('SORTIE :', render_storyboard_v2(sb, Path('/tmp/v2sync'), narr, None))
\"
ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1 /tmp/v2sync/cours_muet.mp4
rm -f /tmp/s_*.png
for t in 6 14 24 34 44; do ffmpeg -y -v error -ss \$t -i /tmp/v2sync/cours_muet.mp4 -frames:v 1 /tmp/s_\$t.png; done
ls /tmp/s_*.png
echo '=== FIN ==='"
```

```powershell
scp lws-nexiom:/tmp/s_*.png .
```

**À rapporter en priorité** : la ligne `[vision2] N blocs mesures dans le navigateur`.
Si elle dit « mesure indisponible », les chevauchements persisteront.

---

## RAPPORT À RENDRE

1. Étape 2 : les empreintes et **le JSON des positions mesurées**.
2. Étape 3 : les lignes `[vision2]`, le `time` réel, la durée.
3. Confirmation que les **cinq PNG** sont rapatriées.
4. Statut final.

Puis **arrête-toi**. Claude vérifie sur les images qu'il n'y a plus de superposition et
que l'écriture est continue.
