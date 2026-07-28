# Rapport Smart Whiteboard — session du 25 au 27 juillet 2026

> **Objet** : rapport détaillé de tout ce qui a été mis en place sur le Smart Whiteboard
> pendant cette session — infrastructure LWS, Supabase, application Flutter — avec les
> difficultés rencontrées, les décisions prises et les améliorations mesurées.
>
> **Statut au 27/07/2026 19h10 UTC** : moteur « Spot Studio » complet, déployé, worker actif.
> Reste à faire : un test grandeur nature depuis l'application sur un sujet réel.

---

## Comment lire ce dossier

Ce dossier est conçu pour qu'on puisse **y ajouter des couches** au fil des sessions.
Chaque fichier est autonome et daté ; on ajoute un nouveau fichier plutôt que de réécrire
l'histoire.

| Fichier | Contenu |
|---|---|
| [`01_INFRA_LWS.md`](01_INFRA_LWS.md) | Le VPS : moteur de rendu, fichiers déployés, performances mesurées |
| [`02_SUPABASE.md`](02_SUPABASE.md) | Edge Functions, storyboard v3, buckets, contrat de données |
| [`03_FLUTTER.md`](03_FLUTTER.md) | Application : aperçu instantané, provider, écran de prévisualisation |
| [`04_DIFFICULTES_ET_DECISIONS.md`](04_DIFFICULTES_ET_DECISIONS.md) | Chaque problème rencontré, sa cause racine, la décision retenue |
| [`05_PROCEDURES.md`](05_PROCEDURES.md) | Commandes de déploiement, de validation visuelle et de diagnostic |
| [`06_RESTE_A_FAIRE.md`](06_RESTE_A_FAIRE.md) | Ce qui n'est pas fait, et les pistes classées par rapport valeur/effort |
| [`07_AUDIT_2026-07-27.md`](07_AUDIT_2026-07-27.md) | **Audit des 3 couches** après l'échec du 1er test réel : 4 défauts trouvés, 18 tests ajoutés |

Documents de référence antérieurs, toujours valables :
- `../SMART_WHITEBOARD_PLAN_SPOT_2026.md` — plan des vagues E, F, G
- `../CAHIER_DES_CHARGES_MISE_EN_SCENE_V2.md` — cahier des charges du rendu v2
- `../ETAT_REEL_SMART_WHITEBOARD_2026-07-25.md` — état des lieux avant cette session

---

## Le problème de départ

Au 25 juillet, le Smart Whiteboard produisait une vidéo qui **fonctionnait** mais qui
ressemblait à un diaporama : une capture d'écran par scène, assemblée en images fixes.
Le texte apparaissait d'un bloc, les formules mathématiques s'affichaient en double, la
voix lisait « x au carré plus b x plus c égale zéro » de façon robotique et désynchronisée
de l'image.

La demande de l'utilisateur, formulée le 27 juillet, résume l'ambition :

> « J'ai besoin que le rendu soit vraiment animé, monté comme si on avait utilisé plusieurs
> logiciels, et surtout la possibilité que ça soit vraiment sous forme de spot […] parce que
> l'idée c'est qu'il soit aligné aux nouvelles technologies qu'on retrouve sur le marché
> actuellement. […] Il faudrait intervenir depuis la génération des scènes, la génération
> des narrations, la mise en scène. »

Deux exigences en tension, qui ont structuré toutes les décisions :
1. **Qualité « spot »** : animations d'entrée et de sortie, typographie cinétique, son.
2. **Rapidité** : une vidéo regardable **10 à 15 secondes après le clic**.

---

## Ce qui a été livré — vue d'ensemble

Le travail s'est organisé en **sept vagues**. Les vagues 1 à 4 ont reconstruit le moteur ;
les vagues E, F, G l'ont transformé en studio de montage.

### Vagues fondatrices (25–26 juillet)

| Vague | Objet | Résultat |
|---|---|---|
| **Vision V2** | Remplacer le diaporama par une **page HTML filmée en temps réel** | Rendu en **1,48× la durée** de la vidéo (objectif : < 2×) |
| **Deux passes** | Mesurer la position réelle des blocs dans le navigateur avant de filmer | Fin des **chevauchements de texte** et des visées de caméra à côté |
| **Rythme académique** | Vitesse de voix, pauses, prononciation française des maths | `TTS_SPEED = 0.88`, débit ~150 mots/min |
| **Tranches parallèles** | Filmer la même page en 3 morceaux simultanés | Capture ramenée de 194 s à ~70 s sur un cours de 250 s |
| **Aperçu instantané** | Publier les 15 premières secondes avant la fin du rendu | L'étudiant regarde **pendant** que la suite se fabrique |

### Vagues « Spot Studio » (27 juillet)

| Vague | Objet | Résultat |
|---|---|---|
| **A + B** | Habillage : générique, main qui écrit, badges, plaquettes | Générique de 3,2 s ; main + stylo SVG suivant l'écriture mot à mot |
| **C** | Maths parlées correctement en français | LaTeX → MathML → **speech-rule-engine ClearSpeak fr** + table de corrections |
| **D** | Voix neuronale locale (Kokoro-82M) | **Abandonnée** — trop lente sur 4 vCPU (voir `04_DIFFICULTES`) |
| **E** | **Génération** : storyboard v3 | Narration par bloc, `beat` de scène, `key_words`, récap obligatoire |
| **F** | **Mise en scène** : typographie cinétique | Mots-clés rouges qui pop, numéro de chapitre, cartes récap, tampon, barre de progression |
| **G** | **Sound design** | Whoosh, pops, gratté de stylo, tampon, lit musical avec ducking |

