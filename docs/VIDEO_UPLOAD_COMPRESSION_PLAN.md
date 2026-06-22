# Plan Upload & Compression Vidéo - Niveau Grande Plateforme
## Basé sur YouTube/TikTok/Instagram Best Practices

**Date**: 20 Juin 2026
**Objectif**: Système d'upload et compression de très haut niveau, comparable aux grandes plateformes

---

## Architecture Globale

### Pipeline Séparé et Clair

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Upload         │ →  │  Édition        │ →  │  Compression    │ →  │  Publication    │
│  (téléphone)    │    │  (téléphone)    │    │  (serveur)      │    │  (feed/studio)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
```

**Règle critique**: Chaque mécanisme intervient à un moment bien spécifique, aucun mélange.

---

## Phase 1: Upload - Niveau YouTube/TikTok

### 1.1 Resumable Upload Protocol (Style YouTube)

**Caractéristiques**:
- Protocol HTTP standard avec Content-Range headers
- Upload séquentiel (pas parallèle - comme TikTok/YouTube)
- Session persistence pour reprise après interruption
- Retry avec exponential backoff
- Upload URL expiration management

**Chunk Size Strategy**:
- Chunk size: 8MB (multiple de 256KB comme YouTube)
- Videos < 5MB: upload complet en une seule requête
- Videos > 64MB: chunked upload obligatoire
- Max 1000 chunks (limite TikTok)

**Implementation**:

```dart
class ResumableUploadService {
  // Chunk size: 8MB (YouTube standard)
  static const int _chunkSize = 8 * 1024 * 1024;
  static const int _maxRetries = 5;
  static const Duration _uploadUrlExpiry = Duration(hours: 1);
  
  // Initialize resumable upload session
  static Future<UploadSession> initializeUpload({
    required String bucket,
    required String path,
    required int fileSize,
    required String contentType,
  }) async {
    // Call Edge Function to create upload session
    final response = await _client.functions.invoke('create-upload-session', body: {
      'bucket': bucket,
      'path': path,
      'file_size': fileSize,
      'content_type': contentType,
    });
    
    return UploadSession.fromJson(response.data);
  }
  
  // Upload chunk with Content-Range header
  static Future<void> uploadChunk({
    required UploadSession session,
    required File file,
    required int chunkIndex,
    required int totalChunks,
  }) async {
    final start = chunkIndex * _chunkSize;
    final end = min(start + _chunkSize, session.fileSize);
    final chunkSize = end - start;
    
    // Read chunk from file
    final raf = await file.open();
    await raf.setPosition(start);
    final chunk = await raf.read(chunkSize);
    await raf.close();
    
    // Upload with Content-Range header
    final headers = {
      'Content-Range': 'bytes $start-${end - 1}/${session.fileSize}',
      'Content-Length': chunkSize.toString(),
    };
    
    // Retry with exponential backoff
    for (int retry = 0; retry < _maxRetries; retry++) {
      try {
        await _client.storage.from(session.bucket).uploadBinary(
          session.chunkPath(chunkIndex),
          Uint8List.fromList(chunk),
          fileOptions: FileOptions(
            contentType: session.contentType,
            upsert: true,
          ),
        );
        return; // Success
      } catch (e) {
        if (retry == _maxRetries - 1) rethrow;
        await Future.delayed(Duration(seconds: (retry + 1) * 2));
      }
    }
  }
  
  // Check upload status for resume
  static Future<int> getUploadedBytes(UploadSession session) async {
    // Check which bytes were received by server
    // Return the next byte offset to resume from
  }
}
```

### 1.2 Edge Function: create-upload-session

**Responsabilités**:
- Créer une session d'upload avec ID unique
- Générer upload URL (si using presigned URLs)
- Persister la session en base de données
- Gérer l'expiration (1 heure)

```typescript
// supabase/functions/create-upload-session/index.ts

