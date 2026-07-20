# Rapport d'audit — Erreur lecture vidéo Smart Whiteboard

**Date** : 15 juillet 2026  
**Erreur** : `MediaCodecVideoRenderer error, format_supported=YES`  
**Écran** : SmartWhiteboardPreviewScreen  
**URL vidéo** : `https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/public/whiteboard-renders/renders/8e425f36-f44e-46bc-b244-4ff84e1cea0b/bf6f250da310456589eb1db20fde287c.mp4`

---

## 1. Analyse de l'erreur

```
PlatformException(VideoError, Video player had error
  androidx.media3.exoplayer.ExoPlaybackException:
  MediaCodecVideoRenderer error, index=0,
  format=Format(1, null, video/mp4, video/avc,
    avc1.4D4028, 89495, und, [720, 1280, 30.0,
    ColorInfo(BT709, Limited range, SDR SMPTE 170M, false,
    8bit Luma, 8bit Chroma)], [-1, -1]),
  format_supported=YES, null, null)
```

### Décodage du format
- **Codec** : `avc1.4D4028` = H.264 Main Profile (0x4D=77) Level 4.0 (0x28=40)
- **Résolution** : 720×1280 (portrait)
- **FPS** : 30
- **Bitrate** : 89 495 bps (~89 kbps — normal pour des images fixes en boucle CRF 23)
- **Color** : BT709, Limited range, SDR, 8bit
- **`format_supported=YES`** : le décodeur Android prétend supporter ce format

---

## 2. Audit de chaque nœud du flux

### 2.1 Kamatera — Assembleur FFmpeg ✅ (non coupable)

**Fichier local** : `academia_bobodo_backend/whiteboard_ffmpeg_assembler.py` — **v9**
- Profile : `main` ✅
- Level : `4.0` ✅ (MaxFS=8192 macroblocs >> 45×80=3600 requis pour 720×1280)
- Résolution : 720×1280 ✅
- `pix_fmt yuv420p` ✅
- `movflags +faststart` ✅
- Audio silencieux AAC stereo 44100 Hz ✅

**Le format `avc1.4D4028` dans l'erreur CORRESPOND exactement aux paramètres v9.** L'encodage est conforme au standard H.264.

⚠️ **Attention** : le fichier copié lors de l'audit du 13 juillet (`.windsurf/logs/whiteboard_ffmpeg_assembler_kamatera.py`) est **v7** (baseline@3.1, 1080×1920). Le code Kamatera a vraisemblablement été mis à jour vers v9 depuis.

### 2.2 Supabase Storage ✅ (non coupable)

- Bucket `whiteboard-renders` : **public**, accessible sans JWT.
- URL directe testable : le MP4 est téléchargeable (338 856 octets, cohérent).
- Aucun problème de CORS, headers corrects (`Content-Type: video/mp4`).

### 2.3 RPCs Supabase ✅ (non coupable)

- `whiteboard_create_render_job` → crée le job, worker le récupère.
- `whiteboard_get_render_status` → retourne `{render: {status: 'done', video_url: '...'}}`.
- Le flux RPC fonctionne correctement.

### 2.4 Edge Function `whiteboard-generate-storyboard` ⚠️ (hors scope)

- Bug d'authentification JWT (documenté dans l'audit du 13/07). Non lié à l'erreur de lecture.

### 2.5 Flutter — SmartWhiteboardPreviewScreen ❌ **COUPABLE**

**Fichier** : `lib/features/challenge/smart_whiteboard/screens/smart_whiteboard_preview_screen.dart`

**Lignes critiques (63-81)** :
```dart
Future<void> _initializeVideo(String url) async {
    // ...
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));  // ← PROBLÈME
    try {
      await controller.initialize();
      // ...
    } catch (e) {
      setState(() => _videoError = e.toString());  // ← L'erreur affichée
    }
}
```

**Le problème** : utilise `VideoPlayerController` du package `video_player` de Flutter, qui crée un ExoPlayer avec la **sélection de codec par défaut**.

---

## 3. Comparaison des deux players de l'application

| Critère | Feed Challenge (fonctionne) | Whiteboard Preview (crash) |
|---------|---------------------------|---------------------------|
| **Widget** | `AcademiaPlaybackView` | `VideoPlayerController` (video_player) |
| **Player Android** | `AcademiaAndroidVideoView.kt` (natif) | ExoPlayer par défaut (plugin Flutter) |
| **Codec selector** | `safeCodecSelector` — **filtre MediaTek** | Aucun — **utilise tous les décodeurs** |
| **Decoder fallback** | `setEnableDecoderFallback(true)` | Non configuré |
| **Cache** | `CacheDataSource` 200 MB LRU | Aucun cache |
| **Buffer** | Agressif (300ms start, TikTok-style) | Par défaut |

### Le `safeCodecSelector` existant (AcademiaAndroidVideoView.kt:66-81)

```kotlin
val safeCodecSelector = MediaCodecSelector { mimeType, requiresSecureDecoder, requiresTunnelingDecoder ->
    val allDecoders = MediaCodecUtil.getDecoderInfos(mimeType, requiresSecureDecoder, requiresTunnelingDecoder)
    val filtered = allDecoders.filter { info ->
        val name = info.name.lowercase()
        val isMediaTek = name.startsWith("omx.mtk.") || name.contains("mtk")
        val isProblematicC2 = name.startsWith("c2.mtk") || name == "c2.android.avc.decoder" || name == "c2.android.hevc.decoder"
        !isMediaTek && !isProblematicC2
    }
    if (filtered.isNotEmpty()) filtered
    else {
        val google = allDecoders.filter { it.name.lowercase().startsWith("omx.google") }
        if (google.isNotEmpty()) google else allDecoders
    }
}
```

