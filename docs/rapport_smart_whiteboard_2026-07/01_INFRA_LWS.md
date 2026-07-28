# 01 — Infrastructure LWS : le moteur de rendu

> VPS LWS, alias SSH `lws-nexiom`, IP `31.207.38.60`.
> Racine du worker : `/opt/whiteboard-worker/`. Moteur : `/opt/whiteboard-worker/vision_engine/`.
> Service systemd : `whiteboard-worker` (`Restart=always`, `EnvironmentFile=/opt/whiteboard-worker/.env`).

---

## 1. Le passage de Vision v1 à Vision v2

### Ce que faisait v1
Une capture d'écran **par scène**, puis assemblage des images fixes par ffmpeg. Résultat :
un diaporama. Le texte apparaissait d'un bloc, aucun mouvement, aucune écriture.

### Ce que fait v2
Une **seule page HTML** contenant tout le cours, avec des animations CSS, **filmée en temps
réel** par Playwright/Chromium pendant que les animations se jouent.

Point d'entrée : `whiteboard_vision_v2.py`, fonction `render_storyboard_v2()`.

```
narration (déjà produite) ──fixe les durées──► write_page() ──► cours.html
                                                                    │
                                                    measure_page.js ─┤ passe 1 : mesure
                                                                    │
                                              write_page(measured) ─┤ passe 2 : caméra juste
                                                                    ▼
                                          record_page_parallel() ──► cours_muet.mp4
                                                                    │
                                              build_full_mix() ─────┤ bruitages + musique
                                                                    ▼
                                                  _mux_audio() ────► cours.mp4
```

### Performance mesurée
Rendu complet d'un cours réel : **1,48× la durée de la vidéo** (objectif fixé : < 2×).

---

## 2. Le rendu en deux passes — la fin des chevauchements

**Le problème.** Les positions verticales des blocs étaient **estimées en Python** avec une
règle du type « environ 30 caractères par ligne ». Sur du contenu réel — une définition
longue, un diagramme, une formule KaTeX haute — l'estimation se trompait de plusieurs
dizaines de pixels. Conséquences : les textes **se chevauchaient**, et la caméra visait à
côté du bloc en cours d'écriture.

**La solution.** Deux passes.

| Passe | Ce qu'on fait | Pourquoi |
|---|---|---|
| 1 | Page écrite **sans défilement**, blocs en flux naturel. On l'ouvre dans Chromium et `measure_page.js` relève la position réelle de chaque bloc. | En flux naturel, le chevauchement est **impossible** par construction |
| 2 | Même page réécrite, mais les mouvements de caméra sont recalculés sur les positions **mesurées** | La caméra vise juste, au pixel |

**Dégradation gracieuse** : si la mesure échoue (timeout, Chromium indisponible), on rend
avec les positions estimées. Mieux vaut une caméra approximative qu'aucune vidéo.

```python
_, duration = write_page(storyboard, page_path, narration)
measured = _measure(page_path)
if measured:
    _, duration = write_page(storyboard, page_path, narration, measured=measured)
else:
    logger.warning("[vision2] mesure indisponible — positions estimees (moins precis)")
```

---

## 3. La capture par tranches parallèles

**Le constat.** Sur un rendu de 250 s, la capture représentait **194 s** — soit 78 % du
temps total. C'était le goulot d'étranglement.

**La solution.** La **même page** est filmée en 3 morceaux simultanés
(`PARALLEL_SLICES = 3`), chaque processus Playwright avançant les animations CSS jusqu'à son
instant de départ (`start_ms`) avant de commencer à filmer. Les morceaux sont ensuite
concaténés par ffmpeg.

**Pourquoi c'est possible** : les animations sont **100 % CSS** et donc *seekables*. Un
processus peut sauter directement à la seconde 40 et filmer de là. Avec une bibliothèque
JavaScript impérative, ce serait impossible.

**Repli automatique** : en cas d'échec d'une tranche, on retombe sur l'enregistrement d'une
seule traite.

### Prototype écarté : `beginFrame` (CDP)
`proto_capture_bf.js` explorait `HeadlessExperimental.beginFrame` pour une capture
déterministe image par image. Résultat : **plus lent** que la capture temps réel, et les
images fixes ressortaient **blanches**. Le fichier est conservé comme trace de l'essai.
⚠️ **Ne pas l'utiliser pour la validation visuelle** — utiliser `snap_still.js`.