export async function handler(req: Request) {
  const { bucket, path, file_size, content_type } = await req.json();
  
  // Generate unique session ID
  const sessionId = crypto.randomUUID();
  
  // Persist session in database
  const { error } = await supabase.from('upload_sessions').insert({
    id: sessionId,
    bucket,
    path,
    file_size,
    content_type,
    uploaded_bytes: 0,
    status: 'initialized',
    expires_at: new Date(Date.now() + 3600000).toISOString(), // 1 hour
  });
  
  return jsonResponse({
    session_id: sessionId,
    upload_url: null, // Will use Supabase Storage directly
    expires_at: expiresAt,
  });
}
```

### 1.3 Edge Function: complete-upload-session

**Responsabilités**:
- Vérifier que tous les chunks sont uploadés
- Assembler les chunks en fichier final
- Nettoyer les chunks temporaires
- Marquer la session comme completed

```typescript
// supabase/functions/complete-upload-session/index.ts

export async function handler(req: Request) {
  const { session_id } = await req.json();
  
  // Fetch session
  const { data: session } = await supabase.from('upload_sessions')
    .select('*')
    .eq('id', session_id)
    .single();
  
  // Assemble chunks (reuse existing assemble-video-chunks logic)
  const assembledPath = await assembleChunks(session.bucket, session.path);
  
  // Update session status
  await supabase.from('upload_sessions')
    .update({ status: 'completed', final_path: assembledPath })
    .eq('id', session_id);
  
  return jsonResponse({
    success: true,
    final_path: assembledPath,
  });
}
```

---

## Phase 2: Édition - Niveau TikTok/Instagram

### 2.1 Pipeline Édition

**Flux**:
1. Upload terminé → fichier disponible en storage
2. Utilisateur peut éditer (trim, speed, rotate, crop)
3. Édition est NON DESTRUCTIVE (crée un nouveau fichier)
4. Export utilise FFmpeg local (pas de compression, juste édition)
5. Fichier édité est sauvegardé comme nouvelle version

**Implementation**:

```dart
class VideoEditService {
  // Non-destructive edit using FFmpeg
  static Future<String> editVideo({
    required String sourcePath,
    required VideoEditOptions options,
  }) async {
    // Use FFmpegKit for editing only (no compression)
    final command = buildFFmpegEditCommand(sourcePath, options);
    
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    
    if (returnCode?.isValueSuccess() == true) {
      return outputPath;
    }
    throw Exception('Edit failed');
  }
  
  static String buildFFmpegEditCommand(String input, VideoEditOptions options) {
    var command = '-i $input';
    
    // Trim
    if (options.trimStart != null || options.trimEnd != null) {
      command += ' -ss ${options.trimStart ?? 0}';
      if (options.trimEnd != null) {
        command += ' -to ${options.trimEnd}';
      }
    }
    
    // Speed
    if (options.speed != 1.0) {
      command += ' -filter:v "setpts=${1.0/options.speed}*PTS"';
      command += ' -filter:a "atempo=${options.speed}"';
    }
    
    // Rotate
    if (options.rotation != 0) {
      command += ' -vf "transpose=${options.rotation}"';
    }
    
    // Crop
    if (options.crop != null) {
      command += ' -vf "crop=${options.crop.width}:${options.crop.height}:${options.crop.x}:${options.crop.y}"';
    }
    
    command += ' -c copy -map 0 $outputPath'; // Copy streams, no re-encoding
    return command;
  }
}
```

---

## Phase 3: Compression - Niveau YouTube/Netflix

### 3.1 FFmpeg Server-Side Compression

**Standards Universels**:
- **Codec**: H.264 (libx264) - accepté par toutes les plateformes
- **Audio**: AAC - accepté par toutes les plateformes
- **Container**: MP4 - accepté par toutes les plateformes
- **Adaptive Bitrate**: HLS/DASH pour multi-renditions

**FFmpeg Commandes**:

```bash
# Single rendition (baseline)
ffmpeg -i input.mp4 \
  -c:v libx264 \
  -profile:v main \
  -preset veryslow \
  -crf 23 \
  -maxrate 1500k \
  -bufsize 3000k \
  -c:a aac \
  -b:a 128k \
  -ar 48000 \
  -movflags +faststart \
  output.mp4

