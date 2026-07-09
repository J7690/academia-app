# D31_3_flutter_player_audit.md

**Date :** 2026-06-30

---

## 1. Fichier audité

- `lib/features/challenge/smart_whiteboard/screens/smart_whiteboard_preview_screen.dart`
- `lib/video/academia_playback_view.dart` (référence pour comparaison)

---

## 2. Lecteur utilisé par le Smart Whiteboard Preview

Le Smart Whiteboard Preview utilise directement le package `video_player` :

```dart
import 'package:video_player/video_player.dart';
...
final controller = VideoPlayerController.networkUrl(Uri.parse(url));
await controller.initialize();
```

**Aucun usage de `AcademiaPlaybackView`**, `AcademiaAndroidVideoView`, `Media3`, `ExoPlayer` natif, ou `safeCodecSelector`.

---

## 3. Lecteur utilisé par le Feed Challenges

Le feed Challenges (et d'autres flows vidéo) utilise `AcademiaPlaybackView` (`lib/video/academia_playback_view.dart`), qui :

- Sur **Android** : passe par un lecteur natif via un `MethodChannel`.
- Sur **iOS / Web** : utilise `video_player`.
- Dispose d'une couche de fallback en cas d'erreur native.

---

## 4. Comparaison Smart Whiteboard vs Feed Challenges

| Critère | Smart Whiteboard Preview | Feed Challenges |
|---|---|---|
| Package | `video_player` direct | `AcademiaPlaybackView` |
| Lecteur Android | `video_player` (ExoPlayer interne du plugin) | Lecteur natif custom via MethodChannel |
| Gestion des erreurs | Basique (`try/catch` + message) | Couche native + fallback |
| Gestion MediaTek | ❌ Aucune | ✅ Lecteur natif adapté |
| Looping | ✅ Oui | ✅ Oui |
| Mute / Volume | Non géré | Géré |
| UI de contrôle | Non | Oui |

---

## 5. Manque précis dans le Smart Whiteboard Preview

| # | Problème | Fichier concerné | Impact |
|---|---|---|---|
| 1 | **Utilise `video_player` directement** | `smart_whiteboard_preview_screen.dart` | Risque de crash sur MediaTek si ExoPlayer sélectionne un décodeur incompatible |
| 2 | **Pas de `safeCodecSelector`** | `smart_whiteboard_preview_screen.dart` | Impossible de forcer un décodeur sûr sur MediaTek |
| 3 | **Pas de fallback vers lecteur natif** | `smart_whiteboard_preview_screen.dart` | Si `video_player` échoue, la vidéo ne peut pas être lue |
| 4 | **Pas de gestion du niveau H.264** | `smart_whiteboard_preview_screen.dart` + worker | Le MP4 Level 3.1 peut être rejeté par MediaTek |
| 5 | **Pas de détection d'erreur ExoPlayer** | `smart_whiteboard_preview_screen.dart` | Seul `controller.initialize()` retourne une erreur générique |
| 6 | **Pas de bouton "réessayer avec lecteur natif"** | `smart_whiteboard_preview_screen.dart` | UX limitée |

---

## 6. Conclusion technique

**Le Smart Whiteboard Preview n'est PAS aussi robuste que le Feed Challenges.**

Le Feed a une couche native Android dédiée pour gérer les décodeurs problématiques (MediaTek, Samsung, etc.). Le Smart Whiteboard Preview repose sur `video_player` directement, qui délègue entièrement à ExoPlayer sans sélection explicite de codec.

**Responsabilité :** Flutter (Smart Whiteboard Preview) pour l'intégration du lecteur.

---

## 7. Recommandation

Pour rendre le Smart Whiteboard Preview aussi robuste que le Feed Challenges :

1. **Remplacer** `VideoPlayerController.networkUrl` par `AcademiaPlaybackView` dans `smart_whiteboard_preview_screen.dart`.
2. **Ou** ajouter une sélection de codec sûr (`safeCodecSelector`) dans le lecteur Smart Whiteboard.
3. **Corréler** avec la correction du Level H.264 côté FFmpeg (passer à Level 4.0+).
