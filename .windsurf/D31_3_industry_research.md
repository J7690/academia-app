# D31_3_industry_research.md

**Date :** 2026-06-30  
**Objectif :** Déterminer les standards industriels pour une vidéo verticale 1080×1920 @ 30fps avec AAC.

---

## 1. Résumé des standards par plateforme

| Plateforme | Résolution | Format | Vidéo | Profil | Level | Bitrate | Audio | Framerate |
|---|---|---|---|---|---|---|---|---|
| **YouTube Shorts** | 1080×1920 | MP4 | H.264 | — | — | 8 Mbps recommandé | AAC 48 kHz | 24/30 fps |
| **TikTok** | 1080×1920 | MP4/MOV | H.264 | — | — | 8–15 Mbps | AAC 44.1 kHz | 30 fps |
| **Instagram Reels** | 1080×1920 | MP4 | H.264/HEVC | progressive | — | max 25 Mbps | AAC 48 kHz | 23–60 fps |
| **Canva** | 1080×1920 | MP4 | H.264 | — | — | 5–10 Mbps | AAC | 30 fps |
| **CapCut** | 1080×1920 | MP4 | H.264 | — | — | 8–15 Mbps | AAC 48 kHz | 30 fps |

---

## 2. YouTube Shorts — sources officielles

- **Google / YouTube Help** : https://support.google.com/youtube/answer/1722171
- Recommandation : MP4, H.264, 1080×1920, 8 Mbps pour SDR 30 fps, AAC 48 kHz.
- Le bitrate est la clé pour éviter la recompression excessive de YouTube.

---

## 3. TikTok — sources

- **Postfast** : https://postfa.st/sizes/tiktok/video
- **Screensnap** : https://www.screensnap.pro/blog/tiktok-video-size-guide
- **Tokportal** : https://www.tokportal.com/post/tiktok-upload-video-quality
- **Postrsocial** : https://www.postrsocial.com/integrations/tiktok/video-specs
- Consensus : MP4/MOV, H.264, AAC, 1080×1920, 30 fps, 8–15 Mbps.

---

## 4. Instagram Reels — sources officielles

- **Meta / Instagram Help** : https://help.instagram.com/...
- **Swat.io** : https://help.swat.io/en/articles/11663331-instagram-reels-format-requirements
- Recommandation : H.264 ou HEVC, 1080×1920, 9:16, max 25 Mbps, AAC 128 kbps, 48 kHz.

---

## 5. Android Media3 / ExoPlayer

- **Source officielle Android** : https://developer.android.com/media/media3/exoplayer/supported-formats
- ExoPlayer supporte H.264 Baseline/Main/High et AAC.
- La compatibilité réelle dépend du décodeur matériel (MediaCodec).
- **Point critique** : pour 1080×1920 @ 30 fps, le H.264 Level **3.1 est insuffisant** ; le Level **4.0 ou 4.1** est recommandé.

### H.264 Level requis

| Level | Résolution max | Frame rate | Bitrate max |
|---|---|---|---|
| 3.1 | 720p (1280×720) | 30 fps | 14 Mbps |
| 4.0 | 1080p (1920×1080) | 30 fps | 20 Mbps |
| 4.1 | 1080p (1920×1080) | 30 fps | 50 Mbps |
| 4.2 | 1080p (1920×1080) | 64 fps | 50 Mbps |

**Conclusion :** 1080×1920 @ 30 fps avec H.264 nécessite **Level 4.0 minimum**.  
Le Smart Whiteboard actuel encode en **Level 3.1**, ce qui est **techniquement sous-spécifié** pour la résolution 1080×1920.

---

## 6. MediaTek

- **Linux kernel patchs** : MediaTek vcodec H.264 level par défaut = 4.1, max 4.2 selon plateforme.
- Cependant, les décodeurs MediaTek sont stricts sur la conformité du level. Un fichier marqué Level 3.1 avec une résolution supérieure à 720p peut être rejeté ou provoquer un crash du décodeur OMX.

---

## 7. Recommandation industrielle finale

Pour une vidéo Smart Whiteboard 1080×1920 @ 30fps :

| Paramètre | Valeur recommandée | Valeur actuelle D31.2 | Statut |
|---|---|---|---|
| Résolution | 1080×1920 | 1080×1920 | ✅ |
| Aspect ratio | 9:16 | 9:16 | ✅ |
| Format | MP4 | MP4 | ✅ |
| Codec vidéo | H.264 | H.264 | ✅ |
| Profil | Baseline ou Main | Constrained Baseline | ✅ acceptable |
| Level | **4.0 ou 4.1** | **3.1** | ❌ sous-spécifié |
| Bitrate vidéo | 3–8 Mbps | **46 kbps** | ❌ très faible |
| GOP | 2s (60 frames) | 2s (60 frames) | ✅ |
| B-frames | Éviter | 0 | ✅ |
| Audio codec | AAC | AAC | ✅ |
| Audio sample rate | 48 kHz | 44.1 kHz | ⚠️ acceptable |
| Audio bitrate | 128 kbps | **2 kbps** | ❌ très faible |
| Audio source | Vraie narration | Silence | ❌ TTS absent |
| faststart | Oui | Oui | ✅ |
| Colorspace | BT.709 | BT.709 | ✅ |
| Pixel format | yuv420p | yuv420p | ✅ |

---

## 8. Sources

- YouTube Help : https://support.google.com/youtube/answer/1722171
- TikTok specs : https://postfa.st/sizes/tiktok/video
- Instagram Reels format : https://help.swat.io/en/articles/11663331-instagram-reels-format-requirements
- Android Media3 supported formats : https://developer.android.com/media/media3/exoplayer/supported-formats
- H.264 levels : ITU-T H.264 / ISO/IEC 14496-10
- MediaTek vcodec H.264 level patches : linux-kernel mailing list, 2023