# Multi-rendition HLS (adaptive bitrate)
ffmpeg -i input.mp4 \
  -filter_complex "[v]split=3[v1][v2][v3]" \
  -map "[v1]" -c:v libx264 -preset veryslow -crf 26 -maxrate 800k -bufsize 1600k -g 48 -keyint_min 48 -sc_threshold 0 \
  -map "[v2]" -c:v libx264 -preset veryslow -crf 23 -maxrate 1500k -bufsize 3000k -g 48 -keyint_min 48 -sc_threshold 0 \
  -map "[v3]" -c:v libx264 -preset veryslow -crf 20 -maxrate 3000k -bufsize 6000k -g 48 -keyint_min 48 -sc_threshold 0 \
  -map a:0 -c:a aac -b:a 128k -ar 48000 \
  -f hls -hls_time 6 -hls_playlist_type vod \
  -hls_segment_filename segment_%v_%03d.ts \
  master.m3u8
```

### 3.2 Edge Function: compress-video

**Responsabilités**:
- Recevoir le fichier source
- Exécuter FFmpeg avec les paramètres optimaux
- Générer multi-renditions (optionnel)
- Retourner les URLs des fichiers compressés

```typescript
// supabase/functions/compress-video/index.ts

export async function handler(req: Request) {
  const { source_path, bucket, options } = await req.json();
  
  // Download source from Storage
  const { data: sourceFile } = await supabase.storage.from(bucket).download(source_path);
  
  // Execute FFmpeg compression
  const output = await executeFFmpegCompression(sourceFile, options);
  
  // Upload compressed file
  const compressedPath = source_path.replace('.mp4', '_compressed.mp4');
  await supabase.storage.from(bucket).upload(compressedPath, output);
  
  // Generate public URL
  const { data: urlData } = supabase.storage.from(bucket).getPublicUrl(compressedPath);
  
  return jsonResponse({
    success: true,
    compressed_path: compressedPath,
    public_url: urlData.publicUrl,
  });
}

async function executeFFmpegCompression(input: Uint8Array, options: CompressionOptions) {
  // Use FFmpeg via Deno.exec or external service
  // For now, delegate to Kamatera Cloud with FFmpeg installed
}
```

### 3.3 Compression Profiles

**Profile Mobile (Low Bandwidth)**:
- Resolution: 480p (854x480)
- Bitrate: 800kbps
- Audio: 96kbps AAC
- CRF: 26

**Profile Standard (WiFi)**:
- Resolution: 720p (1280x720)
- Bitrate: 1500kbps
- Audio: 128kbps AAC
- CRF: 23

**Profile HD (High Bandwidth)**:
- Resolution: 1080p (1920x1080)
- Bitrate: 3000kbps
- Audio: 128kbps AAC
- CRF: 20

---

## Phase 4: Publication - Niveau Instagram/TikTok

### 4.1 Pipeline Publication

**Flux**:
1. Compression terminée → fichier optimisé disponible
2. Création VideoAsset dans base de données
3. Génération de thumbnail (première frame)
4. Publication dans feed/studio
5. Notification aux followers

**Implementation**:

```dart
class VideoPublishService {
  static Future<void> publishVideo({
    required String compressedPath,
    required String context, // 'feed' or 'studio'
    required String? caption,
    required List<String> tags,
  }) async {
    // Create VideoAsset record
    final videoAsset = await _client.rpc('app_videoasset_create_upload_intent', params: {
      'p_origin': context,
      'p_context_type': context,
      'p_mime_type': 'video/mp4',
      'p_expected_size': await File(compressedPath).length(),
    });
    
    // Register uploaded source
    await _client.rpc('app_videoasset_register_uploaded_source', params: {
      'p_video_asset_id': videoAsset['source_id'],
      'p_storage_bucket': 'academia-videos',
      'p_storage_path': compressedPath,
      'p_mime_type': 'video/mp4',
      'p_file_size_bytes': await File(compressedPath).length(),
    });
    
    // Trigger compression (if not already done)
    await _client.functions.invoke('compress-video', body: {
      'source_path': compressedPath,
      'bucket': 'academia-videos',
      'options': {'profile': 'standard'},
    });
    
    // Mark as ready
    await _client.functions.invoke('transcode-video', body: {
      'video_asset_id': videoAsset['source_id'],
    });
  }
}
```

---

## Tables Supabase Requises

### upload_sessions

```sql
CREATE TABLE app.upload_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bucket TEXT NOT NULL,
  path TEXT NOT NULL,
  file_size BIGINT NOT NULL,
  content_type TEXT NOT NULL,
  uploaded_bytes BIGINT DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'initialized', -- initialized, uploading, completed, failed
  final_path TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  user_id UUID REFERENCES auth.users(id)
);

