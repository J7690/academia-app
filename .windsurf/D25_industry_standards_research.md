# D25_industry_standards_research.md — Standards industriels de référence

## Sources documentées

- Android Developers — ExoPlayer Supported Formats : https://developer.android.com/media/media3/exoplayer/supported-formats
- Blitzcut 2026 Social Video Specs : https://blitzcutai.com/blog/social-video-specs-2026
- ClipToolkit Best Export Settings 2026 : https://www.cliptoolkit.net/best-export-settings-tiktok-reels-youtube/
- YouTube Music Video Encoding Specs : https://support.google.com/youtube/answer/6039860
- pkglog.com MP4 Container Guide 2026 : https://pkglog.com/en/blog/container-format-mp4-practical-guide-en/
- WINK MP4 Packaging Showdown FFmpeg vs Bento4 2025 : https://www.wink.co/documentation/MP4-Packaging-Showdown-FFmpeg-MP4Box-Bento4-2025

---

## FORMAT DE RÉFÉRENCE INDUSTRIEL

### 1. YouTube Shorts

| Paramètre | Spécification officielle |
|---|---|
| Container | MP4 (préféré), MOV |
| Codec vidéo | H.264 (recommandé) |
| Profil H.264 | **High** (production) — Baseline accepté |
| Level | 4.0+ recommandé |
| Résolution | 1080×1920 (9:16) |
| FPS | 24–60 fps |
| Bitrate vidéo | 10–15 Mbps |
| Pixel format | yuv420p |
| Color space | **Rec. 709** |
| Audio codec | **AAC** |
| Audio sample rate | **44.1 kHz** recommandé (48 kHz accepté) |
| Audio bitrate | 192 kbps (128 kbps minimum) |
| Canaux audio | Stéréo |
| faststart | **REQUIS** (moov avant mdat) |
| Durée max | 180 secondes |
| B-frames | Autorisés (High profile) |

### 2. TikTok

| Paramètre | Spécification officielle |
|---|---|
| Container | MP4, MOV, AVI, WebM |
| Codec vidéo | H.264 (recommandé) |
| Résolution | 1080×1920 minimum |
| FPS | 23–60 fps |
| Bitrate vidéo | 10–15 Mbps |
| Audio codec | **AAC** |
| Audio sample rate | **44.1 kHz** |
| Audio bitrate | 192 kbps |
| Canaux audio | Stéréo |
| Durée max | 10 minutes (créateurs standards) |
| Max file size | 287.6 MB |

### 3. Instagram Reels

| Paramètre | Spécification officielle |
|---|---|
| Container | MP4, MOV |
| Codec vidéo | H.264 ou HEVC |
| Résolution | 1080×1920 |
| FPS | 23–60 fps |
| Bitrate vidéo | 10–15 Mbps |
| Audio codec | **AAC** |
| Audio sample rate | **44.1 kHz** |
| Audio bitrate | 192 kbps |
| Canaux audio | Stéréo |
| Durée max API | 90 secondes |

### 4. ExoPlayer / Android Media3

Source : https://developer.android.com/media/media3/exoplayer/supported-formats

| Paramètre | Spécification |
|---|---|
| Container | MP4 ✓, M4A ✓, FMP4 ✓, WebM ✓ |
| Codec vidéo | H.264 ✓ (natif Android depuis API 16) |
| Profil H.264 | Baseline ✓, Main ✓, High ✓ (selon device) |
| Audio codec | AAC ✓ (natif), MP3 ✓, Opus ✓, Vorbis ✓ |
| **Audio requis** | **NON obligatoire théoriquement** |
| **Audio pratique** | **OUI requis — décodeurs OMX Qualcomm échouent sur video-only** |
| faststart | **FORTEMENT RECOMMANDÉ** pour lecture réseau |
| Color space | BT.709 ✓, BT.2020 ✓ |
| moov position | **AVANT mdat** impératif pour streaming |

**Note critique ExoPlayer :** Le décodeur plateforme est celui d'Android (`OMX.qcom.video.decoder.avc` sur Qualcomm). Sur les appareils Qualcomm, un MP4 video-only peut déclencher un `MediaCodecVideoRenderer error` lors de la libération de la Surface, même si `format_supported=YES`. La piste audio AAC élimine ce comportement.

### 5. VLC Android

- Lit tous les profils H.264, audio optionnel, pas de faststart requis
- Outil de référence pour tests de compatibilité maximale

---

## Tableau comparatif — Standard industrie vs Implémentation actuelle

| Critère | Standard industrie | Implémentation v7 | Conforme ? |
|---|---|---|---|
| Container | MP4 | MP4 | ✓ OUI |
| Codec vidéo | H.264 | H.264 | ✓ OUI |
| Profil H.264 | High (prod) / Baseline (compat) | **Constrained Baseline** | ⚠ PARTIEL (compat mais pas production) |
| Level | 4.0+ recommandé | **3.1** | ⚠ SOUS-SPÉCIFIÉ |
| Résolution | 1080×1920 (9:16) | 1080×1920 | ✓ OUI |
| FPS | 30 fps | 30 fps | ✓ OUI |
| Bitrate vidéo | 10–15 Mbps | **54 kbps total** | ✗ NON — CRF28 trop bas |
| Pixel format | yuv420p | yuv420p | ✓ OUI |
| Color space | Rec. 709 | BT.709 | ✓ OUI |
| smpte170m | ABSENT | ABSENT | ✓ OUI (v6) |
| B-frames | 0 (Baseline) | 0 | ✓ OUI |
| Audio codec | AAC | AAC | ✓ OUI (v7) |
| Audio sample rate | 44.1–48 kHz | **44.1 kHz** | ✓ OUI |
| Audio bitrate | 128–192 kbps | **64 kbps** | ⚠ SOUS-SPÉCIFIÉ |
| Audio canaux | Stéréo | Stéréo | ✓ OUI |
| Audio réel (TTS) | Voix si narration=tts | **Silence** | ✗ NON |
| faststart (moov<mdat) | REQUIS | OUI | ✓ OUI |
| Durée vidéo | = storyboard | **-19s (49.97 vs 69s)** | ✗ NON |
| duration_ms Supabase | = durée réelle | **45000ms (faux)** | ✗ NON |

### Conformité globale : 10/14 critères (71%)

**Non-conformités critiques :**
1. Bitrate vidéo 54 kbps (industrie : 10–15 Mbps) — qualité dégradée
2. Audio TTS absent (silence au lieu de voix)
3. Durée vidéo -19s vs storyboard
4. Audio bitrate 64 kbps (industrie : 128–192 kbps)

---

*Sources : Android Developers, Blitzcut 2026, ClipToolkit 2026, YouTube officiel.*
