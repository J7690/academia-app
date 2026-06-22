# Instrumentation P6 - Logs Ajoutés

**Date :** 19 Juin 2026  
**Objectif :** Validation runtime des logs et du pipeline vidéo avec preuves irréfutables

---

## 1. Logs ENTER/EXIT ajoutés pour méthodes critiques

### A. _processSegments()
**Fichier :** `student_challenge_video_editor_screen.dart`  
**Lignes :** 242-289

```dart
Future<void> _processSegments(List<XFile> segments) async {
  final enterTime = DateTime.now();
  debugPrint('[P6_ENTER] _processSegments');
  // ... code ...
  final exitTime = DateTime.now();
  final duration = exitTime.difference(enterTime).inMilliseconds;
  debugPrint('[P6_EXIT] _processSegments duration=${duration}ms');
}
```

---

### B. _pickVideo()
**Fichier :** `student_challenge_video_editor_screen.dart`  
**Lignes :** 447-511

```dart
Future<void> _pickVideo() async {
  final enterTime = DateTime.now();
  debugPrint('[P6_ENTER] _pickVideo');
  debugPrint('[P6_PATH] Gallery selected');
  // ... code ...
  final exitTime = DateTime.now();
  final duration = exitTime.difference(enterTime).inMilliseconds;
  debugPrint('[P6_EXIT] _pickVideo duration=${duration}ms');
}
```

---

### C. _initRemoteVideo()
**Fichier :** `student_challenge_video_editor_screen.dart`  
**Lignes :** 1106-1121

```dart
Future<void> _initRemoteVideo(String url) async {
  final enterTime = DateTime.now();
  debugPrint('[P6_ENTER] _initRemoteVideo');
  // ... code ...
  final exitTime = DateTime.now();
  final duration = exitTime.difference(enterTime).inMilliseconds;
  debugPrint('[P6_EXIT] _initRemoteVideo duration=${duration}ms');
}
```

---

### D. _compressAndSetVideo()
**Fichier :** `student_challenge_video_editor_screen.dart`  
**Lignes :** 515-665

```dart
Future<void> _compressAndSetVideo(String sourcePath, String originalName, DateTime t0) async {
  final enterTime = DateTime.now();
  debugPrint('[P6_ENTER] _compressAndSetVideo');
  // ... code ...
  final exitTime = DateTime.now();
  final duration = exitTime.difference(enterTime).inMilliseconds;
  debugPrint('[P6_EXIT] _compressAndSetVideo duration=${duration}ms');
}
```

---

### E. _compressAndWatermarkInBackground()
**Fichier :** `student_challenge_video_editor_screen.dart`  
**Lignes :** 686-799

```dart
Future<void> _compressAndWatermarkInBackground(String sourcePath, String originalName, DateTime t0) async {
  final enterTime = DateTime.now();
  debugPrint('[P6_ENTER] _compressAndWatermarkInBackground');
  // ... code ...
  final exitTime = DateTime.now();
  final duration = exitTime.difference(enterTime).inMilliseconds;
  debugPrint('[P6_EXIT] _compressAndWatermarkInBackground duration=${duration}ms');
}
```

---

### F. _uploadVideo()
**Fichier :** `student_challenge_video_editor_screen.dart`  
**Lignes :** 801-1081

```dart
Future<void> _uploadVideo() async {
  final enterTime = DateTime.now();
  debugPrint('[P6_ENTER] _uploadVideo');
  // ... code ...
  final exitTime = DateTime.now();
  final duration = exitTime.difference(enterTime).inMilliseconds;
  debugPrint('[P6_EXIT] _uploadVideo duration=${duration}ms');
}
```

---

### G. AcademiaPlaybackView._init()
**Fichier :** `academia_playback_view.dart`  
**Lignes :** 135-239

```dart
Future<void> _init() async {
  final enterTime = DateTime.now();
  debugPrint('[P6_ENTER] AcademiaPlaybackView._init');
  // ... code ...
  final exitTime = DateTime.now();
  final duration = exitTime.difference(enterTime).inMilliseconds;
  debugPrint('[P6_EXIT] AcademiaPlaybackView._init duration=${duration}ms');
}
```