CREATE INDEX idx_upload_sessions_user ON app.upload_sessions(user_id);
CREATE INDEX idx_upload_sessions_status ON app.upload_sessions(status);
```

### video_renditions (mise à jour)

```sql
ALTER TABLE app.video_renditions ADD COLUMN compression_profile TEXT;
ALTER TABLE app.video_renditions ADD COLUMN is_original BOOLEAN DEFAULT true;
ALTER TABLE app.video_renditions ADD COLUMN parent_rendition_id UUID REFERENCES app.video_renditions(id);
```

---

## Migration depuis l'ancien système

### Étapes de migration

1. **Créer les nouvelles tables** (upload_sessions)
2. **Implémenter ResumableUploadService** (remplace ChunkedUploadService)
3. **Créer Edge Functions** (create-upload-session, complete-upload-session)
4. **Mettre à jour VideoEditService** (non-destructive edits)
5. **Créer Edge Function compress-video** (FFmpeg server-side)
6. **Mettre à jour VideoPublishService** (pipeline clair)
7. **Tester le pipeline complet**
8. **Supprimer l'ancien ChunkedUploadService** (après validation)

---

## Performance Cibles

### Upload
- **Délai initial**: < 500ms (session creation)
- **Upload speed**: Utiliser 80% de la bande passante disponible
- **Reprise**: < 1s après interruption
- **Progress**: Mise à jour toutes les 1s ou 10%

### Compression
- **Temps compression**: ~30% du temps de lecture (preset veryslow)
- **Qualité**: CRF 23 (visuellement lossless)
- **Taille**: Réduction de 60-80% par rapport à l'original
- **Format**: H.264/AAC MP4 (universel)

### Publication
- **Délai publication**: < 2s après compression
- **Thumbnail**: < 500ms
- **Notification**: < 1s

---

## Monitoring & Logging

### Logs à implémenter

```dart
// Upload logs
debugPrint('[Upload] Session created: $sessionId');
debugPrint('[Upload] Chunk $chunkIndex/$totalChunks uploaded (${chunkSize} bytes)');
debugPrint('[Upload] Upload speed: ${speed} MB/s');
debugPrint('[Upload] Progress: ${(uploadedBytes / totalBytes * 100).toStringAsFixed(1)}%');

// Compression logs
debugPrint('[Compression] Started: $sourcePath');
debugPrint('[Compression] Profile: $profile');
debugPrint('[Compression] Duration: ${duration}ms');
debugPrint('[Compression] Size reduction: ${reduction}%');

// Publication logs
debugPrint('[Publish] VideoAsset created: $videoAssetId');
debugPrint('[Publish] Published to: $context');
```

---

## Sécurité

### Upload URL Expiration
- Sessions expirent après 1 heure
- Nettoyage automatique des sessions expirées (cron job)

### Rate Limiting
- Max 10 uploads simultanés par utilisateur
- Max 100MB par upload (configurable)

### Validation
- Vérification du type MIME côté serveur
- Validation de la taille maximale
- Scan antivirus (optionnel)

---

## Conclusion

Ce plan aligne le système Academia avec les meilleures pratiques de YouTube, TikTok et Instagram:

1. **Upload**: Resumable Upload Protocol avec Content-Range
2. **Édition**: Non-destructive avec FFmpeg local
3. **Compression**: Server-side FFmpeg avec H.264/AAC
4. **Publication**: Pipeline clair et séparé

Chaque mécanisme intervient à un moment bien spécifique, sans mélange.
