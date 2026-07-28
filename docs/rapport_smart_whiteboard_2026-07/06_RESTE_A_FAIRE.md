# 06 — Reste à faire et pistes d'évolution

> Classé par rapport valeur / effort. Les contraintes en tête de ce fichier doivent être
> respectées par **toute** évolution future.

---

## Les trois contraintes non négociables

Avant toute proposition d'amélioration, vérifier qu'elle respecte ces trois règles issues de
l'expérience de la session :

1. **100 % CSS pour les animations.** `record_scene.js` n'avance que les animations CSS. Toute
   animation en JavaScript impératif (GSAP, Lottie piloté par script) casse la capture par
   tranches parallèles — donc la rapidité **et** l'aperçu instantané.
2. **Pas de calcul d'IA sur le VPS.** 4 vCPU, entièrement dédiés à la capture vidéo. Kokoro-82M
   a démontré qu'un modèle local, même petit, y est trop lent (RTF 3,25 à 4,5). Toute IA passe
   par une Edge Function cloud.
3. **Dégradation gracieuse obligatoire.** Toute nouvelle brique doit avoir un plan B explicite.
   L'étudiant doit toujours obtenir son cours, même imparfait.

---

## Priorité immédiate

### ▶ Test grandeur nature depuis l'application

C'est la seule tâche ouverte du plan. Rien n'a encore fait tourner **ensemble** le storyboard
v3, la mise en scène v3 et le sound design sur un **sujet réel** saisi par un étudiant.

**Protocole suggéré.**

1. Depuis l'app, générer un cours sur un sujet de mathématiques (les formules sont le cas le
   plus exigeant).
2. Vérifier dans les logs du worker (`05_PROCEDURES.md` §6) :
   - `blocs mesures dans le navigateur` — passe de mesure OK
   - `APERCU publie` — et **chronométrer** le délai réel depuis le clic
   - `[sfx] mixage : N evenements` — sound design appliqué
3. Contrôler dans l'app : l'aperçu se lance-t-il ? la bascule vers la vidéo complète est-elle
   propre ?
4. Regarder et **écouter** la vidéo finale, en vérifiant point par point :
   - les mots-clés en rouge sont-ils les bons ? (qualité des `key_words` du modèle)
   - la narration de bloc accompagne-t-elle bien le bloc qui s'écrit ?
   - la scène de récap est-elle présente et lisible ?
   - le tampon de correction apparaît-il au bon moment ?
   - les bruitages sont-ils au bon niveau ? (le gratté de stylo est le plus susceptible d'être
     jugé trop présent ou trop discret)

**Ce test est aussi le seul moyen de juger la qualité du prompt v3** : les `key_words` et les
`beat` sont produits par un modèle de langage ; seule l'observation sur des sujets variés dira
si les consignes sont suffisamment contraignantes.

---

## Pistes classées

### Effort faible, valeur immédiate

| Piste | Détail |
|---|---|
| **Déposer un lit musical** | Un seul `scp` (voir `05_PROCEDURES.md` §5). Le ducking est déjà en place. C'est probablement le plus grand saut de perception « production professionnelle » pour le moins d'effort |
| **Ajuster les volumes du sound design** | Après écoute réelle. Le gratté de stylo (0,10) est le réglage le plus subjectif |
| **Nettoyage périodique de `/tmp`** | Les dossiers de travail des rendus s'accumulent. Une tâche `systemd-tmpfiles` ou un cron suffirait |

### Effort moyen

| Piste | Détail | Point de vigilance |
|---|---|---|
| **`plan()` en `NamedTuple`** | Le tuple à 5 éléments non nommés a déjà causé un bug (difficulté n° 15). Un `NamedTuple` rendrait les appelants insensibles à l'ajout d'un champ | Refactorisation touchant plusieurs fichiers |
| **Transitions entre scènes** | Le champ `transition` (`fade`/`slide`/`wipe`) existe dans le storyboard mais est peu exploité visuellement | Doit rester en CSS pur |
| **Micro-animations vectorielles** | Des illustrations légères pour les scènes de concept | **Lottie est piloté par JavaScript** → incompatible. Il faudrait des SVG animés en CSS (`SMIL` ou `@keyframes`) |
| **Sons variés plutôt que répétés** | Le même `pop.wav` sur tous les badges peut lasser sur un cours long. Générer 2-3 variantes et alterner | `MAX_EVENTS` reste le garde-fou |

