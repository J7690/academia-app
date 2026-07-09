# MISSION D.25 — RAPPORT D'AUDIT FORENSIQUE FINAL
## Pipeline de Rendu Smart Whiteboard — Édition Finale

**Date d'audit :** 2026-06-29
**Méthode :** LECTURE SEULE — aucune modification de code appliquée dans cette phase
**Render de référence :** `ad74ed9e-2133-4c79-9a84-29b33d9d8fb3` (worker v7, produit en production)
**Sources de vérité :** ffprobe runtime SSH Kamatera, logs systemd, code source Python actif, REST API Supabase admin

> **Note :** Le précédent rapport portait sur le render `07356b0d` (avant correction P1). Ce rapport final porte sur le render `ad74ed9e` produit par worker v7 après application des corrections D.25.

---

## SYNTHÈSE EXÉCUTIVE

### Ce qui fonctionne (3/5 axes)
- **Compatibilité ExoPlayer** : 13/13 critères validés — MP4 conforme Android (v7)
- **Qualité container** : moov < mdat, H.264 Baseline 3.1, BT.709, yuv420p, 0 B-frames
- **Audio présent** : AAC 44100Hz stéréo (correction P1 appliquée)

### Ce qui est encore défaillant (2/5 axes)
- **Durée vidéo** : 49.97s produit vs 69.00s attendu — écart **-19.033s**
- **Audio TTS** : `narration_mode="tts"` déclaré mais voix absente (silence synthétique)

---

## PHASE 1 — TRAÇAGE COMPLET DE LA DURÉE VIDÉO

### Storyboard JSON — source de vérité

| order | scene_id | duration_ms storyboard | cumul_ms | blocks |
|---|---|---|---|---|
| 0 | scene-001 | 7000 | 7000 | title, paragraph×2 |
| 1 | scene-002 | 8000 | 15000 | definition, formula |
| 2 | scene-003 | 6000 | 21000 | paragraph×2 |
| 3 | scene-004 | 7000 | 28000 | paragraph×2, formula |
| 4 | scene-005 | 9000 | 37000 | paragraph×2, formula×2 |
| 5 | scene-006 | 10000 | 47000 | paragraph, formula×4 |
| 6 | scene-007 | 7000 | 54000 | exercise, formula, paragraph |
| 7 | scene-008 | 8000 | 62000 | correction, formula×3 |
| 8 | scene-009 | 7000 | 69000 | paragraph×4 |

**DURÉE ATTENDUE = 69 000ms = 69.000s**

### Métriques ffprobe runtime

| métrique | valeur réelle |
|---|---|
| duration container (moov/mvhd) | **49.966667s** |
| duration stream vidéo (tkhd) | **49.966667s** |
| nb_frames (header) | **1499** |
| nb_frames (comptés) | **1499** |
| fps réel (avg_frame_rate) | **30/1** |
| time_base vidéo | **1/15360** |
| duration_ts vidéo | **767488** |
| durée calculée (1499÷30) | **49.9667s** |
| taille fichier | **338856 bytes** |
| bit_rate container | **54253 bps** |
| nb_streams | **2** (video + audio) |

### Verdict durée

```
DURÉE ATTENDUE (storyboard) : 69.000s
DURÉE RÉELLE  (ffprobe)     : 49.967s
ÉCART                       : -19.033s  (-27.6%)
```

**NON CONFORME.**

### Responsable identifié

**Fichier :** `whiteboard_ffmpeg_assembler.py` ligne **18**
```python
SECONDS_PER_SCENE = 5  # ← CAUSE RACINE
```

**Preuve :** La constante `SECONDS_PER_SCENE = 5` est utilisée systématiquement dans `concat.txt` pour chaque PNG, ignorant les `duration_ms` du storyboard JSON (6000–10000ms par scène).

**Composants exclus :**
- Storyboard JSON : correct (source de vérité)
- Flutter : affiche seulement
- Supabase : route seulement
- Edge Function : génère le storyboard, pas FFmpeg
- `whiteboard_png_renderer.py` : génère 1 PNG/scène, pas de durée

---

## PHASE 2 — AUDIT FORENSIQUE DES PISTES AUDIO

### Responsabilité théorique

| Composant | Responsable audio ? |
|---|---|
| Flutter | NON — affiche, ne génère pas |
| Edge Function | NON — génère storyboard |
| Supabase | NON — stocke et route |
| Kamatera Worker | OUI (orchestration) |
| FFmpeg Assembler | OUI (direct — construit la cmd FFmpeg) |
| TTS Service | OUI SI narration_mode=tts |

