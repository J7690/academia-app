# MISSION D.28 — AUDIT INDUSTRIEL EXTERNE SMART WHITEBOARD

**Statut :** lecture seule, aucune modification.  
**Sources :** Android Developers, ExoPlayer/Media3, GitHub androidx/media, YouTube, Khan Academy, Canva, CapCut, Explain Everything, TikTok, Instagram Reels, ITU-T/Wikipedia.

---

## PHASE 1 — DURÉE DES SCÈNES

### Standards industriels observés

| Plateforme | Gestion de la durée | Preuve |
|---|---|---|
| **Khan Academy** | Durées variables, narrateur humain, pas de scène hardcodée. | "Adobe Premiere Pro or Camtasia for timeline editing" (Quora) ; "Text-to-Speech Is Live on Khanmigo" (LMNT pour l'IA, pas pour les vidéos). |
| **Explain Everything** | Timeline avec clips audio/vidéo indépendants ; chaque slide a sa propre timeline. | Help Center : "Each slide has its own, independent Timeline. When the video is exported, the slides will be joined together." |
| **Canva** | Timeline éditable ; l'utilisateur ajuste la durée des scènes et synchronise l'IA Voice. | Canva Help Center : "Adjust the audio with the video to your required timeline." |
| **CapCut** | Timeline par clips ; durée définie par le média ou l'utilisateur. | CapCut TTS docs : génération audio puis placement sur la timeline. |
| **TikTok / Shorts / Reels** | Clips courts, durée définie par le créateur ou par la musique, 1080×1920, 30 fps. | Postfást / YouTube Help / Instagram Help. |
| **YouTube** | Recommande Closed GOP de moitié du framerate, CBR/VBR, pas de durée fixe par scène. | YouTube Help : "GOP of half the frame rate." |

### Verdict industriel

**A) Hardcodée 5 s → NON.**  
Aucune plateforme éducative ou sociale majeure n'utilise une durée fixe par scène. Cela est propre au pipeline Academia v7.

**B) Pilotée par `duration_ms` du storyboard → OUI, minimum acceptable.**  
C'est la méthode la plus proche des outils de storyboard type Explain Everything / Canva : chaque scène possède une durée déclarée.

**C) Calculée automatiquement à partir du TTS → OUI, meilleure pratique.**  
L'industrie synchronise la narration sur la timeline (Canva, CapCut, ElevenLabs). La durée de la scène doit donc dériver de la durée audio TTS (+ marge de lecture visuelle).

---

## PHASE 2 — TTS (TEXT-TO-SPEECH)

### Comment fonctionnent les références

| Plateforme | Responsable TTS | Mécanisme |
|---|---|---|
| **Khan Academy** | Humain ( narration enregistrée ) + LMNT pour l'IA tutorielle | Vidéos pédagogiques : voix humaine. Khanmigo : TTS cloud LMNT. |
| **Explain Everything** | Utilisateur (micro) | Enregistrement local sur la timeline. |
| **Canva** | Service cloud Canva | "AI Voice" génère l'audio dans l'éditeur, puis l'utilisateur le synchronise. |
| **CapCut** | Service cloud CapCut / partenaire (ElevenLabs) | Génération TTS dans l'app, puis placement sur la timeline. |

### Architecture recommandée pour Academia

1. **Génération TTS** : côté backend (Edge Function ou worker) via un service tiers (ElevenLabs, OpenAI TTS, LMNT, Google Cloud TTS).
2. **Stockage** : bucket Supabase `whiteboard-narrations` (déjà prévu dans le code Flutter).
3. **Synchronisation** : la durée de chaque scène est calculée à partir de la durée de l'audio TTS.
4. **Assemblage** : le worker FFmpeg mélange la piste audio TTS avec les images de la scène.

### Responsabilité TTS

**Aucun composant n'est actuellement responsable.** Le code Flutter contient un `TODO` TTS, aucune Edge Function TTS n'existe, et le worker Kamatera génère une piste `anullsrc` (silence). La responsabilité est donc **architecturale** : il manque un service TTS dans le pipeline.

---

## PHASE 3 — COMPATIBILITÉ MP4 ANDROID

### Recommandations officielles

