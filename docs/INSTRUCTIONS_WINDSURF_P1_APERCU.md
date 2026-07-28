# P1 — Diagnostic de l'aperçu instantané (exécution stricte)

> **Contexte mesuré (Claude, 28/07)** : sur **71 rendus réussis, 0 aperçu publié**.
> Le seul `preview.mp4` du bucket est un test manuel (`renders/test-apercu-0001/preview.mp4`).
> Conséquence : l'étudiant attend le rendu **complet** (jusqu'à 6 min 41 s) au lieu des ~15-30 s prévus.
> Le code est en place et les seuils sont respectés (vidéos de 120-201 s ≫ `MIN_DURATION_FOR_PREVIEW=60`).
> Donc **l'aperçu échoue à l'exécution** et l'exception est avalée par le `except` de
> `record_page_parallel` (« apercu non publie — rendu poursuivi »).

## RÈGLES
- **Diagnostic uniquement.** Ne corrige rien tant que la cause n'est pas identifiée et validée.
- Ne touche à aucun autre service, ni à Supabase, ni au pare-feu.
- À la moindre ambiguïté → STOP + rapport.

## Tâche 1 — Récupérer la trace réelle du dernier rendu
```bash
ssh lws-nexiom "journalctl -u whiteboard-worker --since '3 days ago' --no-pager | grep -iE 'apercu|APERCU|preview|tranches en parallele' | tail -40"
```
On cherche précisément :
- `[capture] N tranches en parallele (total X s), dont un apercu de 15 s` → l'aperçu **est demandé**
- `[capture] apercu pret en X s` → la tranche **est produite**
- `[capture] apercu non publie (<ERREUR>)` → **la ligne décisive : l'erreur exacte**
- `APERCU publie` → succès (ne devrait pas apparaître)

## Tâche 2 — Vérifier l'hypothèse principale (upload dans un thread)
`_publish_preview` est appelé depuis un thread de capture, alors que le worker est asyncio.
Vérifier que `upload_preview_sync` est bien **synchrone** (pas de `await`/boucle asyncio) :
```bash
ssh lws-nexiom "sed -n '40,95p' /opt/whiteboard-worker/whiteboard_upload_renderer.py"
```

## Tâche 3 — Test isolé de l'upload (reproduire hors rendu)
```bash
ssh lws-nexiom "cd /opt/whiteboard-worker && set -a && . ./.env && set +a && python3 -c \"
from pathlib import Path
import whiteboard_upload_renderer as u
p = Path('/tmp/diag_preview.mp4')
import subprocess
subprocess.run(['ffmpeg','-y','-v','error','-f','lavfi','-i','color=c=white:s=720x1280:d=3','-c:v','libx264','-pix_fmt','yuv420p',str(p)],check=True)
print('upload ->', u.upload_preview_sync(p, 'diag-p1-0001'))
\""
```
- Si ça **réussit** → l'upload marche seul ; le problème est le **contexte d'appel** (thread) ou le
  chemin du fichier de tranche.
- Si ça **échoue** → l'erreur affichée est la cause racine (droits, clé, RLS storage, réseau).

## RAPPORT ATTENDU
1. Les lignes trouvées en Tâche 1 (surtout `apercu non publie (...)` avec l'erreur complète).
2. La sortie de la Tâche 3.
3. Ton verdict en une phrase : l'aperçu échoue à l'étape X pour la raison Y.
Puis **arrête-toi**. Claude fournira le correctif ciblé.