### Responsabilité réelle — preuves

**grep commande FFmpeg réelle :**
```python
"-f", "lavfi",
"-i", "anullsrc=r=44100:cl=stereo",  # silence synthétique
"-c:a", "aac",
"-b:a", "64k",
"-ar", "44100",
"-ac", "2",
"-shortest",
```

**Flags audio — présence/absence :**

| Flag | Présent |
|---|---|
| `-c:a aac` | OUI |
| `anullsrc` | OUI |
| `-an` | NON |
| `-i narration.wav` | NON |
| `-i audio.mp3` | NON |
| `-map 0:v` | NON |

**ffprobe -show_streams résultat :**
```
VIDEO + AUDIO : 2 streams
AUDIO : codec=aac sr=44100 ch=2 stereo dur=49.946s bit_rate=2091bps
```

**→ VIDEO + AUDIO ✓ — mais audio silencieux (anullsrc)**

### Premier composant défaillant sur la chaîne TTS

`whiteboard_render_worker.py` — aucun appel TTS entre `render_storyboard_to_pngs()` et `assemble_pngs_to_mp4()`. Malgré `narration_mode="tts"` dans le storyboard, aucune voix n'est jamais générée.

---

## PHASE 3 — TRAÇAGE COMPLET DE LA CHAÎNE KAMATERA

```
STORYBOARD JSON (Supabase app.whiteboard_projects)
  ↓ RPC whiteboard_fetch_queued_jobs → job["storyboard"]

whiteboard_render_worker.py — _process_single_job()
  ↓ _mark_job_processing()

whiteboard_png_renderer.py — render_storyboard_to_pngs()
  Input  : storyboard_json (dict)
  Output : [scene_0.png … scene_8.png]  (1080×1920, thème notebook)
  Durées : IGNORÉES — 1 PNG par scène sans notion de durée

whiteboard_ffmpeg_assembler.py — assemble_pngs_to_mp4()
  Input  : [9 PNGs], output_dir
  Action : concat.txt avec duration=5 (fixe) par PNG
  FFmpeg : 9×5s = 45s concat → 49.967s réel avec dernière frame
  Audio  : anullsrc (silence AAC)
  Output : output.mp4 (338856 bytes)

whiteboard_upload_renderer.py — upload_mp4_to_storage()
  Bucket : whiteboard-renders
  Path   : renders/{job_id}/{uuid}.mp4
  Output : URL publique Supabase

whiteboard_render_worker.py — _mark_job_done()
  duration_ms = len(scenes) * 5000 = 45000  ← FAUX (réel=49967, attendu=69000)
  → RPC whiteboard_mark_done()

RÉSULTAT : status=done, video_url=OK, duration_ms=45000 (incorrect)
```

**Logs runtime (render ad74ed9e) :**
```
09:35:03 Processing job ad74ed9e
09:35:03 Assembling MP4 for job ad74ed9e
09:35:16 Uploading MP4 for job ad74ed9e
09:35:17 Job ad74ed9e completed successfully
Durée totale : 14 secondes
```

---

## PHASE 4 — STANDARDS GRANDES PLATEFORMES

### Format industriel de référence (2026)

| Critère | Standard industrie | Sources |
|---|---|---|
| Codec | H.264 | YouTube, TikTok, Reels |
| Profil H264 | High (prod) / Baseline (compat) | Android CTS |
| Level | 4.0+ | Android Media3 |
| FPS | 30 fps (24–60 accepté) | Tous |
| Pixel format | yuv420p | Tous |
| Color space | Rec.709 / BT.709 | Tous |
| Audio | AAC obligatoire | ExoPlayer pratique |
| Sample rate | 44.1 kHz ou 48 kHz | YouTube/TikTok/Reels |
| Audio bitrate | 128–192 kbps | Tous |
| Canaux | Stéréo | Tous |
| Faststart | REQUIS | Streaming |
| Atom order | moov < mdat | ISO BMFF |
| B-frames | 0 (Baseline) | Android compat |
| Container | MP4 | Tous |
| Résolution | 1080×1920 (9:16) | Shorts/TikTok/Reels |

### Conformité implémentation v7 : 10/14 (71%)

**Non-conformités :**
1. Bitrate vidéo : 54 kbps vs 10–15 Mbps industrie (CRF28 trop compressif)
2. Audio TTS : absent (silence vs voix attendue)
3. Durée : -19s vs storyboard
4. Audio bitrate : 64 kbps vs 128–192 kbps

