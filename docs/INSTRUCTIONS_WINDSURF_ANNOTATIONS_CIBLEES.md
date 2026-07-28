# Instructions Windsurf — Annotations ciblées sur les mots (Remotion, LWS) — v6

**Date** : 25 juillet 2026
**Serveur cible** : `lws-nexiom` (root@31.207.38.60) — **uniquement**. Ne touche pas à Kamatera.
**Nature** : copier 2 fichiers + rendu de test + images. Aucun secret, aucune installation.

## Contexte

Le rappel pédagogique et les annotations sont désormais visibles (validé sur les images
v5). Défaut restant : **l'ovale englobe le bloc entier** — deux lignes de texte et un
débordement à droite — au lieu de cibler quelques mots. Un professeur entoure *un mot*.

## Ce qui a été implémenté

Nouveau champ `emphasis_target` : l'IA (ou le storyboard) désigne **les mots exacts** à
annoter dans un bloc. Exemple :

```jsonc
{
  "type": "correction",
  "content": "Une primitive de 2x est x² + C.",
  "emphasis": "underline",
  "emphasis_target": "x² + C"      // ← seuls ces mots sont soulignés
}
```

**Comment c'est fait, sans mesurer quoi que ce soit** : plutôt que de calculer la
position des mots à l'écran (peu fiable en rendu image par image), les mots visés sont
enveloppés dans un conteneur `inline-block` et l'annotation est placée **à l'intérieur**.
Elle épouse donc automatiquement leur largeur et leur hauteur réelles.

Trois gestes disponibles : `circle` (s'efface après ~1,6 s), `underline` (s'efface),
`highlight` (surlignage au feutre qui **reste**, comme un vrai marqueur).

Sécurité : si les mots visés ne se trouvent pas dans le texte (formulation approximative
de l'IA), on retombe silencieusement sur le texte simple — le rendu n'échoue jamais.

Le storyboard d'exemple (`src/sample_storyboard.json`) a été enrichi pour éprouver les
trois gestes : `circle` sur « F telle que », `highlight` sur « une primitive »,
`underline` sur « x² + C ».

## RÈGLES ABSOLUES

1. Agis **uniquement** sur `lws-nexiom`. Ne touche pas à Kamatera (185.167.97.144).
2. **Ne modifie AUCUN fichier du dépôt Git**, ne committe rien.
3. **Ne touche pas à Supabase**, n'ajoute aucun secret.
4. **Ne désinstalle PAS Vision**, **ne bascule pas l'app**.
5. **N'installe PAS `@remotion/google-fonts`**.
6. À la moindre erreur → **STOP + rapport** intégral.

---

## ÉTAPE 1 — Copier les 2 fichiers

```powershell
scp whiteboard_engine_remotion/src/blocks.tsx ^
    whiteboard_engine_remotion/src/sample_storyboard.json ^
    lws-nexiom:/opt/whiteboard-engine-remotion/src/
```

## ÉTAPE 2 — Types

```bash
ssh lws-nexiom "cd /opt/whiteboard-engine-remotion && npx tsc --noEmit 2>&1 | head -30; echo '--- fin tsc ---'"
```
Attendu : aucune erreur. Sinon → copie tout et **arrête-toi**.

## ÉTAPE 3 — Rendu de test

```bash
ssh lws-nexiom "cd /opt/whiteboard-engine-remotion
timeout 900 node render.mjs --storyboard src/sample_storyboard.json --out /tmp/manuscrit6.mp4 2>&1 | tail -15
ffprobe -v error -show_entries stream=width,height -show_entries format=duration -of default=noprint_wrappers=1 /tmp/manuscrit6.mp4"
```

## ÉTAPE 4 — Images de contrôle (toutes les 2 s)

```bash
ssh lws-nexiom "cd /tmp
rm -f /tmp/v6_frame_*.png
DUR=\$(ffprobe -v error -show_entries format=duration -of csv=p=0 /tmp/manuscrit6.mp4 | cut -d. -f1)
echo \"duree = \$DUR s\"
for t in \$(seq 2 2 \$((DUR-1))); do ffmpeg -y -v error -ss \$t -i /tmp/manuscrit6.mp4 -frames:v 1 /tmp/v6_frame_\$t.png; done
ls /tmp/v6_frame_*.png | wc -l"
```
```powershell
scp lws-nexiom:/tmp/v6_frame_*.png .
```

## ÉTAPE 5 — Redémarrer le worker

```bash
ssh lws-nexiom "systemctl restart whiteboard-worker && sleep 3 && systemctl is-active whiteboard-worker"
```

---

## RAPPORT À RENDRE

1. Étape 2 : sortie complète de `tsc`.
2. Étape 3 : `ffprobe` (durée).
3. Étape 4 : nombre de PNG + confirmation du rapatriement à la racine du dépôt.
4. Étape 5 : `active` ou non.
5. Statut final.

Puis **arrête-toi**. Claude vérifie sur les images que les trois gestes visent bien les
mots et non le bloc entier.
