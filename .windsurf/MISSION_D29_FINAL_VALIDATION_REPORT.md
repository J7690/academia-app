# MISSION D.29 — VALIDATION INDUSTRIELLE FINALE SMART WHITEBOARD

**Date :** 2026-06-30  
**Mode :** LECTURE SEULE — aucune modification appliquée  
**Sources :** documents de conception `.windsurf/` et `docs/`, snapshots Kamatera, RPCs réels, recherches externes officielles.

---

## PHASE 1 — CAHIER DES CHARGES INITIAL

### Sources lues

- `docs/AUDIT_SMART_WHITEBOARD_STUDIO.md`
- `docs/AUDIT_STORYBOARD_ENGINE_N3.md`
- `docs/SMART_WHITEBOARD_DATA_CONTRACT.md`
- `docs/SMART_WHITEBOARD_USER_JOURNEY.md`
- `docs/SMART_WHITEBOARD_IMPLEMENTATION_PLAN.md`
- `docs/SMART_WHITEBOARD_STORAGE_VALIDATION.md`
- `docs/SMART_WHITEBOARD_EVOLUTION_ROADMAP.md`
- `docs/STUDIO_ARCHITECTURE_CURRENT_STATE.md`
- `.windsurf/MISSION_D22_GROUND_TRUTH_REPORT.md`
- `.windsurf/MISSION_D23_FINAL_CONTRACT_AUDIT.md`
- `.windsurf/MISSION_D25_FORENSIC_REPORT.md`
- `.windsurf/MISSION_D26_FORENSIC_REPORT.md`
- `.windsurf/MISSION_D28_INDUSTRIAL_AUDIT.md`
- `.windsurf/kamatera_snapshot/`

### Fonctionnalités prévues (V1 MVP)

| Fonctionnalité | Description | Responsable prévu |
|---|---|---|
| Génération IA | Générer storyboard depuis sujet / texte / plan | Edge Function `whiteboard-generate-storyboard` + OpenRouter |
| Storyboard | Structure JSON : scènes, blocs, thèmes, narration_mode | Edge Function (génération) + Flutter (édition) + Supabase (stockage) |
| Scènes | Conteneurs pédagogiques avec `duration_ms` | Storyboard JSON |
| Blocs | title, paragraph, formula, definition, exercise, correction | Storyboard JSON + renderer PNG |
| Thèmes | `scientific`, `notebook` | Renderer PNG + storyboard JSON |
| Renderers | Génération PNG (Pillow) thématique | Kamatera `whiteboard_png_renderer.py` |
| TTS | Narration voix IA (mode `tts`) | Service TTS backend/worker (prévu V1-V2) |
| Upload audio | Enregistrement utilisateur (mode `user_recording`) | Flutter + Supabase Storage `whiteboard-narrations` |
| Édition | Modifier le storyboard, ajouter/supprimer/réorganiser blocs | Flutter `smart_whiteboard_storyboard_editor_screen.dart` |
| Export MP4 | 1080×1920, 30fps, H.264, AAC | Kamatera worker `whiteboard_ffmpeg_assembler.py` |
| Publication Challenge | Partage TikTok / Shorts / Reels / téléchargement | Flutter `video_publish_screen.dart` (intégration existante) |
| Preview | Lecteur vertical de la vidéo générée | Flutter `smart_whiteboard_preview_screen.dart` |
| Render Job | File d'attente de rendu cloud | Supabase `whiteboard_renders` + Kamatera worker |

### Architecture prévue

```
Flutter (input/editor/preview)
    ↓
Supabase (auth, tables whiteboard_projects/renders, storage, RPCs)
    ↓
Edge Function whiteboard-generate-storyboard (IA storyboard)
    ↓
Kamatera whiteboard-worker.service (poll + render + upload)
    ↓
FFmpeg (PNG → MP4)
    ↓
Supabase Storage whiteboard-renders
    ↓
Flutter preview (video_player)
    ↓
Publication Challenge / téléchargement
```

### Responsabilité prévue par étape