---

## 4. L'aperçu instantané — répondre au « 10-15 secondes »

**L'exigence.** Une vidéo regardable 10 à 15 secondes après le clic. Impossible pour un
cours de 90 s dont le rendu prend ~130 s.

**Le raisonnement.** L'étudiant n'a pas besoin de *toute* la vidéo tout de suite. Il a
besoin de **voir que ça marche**, tout de suite.

**L'implémentation.** Dans `record_page_parallel()`, la tranche 0 est filmée **seule et
d'abord** (donc sur 4 vCPU non partagés, à vitesse maximale), puis publiée immédiatement via
le callback `on_preview`. Les tranches restantes sont ensuite lancées en parallèle.

```python
def _one(i, start, dur):
    out = record_page(html_path, parts[i], dur, fps, strict, start)
    if i == 0 and want_preview:
        try:
            on_preview(out)
        except Exception as exc:
            logger.warning("[capture] apercu non publie (%s) — rendu poursuivi", exc)
    return out
```

**Paramètres** : `PREVIEW_SEC = 15.0` (durée de l'aperçu), `MIN_DURATION_FOR_PREVIEW = 60.0`
(en dessous, l'aperçu est inutile : la vidéo complète arrive presque aussi vite).

**Robustesse** : un échec de publication d'aperçu est **journalisé et ignoré**. Le rendu
complet continue. L'aperçu est un bonus, jamais un point de rupture.

---

## 5. Narration : voix, rythme et maths parlées

### 5.1 Le rythme académique
Le débit initial était celui d'un présentateur, pas d'un professeur.

| Réglage | Valeur | Raison |
|---|---|---|
| `TTS_SPEED` | **0.88** | Débit ~150 mots/min, celui d'un cours suivi au tableau |
| Rembourrage de scène | actif | Un silence court après chaque bloc laisse le temps de lire |
| Durée minimale de scène | active | Une scène courte ne défile pas trop vite pour être lue |

⚠️ **L'Edge Function TTS ignore le paramètre `speed`** (elle reçoit `input` et `voice`
seulement). Le ralenti est donc appliqué **côté worker** par ffmpeg `atempo`, suivi d'une
normalisation `loudnorm` à -16 LUFS.

### 5.2 Les mathématiques parlées en français (vague C)

**Le problème.** `x^2 + bx + c = 0` était lu comme une suite de symboles. Un module regex
maison (`math_speech_fr.py`) faisait de son mieux mais butait sur les fractions imbriquées,
les limites, les vecteurs.

**La chaîne retenue.**

```
LaTeX ──KaTeX──► MathML ──speech-rule-engine (ClearSpeak, locale fr)──► phrase française
                                                                              │
                                                              table _FIXES ───┘
```

- `vision_engine/latex_speech.js` — script Node qui exécute la chaîne, en **batch** (une
  seule ouverture de Chromium pour toutes les formules) avec **cache**.
- `math_speech_sre.py` — pont Python, avec **repli sur `math_speech_fr.py`** si SRE échoue.

**La table `_FIXES`** corrige les défauts de la locale française de SRE :

| SRE dit | On corrige en | Pourquoi |
|---|---|---|
| « triangle » | « delta » | Δ en maths se dit delta, pas triangle |
| « flèche droite » | « tend vers » | Notation de limite |
| (élisions manquantes) | « d'x », « l'ensemble » | Français correct — **uniquement sur les vrais mots (3 lettres et plus)**, pour ne pas élider les noms de variables |
| limites | « par valeurs supérieures / inférieures » | Formulation académique française |

**Branchement** dans `whiteboard_narration.py` :
- `_clean_latex()` — pour la prose contenant des segments `$...$`
- `_clean_formula()` — pour les blocs de formule en LaTeX pur

### 5.3 Vague D — Kokoro-82M : essai et abandon

Objectif : une voix neuronale plus naturelle, en local, sans coût par requête.

| Variante testée | RTF mesuré (4 vCPU) | Verdict |
|---|---|---|
| Kokoro-82M PyTorch CPU | **3,25** | 1 min de voix = 3 min 15 de calcul |
| Kokoro ONNX int8 | **4,5** | Pire — affinité des threads bridée sur le VPS |

**Décision : abandon.** Le TTS actuel (Edge Function OpenRouter, repli gTTS) est conservé.

**Nettoyage effectué** : `/opt/kokoro-tts` et le cache HuggingFace **supprimés du VPS**,
scripts de banc d'essai locaux supprimés. Un seul artefact conservé pour référence d'écoute :
`academia_bobodo_backend/kokoro_echantillon_fr.wav`.

**Règle pour l'avenir** : toute amélioration de voix passe par une **Edge Function cloud**,
jamais par du calcul sur la machine de rendu.

---

## 6. Vagues A + B — L'habillage « spot » et la main qui écrit

Tout est dans `vision_engine/whiteboard_page_builder.py` (43 Ko).

### Le générique d'ouverture
`INTRO_SEC = 3.2` secondes : carte-titre pleine page en dégradé, sur-titre « COURS » espacé,
titre qui apparaît **lettre par lettre**, puis sortie en balayage.

**Conséquence en cascade** : `plan()` décale tout le cours de `INTRO_SEC`. La narration doit
donc être décalée d'autant — fait dans `whiteboard_render_worker.py` par ffmpeg `adelay`.

### La main et le stylo
Une main + stylo en **SVG (data-URI)** suit l'écriture mot à mot, via `.w::after` et
`animation-delay: inherit`.

**Pourquoi pas GSAP ?** GSAP est désormais gratuit et aurait offert des timelines riches.
Mais `record_scene.js` n'avance que les animations **CSS** via `document.getAnimations()` —
une animation GSAP resterait figée dans les tranches parallèles. **100 % CSS, non
négociable.** C'est la contrainte la plus structurante de tout le projet.

### Le reste de l'habillage
Badges pilule en pop, plaquette de titre de scène qui se déploie, formules en pop, liseré de
définition synchronisé avec le premier mot écrit.

---

## 7. Vague F — La mise en scène v3

| Élément | Sélecteur CSS | Comportement |
|---|---|---|
| **Typographie cinétique** | `.w.kw` | Les `key_words` du storyboard s'écrivent en **rouge**, plus gros, avec un pop élastique (`kwIn`) — comme un prof qui souligne au feutre |
| **Numéro de chapitre** | `.chap` | Pastille « 01 », « 02 »… sur la plaquette de titre (`scene_index + 1`) |
| **Cartes récap** | `.blk-recap`, `.chk` | Sur les scènes de `beat: recap` : carte blanche, coches vertes qui apparaissent une par une |
| **Tampon de correction** | `.stamp` | Un ✓ tamponné après la dernière ligne des corrections, à `write_end + 0.25 s` |
| **Barre de progression** | `#prog` | `scaleX` linéaire sur toute la durée, en bas de l'écran |

**Validation** : effectuée **image par image** sur le VPS, aux instants clés (1,5 s
générique / 21,5 s chapitre + mot-clé rouge / 82 s tampon + première coche / 85,3 s récap
complet). Toutes les captures conformes.

---

## 8. Vague G — Le sound design

Fichier : `vision_engine/whiteboard_sound_design.py`. Branché dans `render_storyboard_v2()`.

### Choix d'architecture

1. **Tout se joue en post-production ffmpeg.** Zéro impact sur la capture et sur la
   synchronisation.
2. **Les instants viennent du même `plan()`** qui a construit la page. Image et son sont
   donc calés sur **la même horloge** — pas de dérive possible.
3. **Les bruitages sont synthétisés par ffmpeg** au premier usage, puis mis en cache dans
   `vision_engine/sfx/`. Aucun fichier à télécharger, aucune question de licence.
4. **Toute erreur est non fatale** : on retourne `None` et la vidéo garde sa narration seule.

### La banque de bruitages

| Son | Recette | Volume | Déclencheur |
|---|---|---|---|
| `whoosh.wav` | Bruit rose filtré en bande (900 Hz), fondus | 0,32 | Générique (entrée + sortie), plaquettes de titre |
| `pop.wav` | Sinus 820 Hz de 0,12 s, chute rapide | 0,26 | Badges, formules, définitions, exercices, coches de récap |
| `stamp.wav` | Sinus 150 Hz amorti | 0,40 | Tampon des corrections (`write_end + 0.25`) |
| `scratch.wav` | Bruit rose 1,4–4,2 kHz, bouclé | 0,10 | Pendant l'écriture manuscrite (blocs > 0,4 s) |

### Le lit musical — optionnel

Si `vision_engine/sfx/music_bed.mp3` existe (n'importe quel morceau libre déposé là), il est
bouclé sur la durée, mis à volume 0,10, avec fondus, et **compressé en sidechain sous la
voix** :

```
sidechaincompress=threshold=0.03:ratio=8:attack=80:release=600
```

La musique s'efface donc automatiquement quand le professeur parle, et remonte dans les
silences. **Sans ce fichier, pas de musique** — le reste du sound design fonctionne
normalement.

### Garde-fous
- `MAX_EVENTS = 120` — un cours n'est pas un clip : on borne le nombre d'événements pour ne
  pas fatiguer l'oreille ni dépasser les limites d'entrées ffmpeg.
- `amix ... normalize=0` — sans quoi ffmpeg diviserait le volume par le nombre d'entrées et
  la voix deviendrait inaudible.
- `duration=first` — la voix est la référence temporelle.

### Résultat du test
```
[sfx] mixage : 16 evenements, 12 grattes, musique=False
duree: 88.900000 s (attendu ~ 88.9 )
```
Durée **exacte** au centième. Extrait d'écoute rapatrié :
`academia_bobodo_backend/extrait_sound_design.mp3`.

---

## 9. Inventaire des fichiers déployés (27/07/2026 19h10)

### `/opt/whiteboard-worker/`
| Fichier | Taille | Rôle |
|---|---|---|
| `whiteboard_render_worker.py` | 26 Ko | Orchestration des jobs, narration, aperçu, upload |
| `whiteboard_narration.py` | 27 Ko | TTS, cache, atempo/loudnorm, maths parlées |
| `math_speech_sre.py` | 7 Ko | Pont vers speech-rule-engine + table `_FIXES` |
| `math_speech_fr.py` | 18 Ko | Verbalisation regex — **repli** de SRE |
| `whiteboard_upload_renderer.py` | 4 Ko | Upload MP4 + upload aperçu |

### `/opt/whiteboard-worker/vision_engine/`
| Fichier | Taille | Rôle |
|---|---|---|
| `whiteboard_page_builder.py` | 43 Ko | **Cœur de la mise en scène** — HTML + CSS + timing |
| `whiteboard_video_capture.py` | 17 Ko | Capture par tranches + aperçu |
| `whiteboard_vision_v2.py` | 8 Ko | Point d'entrée, deux passes, mux |
| `whiteboard_sound_design.py` | 8 Ko | Vague G |
| `record_scene.js` | 7 Ko | Capture Playwright temps réel |
| `measure_page.js` | 2 Ko | Relevé des positions réelles |
| `latex_speech.js` | 2 Ko | LaTeX → parole française |
| `sfx/` | 335 Ko | `whoosh.wav`, `pop.wav`, `stamp.wav`, `scratch.wav` |

### Outils de validation (sur le VPS, hors chaîne de production)
| Fichier | Usage |
|---|---|
| `snap_still.js` | Capture d'une image fixe après avoir avancé les animations CSS |
| `snap_frames.sh` | Lance plusieurs captures d'affilée à des instants donnés |
| `debug_page.js` | Inspecte l'état des animations dans la page |
| `inspect_delays.py` | Liste les délais d'animation du HTML généré |
| `test_sfx.py` | Banc d'essai du mixage sur narration factice |
| `test_storyboard_v3.json` | Storyboard de test au format v3 |

### Traces d'essais conservées (ne pas utiliser en production)
`proto_capture_bf.js`, `proto_capture.js`, `capture_scene.js`,
`whiteboard_playwright_capture.py`, `whiteboard_scene_engine.py`, `scene_template.html`,
`whiteboard_png_renderer.py`, `whiteboard_ffmpeg_assembler.py` (chaîne Pillow/diaporama
d'origine).