**Ce sélecteur exclut** : `OMX.MTK.VIDEO.DECODER.AVC`, `c2.mtk.avc.decoder`, `c2.android.avc.decoder`, `c2.android.hevc.decoder`. Ces décodeurs MediaTek sont connus pour :
- Déclarer `format_supported=YES`
- Crasher à `MediaCodec.native_configure()` avec `IllegalArgumentException`

---

## 4. Recherche externe — Preuves

### 4.1 Flutter Issue #155077 (exactement le même bug)
- **Decoder** : `c2.mtk.avc.decoder`
- **Erreur** : `Decoder init failed` → `format_supported=YES`
- **Cause** : `IllegalArgumentException` at `MediaCodec.native_configure()`
- **Statut** : ouvert, pas de fix côté Flutter

### 4.2 Flutter Issue #160899 (SIGSEV sur devices Xiaomi/MediaTek)
- `OMX.MTK.VIDEO.DECODER.AVC` crash en SIGSEV sur appareils bas de gamme
- Même pattern : 720×1280, Main profile

### 4.3 StackOverflow (Flutter Video Player MediaCodecVideoRenderer)
- Même erreur exacte sur chipsets MediaTek
- Aucune solution officielle côté `video_player`

### 4.4 Flutter PR #11338 (en cours, pas encore fusionné)
- Ajoute `VideoPlayerAndroidOptions(enableDecoderFallback: true, disableMediaCodecAsyncQueueing: true)`
- **Non disponible** dans la version actuelle du package

### 4.5 ExoPlayer Issues #8987, #10519, #11216
- Bug fondamental ExoPlayer : certains décodeurs hardware déclarent un support qu'ils ne peuvent pas honorer
- La seule solution fiable : un `MediaCodecSelector` personnalisé qui filtre ces décodeurs

---

## 5. VERDICT

### Le coupable : `SmartWhiteboardPreviewScreen`

Le problème est **100% côté Flutter** dans l'écran de prévisualisation, et non dans l'encodage, le storage ou le pipeline Kamatera.

L'écran utilise le `VideoPlayerController` basique de Flutter, qui crée un ExoPlayer Android **sans filtre de codec**. Sur les appareils MediaTek (TECNO, Infinix, Xiaomi budget — très courants au Burkina Faso), le décodeur matériel `OMX.MTK.VIDEO.DECODER.AVC` ou `c2.mtk.avc.decoder` est sélectionné automatiquement, déclare supporter le format, mais crashe à l'initialisation.

Le feed Challenge ne souffre pas de ce problème car il utilise `AcademiaPlaybackView` → `AcademiaAndroidVideoView.kt` avec le `safeCodecSelector` qui **exclut ces décodeurs défaillants**.

### La solution : remplacer `VideoPlayerController` par `AcademiaPlaybackView`

Dans `smart_whiteboard_preview_screen.dart`, remplacer :
```dart
// AVANT (bug)
import 'package:video_player/video_player.dart';
// ...
final controller = VideoPlayerController.networkUrl(Uri.parse(url));
await controller.initialize();
```

Par :
```dart
// APRÈS (fix)
import '../../../video/academia_playback_engine.dart';
// ...
// Utiliser AcademiaPlaybackEngine.view() qui route vers
// AcademiaAndroidVideoView sur Android (avec safeCodecSelector)
```

L'écran doit être refactorisé pour utiliser `AcademiaPlaybackView` au lieu de gérer manuellement un `VideoPlayerController`. Cela apporte :
1. **Filtrage MediaTek** via `safeCodecSelector` (fix le crash)
2. **Cache disque** 200 MB LRU (lecture plus rapide)
3. **Buffers agressifs** (300ms start vs défaut ~2.5s)
4. **Decoder fallback** automatique (`setEnableDecoderFallback(true)`)

---

## 6. Matrice de vérité

| Composant | État | Verdict |
|-----------|------|---------|
| FFmpeg assembler v9 (local) | Main@4.0, 720×1280 | ✅ Correct |
| FFmpeg assembler Kamatera | v7 dans les logs (à vérifier/redéployer) | ⚠️ Obsolète |
| Supabase bucket whiteboard-renders | Public, MP4 accessible | ✅ OK |
| RPCs whiteboard_* | Fonctionnelles | ✅ OK |
| SmartWhiteboardPreviewScreen | `video_player` sans filtre codec | ❌ **COUPABLE** |
| AcademiaAndroidVideoView | safeCodecSelector actif | ✅ Protégé |
| Feed Challenge | Utilise AcademiaPlaybackView | ✅ Pas affecté |

---

## 7. Preuves et artefacts

- Screenshot erreur utilisateur (image jointe)
- `lib/features/challenge/smart_whiteboard/screens/smart_whiteboard_preview_screen.dart` lignes 63-81
- `android/app/src/main/kotlin/.../AcademiaAndroidVideoView.kt` lignes 66-81
- `lib/video/academia_playback_view.dart` lignes 89-93 (branching natif Android)
- Flutter Issue #155077: https://github.com/flutter/flutter/issues/155077
- Flutter Issue #160899: https://github.com/flutter/flutter/issues/160899
- Flutter PR #11338: https://github.com/flutter/packages/pull/11338