| Étape | Responsable | Livrable attendu |
|---|---|---|
| Saisie sujet/renderer/thème/narration | Flutter | Payload correct vers `createProject` |
| Création projet | Supabase RPC `whiteboard_create_project` | `project_id` |
| Stockage projet | Supabase | `app.whiteboard_projects` |
| Génération contenu | Edge Function + IA | Storyboard JSON structuré, `duration_ms` par scène |
| Édition storyboard | Flutter | Storyboard mis à jour via `whiteboard_update_project` |
| Enregistrement audio (option) | Flutter | Upload dans `whiteboard-narrations` |
| TTS (option) | Backend / worker | Fichier audio narratif |
| Création render job | Flutter via `whiteboard_create_render_job` | Ligne dans `whiteboard_renders` |
| Rendu PNG | Kamatera | 1 PNG par scène |
| Assemblage MP4 | Kamatera FFmpeg | MP4 1080×1920, audio, durée correcte |
| Upload MP4 | Kamatera | URL dans `whiteboard-renders` |
| Mise à jour statut | Kamatera via `whiteboard_mark_done` | `video_url`, `duration_ms` |
| Polling / preview | Flutter | Lecture URL via `video_player` |
| Publication | Flutter | `video_publish_screen.dart` |

---

## PHASE 2 — ÉTAT RÉEL D'IMPLÉMENTATION

| Fonctionnalité | Prévue | Implémentée | Opérationnelle | Responsable |
|---|---|---|---|---|
| **Génération IA** | OUI | OUI | PARTIELLEMENT | Edge Function OK ; Flutter envoie mauvais payload (`_currentProject` null) |
| **Storyboard JSON** | OUI | OUI | OUI | Edge Function génère ; Supabase stocke ; Flutter affiche |
| **Scènes** | OUI | OUI | OUI | Storyboard JSON avec `duration_ms` |
| **Blocs V1** | OUI | OUI | OUI | 6 types supportés dans les modèles Flutter |
| **Thèmes** | OUI | OUI | OUI | `scientific`, `notebook` |
| **Renderers PNG** | OUI | OUI | OUI | Kamatera `whiteboard_png_renderer.py` |
| **TTS** | OUI (V1) | **NON** | **NON** | **Architecture complète** : pas d'Edge Function, pas de service worker, pas de package |
| **Upload audio utilisateur** | OUI | **NON** | **NON** | Service Flutter existe mais non branché à un recorder |
| **Édition storyboard** | OUI | OUI | PARTIELLEMENT | UI basique, pas de drag & drop de scènes, pas de réorganisation complète |
| **Export MP4** | OUI | OUI | **PARTIELLEMENT** | MP4 généré mais durée hardcodée 5s/scène, TTS absent, level 3.1 sous-spécifié |
| **Publication Challenge** | OUI | OUI | NON ATTEINT | `video_publish_screen.dart` existe mais le flux ne l'atteint pas (preview inaccessible) |
| **Preview** | OUI | OUI | **NON** | Player standard sans filtre MediaTek ; `_currentProject` null empêche d'atteindre la preview en conditions réelles |
| **Render Job** | OUI | OUI | OUI | Kamatera worker poll, traite, upload, marque done |
| **Upload Storage** | OUI | OUI | OUI | `whiteboard-renders` reçoit les MP4 |

### Détail des écarts critiques

1. **Durée storyboard** : prévu `duration_ms` ; implémenté `SECONDS_PER_SCENE = 5` (`.windsurf/kamatera_snapshot/whiteboard_ffmpeg_assembler.py:18`).
2. **TTS** : prévu en V1 (roadmap) ; **totalement absent** — `grep tts` sur Kamatera retourne vide (D26).
3. **Audio** : présent mais silencieux (`anullsrc`, D26 : -91 dB).
4. **Preview** : `video_player` standard sans `safeCodecSelector` (D26).
5. ** `_currentProject` null** : empêche le flux d'atteindre la preview en conditions réelles (D22/D23).
6. **`whiteboard_get_render_status` cassée** : référence `wr.file_size_bytes` absent (D23) → HTTP 400 si polling.

---

## PHASE 3 — RECHERCHES EXTERNES APPROFONDIES

### Standards industriels par plateforme

