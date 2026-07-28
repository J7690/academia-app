# Instructions Windsurf — Diagnostic du worker LWS puis mise à jour

**Date** : 25 juillet 2026
**Serveur** : `lws-nexiom` **UNIQUEMENT**.

---

## AVERTISSEMENT — lis ceci avant toute chose

Ton rapport précédent contenait une **erreur d'interprétation** qui a fait perdre du
temps. Tu as écrit : « sur Kamatera, le service whiteboard-worker est active ». C'est
faux. La connexion SSH à Kamatera a été **refusée** (`Permission denied`, étape 2). Le
bloc Kamatera de l'étape 1 utilisait la même commande : il a donc échoué et n'a rien
produit. La sortie que tu as affichée (`vps122603`, `active`, une ligne de processus)
correspond exactement à la séquence du bloc **LWS** (`hostname`, puis
`systemctl is-active`, puis `ps aux | head -3`).

**Conclusion : `vps122603` est le nom de machine de LWS. Aucune information n'a été
obtenue sur Kamatera.**

### Règles de rapport, désormais obligatoires

1. **Ne conclus JAMAIS quelle machine a produit une sortie.** Rapporte la sortie brute,
   telle quelle, et laisse Claude l'interpréter.
2. **Ne présente jamais une absence de sortie comme une troncature.** Si un bloc ne
   renvoie rien, écris « aucune sortie pour ce bloc ».
3. **Une commande = son résultat.** Ne fusionne pas, ne résume pas, ne réordonne pas.
4. Si une commande échoue, colle **le message d'erreur exact** et continue avec la
   suivante quand l'instruction le permet.

---

## RÈGLES ABSOLUES POUR CETTE TÂCHE

1. Agis **uniquement** sur `lws-nexiom`. **N'essaie plus de te connecter à Kamatera**
   (185.167.97.144) : l'accès est refusé, c'est acquis, n'y reviens pas.
2. **Ne modifie AUCUN fichier du dépôt Git**, ne committe rien.
3. **Ne touche pas à Supabase**, n'ajoute aucun secret, ne modifie pas le `.env`.
4. **Ne supprime rien**, ne désinstalle rien.
5. **ÉTAPE 1 SEULEMENT, puis STOP.** N'exécute l'étape 2 que si Claude te donne le feu
   vert, après lecture de ton rapport.

---

## ÉTAPE 1 — Diagnostic (lecture seule). Exécute, rapporte, ARRÊTE-TOI.

```bash
ssh lws-nexiom "echo '=== A. identite machine ==='
hostname

echo '=== B. le worker deploye contient-il la branche remotion ? ==='
grep -n 'remotion' /opt/whiteboard-worker/whiteboard_render_worker.py | head -20 || echo 'AUCUNE OCCURRENCE DE remotion'

echo '=== C. la fonction de rendu remotion est-elle importee ? ==='
grep -n 'render_storyboard_remotion\|_HAS_REMOTION\|REMOTION_ENGINE_DIR' /opt/whiteboard-worker/whiteboard_render_worker.py | head -10 || echo 'AUCUNE OCCURRENCE'

echo '=== D. empreinte et date du fichier deploye ==='
md5sum /opt/whiteboard-worker/whiteboard_render_worker.py
ls -la /opt/whiteboard-worker/whiteboard_render_worker.py

echo '=== E. le worker peut-il importer le pont remotion ? ==='
cd /opt/whiteboard-worker && python3 -c \"
import os, sys
sys.path.insert(0, os.environ.get('REMOTION_ENGINE_DIR', '/opt/whiteboard-engine-remotion'))
try:
    from render_bridge import render_storyboard_remotion
    print('IMPORT OK : render_storyboard_remotion disponible')
except Exception as e:
    print('IMPORT ECHEC :', type(e).__name__, e)
\"

echo '=== F. 30 dernieres lignes du journal du worker ==='
journalctl -u whiteboard-worker -n 30 --no-pager"
```

Puis, sur ta machine (pour comparer au dépôt) :
```powershell
certutil -hashfile academia_bobodo_backend\whiteboard_render_worker.py MD5
```

**RAPPORTE** : la sortie brute complète des sections A à F, plus l'empreinte MD5 du
fichier du dépôt. **Puis arrête-toi.** N'exécute pas l'étape 2.

---

## ÉTAPE 2 — (SEULEMENT sur feu vert de Claude) Mettre le worker à jour

À n'exécuter que si Claude confirme que le fichier déployé est obsolète.

```powershell
scp academia_bobodo_backend/whiteboard_render_worker.py lws-nexiom:/opt/whiteboard-worker/
```
```bash
ssh lws-nexiom "cd /opt/whiteboard-worker
md5sum whiteboard_render_worker.py
python3 -c \"import ast; ast.parse(open('whiteboard_render_worker.py',encoding='utf-8').read()); print('syntaxe OK')\"
systemctl restart whiteboard-worker && sleep 3 && systemctl is-active whiteboard-worker
journalctl -u whiteboard-worker -n 15 --no-pager"
```

Rapporte la nouvelle empreinte, le résultat de la vérification de syntaxe, l'état du
service et les dernières lignes du journal. Puis **arrête-toi** : Claude lance un rendu
de contrôle via Supabase pour vérifier que le manuscrit sort enfin par l'application.
