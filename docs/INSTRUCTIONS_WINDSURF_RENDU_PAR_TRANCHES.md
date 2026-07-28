# Instructions Windsurf — Rendu par tranches (correctif mémoire définitif)

**Date** : 25 juillet 2026
**Serveur** : `lws-nexiom` **UNIQUEMENT**.

## Contexte — deux correctifs ciblés ont échoué, on change de méthode

Le rendu du cours complet (8 scènes, ~155 s) échoue systématiquement sur
`FATAL ERROR: Reached heap limit — JavaScript heap out of memory`, à ~6 Go, après une
douzaine de minutes. Une vidéo courte (29,5 s) passe sans difficulté, en 103 s, avec une
empreinte modeste.

Deux hypothèses ont été testées et **invalidées** :
1. le nombre d'éléments animés par caractère (réduit d'un facteur 19 — le crash persiste) ;
2. la concurrence Chromium (déjà à 1 depuis l'origine).

La consommation croît donc avec le **nombre d'images rendues dans un même processus** :
quelque chose s'accumule au fil du rendu sans être libéré.

**Nouvelle approche : borner le problème au lieu de le chercher.** Le rendu est découpé
en tranches de 900 images (30 s), chacune confiée à un **processus Node distinct** qui se
termine et rend toute sa mémoire au système. L'empreinte maximale ne dépend plus de la
durée de la vidéo, mais de la taille d'une tranche — une valeur qu'on sait sûre, puisque
29,5 s passent déjà sans problème.

Le découpage porte sur des **numéros d'images**, pas sur les scènes : la continuité du
cahier qui défile, la voix off et les annotations sont préservées à l'identique. Les
tranches sont ensuite recollées sans réencodage.

Attendu pour un cours de 155 s : 6 tranches, environ 10 minutes de rendu.

## RÈGLES ABSOLUES

1. Agis **uniquement** sur `lws-nexiom`.
2. **Ne modifie AUCUN fichier du dépôt Git**, ne committe rien.
3. **Ne touche pas à Supabase**, n'ajoute aucun secret.
4. Ne supprime rien, ne désinstalle rien.
5. **Rapporte la sortie brute, sans interpréter.** Si un bloc ne renvoie rien, écris
   « aucune sortie ».
6. À la moindre erreur → **STOP + rapport** intégral.

---

## ÉTAPE 1 — Copier le nouveau script de rendu

```powershell
scp whiteboard_engine_remotion/render.mjs lws-nexiom:/opt/whiteboard-engine-remotion/
```

## ÉTAPE 2 — Vérifier la syntaxe

```bash
ssh lws-nexiom "cd /opt/whiteboard-engine-remotion && node --check render.mjs && echo 'SYNTAXE OK'"
```

## ÉTAPE 3 — Test court (non-régression) : la vidéo de 29 s doit toujours sortir

```bash
ssh lws-nexiom "cd /opt/whiteboard-engine-remotion
timeout 1200 node render.mjs --storyboard src/sample_storyboard.json --out /tmp/tranches_court.mp4 2>&1 | grep -iE 'tranche|done|error|heap' | head -20
echo '--- ffprobe ---'
ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1 /tmp/tranches_court.mp4
echo '=== FIN ETAPE 3 ==='"
```
Attendu : une seule tranche (885 images < 900), durée ~29,5 s, `[done]`.

## ÉTAPE 4 — Redémarrer le worker

```bash
ssh lws-nexiom "systemctl restart whiteboard-worker && sleep 3 && systemctl is-active whiteboard-worker"
```

---

## RAPPORT À RENDRE

1. Étape 2 : `SYNTAXE OK` ou l'erreur.
2. Étape 3 : la sortie complète (lignes `tranche`, `done`, et le `ffprobe`).
3. Étape 4 : `active` ou non.
4. Statut final.

Puis **arrête-toi**. Claude relance le cours complet via Supabase : c'est ce rendu-là,
échoué deux fois, qui validera ou non l'approche. S'il échoue encore, l'approche Remotion
sera remise en question — c'est le critère annoncé au propriétaire.
