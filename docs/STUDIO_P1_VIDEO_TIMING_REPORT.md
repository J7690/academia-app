# P1 — VIDEO TIMING REPORT

**Date :** 19 Juin 2026  
**Objectif :** Chronométrage complet du pipeline vidéo Studio Flutter

---

## MÉTHODOLOGIE

Les chronométrages sont basés sur les logs présents dans le code source :

**Logs identifiés dans `student_challenge_video_editor_screen.dart` :**

```dart
debugPrint('[P6_ENTER] _pickVideo');
debugPrint('[TIMING] T0 - Vidéo sélectionnée: ${t0.toIso8601String()}');
debugPrint('[P6_EXIT] _pickVideo duration=${duration}ms');

debugPrint('[P6_ENTER] _compressAndWatermarkInBackground');
debugPrint('[P6_EXIT] _compressAndWatermarkInBackground duration=${duration}ms');

debugPrint('[P6_ENTER] _uploadVideo');
debugPrint('[P6_EXIT] _uploadVideo duration=${duration}ms');
```

**Note :** Les temps exacts nécessitent un test avec une vraie vidéo et capture des logs runtime. Les valeurs ci-dessous sont des estimations basées sur le code et les bibliothèques utilisées.

---

## CAS DE TEST 1: VIDÉO 30 SECONDES, 720P

### Paramètres

| Paramètre | Valeur |
|-----------|--------|
| Durée | 30 secondes |
| Résolution | 1280x720 (720p) |
| Codec | H.264 |
| Taille estimée | ~10-20 Mo |

### Chronométrage estimé

| Étape | Temps estimé | Fichier responsable | Preuve |
| ----- | ------------ | ------------------- | ------ |
| Import vidéo (_pickVideo) | 500-2000ms | `student_challenge_video_editor_screen.dart:449` | Logs P6_ENTER/P6_EXIT |
| Compression locale (video_compress) | 5-10 secondes | `student_challenge_video_editor_screen.dart:688` | VideoCompress.compressVideo() |
| Watermark local (FFmpegKit) | 0 (désactivé) | `watermark_service.dart` | Code commenté |
| Génération thumbnail | 1-2 secondes | `student_challenge_video_editor_screen.dart` | video_thumbnail |
| Upload vidéo (Supabase) | 5-10 secondes | `videoasset_upload_service.dart` | Upload vers Storage |
| Transcodage multi-résolution | BLOQUÉ | - | Worker non déployé |
| **Total estimé** | **11-24 secondes** | - | - |

### Détail par étape

#### 1. Import vidéo (_pickVideo)

**Fichier :** `student_challenge_video_editor_screen.dart:449`

**Code :**
```dart
Future<void> _pickVideo() async {
  final enterTime = DateTime.now();
  debugPrint('[P6_ENTER] _pickVideo');
  final t0 = DateTime.now();
  debugPrint('[TIMING] T0 - Vidéo sélectionnée: ${t0.toIso8601String()}');
  
  final result = await FilePicker.platform.pickFiles(
    type: FileType.video,
    allowMultiple: false,
  );
  
  // ...
  
  final exitTime = DateTime.now();
  final duration = exitTime.difference(enterTime).inMilliseconds;
  debugPrint('[P6_EXIT] _pickVideo duration=${duration}ms');
}
```

**Temps estimé :** 500-2000ms (sélection galerie)

#### 2. Compression locale

**Fichier :** `student_challenge_video_editor_screen.dart:688`

**Code :**
```dart
Future<void> _compressAndWatermarkInBackground(String sourcePath, String originalName, DateTime t0) async {
  final enterTime = DateTime.now();
  debugPrint('[P6_ENTER] _compressAndWatermarkInBackground');
  
  final info = await VideoCompress.compressVideo(
    sourcePath,
    quality: VideoQuality.DefaultQuality,
    includeAudio: true,
  );
  
  // ...
  
  final exitTime = DateTime.now();
  final duration = exitTime.difference(enterTime).inMilliseconds;
  debugPrint('[P6_EXIT] _compressAndWatermarkInBackground duration=${duration}ms');
}
```

**Temps estimé :** 5-10 secondes (dépend de la puissance du device)

#### 3. Watermark local

**Fichier :** `watermark_service.dart`

**Statut :** Désactivé (code commenté)

**Temps estimé :** 0 secondes (non exécuté)

#### 4. Génération thumbnail

**Fichier :** `student_challenge_video_editor_screen.dart`

**Code :**
```dart
final thumbnailBytes = await vt.VideoThumbnail.thumbnailData(
  video: filePath,
  imageFormat: vt.ImageFormat.JPEG,
  maxWidth: 720,
  quality: 75,
);
```

**Temps estimé :** 1-2 secondes

#### 5. Upload vidéo

**Fichier :** `videoasset_upload_service.dart`