| Plateforme | Storyboard | Narration / TTS | Durée scène | Rendu vidéo | Export MP4 |
|---|---|---|---|---|---|
| **Khan Academy** | Vidéos pédagogiques avec narrateur humain, pas de storyboard machine | Voix humaine (Camtasia/Premiere) ; TTS LMNT pour Khanmigo uniquement | Variable selon pédagogie | Montage manuel | MP4 standard |
| **Explain Everything** | Slides + timeline par slide | Micro utilisateur, piste audio indépendante | Déterminée par l'enregistrement et la timeline | Rendu local/cloud | MP4 |
| **Canva Video** | Scènes sur timeline | AI Voice (TTS cloud) généré puis ajusté sur timeline | Durée de la scène = durée du média ou choix utilisateur | Cloud render | MP4 H.264 AAC |
| **CapCut Education** | Clips sur timeline | Text-to-speech cloud, placement manuel | Clip duration = durée média/TTS | Device/cloud export | H.264 AAC |
| **YouTube Shorts** | Pas de storyboard natif | Voix off / TTS | 60s max | Upload | Recommande H.264 High, level 4.1, AAC 48kHz, faststart |
| **TikTok / Reels** | Pas de storyboard natif | Voix off / TTS | 15s–10min | Upload | H.264, AAC, 1080×1920 |
| **GoodNotes** | Prise de notes + enregistrement audio | Audio utilisateur | Lié à la page/note | Export PDF/audio (pas de vidéo automatisée) | N/A |

### Qui calcule la durée dans l'industrie ?

| Source | Réponse |
|---|---|
| Canva / CapCut | La timeline calcule la durée ; chaque scène/clips a une durée explicite ou dérive du média audio/vidéo. |
| Explain Everything | La durée d'une slide est la durée de l'enregistrement + contenu. |
| TTS-driven videos | La durée de la scène est calculée à partir de la durée audio TTS (+ marge visuelle). |
| YouTube / TikTok | La durée est une métadonnée éditoriale, jamais hardcodée. |

**Verdict :** la durée doit être calculée par le **worker/renderer** à partir du **storyboard** (`duration_ms`) et, quand TTS est actif, de la **durée audio TTS**. **FFmpeg** n'est qu'un exécutant : il reçoit les durées explicites.

### Qui produit l'audio ?

| Plateforme | Producteur audio |
|---|---|
| Canva AI Voice | Backend cloud (service TTS) |
| CapCut TTS | Backend cloud ou intégré partenaire (ElevenLabs) |
| Explain Everything | Frontend (microphone) |
| Khan Academy | Humain (post-prod) / LMNT cloud pour IA |

**Verdict industriel :** le TTS est produit par un **service backend/cloud** (pas le frontend ni le simple FFmpeg). Le frontend enregistre la voix utilisateur. Le worker mélange les pistes.

---

## PHASE 4 — VALIDATION MEDIA3 / EXOPLAYER

### Spécifications officielles pour 1080×1920 @ 30fps

| Paramètre | Recommandation officielle | Source |
|---|---|---|
| H.264 profile | **High** ou **Main** ; Baseline acceptable mais non optimal | YouTube Help, FFmpeg Cookbook |
| H.264 level | **4.0 minimum** pour 1080×1920@30fps (Max Frame Size 8192, MaxMBPS 245760) | H.264 spec ; Android Media3 ; D26 calcul |
| GOP | Half framerate (≈ 15 frames / 0.5s) ou 2s | YouTube Help ; D26 constate 2s |
| Bitrate | 8–10 Mbps (1080p@30fps) ; 8–12 Mbps (Shorts) | YouTube Help, ShortSync, Accio |
| Audio AAC | AAC-LC, 48 kHz, stéréo, 128–192 kbps | YouTube Help, FFmpeg Cookbook |
| moov/mdat | `moov` avant `mdat` (faststart) | ISO BMFF / YouTube / ExoPlayer |
| Colorspace | BT.709, 4:2:0, limited range | YouTube Help, D26 |

### Conformité du MP4 v7 actuel (D25/D26)

| Critère | Valeur v7 | Conforme | Commentaire |
|---|---|---|---|
| Container MP4 | OUI | ✅ | `mov,mp4,m4a,3gp,3g2,mj2` |
| H.264 | OUI | ✅ | `Constrained Baseline` |
| Level | **3.1** | ⚠️ **SOUS-SPECIFIÉ** | Nécessite 4.0 pour 1080×1920@30fps (D26) |
| FPS | 30 | ✅ | |
| Resolution | 1080×1920 | ✅ | |
| Pixel format | yuv420p | ✅ | |
| Color space | BT.709 | ✅ | |
| B-frames | 0 | ✅ | Baseline |
| Audio AAC | OUI | ✅ | `anullsrc` → AAC 44.1kHz stéréo |
| Audio bitrate | 64 kbps | ⚠️ Faible | 128–192 kbps recommandé |
| moov/mdat | moov avant mdat | ✅ | faststart |
| GOP | 2s | ✅ | |
| Bitrate vidéo | ~45 kbps | ❌ | Très faible ; 8–10 Mbps recommandé |
| Decode errors | 0 | ✅ | |

