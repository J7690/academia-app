# D.18 – PHASE 5: AUDIT DE NON-RÉGRESSION UPLOAD MÉDIA

**Date**: 2026-06-26
**Mission**: D.18

---

## 1. PIPELINE D'UPLOAD MÉDIA IDENTIFIÉ

### 1.1 Flutter

**Écran d'entrée**:
- `video_publish_screen.dart` (TikTok-style publication)
- `student_challenge_video_editor_screen.dart` (édition challenge)
- `student_challenge_video_ar_combined_screen.dart` (AR)

**Service principal**:
- `videoasset_upload_service.dart`

**Service TUS**:
- `tus_upload_service.dart`

### 1.2 RPCs Supabase

- `app_videoasset_create_upload_intent`
- `app_videoasset_register_uploaded_source`

### 1.3 Edge Function

- `transcode-video`

### 1.4 Tables

- `app.video_assets`
- `app.video_sources`
- `app.video_renditions`

### 1.5 Bucket

Le bucket est déterminé dynamiquement par `app_videoasset_create_upload_intent` (retourne `storage_bucket` et `storage_path`).

---

## 2. FLUX DÉTAILLÉ

### 2.1 Étape 1: Création de l'intention d'upload

**Fichier**: `videoasset_upload_service.dart:48-60`

```dart
final dynamic intentResponse = await _client.rpc(
  'app_videoasset_create_upload_intent',
  params: {
    'p_origin': origin,
    'p_context_type': contextType,
    'p_context_id': contextId,
    'p_role': 'primary',
    'p_mime_type': normalizedMime,
    'p_expected_size': expectedSize,
  },
);
```

**Attendu**: `intentResponse['success'] == true` + `storage_bucket`, `storage_path`, `source_id`

### 2.2 Étape 2: Upload du fichier

**Fichier**: `videoasset_upload_service.dart:83-136`

Deux mécanismes:
- **Fichiers >= 6 MB**: TUS resumable upload via `tus_upload_service.dart`
- **Fichiers < 6 MB**: upload direct via `_client.storage.from(bucket).uploadBinary(path, bytes, ...)`

**Endpoint TUS**:
```dart
@academia_app/lib/services/tus_upload_service.dart:33
static String get _endpoint => '${SupabaseConfig.url}/storage/v1/upload/resumable';
```

### 2.3 Étape 3: Enregistrement de la source

**Fichier**: `videoasset_upload_service.dart:141-152`

```dart
final dynamic registerResponse = await _client.rpc(
  'app_videoasset_register_uploaded_source',
  params: {
    'p_source_id': sourceId,
    'p_checksum_sha256': null,
    'p_width': null,
    'p_height': null,
    'p_duration_ms': null,
    'p_has_audio': null,
    'p_validation_report': null,
  },
);
```

### 2.4 Étape 4: Déclenchement du transcodage

**Fichier**: `videoasset_upload_service.dart:175-187`

```dart
final response = await _client.functions.invoke(
  'transcode-video',
  body: {
    'video_asset_id': videoAssetId,
    if (posterUrl != null) 'poster_url': posterUrl,
  },
);
```

### 2.5 Étape 5: Retour du playback

**Fichier**: `transcode-video/index.ts`

L'Edge Function retourne `data['playback']` que le service Flutter attend:
```dart
return data['playback'] as Map<String, dynamic>?;
```

---

## 3. ANALYSE DES RÉGRESSIONS POTENTIELLES

### 3.1 Mismatch dans `transcode-video`

**Fichier**: `transcode-video/index.ts:78-85`

```typescript
const { data: source, error: srcErr } = await appDb
  .from('video_sources')
  .select('id, storage_bucket, storage_path, mime_type, file_size_bytes')
  .eq('video_asset_id', videoAssetId)
  .order('created_at', { ascending: false })
  .limit(1)
  .single();
```

Le commentaire dit: "schema does not have a 'role' column". Cela indique une adaptation au schema actuel.

### 3.2 Mismatch dans `transcode-multi-resolution`

**Fichier**: `transcode-multi-resolution/index.ts:99-145`

Cette Edge Function insère des jobs dans `app.video_processing_jobs` pour un worker externe. Il n'y a pas de preuve que ce worker soit déployé.

### 3.3 Appel compress-video

**Fichier**: `compress-video/index.ts:23-24`

```typescript
const KAMATERA_IP = '185.167.97.144';
const KAMATERA_FFMPEG_URL = `http://${KAMATERA_IP}:8001/compress`;
```

Cette Edge Function appelle Kamatera. Si le serveur est down, l'upload média échouera.

---

## 4. STATUT GLOBAL

| Composant | Statut | Remarque |
|-----------|--------|----------|
| `VideoAssetUploadService` | ✅ MATCH | Code cohérent |
| `TusUploadService` | ✅ MATCH | Endpoint TUS correct |
| `app_videoasset_create_upload_intent` | ⚠️ NON VÉRIFIÉ | RPC non lue dans les fichiers SQL |
| `app_videoasset_register_uploaded_source` | ⚠️ NON VÉRIFIÉ | RPC non lue dans les fichiers SQL |
| `transcode-video` | ⚠️ PARTIEL | Récupère `video_sources` sans `role` |
| `compress-video` | ⚠️ RÉGRESSION POTENTIELLE | Dépend de Kamatera `185.167.97.144:8001` |
| `transcode-multi-resolution` | ⚠️ RÉGRESSION POTENTIELLE | Dépend d'un worker externe non prouvé |

---

## 5. CONCLUSION

L'upload média de base (intention → upload → register) semble cohérent.

Les risques de régression sont:
1. **Dépendance à Kamatera** pour `compress-video`.
2. **Dépendance à un worker externe** pour `transcode-multi-resolution`.

Aucun MISMATCH démontré dans le code Flutter de l'upload média.
