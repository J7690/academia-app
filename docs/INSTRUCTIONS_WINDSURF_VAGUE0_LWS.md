# Instructions Windsurf — Vague 0 : correctifs Smart Whiteboard + diagnostic narration

**Date** : 25 juillet 2026 (version corrigée)
**Serveur cible** : `lws-nexiom` (root@31.207.38.60) — **uniquement**. Ne touche pas à Kamatera.

## Contexte (constaté par Claude via Supabase, pas supposé)

La vidéo Vision du 25/07 présentait 3 défauts. Claude a corrigé les 2 premiers **dans le
dépôt** ; le 3e (la voix) reste une énigme à documenter avant de la corriger.

| Défaut | Cause trouvée | État |
|---|---|---|
| `\lim_{x \to 1^-}` affiché en clair | KaTeX n'était appliqué qu'aux blocs `type=formula` | ✅ corrigé (code) |
| Numérotation absurde (`11.`, `1Conclusion`) | Compteur préfixé devant un contenu déjà numéroté | ✅ corrigé (code) |
| **Aucune voix sur le rendu Vision** | **Inconnue — voir ci-dessous** | ❓ diagnostic requis |

### L'énigme de la voix (à résoudre par l'Étape 3)

Faits vérifiés dans les logs Supabase du 25/07 :
- Rendu **Remotion** (12:22:38 → 12:25:27) : l'Edge Function `whiteboard-tts` a été
  appelée **7 fois, toutes en 200 OK**, entre 12:23:33 et 12:23:59. **La vidéo a du son.**
- Rendu **Vision** (12:45:00 → 12:47:35) : **aucun appel** à `whiteboard-tts`.
  **La vidéo est muette.**
- Ce sont les seuls jobs de la journée : aucune autre source possible.

Ce que ça prouve : la clé `OPENROUTER_API_KEY` (côté Supabase), la variable
`WHITEBOARD_TTS_URL` et `SUPABASE_SERVICE_KEY` (côté worker LWS) sont **déjà bien
configurées** — sinon aucun appel n'aurait abouti. **Il n'y a donc AUCUN secret à
ajouter.** Le problème est ailleurs, dans le chemin de code Vision.

Ce qui est incohérent : dans la version du dépôt, le moteur Remotion sort de la fonction
**avant** le bloc de narration — il ne devrait donc jamais appeler `whiteboard-tts`. Or
il l'a fait. **Le worker déployé sur LWS diffère probablement du dépôt.** L'Étape 3 sert
à le vérifier.

## RÈGLES ABSOLUES

1. Agis **uniquement** sur `lws-nexiom`. Ne touche pas à Kamatera (185.167.97.144).
2. **Ne modifie AUCUN fichier du dépôt Git**, ne committe rien.
3. **Ne touche pas à Supabase** (ni SQL, ni secrets, ni Edge Functions).
4. **N'ajoute AUCUN secret et ne modifie pas le `.env`** — tout est déjà configuré.
5. Ne bascule aucune IP applicative.
6. N'affiche jamais la valeur d'un secret (uniquement les **noms** de variables).
7. À la moindre erreur ou sortie inattendue → **STOP + rapport**.

---

## ÉTAPE 1 — Copier les 3 fichiers corrigés (depuis la racine du dépôt `academia/`)

```powershell
scp academia_bobodo_backend/whiteboard_narration.py lws-nexiom:/opt/whiteboard-worker/
scp academia_bobodo_backend/whiteboard_vision/whiteboard_scene_engine.py lws-nexiom:/opt/whiteboard-worker/vision_engine/
scp academia_bobodo_backend/whiteboard_vision/scene_template.html lws-nexiom:/opt/whiteboard-worker/vision_engine/
```

## ÉTAPE 2 — Vérifier que KaTeX est disponible pour le moteur Vision

Le rendu des formules appelle `katex_renderer.js`, qui fait `require('katex')`.

```bash
ssh lws-nexiom "cd /opt/whiteboard-worker
NODE_PATH=/opt/whiteboard-worker/node_modules node -e \"require('katex'); console.log('katex OK')\" 2>&1 || npm install katex
cd /opt/whiteboard-worker/vision_engine
NODE_PATH=/opt/whiteboard-worker/node_modules node katex_renderer.js '\\lim_{x \\to 1^-}' | head -c 200; echo"
```
Attendu : `katex OK`, puis du HTML commençant par `<span class="katex"`.

## ÉTAPE 3 — DIAGNOSTIC narration (le plus important : ne corrige RIEN, rapporte)

```bash
ssh lws-nexiom "cd /opt/whiteboard-worker
echo '=== 3a. Le worker deploye contient-il la branche remotion AVANT la narration ? ==='
grep -n 'engine.*remotion\|Narration audio\|build_narration\|return$' whiteboard_render_worker.py | head -30

echo
echo '=== 3b. Empreinte du worker deploye (pour comparer au depot) ==='
md5sum whiteboard_render_worker.py whiteboard_narration.py

echo
echo '=== 3c. Modules Python disponibles ==='
python3 -c \"import gtts; print('gTTS present')\" 2>&1 | tail -1
python3 -c \"import httpx; print('httpx present')\" 2>&1 | tail -1

echo
echo '=== 3d. Variables presentes dans le .env (NOMS uniquement) ==='
grep -oE '^[A-Z_]+=' .env

echo
echo '=== 3e. Journal du worker pendant le rendu Vision de 12:45 UTC ==='
journalctl -u whiteboard-worker --since '2026-07-25 14:44' --until '2026-07-25 14:50' --no-pager | grep -iE 'narration|tts|vision|remotion|error|warn' | head -40"
```

> Note : le serveur est en CEST (UTC+2) — 12:45 UTC = 14:45 heure serveur, d'où les
> heures utilisées dans `journalctl`.

## ÉTAPE 4 — Redémarrer le worker

```bash
ssh lws-nexiom "systemctl restart whiteboard-worker && sleep 3 && systemctl is-active whiteboard-worker"
```

---

## RAPPORT À RENDRE

Colle la sortie **brute et complète**, dans l'ordre, en particulier :
1. Étape 2 : `katex` déjà présent ou installé ? + les 200 premiers caractères du HTML.
2. **Étape 3 en entier** — c'est la partie décisive. Surtout `3a` (ordre du code),
   `3b` (empreintes md5), `3c` (gTTS présent ou non) et `3e` (le journal).
3. Étape 4 : `active` ou non.
4. Statut final : « terminé sans erreur » ou « arrêté à l'étape X » avec l'erreur exacte.

Puis **arrête-toi**. Claude compare les empreintes avec le dépôt, comprend pourquoi la
narration saute sur le chemin Vision, corrige, et relance lui-même un rendu réel.