| Paramètre | Recommandation industrielle | Source |
|---|---|---|
| **Résolution** | 1080×1920 (9:16) | TikTok, YouTube Shorts, Instagram Reels |
| **Framerate** | 30 fps (60 fps optionnel) | YouTube Help, TikTok |
| **Codec vidéo** | H.264 | YouTube Help, TikTok, Instagram |
| **Profile** | **High** (YouTube) ou **Main** ; **Baseline** déconseillé pour 1080p | YouTube Help : "High Profile" ; Android CDD : Baseline Level 3 minimum, Main Level 4 recommandé. |
| **Level** | **4.0 ou 4.1** minimum pour 1080p@30fps | `AVCLevel4` / `AVCLevel41` dans `MediaCodecInfo.CodecProfileLevel` ; FFmpeg Cookbook : `-level 4.1` pour 1080p. |
| **Bitrate** | 8–10 Mbps pour 1080p@30fps (YouTube), 8–12 Mbps (Shorts) | YouTube Help, Accio.com, ShortSync |
| **GOP** | Moitié du framerate (closed GOP) | YouTube Help : "Closed GOP. GOP of half the frame rate." |
| **Audio** | AAC-LC, 48 kHz, 128–192 kbps stéréo | YouTube Help, FFmpeg Cookbook |
| **moov/mdat** | `moov` en tête de fichier (`faststart`) | YouTube/FFmpeg Cookbook : `-movflags +faststart` |
| **Colorspace** | BT.709, 4:2:0, SDR | YouTube Help, Accio.com |
| **B-frames** | 2 B-frames (YouTube) ; 0 pour compatibilité maximale | YouTube recommande 2 ; Baseline interdit les B-frames. |

### Problème MediaTek / TECNO

**Preuve officielle :** androidx/media issue #2702 — "L1 DRM Playback Fails with MediaCodecVideoDecoderException on MediaTek Devices (Vertical 9:16 Video)".

- Appareils reproduisant : Redmi 13C (Helio G85), OnePlus Pad Go (Helio G99), Samsung Galaxy A22 (Helio G80).
- Conclusion de l'équipe Android :  
  > "Mediatek does not support the 1080*1920 format due to this issue. [...] the choices seem to be use L3 DRM or use a different resolution."

**Implication :** un fichier MP4 de 1080×1920 peut échouer sur le décodeur MediaTek, indépendamment du profile/level. La solution industrielle est soit de réduire la résolution verticale (ex. 1080×1920 → 1080×1440 ou 720×1280), soit de s'assurer que le lecteur Flutter utilise un codec compatible.

---

## PHASE 4 — PIPELINE INDUSTRIEL

### Pipeline Academia actuel

```
Flutter → Edge Function (storyboard) → Supabase → Kamatera → FFmpeg → Storage → Preview
```

### Comparaison avec les leaders

| Composant | Academia | Canva / CapCut / Explain Everything | Statut |
|---|---|---|---|
| Storyboard généré par IA | ✅ Edge Function | ✅ Canva Magic Media, CapCut templates | Conforme |
| Éditeur de storyboard | ✅ Basique | ✅ Avancé (timeline, calques, transitions) | Minimum |
| TTS | ❌ Absent | ✅ AI Voice / TTS intégré | **Manquant** |
| Bibliothèque médias | ❌ Absent | ✅ Stock, stickers, musique | **Manquant** |
| Sous-titres / captions | ❌ Absent | ✅ Auto-captions | **Manquant** |
| Rendu cloud | ✅ Kamatera + FFmpeg | ✅ Cloud render + multi-résolution | Conforme en principe |
| Multi-résolution | ❌ Non | ✅ 1080p, 720p, etc. | **Manquant** |
| Preview côté client | ✅ video_player | ✅ Player optimisé + fallback codec | **À renforcer** |
| Monitoring render queue | ❌ Basique | ✅ Dashboard, logs | **Manquant** |
| Export 9:16 | ✅ 1080×1920 | ✅ Standard | Conforme |

### Composants manquants critique

1. **Moteur TTS** et synchronisation audio/vidéo.
2. **Gestion dynamique de la durée** (`duration_ms` ou durée audio).
3. **Encodage compatible MediaTek** : profile/level et résolution fallback.
4. **Lecteur preview avec sélection de codec sécurisée** (safe codec selector).
5. **Monitoring / logs exploitables** du worker Kamatera.

---

## PHASE 5 — MATRICE DE RESPONSABILITÉ

