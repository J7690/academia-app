# Instructions Windsurf — Correctif débordement de texte (Remotion, LWS) — v4

**Date** : 25 juillet 2026
**Serveur cible** : `lws-nexiom` — **uniquement**. Ne touche pas à Kamatera.

## Résultat de la v3 : 3 défauts sur 3 corrigés ✅

Vérifié sur les images : la formule s'affiche **une seule fois** et proprement, plus
aucun tiret vert parasite, plus de boîte grise vide. L'encerclage fonctionne.

## Nouveau défaut vu sur les mêmes images : le texte déborde à droite

« Trouver une primitive de f(x) = … » et « Une primitive de 2x est x² + C » sortaient
du cadre par la droite, tronqués.

**Cause** : pour préserver les espaces pendant l'écriture, chaque espace était rendu
comme une **espace insécable** — ce qui interdit au navigateur de revenir à la ligne.
Les blocs « exercice », « correction » et « définition », qui reçoivent leur texte d'un
seul tenant, ne pouvaient donc jamais se replier.

**Correctif** : espaces normales + `white-space: pre-wrap` (préserve les espaces **et**
autorise le retour à la ligne) + `overflow-wrap: break-word` en filet de sécurité.

## À FAIRE

```powershell
scp whiteboard_engine_remotion/src/blocks.tsx lws-nexiom:/opt/whiteboard-engine-remotion/src/
```
```bash
ssh lws-nexiom "cd /opt/whiteboard-engine-remotion && npx tsc --noEmit 2>&1 | head -20; echo '--- fin tsc ---'
timeout 900 node render.mjs --storyboard src/sample_storyboard.json --out /tmp/manuscrit4.mp4 2>&1 | tail -12
ffprobe -v error -show_entries stream=width,height -show_entries format=duration -of default=noprint_wrappers=1 /tmp/manuscrit4.mp4
cd /tmp && for t in 12 20 26; do ffmpeg -y -v error -ss \$t -i /tmp/manuscrit4.mp4 -frames:v 1 /tmp/v4_frame_\$t.png; done
ls -la /tmp/v4_frame_*.png"
```
```powershell
scp lws-nexiom:/tmp/v4_frame_12.png lws-nexiom:/tmp/v4_frame_20.png lws-nexiom:/tmp/v4_frame_26.png .
ssh lws-nexiom "systemctl restart whiteboard-worker && sleep 3 && systemctl is-active whiteboard-worker"
```

Rapporte : sortie `tsc`, `ffprobe`, confirmation des 3 PNG rapatriés, statut du worker.
Puis **arrête-toi**. Ne désinstalle pas Vision, ne bascule pas l'app, n'installe pas
`@remotion/google-fonts`.

---
---

# (Archive) Instructions v3 — correctifs formule + annotations

**Date** : 25 juillet 2026
**Serveur cible** : `lws-nexiom` (root@31.207.38.60) — **uniquement**. Ne touche pas à Kamatera.
**Nature** : copier 3 fichiers + rendu de test + extraction d'images. Aucun secret, aucune installation.

## Contexte — défauts vus sur les images du rendu v2

L'écriture manuscrite est validée par le propriétaire. Trois défauts restent, tous
diagnostiqués avec leur cause exacte :

| Défaut observé | Cause | Correctif |
|---|---|---|
| **Formule affichée EN DOUBLE** (une version italique par-dessus une version droite) | KaTeX produit une couche HTML **et** une couche MathML. Sans sa feuille de style, rien ne masque la seconde — or la CSS de KaTeX n'était jamais chargée dans le moteur Remotion | Import de `katex/dist/katex.min.css` **et** `output: "html"` (on ne génère plus la couche MathML du tout) |
| **Petits tirets verts flottant dans le vide**, parfois très longtemps avant l'annotation | `strokeLinecap="round"` dessine des bouts arrondis visibles **même quand le trait est entièrement masqué** (dashoffset = 1) | Opacité forcée à 0 tant que le tracé n'a pas commencé |
| **Boîte grise vide** affichée plusieurs secondes avant son texte | Le cadre coloré du bloc « exercice » s'affichait dès la réservation de l'espace | Le cadre apparaît en fondu **au moment où l'écriture commence** |

## RÈGLES ABSOLUES