### Analyse du crash TECNO / MediaTek

**Preuves officielles :**

1. **D26 a éliminé les causes classiques :** durée, B-frames, absence audio, moov/mdat, container, PTS/DTS, GOP. Toutes validées OK.
2. **D26 a identifié le level 3.1 comme sous-spécifié :**  
   - Max Frame Size Level 3.1 = 3600 macroblocks ; 1080×1920 = **8100 macroblocks** (×2.25).  
   - MaxMBPS Level 3.1 = 108000 ; 1080×1920@30fps = **243000** (×2.25).  
   - **Level 4.0** est le minimum théorique (Max Frame Size 8192, MaxMBPS 245760).
3. **L'app a déjà rencontré des problèmes MediaTek :** `AcademiaAndroidVideoView.kt:65-75` filtre les codecs `omx.mtk.*` et `c2.mtk.*` (D26). Ce filtre n'est **pas** utilisé par `SmartWhiteboardPreviewScreen`.
4. **androidx/media issue #2702** : équipe Google/MediaTek confirme que certains décodeurs MediaTek ne supportent pas le format 1080×1920 vertical dans certains contextes (DRM L1). Cependant, le MP4 v7 actuel n'est pas testé sur le TECNO LD7 dans D26.
5. **D25 a corrigé un crash ExoPlayer antérieur** en ajoutant une piste audio `anullsrc`. Le crash précédent était dû à un MP4 **video-only**, pas au level 3.1.

### Réponse aux 5 questions

| # | Question | Réponse | Confiance |
|---|---|---|---|
| A | Le problème vient-il du level 3.1 ? | **PARTIELLEMENT** — le level 3.1 est sous-spécifié pour 1080×1920@30fps et peut être rejeté par les décodeurs MediaTek stricts. | 75% |
| B | Du profile Baseline ? | **NON** comme cause unique. Baseline est supporté par ExoPlayer. Il est sous-optimal mais ne cause pas de crash à lui seul. | 90% |
| C | Du bitrate ? | **NON** comme cause de crash. Le bitrate très faible dégrade la qualité mais n'empêche pas le décodage. | 95% |
| D | Du lecteur Flutter ? | **PARTIELLEMENT** — `video_player` utilise ExoPlayer sans le `safeCodecSelector` MediaTek déjà présent dans l'app. | 85% |
| E | D'une combinaison ? | **OUI** : crash historique = MP4 video-only (absence audio) ; risque résiduel = Level 3.1 + lecteur sans filtre MediaTek. | 90% |

---

## PHASE 5 — MATRICE DE RESPONSABILITÉ FINALE

| Problème | Composant responsable | Fichier exact | Preuve | Commentaire |
|---|---|---|---|---|
| **1. Durée incorrecte** | **Kamatera FFmpeg Assembler** | `/opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py:18` | `SECONDS_PER_SCENE = 5` | Ignore les `duration_ms` du storyboard. Responsable unique. |
| **2. TTS absent** | **Architecture globale** | N/A | Aucun service TTS n'existe | Edge Function, worker, Flutter, Supabase : aucun ne produit de voix. |
| **3. Preview TECNO** | **Flutter Preview + Kamatera Assembler** | `smart_whiteboard_preview_screen.dart` + `whiteboard_ffmpeg_assembler.py` | Player sans `safeCodecSelector` ; level 3.1 | Le crash historique était absence audio (corrigé v7). Le risque résiduel est le level 3.1 + player non protégé. |
| **4. Compatibilité MP4** | **Kamatera Assembler** | `whiteboard_ffmpeg_assembler.py` | `-level:v 3.1`, bitrate 45 kbps, audio 64 kbps | Conforme de base mais sous-spécifié. Recommandé : level 4.0, 8–10 Mbps, AAC 128 kbps. |
| **5. Render Job** | **Opérationnel** | Kamatera worker + Supabase RPCs | 0 jobs en attente (D22) ; worker actif | Le job est créé/traité/uploadé si le flux Flutter l'atteint. Actuellement le flux ne l'atteint pas à cause de `_currentProject` null. |
| **6. Upload Storage** | **Opérationnel** | `whiteboard_upload_renderer.py` | Upload vers `whiteboard-renders` | Fonctionne quand le rendu est produit. |
| **7. Preview inaccessible** | **Flutter Provider** | `smart_whiteboard_provider.dart:~100-103` | `_currentProject` jamais assigné | Bloque le flux avant la preview et le rendu. |
| **8. Polling render status cassé** | **Supabase RPC** | `whiteboard_get_render_status` | Référence `wr.file_size_bytes` absent | HTTP 400 systématique si atteint. |

