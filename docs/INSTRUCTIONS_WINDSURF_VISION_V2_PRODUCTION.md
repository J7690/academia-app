# Instructions Windsurf — Vision v2 en production + inventaire disque

**Date** : 25 juillet 2026
**Serveur** : `lws-nexiom` **UNIQUEMENT**.

## Où on en est

Vision v2 est validé sur banc d'essai : écriture manuscrite, cahier qui défile, formules
KaTeX affichées une seule fois, calage à 0,1 %, **1,48× le temps réel** (objectif < 2×).

Il reste à le brancher sur le worker, et à **mesurer** ce qui occupe le disque avant de
supprimer quoi que ce soit.

## Ce qui a changé dans le code

- Le worker n'importe plus le moteur Remotion (l'import ouvrait son dossier à chaque
  démarrage, ce qui empêchait de l'archiver proprement).
- La branche `engine=remotion` ne rend plus avec Remotion : elle **redirige vers
  Vision v2**. Un storyboard généré avant la bascule reste donc rendable — priver un
  étudiant de sa vidéo pour une raison qui ne le concerne pas serait absurde.
- Nouvelle branche `engine=vision2`, qui **n'accepte jamais de dégrader en silence**.

## RÈGLES ABSOLUES

1. Agis **uniquement** sur `lws-nexiom`.
2. **Ne modifie AUCUN fichier du dépôt Git**, ne committe rien.
3. **Ne touche pas à Supabase**, n'ajoute ni ne modifie aucun secret.
4. **Ne modifie pas le `.env`.**
5. **NE SUPPRIME RIEN.** L'étape 4 ne fait que **mesurer**. La suppression viendra après
   validation d'un rendu réel — supprimer le filet avant d'avoir vérifié le remplaçant
   serait exactement l'erreur à ne pas commettre.
6. **Rapporte la sortie brute, sans interpréter.**

---

## ÉTAPE 1 — Copier les deux fichiers

```powershell
scp academia_bobodo_backend/whiteboard_vision/whiteboard_vision_v2.py lws-nexiom:/opt/whiteboard-worker/vision_engine/
scp academia_bobodo_backend/whiteboard_render_worker.py lws-nexiom:/opt/whiteboard-worker/
```

Empreinte attendue du worker : `488d3d5a7fbc57bdd7cb2457570fd5b1`

## ÉTAPE 2 — Vérifier le worker

```bash
ssh lws-nexiom "cd /opt/whiteboard-worker
export NODE_PATH=/opt/whiteboard-worker/node_modules
md5sum whiteboard_render_worker.py
python3 -c \"import ast; ast.parse(open('whiteboard_render_worker.py',encoding='utf-8').read()); print('SYNTAXE OK')\"
python3 -c \"
import sys; sys.path.insert(0, '/opt/whiteboard-worker/vision_engine')
from whiteboard_vision_v2 import render_storyboard_v2, planned_duration
print('IMPORT VISION V2 : OK')
\"
echo '--- le worker ne doit plus importer Remotion ---'
grep -c 'render_bridge' whiteboard_render_worker.py || echo '0 (attendu)'"
```

Attendu : l'empreinte, `SYNTAXE OK`, `IMPORT VISION V2 : OK`, et **0** occurrence de
`render_bridge`. Si l'import de Vision v2 échoue → **STOP + rapport**.

## ÉTAPE 3 — Redémarrer le worker

```bash
ssh lws-nexiom "systemctl restart whiteboard-worker && sleep 4 && systemctl is-active whiteboard-worker
journalctl -u whiteboard-worker -n 25 --no-pager | grep -v 'Found 0 queued' | grep -v httpx | tail -12"
```

Attendu : `active`, aucun `Traceback`.

## ÉTAPE 4 — INVENTAIRE DISQUE (mesure seulement, AUCUNE suppression)

```bash
ssh lws-nexiom "echo '=== espace global ==='
df -h / | tail -1
echo
echo '=== les 15 plus gros dossiers de /opt ==='
du -sh /opt/* 2>/dev/null | sort -rh | head -15
echo
echo '=== detail du moteur Remotion (candidat n1 a l archivage) ==='
du -sh /opt/whiteboard-engine-remotion 2>/dev/null
du -sh /opt/whiteboard-engine-remotion/* 2>/dev/null | sort -rh | head -8
echo
echo '=== fichiers temporaires de rendu accumules ==='
du -sh /tmp 2>/dev/null
ls -la /tmp/*.mp4 /tmp/*.webm 2>/dev/null | head -20
echo
echo '=== caches ==='
du -sh /root/.cache /root/.npm 2>/dev/null
echo '=== FIN ==='"
```

---

## RAPPORT À RENDRE

1. Étape 2 : empreinte, syntaxe, import Vision v2, nombre d'occurrences `render_bridge`.
2. Étape 3 : `active` et les dernières lignes du journal.
3. **Étape 4 : l'inventaire complet** — c'est lui qui dira ce qu'il vaut la peine de
   supprimer, et combien on récupère.
4. Statut final.

Puis **arrête-toi**. Claude lance un rendu réel `engine=vision2` du cours complet
« la continuité » (8 scènes, voix, annotations ciblées, 2 rappels) — le rendu qui
vérifiera enfin les annotations et le rappel, jamais vus dans Vision v2.
