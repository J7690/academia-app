# Instructions Windsurf — Écriture manuscrite (Remotion, LWS) — v2 après correctifs

**Date** : 25 juillet 2026 (version 2 — corrige les erreurs `tsc` remontées)
**Serveur cible** : `lws-nexiom` (root@31.207.38.60) — **uniquement**. Ne touche pas à Kamatera.

## Ce qui a changé depuis ta v1 (merci pour le rapport `tsc`)

Ton rapport a mis au jour un point capital. Le commentaire en tête de `Root.tsx` dit :

> « Polices : on N'utilise PLUS `@remotion/google-fonts` (chargeait des centaines de
> fichiers -> **OOM au rendu**) »

C'est exactement le crash `JavaScript heap out of memory` du 23/07. Ma première version
réintroduisait ce paquet : **elle aurait fait replanter le moteur.** Corrigé.

| Erreur `tsc` remontée | Correctif |
|---|---|
| 3 erreurs `Root.tsx` (types de `Composition`) | Conversions de types explicites — **pré-existantes**, pas liées à l'écriture manuscrite |
| `Property 'subject' does not exist on type 'Storyboard'` | Champ `subject?: string` ajouté au type — **pré-existante** |
| `Could not find a declaration file for module 'katex'` | Nouveau `src/katex.d.ts` (déclaration minimale, aucune dépendance à installer) |
| *(risque non signalé par tsc)* police via google-fonts | **Remplacé** : un seul fichier `.woff2`, chargé via l'API `FontFace` + `delayRender` |

Note : ces erreurs `tsc` existaient **avant** mes modifications — le moteur rendait quand
même, car le bundler de Remotion (esbuild) ne vérifie pas les types. On en profite pour
assainir.

## RÈGLES ABSOLUES

1. Agis **uniquement** sur `lws-nexiom`. Ne touche pas à Kamatera (185.167.97.144).
2. **Ne modifie AUCUN fichier du dépôt Git**, ne committe rien.
3. **Ne touche pas à Supabase**, n'ajoute aucun secret.
4. **Ne désinstalle PAS le moteur Vision** : il produit actuellement toutes les vidéos
   des étudiants. Il sera retiré plus tard, après validation de Remotion.
5. **Ne bascule pas l'app sur `engine: remotion`** — Claude s'en charge après validation.
6. **N'installe PAS `@remotion/google-fonts`** ni aucun paquet de polices (cause connue
   du crash mémoire).
7. À la moindre erreur → **STOP + rapport** intégral.

---

## ÉTAPE 1 — Télécharger la police manuscrite (UN SEUL fichier)

> **Correctif v3** : l'URL de la v2 était erronée (404) — l'empreinte du fichier avait
> été supposée au lieu d'être vérifiée. On interroge désormais l'API Google Fonts pour
> **obtenir l'URL réelle**, puis on télécharge. Cette méthode reste valable même si
> Google change la version de la police (actuellement v23).

```bash
ssh lws-nexiom "mkdir -p /opt/whiteboard-engine-remotion/public/fonts
URL=\$(curl -fsSL 'https://fonts.googleapis.com/css2?family=Caveat:wght@600' | grep -oE 'https://[^)]+\.(ttf|woff2)' | head -1)
echo \"URL trouvee : \$URL\"
curl -fsSL -o /opt/whiteboard-engine-remotion/public/fonts/Caveat.ttf \"\$URL\"
ls -la /opt/whiteboard-engine-remotion/public/fonts/"
```

URL de secours (vérifiée le 25/07/2026) si la commande ci-dessus ne trouve rien :
```bash
ssh lws-nexiom "curl -fsSL -o /opt/whiteboard-engine-remotion/public/fonts/Caveat.ttf \
  'https://fonts.gstatic.com/s/caveat/v23/WnznHAc5bAfYB2QRah7pcpNvOx-pjSx6SII.ttf'
ls -la /opt/whiteboard-engine-remotion/public/fonts/"
```

Attendu : un fichier `Caveat.ttf` de **plusieurs dizaines de kilo-octets** (surtout pas
0 octet). Vérifie que c'est bien une police :
```bash
ssh lws-nexiom "file /opt/whiteboard-engine-remotion/public/fonts/Caveat.ttf"
```
Attendu : une mention `TrueType` / `OpenType`. Si le fichier est vide, en HTML, ou que
les deux méthodes échouent → STOP + rapport.

## ÉTAPE 2 — Copier les sources corrigées (depuis la racine du dépôt `academia/`)

```powershell
scp whiteboard_engine_remotion/src/fonts.ts ^
    whiteboard_engine_remotion/src/katex.d.ts ^
    whiteboard_engine_remotion/src/types.ts ^
    whiteboard_engine_remotion/src/theme.ts ^
    whiteboard_engine_remotion/src/blocks.tsx ^
    whiteboard_engine_remotion/src/SmartWhiteboard.tsx ^
    whiteboard_engine_remotion/src/Root.tsx ^
    lws-nexiom:/opt/whiteboard-engine-remotion/src/
```
(`fonts.ts` et `katex.d.ts` sont nouveaux. Si `^` pose problème, mets tout sur une ligne.)

## ÉTAPE 3 — Vérifier les types

```bash
ssh lws-nexiom "cd /opt/whiteboard-engine-remotion && npx tsc --noEmit 2>&1 | head -40; echo '--- fin tsc ---'"
```
Attendu : **aucune erreur**. S'il en reste, copie-les intégralement et **arrête-toi**.

## ÉTAPE 4 — Rendu de test isolé

```bash
ssh lws-nexiom "cd /opt/whiteboard-engine-remotion
free -h | head -2
timeout 900 node render.mjs --storyboard src/sample_storyboard.json --out /tmp/manuscrit.mp4 2>&1 | tail -25
echo '--- ffprobe ---'
ffprobe -v error -show_entries stream=width,height,codec_name -show_entries format=duration -of default=noprint_wrappers=1 /tmp/manuscrit.mp4"
```
Attendu : MP4 produit, `width=720 height=1280`, durée non nulle, **aucun message
`heap out of memory`**. Si ce message apparaît → STOP + rapport immédiat.

## ÉTAPE 5 — Extraire 3 images pour juger l'écriture

```bash
ssh lws-nexiom "cd /tmp
for t in 2 5 9; do ffmpeg -y -v error -ss \$t -i /tmp/manuscrit.mp4 -frames:v 1 /tmp/frame_\$t.png; done
ls -la /tmp/frame_*.png"
```
Puis rapatrie-les pour que le propriétaire les voie :
```powershell
scp lws-nexiom:/tmp/frame_2.png lws-nexiom:/tmp/frame_5.png lws-nexiom:/tmp/frame_9.png .
```

## ÉTAPE 6 — Redémarrer le worker

```bash
ssh lws-nexiom "systemctl restart whiteboard-worker && sleep 3 && systemctl is-active whiteboard-worker"
```

---

## RAPPORT À RENDRE

1. Étape 1 : taille du fichier `Caveat.woff2`.
2. **Étape 3 : sortie complète de `tsc`** (point de contrôle principal).
3. Étape 4 : mémoire libre, dernières lignes du rendu, sortie `ffprobe`.
4. Étape 5 : confirmation que les 3 PNG sont créés et rapatriés.
5. Étape 6 : `active` ou non.
6. Statut final : « terminé sans erreur » ou « arrêté à l'étape X ».

Puis **arrête-toi**. Claude lance un vrai rendu via Supabase ; le propriétaire jugera
l'écriture manuscrite sur les images et la vidéo.