| Problème | Responsable exact | Justification |
|---|---|---|
| **1. Durée incorrecte** | **Kamatera (FFmpeg assembler)** + **Edge Function / IA** | `SECONDS_PER_SCENE = 5` dans `whiteboard_ffmpeg_assembler.py` ignore le storyboard. L'Edge Function génère `duration_ms = 5000` par défaut dans le prompt. Flutter n'a pas d'impact. |
| **2. TTS absent** | **Architecture / produit** (pas un seul composant) | Aucune Edge Function TTS, le worker n'appelle aucun TTS, le `generateTTS` du provider est un `TODO`. Responsabilité transversale : il faut ajouter un service TTS. |
| **3. Crash TECNO (MediaTek)** | **Kamatera (FFmpeg)** + **Flutter (preview)** | Le fichier 1080×1920 déclenche un bug connu du décodeur MediaTek (androidx/media #2702). Le lecteur Flutter `video_player` n'utilise pas le `safeCodecSelector` du feed. La root cause est le MP4 incompatible. |
| **4. Preview Flutter** | **Flutter** (lecteur) + **Kamatera** (fournisseur MP4) | Le preview utilise `VideoPlayerController.networkUrl` standard. Si le MP4 est corrigé, le preview fonctionne. Si le MP4 reste incompatible, le preview a besoin d'un fallback codec. |

---

## PHASE 6 — RAPPORT FINAL

### 1. Ce qui est conforme aux standards industriels

- **Résolution 1080×1920, 30 fps, MP4/H.264/AAC** : conforme aux specs TikTok / YouTube Shorts / Instagram Reels.
- **Faststart (`moov` avant `mdat`)** : conforme aux best practices web/mobile.
- **Colorspace BT.709, 4:2:0** : conforme aux recommandations YouTube.
- **Audio AAC 44.1 kHz / 64 kbps** : acceptable en l'absence de TTS, mais faible par rapport aux 128–192 kbps recommandés.
- **Pipeline cloud rendering** : architecture proche de Canva/CapCut (génération côté serveur).

### 2. Ce qui manque encore

- **TTS** : aucun moteur ni synchronisation.
- **Gestion de la durée** : hardcodée 5 s au lieu de `duration_ms` ou durée audio.
- **Compatibilité MediaTek** : level 3.1 + 1080×1920 vertical = non conforme / risque crash.
- **Multi-résolution / fallback** : un seul MP4 généré, pas de version 720p ou format 16:9.
- **Lecteur preview robuste** : pas de `safeCodecSelector`.
- **Sous-titres / captions** : absent.
- **Bibliothèque médias et transitions** : absent.

### 3. Corrections minimales nécessaires (non appliquées)

1. **Durée** : remplacer `SECONDS_PER_SCENE = 5` par la somme des `duration_ms` du storyboard, puis par la durée audio TTS quand le TTS sera intégré.
2. **TTS** : ajouter un service TTS (Edge Function ou backend) et l'intégrer au worker FFmpeg.
3. **MediaTek** : utiliser **H.264 High/Main Profile Level 4.1** pour 1080×1920@30fps ; ajouter un fallback 720×1280 pour les appareils MediaTek.
4. **Preview** : utiliser le lecteur avec `safeCodecSelector` ou s'assurer que le MP4 est compatible.
5. **Audio** : monter le bitrate à 128 kbps (voix) et 48 kHz, stocker la piste TTS séparément.

### 4. Preuves externes utilisées

- Android Developers — ExoPlayer Supported Formats : https://developer.android.com/media/media3/exoplayer/supported-formats
- Android Developers — `MediaCodecInfo.CodecProfileLevel` : https://developer.android.com/reference/android/media/MediaCodecInfo.CodecProfileLevel
- Android CDD — H.264 profile/level requirements : https://android.googlesource.com/platform/compatibility/cdd/+/refs/heads/nougat-dev/5_multimedia/5_3_video-decoding.md
- androidx/media issue #2702 — MediaTek 1080×1920 vertical crash : https://github.com/androidx/media/issues/2702
- YouTube Help — Upload encoding settings : https://support.google.com/youtube/answer/1722171
- FFmpeg Cookbook — YouTube encoding 2026 : https://ffmpeg-cookbook.com/en/articles/youtube-ffmpeg-settings/
- Canva Help — AI Voice : https://www.canva.com/help/canva-ai-voice/
- CapCut — Text to Speech : https://www.capcut.com/tools/text-to-speech
- Explain Everything Help — Recording & Timeline : https://help.explaineverything.com/hc/en-us/articles/360013082319
- Khan Academy Blog — TTS LMNT : https://blog.khanacademy.org/text-to-speech-is-live-on-khanmigo/
- TikTok video specs : https://postfa.st/sizes/tiktok/video
- Instagram Reels specs : https://help.instagram.com/1038071743007909

---

## Conclusion

Le Smart Whiteboard Academia est **conforme sur la forme** (résolution, container, codec de base) mais **non conforme sur le fond** : durée hardcodée, TTS absent, et MP4 incompatible avec les décodeurs MediaTek en raison du level 3.1 et du format 1080×1920 vertical. Les corrections minimales prioritaires sont la durée pilotée par le storyboard, l'intégration d'un TTS cloud, et le passage à H.264 Level 4.1 avec un fallback résolution pour MediaTek.
