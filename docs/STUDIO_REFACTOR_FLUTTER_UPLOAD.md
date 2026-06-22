# STUDIO_REFACTOR_FLUTTER_UPLOAD

**Date :** 19 Juin 2026  
**Objectif :** Supprimer la compression locale et conserver uniquement l'upload brut

---

## IDENTIFICATION DES APPELS VIDEOCOMPRESS

### Fichiers concernés

| Fichier | Lignes | Fonction | Impact |
|---------|--------|----------|--------|
| student_challenge_video_editor_screen.dart | 581-586 | Compression HD/Medium avant watermark | Bloquant (await) |
| student_challenge_video_editor_screen.dart | 717-722 | Compression HD/Medium en background | Bloquant (await) |
| gameplay_recorder_service.dart | 199-204 | Compression gameplay recording | Bloquant (await) |

### Analyse détaillée

#### student_challenge_video_editor_screen.dart (ligne 581)

```dart
final MediaInfo? info = await VideoCompress.compressVideo(
  sourcePath,
  quality: quality,
  deleteOrigin: false,
  includeAudio: true,
);
```

**Impact :**
- Compression software sur Android
- Durée estimée : 5-20 secondes selon la durée/résolution
- Bloquant : utilisateur attend la fin de la compression
- Watermark appliqué sur la vidéo compressée

#### student_challenge_video_editor_screen.dart (ligne 717)

```dart
final MediaInfo? info = await VideoCompress.compressVideo(
  sourcePath,
  quality: quality,
  deleteOrigin: false,
  includeAudio: true,
);
```

**Impact :**
- Même fonction mais en background
- Toujours bloquant (await)
- Watermark appliqué sur la vidéo compressée

#### gameplay_recorder_service.dart (ligne 199)

```dart
final info = await VideoCompress.compressVideo(
  sourcePath,
  quality: VideoQuality.MediumQuality,
  deleteOrigin: false,
  includeAudio: false,
);
```

**Impact :**
- Compression gameplay recording
- Pas d'audio (includeAudio: false)
- Bloquant : utilisateur attend la fin de la compression

---

## MESURE DE L'IMPACT

### Durée actuelle de compression

Basé sur les logs P2 :
- Vidéo 15s : ~5 secondes
- Vidéo 30s : ~10 secondes
- Vidéo 60s : ~15 secondes
- Vidéo 90s : ~20 secondes

### Réduction de taille

Basé sur les logs gameplay_recorder_service :
- Réduction moyenne : 30-50%
- Mais inutile car le Worker Kamatera va retranscoder

### Conséquences négatives

1. **Bloquant :** L'utilisateur attend la compression avant de pouvoir continuer
2. **Redondant :** Le Worker Kamatera va retranscoder la vidéo de toute façon
3. **Qualité dégradée :** Compression software sur Android est moins performante que FFmpeg sur Kamatera
4. **Batterie :** Compression locale consomme de la batterie

---

## ACTIONS REQUISES

### 1. Supprimer la compression dans student_challenge_video_editor_screen.dart

**Avant (ligne 581-586) :**
```dart
final compressStart = DateTime.now();
debugPrint('[P6_COMPRESSION] START');
final MediaInfo? info = await VideoCompress.compressVideo(
  sourcePath,
  quality: quality,
  deleteOrigin: false,
  includeAudio: true,
);
final compressEnd = DateTime.now();
final compressDuration = compressEnd.difference(compressStart).inMilliseconds;
debugPrint('[P6_COMPRESSION] END duration=${compressDuration}ms');
```

**Après :**
```dart
// Skip compression - upload raw video
final compressStart = DateTime.now();
debugPrint('[P6_COMPRESSION] SKIPPED - uploading raw video');
final MediaInfo? info = MediaInfo(path: sourcePath);
final compressEnd = DateTime.now();
final compressDuration = 0;
debugPrint('[P6_COMPRESSION] END duration=0ms');
```

**Avant (ligne 717-722) :**
```dart
final compressStart = DateTime.now();
debugPrint('[P6_COMPRESSION] START');
final MediaInfo? info = await VideoCompress.compressVideo(
  sourcePath,
  quality: quality,
  deleteOrigin: false,
  includeAudio: true,
);
final compressEnd = DateTime.now();
final compressDuration = compressEnd.difference(compressStart).inMilliseconds;
debugPrint('[P6_COMPRESSION] END duration=${compressDuration}ms');
```

**Après :**
```dart
// Skip compression - upload raw video
final compressStart = DateTime.now();
debugPrint('[P6_COMPRESSION] SKIPPED - uploading raw video');
final MediaInfo? info = MediaInfo(path: sourcePath);
final compressEnd = DateTime.now();
final compressDuration = 0;
debugPrint('[P6_COMPRESSION] END duration=0ms');
```

### 2. Supprimer la compression dans gameplay_recorder_service.dart

**Avant (ligne 199-204) :**
```dart
final info = await VideoCompress.compressVideo(
  sourcePath,
  quality: VideoQuality.MediumQuality,
  deleteOrigin: false,
  includeAudio: false,
);
```

**Après :**
```dart
// Skip compression - upload raw video
debugPrint('[GameplayRecorder] Compression SKIPPED - uploading raw video');
final info = MediaInfo(path: sourcePath);
```

### 3. Conserver uniquement

- Validation (taille, format)
- Thumbnail (génération rapide)
- Upload brut

### 4. Adapter le watermark

Le watermark doit être appliqué par le Worker Kamatera et non localement.

**Action :** Supprimer l'appel WatermarkService.addWatermark() dans student_challenge_video_editor_screen.dart.

---

## TESTS REQUIS

### Scénarios de test

| Durée vidéo | Résolution | Test attendu |
|-------------|------------|--------------|
| 15s | 720p | Upload brut < 5s |
| 30s | 720p | Upload brut < 10s |
| 60s | 1080p | Upload brut < 20s |
| 90s | 1080p | Upload brut < 30s |

### Validation

1. **Upload brut :** La vidéo est uploadée sans compression
2. **Watermark :** Le watermark est appliqué par le Worker Kamatera
3. **Renditions :** Les renditions sont générées par le Worker Kamatera
4. **Feed :** La vidéo est lisible dans le feed
5. **Performance :** L'upload est plus rapide (pas de compression locale)

---

## LIVRABLES

- [ ] Suppression compression student_challenge_video_editor_screen.dart (ligne 581)
- [ ] Suppression compression student_challenge_video_editor_screen.dart (ligne 717)
- [ ] Suppression compression gameplay_recorder_service.dart (ligne 199)
- [ ] Suppression WatermarkService.addWatermark()
- [ ] Tests 15s
- [ ] Tests 30s
- [ ] Tests 60s
- [ ] Tests 90s

---

**Statut :** 🚧 En cours