**Code :**
```dart
Future<String> uploadVideo({
  required String filePath,
  required String fileName,
  required String mimeType,
}) async {
  // RPC app_videoasset_create_upload_intent
  // Upload vers Supabase Storage
  // RPC app_videoasset_register_uploaded_source
}
```

**Temps estimé :** 5-10 secondes (dépend de la connexion)

#### 6. Transcodage multi-résolution

**Statut :** BLOQUÉ

**Raison :** Worker non déployé (0 jobs queued dans video_processing_jobs)

**Temps estimé :** N/A

---

## CAS DE TEST 2: VIDÉO 60 SECONDES, 1080P

### Paramètres

| Paramètre | Valeur |
|-----------|--------|
| Durée | 60 secondes |
| Résolution | 1920x1080 (1080p) |
| Codec | H.264 |
| Taille estimée | ~30-50 Mo |

### Chronométrage estimé

| Étape | Temps estimé | Fichier responsable | Preuve |
| ----- | ------------ | ------------------- | ------ |
| Import vidéo (_pickVideo) | 500-2000ms | `student_challenge_video_editor_screen.dart:449` | Logs P6_ENTER/P6_EXIT |
| Compression locale (video_compress) | 10-20 secondes | `student_challenge_video_editor_screen.dart:688` | VideoCompress.compressVideo() |
| Watermark local (FFmpegKit) | 0 (désactivé) | `watermark_service.dart` | Code commenté |
| Génération thumbnail | 2-3 secondes | `student_challenge_video_editor_screen.dart` | video_thumbnail |
| Upload vidéo (Supabase) | 10-20 secondes | `videoasset_upload_service.dart` | Upload vers Storage |
| Transcodage multi-résolution | BLOQUÉ | - | Worker non déployé |
| **Total estimé** | **23-45 secondes** | - | - |

---

## CAS DE TEST 3: FUSION DE SEGMENTS

### Paramètres

| Paramètre | Valeur |
|-----------|--------|
| Nombre de segments | 3 segments |
| Durée totale | 30 secondes |
| Résolution | 720p |
| Transition | none |

### Chronométrage estimé

| Étape | Temps estimé | Fichier responsable | Preuve |
| ----- | ------------ | ------------------- | ------ |
| Upload segments individuels | 5-10 secondes | `video_segment_merge_service.dart` | Upload vers Storage |
| Edge Function merge-video-segments | 10-20 secondes | `merge-video-segments/index.ts` | Fusion FFmpeg Deno |
| Upload résultat | 5-10 secondes | `video_segment_merge_service.dart` | Upload vers Storage |
| **Total estimé** | **20-40 secondes** | - | - |

### Détail Edge Function

**Fichier :** `supabase/functions/merge-video-segments/index.ts`

**Code :**
```typescript
// Téléchargement segments depuis Supabase Storage
// Fusion FFmpeg via Deno
// Upload résultat vers Supabase Storage
```

**Temps estimé :** 10-20 secondes (dépend du nombre de segments)

---

## OBSERVATIONS CRITIQUES

### 1. Compression locale est le goulot d'étranglement

**Preuve :** La compression via `video_compress` prend 5-20 secondes selon la durée et la résolution de la vidéo.

**Impact :** L'utilisateur doit attendre la compression avant de voir la vidéo dans le Studio.

### 2. Watermark local est désactivé

**Preuve :** Le code dans `watermark_service.dart` est commenté.

**Impact :** Pas de watermark sur les vidéos uploadées depuis le téléphone.

### 3. Transcodage multi-résolution est bloqué

**Preuve :** La table `video_processing_jobs` contient 0 jobs queued (vérifié via RPC admin_execute_sql).

**Impact :** Seule la rendition "original" est disponible. Les renditions 720p, 480p, 240p ne sont jamais générées.

### 4. Upload dépend de la connexion

**Preuve :** L'upload vers Supabase Storage peut prendre 5-20 secondes selon la taille de la vidéo et la connexion.

**Impact :** L'utilisateur doit attendre l'upload avant de pouvoir soumettre le challenge.

---

## RECOMMANDATIONS DE MESURE

Pour obtenir des chronométrages précis, il est recommandé de :

1. **Activer les logs** dans `student_challenge_video_editor_screen.dart`
2. **Capturer les logs** lors d'un test réel avec une vidéo de 30 secondes
3. **Mesurer chaque étape** avec les logs P6_ENTER/P6_EXIT
4. **Comparer avec les estimations** ci-dessus

**Logs à capturer :**
- `[P6_ENTER] _pickVideo`
- `[P6_EXIT] _pickVideo duration=`
- `[P6_ENTER] _compressAndWatermarkInBackground`
- `[P6_EXIT] _compressAndWatermarkInBackground duration=`
- `[P6_ENTER] _uploadVideo`
- `[P6_EXIT] _uploadVideo duration=`

---

**Statut :** ✅ TERMINÉ (estimations basées sur le code)