1. Agis **uniquement** sur `lws-nexiom`. Ne touche pas à Kamatera (185.167.97.144).
2. **Ne modifie AUCUN fichier du dépôt Git**, ne committe rien.
3. **Ne touche pas à Supabase**, n'ajoute aucun secret.
4. **Ne désinstalle PAS le moteur Vision** : il produit toutes les vidéos des étudiants.
5. **Ne bascule pas l'app sur `engine: remotion`** — Claude s'en charge après validation.
6. **N'installe PAS `@remotion/google-fonts`** (cause connue du crash mémoire).
7. À la moindre erreur → **STOP + rapport** intégral.

---

## ÉTAPE 1 — Copier les 3 fichiers corrigés (depuis la racine du dépôt `academia/`)

```powershell
scp whiteboard_engine_remotion/src/blocks.tsx ^
    whiteboard_engine_remotion/src/Annotation.tsx ^
    whiteboard_engine_remotion/src/SmartWhiteboard.tsx ^
    lws-nexiom:/opt/whiteboard-engine-remotion/src/
```

## ÉTAPE 2 — Vérifier que la CSS de KaTeX est bien présente sur le serveur

Le nouvel import `katex/dist/katex.min.css` doit exister, sinon la compilation échouera.

```bash
ssh lws-nexiom "ls -la /opt/whiteboard-engine-remotion/node_modules/katex/dist/katex.min.css"
```
Attendu : un fichier d'environ 20 à 30 Ko. S'il est absent → STOP + rapport (ne
réinstalle rien de ta propre initiative).

## ÉTAPE 3 — Vérifier les types

```bash
ssh lws-nexiom "cd /opt/whiteboard-engine-remotion && npx tsc --noEmit 2>&1 | head -40; echo '--- fin tsc ---'"
```
Attendu : aucune erreur. Si `tsc` se plaint de l'import CSS (`Cannot find module
'katex/dist/katex.min.css'`), **signale-le sans le corriger** : c'est un avertissement de
typage qui n'empêche pas le rendu, Claude ajoutera une déclaration si nécessaire.

## ÉTAPE 4 — Rendu de test

```bash
ssh lws-nexiom "cd /opt/whiteboard-engine-remotion
free -h | head -2
timeout 900 node render.mjs --storyboard src/sample_storyboard.json --out /tmp/manuscrit3.mp4 2>&1 | tail -20
echo '--- ffprobe ---'
ffprobe -v error -show_entries stream=width,height -show_entries format=duration -of default=noprint_wrappers=1 /tmp/manuscrit3.mp4"
```
Attendu : MP4 720×1280, durée non nulle, **aucun `heap out of memory`**.
⚠️ La CSS de KaTeX embarque une vingtaine de fichiers de police : surveille bien
l'absence de message mémoire. S'il en apparaît un → STOP + rapport immédiat.

## ÉTAPE 5 — Extraire les images de contrôle

```bash
ssh lws-nexiom "cd /tmp
for t in 5 12 14 20 26; do ffmpeg -y -v error -ss \$t -i /tmp/manuscrit3.mp4 -frames:v 1 /tmp/v3_frame_\$t.png; done
ls -la /tmp/v3_frame_*.png"
```
Puis rapatrie-les à la racine du dépôt :
```powershell
scp lws-nexiom:/tmp/v3_frame_5.png lws-nexiom:/tmp/v3_frame_12.png lws-nexiom:/tmp/v3_frame_14.png lws-nexiom:/tmp/v3_frame_20.png lws-nexiom:/tmp/v3_frame_26.png .
```

## ÉTAPE 6 — Redémarrer le worker

```bash
ssh lws-nexiom "systemctl restart whiteboard-worker && sleep 3 && systemctl is-active whiteboard-worker"
```

---

## RAPPORT À RENDRE

1. Étape 2 : taille de `katex.min.css`.
2. Étape 3 : sortie complète de `tsc`.
3. Étape 4 : mémoire libre, dernières lignes du rendu, sortie `ffprobe`.
4. Étape 5 : confirmation que les 5 PNG sont créés **et rapatriés à la racine du dépôt**.
5. Étape 6 : `active` ou non.
6. Statut final : « terminé sans erreur » ou « arrêté à l'étape X ».

Puis **arrête-toi**. Claude examine les images (formule affichée une seule fois ?
plus de tirets parasites ? plus de boîte vide ?) avant de passer au morceau suivant :
le changement de page quand la feuille est pleine.