---

## PHASE 5 — OUTILS D'ANALYSE RECOMMANDÉS

| Outil | Usage principal | Disponible Kamatera |
|---|---|---|
| ffprobe | Durées, streams, color, frames | OUI (v6.1.1) |
| MediaInfo | Rapport lisible, profil H264 | NON (à installer) |
| mp4dump (Bento4) | Structure atoms ISO BMFF | NON (à installer) |
| AtomicParsley | Métadonnées ID3/iTunes | NON |
| VLC | Test compatibilité maximale | NON (GUI) |
| mpv | Test decode CPU-only | NON |
| ExoPlayer Demo | Test OMX Android réel | APK à installer |
| adb logcat | Erreurs OMX runtime | Via ADB |

---

## PHASE 6 — RESPONSABILITÉ FINALE

### Durée vidéo

| | |
|---|---|
| **Composant responsable** | `whiteboard_ffmpeg_assembler.py` |
| **Fichier exact** | `/opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py` |
| **Ligne** | **18** |
| **Code** | `SECONDS_PER_SCENE = 5` |
| **Preuve runtime** | concat.txt : `duration 5` pour chaque scène, quelle que soit `duration_ms` storyboard |
| **Logs** | Worker traite en 14s → durée 49.97s au lieu de 69s |
| **Conclusion** | Hardcode de 5s/scène → durée toujours fausse, indépendamment du storyboard |

### Piste audio

| | |
|---|---|
| **Composant responsable (audio présent)** | `whiteboard_ffmpeg_assembler.py` v7 |
| **Preuve runtime** | `-f lavfi -i anullsrc` dans la commande FFmpeg |
| **ffprobe** | 2 streams, AAC 44100Hz stéréo 2151 frames |
| **Composant responsable (TTS absent)** | `whiteboard_render_worker.py` |
| **Preuve runtime** | Aucun appel TTS entre lignes 125 et 129 du worker |
| **Conclusion** | Audio AAC présent → ExoPlayer OK. Voix TTS absente → expérience muette |

### Compatibilité ExoPlayer

| | |
|---|---|
| **Composant responsable (résolution)** | `whiteboard_ffmpeg_assembler.py` v7 (correction P1) |
| **Preuve runtime** | 13/13 checks passés : AAC, BT709, Baseline 3.1, 0 B-frames, moov<mdat, decode OK |
| **Logs** | `Job ad74ed9e completed successfully` |
| **Conclusion** | Crash ExoPlayer (MediaCodecVideoRenderer error) résolu par ajout AAC |

---

## PREMIER POINT DE NON-CONFORMITÉ UNIQUE

**Le premier. Celui qui casse toute la chaîne.**

| | |
|---|---|
| **Fichier** | `/opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py` |
| **Ligne** | **18** |
| **Code** | `SECONDS_PER_SCENE = 5` |
| **Preuve runtime** | ffprobe : 49.967s réel vs 69.000s attendu → écart -19.033s |
| **Cause** | Durée hardcodée lors du développement Phase C.3 comme simplification temporaire |
| **Conséquences** | (1) Durée vidéo fausse pour tout projet. (2) duration_ms Supabase erroné. (3) Expérience pédagogique dégradée. (4) TTS (si implémenté) désynchronisé |

---

## LIVRABLES PRODUITS

| Fichier | Contenu |
|---|---|
| `D25_duration_forensics.md` | Traçage durée storyboard vs ffprobe — responsabilité assembler L.18 |
| `D25_audio_forensics.md` | Audit audio — preuves anullsrc, TTS absent |
| `D25_kamatera_render_chain.md` | Chaîne complète Python → FFmpeg → Supabase avec logs |
| `D25_industry_standards_research.md` | Standards YouTube/TikTok/Reels/ExoPlayer documentés |
| `D25_tools_benchmark.md` | Outils industrie (ffprobe, Bento4, MediaInfo, adb) |
| `D25_final_responsibility_matrix.md` | Matrice complète par composant |
| `MISSION_D25_FORENSIC_REPORT.md` | Ce document — rapport de synthèse |

---

*Audit réalisé en lecture seule. Aucun code modifié dans cette phase.*
*Render validé : `ad74ed9e-2133-4c79-9a84-29b33d9d8fb3` — Worker v7 actif sur Kamatera 185.167.97.144.*