---

## PHASE 6 — PLAN DE CORRECTION MINIMAL (NON APPLIQUÉ)

| ID | Correction | Fichier | Responsable | Impact | Temps estimé |
|---|---|---|---|---|---|
| **C1** | Utiliser `duration_ms` du storyboard au lieu de `SECONDS_PER_SCENE = 5` | `whiteboard_ffmpeg_assembler.py` | Kamatera | Durée vidéo correcte | 15 min |
| **C2** | Réparer `whiteboard_get_render_status` (retirer `wr.file_size_bytes`) | Supabase SQL function | Supabase | Polling Flutter fonctionnel | 10 min |
| **C3** | Construire `_currentProject` après `createProject` | `smart_whiteboard_provider.dart` | Flutter | Payload Edge Function correct, flux atteint preview | 15 min |
| **C4** | Ajouter une Edge Function / service TTS et l'appeler depuis le worker | `supabase/functions/whiteboard-tts/` + `whiteboard_render_worker.py` | Supabase + Kamatera | Narration audio réelle | 2–4 h |
| **C5** | Utiliser `AcademiaAndroidVideoView` avec `safeCodecSelector` dans la preview | `smart_whiteboard_preview_screen.dart` | Flutter | Compatibilité TECNO / MediaTek | 30 min |
| **C6** | Passer FFmpeg à H.264 Level 4.0, bitrate 8 Mbps, AAC 128 kbps | `whiteboard_ffmpeg_assembler.py` | Kamatera | Compatibilité et qualité industrielles | 20 min |
| **C7** | Permettre l'upload audio utilisateur et son mixage | `smart_whiteboard_narration_service.dart` + worker | Flutter + Kamatera | Narration manuelle | 1–2 h |
| **C8** | Brancher la publication Challenge (`video_publish_screen`) | Navigation Flutter + provider | Flutter | Publication opérationnelle | 30 min |

---

## PHASE 7 — VERDICT FINAL

### 1. Le Smart Whiteboard respecte-t-il aujourd'hui son cahier des charges initial ?

**NON.**

Le cahier des charges V1 prévoit un flux fonctionnel de bout en bout : création → génération IA → édition → rendu MP4 → preview → publication. Aujourd'hui, plusieurs ruptures empêchent le flux réel d'atteindre la preview et la publication, et le MP4 produit est non conforme à la durée et au TTS prévus.

### 2. Fonctionnalités totalement opérationnelles

- Création de projet (`whiteboard_create_project`).
- Stockage projet / storyboard JSON (`app.whiteboard_projects`).
- Génération de storyboard par l'Edge Function (si le payload est correct).
- Rendu PNG par thème (`whiteboard_png_renderer.py`).
- Assemblage MP4 basique (`whiteboard_ffmpeg_assembler.py`).
- Upload MP4 vers Supabase Storage (`whiteboard-renders`).
- Worker Kamatera poll/marquage done/failed.
- Tables, index, RLS, triggers (vérifiés par `verify_whiteboard_deployment.py`).
- RPCs editor et worker déployées (vérifiées D27B).

### 3. Fonctionnalités partiellement implémentées

- **Génération IA :** l'Edge Function fonctionne mais reçoit un payload incorrect à cause de `_currentProject` null.
- **Édition storyboard :** UI basique disponible, mais pas de gestion complète des scènes (drag & drop, réorganisation avancée).
- **Export MP4 :** MP4 généré mais avec durée hardcodée, audio silencieux, qualité sous-optimale, level sous-spécifié.
- **Preview :** lecteur présent mais sans protection MediaTek et inaccessible en flux réel.
- **Publication :** écran existant mais non atteint.