### Effort élevé, à évaluer

| Piste | Détail | Réserve |
|---|---|---|
| **Voix plus naturelle** | Passer à un fournisseur TTS cloud de meilleure qualité, via Edge Function | Coût par requête à évaluer ; c'est le poste où l'écart avec les productions du marché reste le plus perceptible |
| **Aperçu par WebView** | Afficher la page HTML animée dans une WebView : aperçu quasi instantané | Écartée pour l'instant : le rendu mobile **différerait** du rendu final (polices, KaTeX, mesures serveur) → aperçu trompeur. L'aperçu MP4 garantit d'être exactement le début de la vidéo finale |
| **Plus de tranches parallèles** | Passer de 3 à 4+ | Sur 4 vCPU, les processus se concurrenceraient. Nécessiterait un VPS plus puissant — à arbitrer contre le coût |
| **Diagrammes Mermaid animés** | Le type de bloc `diagram` existe mais n'a pas d'animation d'apparition dédiée | Mermaid génère du SVG ; l'animer en CSS pur est faisable mais demande de comprendre la structure générée |

---

## Ce qui a été délibérément écarté — ne pas y revenir sans raison nouvelle

| Écarté | Raison | Ce qui pourrait changer la donne |
|---|---|---|
| **GSAP** | Incompatible avec `document.getAnimations()` → casse la capture par tranches | Réécrire `record_scene.js` pour piloter aussi la timeline GSAP — mais on perdrait la simplicité du *seek* CSS |
| **Kokoro-82M en local** | RTF 3,25 à 4,5 sur 4 vCPU | Un VPS avec GPU, ou beaucoup plus de cœurs — mais une Edge Function cloud resterait plus simple |
| **`beginFrame` (CDP)** | Plus lent que le temps réel, images blanches | Rien à l'horizon ; l'approche temps réel donne satisfaction |
| **Colonne `preview_url` en base** | Un chemin conventionnel évite migration et désynchronisation | Si le chemin devait devenir dynamique |
| **Rejet des storyboards imparfaits** | L'étudiant perdrait crédits et vidéo | Jamais : la philosophie « nettoyer, pas rejeter » est un acquis |

---

## Points de vigilance permanents

### Le couplage du chemin d'aperçu
`renders/<renderId>/preview.mp4` est écrit **dans deux fichiers** :
- serveur : `whiteboard_upload_renderer.preview_object_key`
- app : `SmartWhiteboardRenderService._previewObjectKey`

Modifier l'un sans l'autre casse silencieusement l'aperçu — sans message d'erreur, puisque le
HEAD renverra simplement 404 et que l'échec est traité comme « pas encore prêt ». **Le
commentaire est présent dans les deux fichiers ; le conserver.**

### Le décalage `INTRO_SEC`
`INTRO_SEC = 3.2` est utilisé dans `whiteboard_page_builder.plan()` **et** répliqué par un
`adelay` ffmpeg dans `whiteboard_render_worker.py`. Une modification d'un seul côté désynchronise
la voix sur **toute** la vidéo.

### L'Edge Function TTS ignore `speed`
Ne pas perdre de temps à envoyer un paramètre `speed` : il est ignoré. Le réglage est
`TTS_SPEED = 0.88` dans `whiteboard_narration.py`, appliqué par ffmpeg `atempo`.

### `proto_capture_bf.js` rend des images blanches
Pour toute validation visuelle : `snap_still.js` / `snap_frames.sh`. Cette confusion a déjà fait
perdre du temps une fois.

---

## Traces d'essais à nettoyer un jour

Ces fichiers sur le VPS appartiennent à des générations antérieures du moteur. Ils ne sont plus
appelés par la chaîne de production mais restent comme documentation vivante des essais :

`proto_capture_bf.js`, `proto_capture.js`, `capture_scene.js`,
`whiteboard_playwright_capture.py`, `whiteboard_scene_engine.py`, `scene_template.html`,
`whiteboard_png_renderer.py`, `whiteboard_ffmpeg_assembler.py` (chaîne Pillow d'origine).

**Recommandation** : les conserver jusqu'à ce que la vague G soit validée en production sur
plusieurs cours réels, puis les archiver.