---

## 2. Instrumentation des durées critiques

### A. Compression
**Fichier :** `student_challenge_video_editor_screen.dart`  
**Lignes :** 575-585, 713-724

```dart
final compressStart = DateTime.now();
debugPrint('[P6_COMPRESSION] START');
final MediaInfo? info = await VideoCompress.compressVideo(...);
final compressEnd = DateTime.now();
final compressDuration = compressEnd.difference(compressStart).inMilliseconds;
debugPrint('[P6_COMPRESSION] END duration=${compressDuration}ms');
```

---

### B. Watermark
**Fichier :** `student_challenge_video_editor_screen.dart`  
**Lignes :** 597-602, 734-739

```dart
final watermarkStart = DateTime.now();
debugPrint('[P6_WATERMARK] START');
final watermarkedPath = await WatermarkService.addWatermark(info.path!);
final watermarkEnd = DateTime.now();
final watermarkDuration = watermarkEnd.difference(watermarkStart).inMilliseconds;
debugPrint('[P6_WATERMARK] END duration=${watermarkDuration}ms');
```

---

### C. Initialisation Player
**Fichier :** `academia_playback_view.dart`  
**Lignes :** 181-185 (déjà existant dans P5)

```dart
debugPrint('[RUNTIME PLAYER] Calling initialize() - START');
final stopwatch = Stopwatch()..start();
await controller.initialize();
stopwatch.stop();
debugPrint('[RUNTIME PLAYER] Calling initialize() - END - duration=${stopwatch.elapsedMilliseconds}ms');
```

---

### D. Upload
**Fichier :** `student_challenge_video_editor_screen.dart`  
**Lignes :** 835-885 (déjà existant dans P5)

```dart
final t7 = DateTime.now();
debugPrint('[TIMING] T7 - Début upload: ${t7.toIso8601String()}');
// ... upload ...
final t8 = DateTime.now();
debugPrint('[TIMING] T8 - Fin upload: ${t8.toIso8601String()} (ΔT8-T7: ${t8.difference(t7).inMilliseconds}ms)');
```

---

## 3. Logs de parcours galerie

### A. Gallery selected
**Fichier :** `student_challenge_video_editor_screen.dart`  
**Ligne :** 452

```dart
debugPrint('[P6_PATH] Gallery selected');
```

---

### B. Editor opened
**Fichier :** `student_challenge_video_editor_screen.dart`  
**Ligne :** 181

```dart
debugPrint('[P6_PATH] Editor opened');
```

---

### C. Preview widget created
**Fichier :** `student_challenge_video_editor_screen.dart`  
**Ligne :** 503

```dart
debugPrint('[P6_PATH] Preview widget created');
```

---

### D. Preview first frame visible
**Fichier :** `academia_playback_view.dart`  
**Ligne :** 197

```dart
debugPrint('[P6_PATH] Preview first frame visible');
```

---

## 4. Résumé des tags P6

| Tag | Description | Fichier |
|-----|-------------|---------|
| `[P6_ENTER]` | Entrée de méthode critique | student_challenge_video_editor_screen.dart, academia_playback_view.dart |
| `[P6_EXIT]` | Sortie de méthode critique avec durée | student_challenge_video_editor_screen.dart, academia_playback_view.dart |
| `[P6_COMPRESSION]` | START/END de compression | student_challenge_video_editor_screen.dart |
| `[P6_WATERMARK]` | START/END de watermark | student_challenge_video_editor_screen.dart |
| `[P6_PATH]` | Points clés du parcours | student_challenge_video_editor_screen.dart, academia_playback_view.dart |

---

## 5. État de compilation

**APK compilé :** ✅ `build/app/outputs/flutter-apk/app-debug.apk`  
**Installation :** ⏳ En attente (appareil non connecté)

---

## 6. Prochaines étapes

1. Connecter l'appareil TECNO LD7
2. Installer l'APK instrumenté
3. Lancer la capture des logs
4. Effectuer le parcours : Feed → + → Galerie → Sélection vidéo → Editor → Upload
5. Analyser les logs collectés
6. Créer le rapport `VIDEO_RUNTIME_PROOF_P6.md`