### 4. Fonctionnalités n'existant pas encore

- **TTS (voix IA)** : aucun service, aucun appel.
- **Enregistrement audio utilisateur intégré** : le service existe mais n'est pas branché à un recorder.
- **Captions / sous-titres**.
- **Multi-résolution / fallback**.
- **Synchronisation audio/vidéo** (timestamps mot à mot).
- **Bibliothèque médias, musique, transitions**.
- **Monitoring dashboard** des rendus.

### 5. Corrections absolument obligatoires avant mise en production

1. **C3** — `_currentProject` null (débloque tout le flux).
2. **C2** — `whiteboard_get_render_status` cassée (débloque le polling).
3. **C1** — durée hardcodée (respect du cahier des charges `duration_ms`).
4. **C4** — TTS ou audio utilisateur (sinon la vidéo est muette).
5. **C6** — H.264 Level 4.0 + bitrate/audio corrects (compatibilité industrielle).
6. **C5** — filtre MediaTek dans la preview (stabilité TECNO).
7. **C8** — publication Challenge branchée (objectif final du user journey).

Sans ces 7 corrections, le Smart Whiteboard **ne peut pas être considéré comme opérationnel**.

---

## SOURCES ET PREUVES

### Documents internes

- `docs/SMART_WHITEBOARD_USER_JOURNEY.md` — parcours prévu, 7-8 minutes, narration TTS/record.
- `docs/SMART_WHITEBOARD_EVOLUTION_ROADMAP.md` — V1 MVP avec TTS prévu.
- `docs/SMART_WHITEBOARD_DATA_CONTRACT.md` — `duration_ms` obligatoire par scène.
- `docs/SMART_WHITEBOARD_IMPLEMENTATION_PLAN.md` — lots de développement attendus.
- `.windsurf/MISSION_D22_GROUND_TRUTH_REPORT.md` — `_currentProject` null, 0 jobs.
- `.windsurf/MISSION_D23_FINAL_CONTRACT_AUDIT.md` — cause racine `_currentProject` null, `file_size_bytes` absent.
- `.windsurf/MISSION_D25_FORENSIC_REPORT.md` — durée 49.97s vs 69s, `SECONDS_PER_SCENE=5`, audio silencieux.
- `.windsurf/MISSION_D26_FORENSIC_REPORT.md` — 13/13 checks ExoPlayer, level 3.1 sous-spécifié, filtre MediaTek absent.
- `.windsurf/MISSION_D27B_rpc_inventory_output.json` — RPCs `get/update/delete/list` existent dans `public`.
- `.windsurf/kamatera_snapshot/whiteboard_ffmpeg_assembler.py` — code source actuel.
- `.windsurf/kamatera_snapshot/whiteboard_render_worker.py` — aucun appel TTS.

### Sources externes

- Android Developers — ExoPlayer Supported Formats : https://developer.android.com/media/media3/exoplayer/supported-formats
- Android CDD — H.264 profile/level requirements : https://android.googlesource.com/platform/compatibility/cdd/+/refs/heads/nougat-dev/5_multimedia/5_3_video-decoding.md
- YouTube Help — Upload encoding settings : https://support.google.com/youtube/answer/1722171
- FFmpeg Cookbook — YouTube encoding 2026 : https://ffmpeg-cookbook.com/en/articles/youtube-ffmpeg-settings/
- Canva Help — AI Voice : https://www.canva.com/help/canva-ai-voice/
- CapCut — Text to Speech : https://www.capcut.com/tools/text-to-speech
- Explain Everything Help — Recording & Timeline : https://help.explaineverything.com/hc/en-us/articles/360013082319
- Khan Academy Blog — TTS LMNT : https://blog.khanacademy.org/text-to-speech-is-live-on-khanmigo/
- TikTok specs : https://postfa.st/sizes/tiktok/video
- Instagram Reels specs : https://help.instagram.com/1038071743007909
- androidx/media issue #2702 — MediaTek vertical 9:16 : https://github.com/androidx/media/issues/2702

---

**MISSION D.29 CLÔTURÉE**  
Validation industrielle finale. Aucune modification appliquée. Plan de correction minimal produit.
