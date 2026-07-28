# Instructions Windsurf — Identifier le worker LWS auprès de la file

**Date** : 25 juillet 2026
**Serveur** : `lws-nexiom` **UNIQUEMENT**. N'essaie pas Kamatera (accès refusé, acquis).

## Contexte — ce qui a été prouvé

Un worker **non identifié**, sur une machine devenue inaccessible, consomme la même file
de rendu que LWS avec une **version ancienne du code** : il ignore `storyboard.engine` et
rend tout avec le moteur Vision. Preuve : le job `c1e27dd2` (engine=remotion) a été
traité de 19:21:02 à 19:23:47 heure serveur, alors que le journal du worker LWS ne montre
**aucune activité** sur cette plage. Conséquence pour l'étudiant : une vidéo sur deux sort
sans écriture manuscrite ni annotations, au hasard de qui rafle le job.

Ne pouvant pas arrêter cette machine, Claude a **verrouillé la file côté Supabase** : les
workers doivent désormais s'identifier avec une clé connue. Un appelant non identifié
recevra une file vide — il tournera à vide, sans erreur ni bruit.

**Le verrou n'est PAS encore actif** (mode permissif). Ton rôle : mettre à jour le worker
LWS pour qu'il s'identifie. Claude activera le verrou ensuite.

## RÈGLES ABSOLUES

1. Agis **uniquement** sur `lws-nexiom`.
2. **Ne modifie AUCUN fichier du dépôt Git**, ne committe rien.
3. **Ne touche pas à Supabase**, n'ajoute aucun secret, ne modifie pas le `.env`.
4. Ne supprime rien, ne désinstalle rien.
5. **Rapporte la sortie brute, sans interpréter, et sans conclure quelle machine a fait
   quoi.** Si un bloc ne renvoie rien, écris « aucune sortie ».
6. À la moindre erreur → **STOP + rapport** intégral.

---

## ÉTAPE 1 — Copier le worker mis à jour

```powershell
scp academia_bobodo_backend/whiteboard_render_worker.py lws-nexiom:/opt/whiteboard-worker/
```

Empreinte attendue du fichier copié : `c403ef85427e2e0df650bd236572b006`

## ÉTAPE 2 — Vérifier et redémarrer

```bash
ssh lws-nexiom "cd /opt/whiteboard-worker
echo '=== A. empreinte apres copie ==='
md5sum whiteboard_render_worker.py

echo '=== B. la cle et l identification sont-elles presentes ? ==='
grep -n 'WORKER_KEY\|p_worker_key\|p_host' whiteboard_render_worker.py

echo '=== C. syntaxe ==='
python3 -c \"import ast; ast.parse(open('whiteboard_render_worker.py',encoding='utf-8').read()); print('syntaxe OK')\"

echo '=== D. redemarrage ==='
systemctl restart whiteboard-worker && sleep 4 && systemctl is-active whiteboard-worker

echo '=== E. journal apres redemarrage (hors bruit) ==='
journalctl -u whiteboard-worker -n 40 --no-pager | grep -v 'Found 0 queued' | grep -v 'httpx' | tail -20
echo '=== FIN ==='"
```

**Attendu** :
- A : `c403ef85427e2e0df650bd236572b006`
- B : trois lignes (déclaration de `WORKER_KEY`, `p_worker_key`, `p_host`)
- C : `syntaxe OK`
- D : `active`
- E : aucune erreur, aucun `Traceback`

⚠️ Si le journal montre des erreurs HTTP 400 ou `whiteboard_fetch_queued_jobs failed`,
**arrête-toi et rapporte immédiatement** : cela signifierait que le worker n'arrive plus
à réclamer de travail, et Claude devra corriger avant d'aller plus loin.

---

## RAPPORT À RENDRE

La sortie brute des sections A à E, plus le statut final (« terminé sans erreur » ou
« arrêté à l'étape X »). Puis **arrête-toi**.

Claude vérifiera ensuite côté Supabase que le worker LWS s'est bien annoncé (sa dernière
visite et son nom de machine sont enregistrés dans la table `app.whiteboard_workers`),
avant d'activer le verrou qui affamera l'autre worker.