---

## Résultats mesurés

| Indicateur | Avant la session | Après | Comment mesuré |
|---|---|---|---|
| Temps de rendu | ~4× la durée vidéo | **1,48×** | Rendu complet d'un cours réel sur le VPS |
| Délai avant première image regardable | = temps de rendu complet | **~15 s** (aperçu) | Log `APERCU publie` du worker |
| Formules mathématiques | Affichées **en double** | Correctes | Inspection visuelle du HTML rendu |
| Chevauchement de texte | Fréquent sur contenu long | Éliminé | Mesure `measure_page.js` + captures |
| Prononciation des maths | Symboles lus littéralement | Phrases françaises naturelles | Écoute des échantillons TTS |
| Événements sonores par cours | 0 | **16 bruitages + 12 grattés** | `test_sfx.py` sur le storyboard de test |

---

## Architecture finale en une image

```
ÉTUDIANT tape un sujet dans l'app Flutter
        │
        ▼
[Supabase] Edge Function whiteboard-generate-storyboard
        │  → storyboard v3 : scènes + beats + blocs + narration par bloc + key_words
        ▼
[Supabase] table de jobs de rendu (statut : queued)
        │
        ▼
[VPS LWS] worker systemd whiteboard-worker
        │
        ├─ 1. NARRATION d'abord (elle fixe la durée de chaque scène)
        │     whiteboard_narration.py → Edge Function TTS → ffmpeg (atempo, loudnorm)
        │     maths verbalisées par math_speech_sre.py (SRE ClearSpeak fr)
        │
        ├─ 2. PAGE HTML animée, calée sur ces durées
        │     whiteboard_page_builder.py → cahier continu, écriture mot à mot,
        │     main + stylo, typographie cinétique, barre de progression
        │     (passe 1 : mesure des positions réelles → passe 2 : caméra recalculée)
        │
        ├─ 3. CAPTURE en 3 tranches parallèles (Playwright/Chromium)
        │     la tranche 1 part seule → APERÇU publié tout de suite
        │
        ├─ 4. SOUND DESIGN : bruitages synthétisés + ducking musical (ffmpeg)
        │
        └─ 5. MUX audio/vidéo → upload Supabase Storage → statut : done
        │
        ▼
[Flutter] l'aperçu joue dès sa publication, puis bascule sur la vidéo complète
```

**Point d'architecture clé** : la narration est produite **avant** la page. C'est elle qui
fixe la durée de chaque scène, pour que la voix ne soit jamais coupée. L'image se cale sur
la voix, jamais l'inverse.

---

## Fichiers touchés pendant la session

### Sur le VPS (`/opt/whiteboard-worker/`)
- `whiteboard_render_worker.py` — orchestration, décalage narration, publication aperçu
- `whiteboard_narration.py` — TTS, cache, post-traitement, maths parlées
- `whiteboard_upload_renderer.py` — upload MP4 + upload de l'aperçu
- `math_speech_sre.py` — **créé** : pont vers speech-rule-engine
- `vision_engine/whiteboard_page_builder.py` — mise en scène complète (43 Ko)
- `vision_engine/whiteboard_video_capture.py` — capture par tranches + aperçu
- `vision_engine/whiteboard_vision_v2.py` — point d'entrée, deux passes, mux
- `vision_engine/whiteboard_sound_design.py` — **créé** : vague G
- `vision_engine/record_scene.js` — capture Playwright temps réel
- `vision_engine/latex_speech.js` — **créé** : LaTeX → parole française
- `vision_engine/measure_page.js` — relevé des positions réelles
- `vision_engine/sfx/` — **créé** : banque de bruitages synthétisés

### Sur Supabase
- `supabase/functions/whiteboard-generate-storyboard/index.ts` — prompt v3 + validation

### Dans l'application Flutter
- `lib/features/challenge/smart_whiteboard/services/smart_whiteboard_render_service.dart`
- `lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart`
- `lib/features/challenge/smart_whiteboard/screens/smart_whiteboard_preview_screen.dart`

---

## Les trois enseignements de la session

1. **La contrainte technique la plus structurante n'était pas la puissance, c'était le
   moteur de capture.** `record_scene.js` n'avance que les animations **CSS**
   (`document.getAnimations()`). Cela a écarté GSAP et imposé que 100 % de la mise en scène
   soit en CSS pur — contrainte qui s'est révélée bénéfique : le rendu par tranches
   parallèles reste possible, donc le rendu reste rapide.

2. **Le calcul local d'IA n'a pas sa place sur ce VPS.** Kokoro-82M en TTS local plafonne à
   un RTF de 3,25 (PyTorch) à 4,5 (ONNX int8) sur 4 vCPU : générer 1 minute de voix
   prendrait 3 à 4 minutes. Pour toute amélioration de voix : passer par une Edge Function
   cloud, pas par du calcul sur la machine de rendu.

3. **La perception de rapidité vaut mieux qu'une rapidité absolue.** Descendre le rendu
   complet sous 15 secondes est hors de portée. Publier les 15 premières secondes en 15
   secondes, en revanche, satisfait exactement le besoin exprimé.
