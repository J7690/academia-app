# Audit ciblé — Pipeline vidéo Challenge (capture → upload → édition → compression → publication → feed)

Date: 2026-06-21 · Périmètre STRICT: onglet Challenge uniquement (Dart + Edge Functions + RPC + Kamatera liés).

## 1. Fichiers audités
- Flutter (UI/flux): `academia_app/lib/features/student/tabs/student_challenges_tab.dart` (feed + bouton "+"), `challenge_camera_capture_screen.dart`, `student_challenge_video_editor_screen.dart` (studio), `video_publish_screen.dart` (description/hashtags).
- Flutter (services): `services/videoasset_upload_service.dart`, `services/resumable_upload_service.dart`, `services/video_publish_service.dart`, `services/video_player_lifecycle_service.dart`, `providers/student_challenges_provider.dart`.
- Edge Functions: `create-upload-session`, `complete-upload-session`, `assemble-video-chunks`, `compress-video`, `transcode-video`, `transcode-multi-resolution`.
- Kamatera (185.167.97.144): `academia-compress.service` (:8001), `video-worker.service` (`/opt/video-worker/videoasset_worker.py`).
- DB (schema app): `video_assets`, `video_sources`, `video_renditions`, `video_processing_jobs`, `upload_sessions`.

## 2. Flux réel implémenté
"+" → `_pauseAllControllers()` → `ChallengeCameraCaptureScreen` (segments) → Studio editor → clic "Suivant" (`_uploadVideo`) → `VideoAssetUploadService.ingestVideoFromBytes` → `ResumableUploadService.uploadFile` (CASSÉ) → fallback `provider.uploadChallengeVideo/uploadFreeVideo` (qui ré-utilise le MÊME service cassé) → `triggerTranscode` (`transcode-video`) + `_triggerMultiResolution` (`transcode-multi-resolution`, jobs orphelins) → résolution playback (cascade de fallbacks) → enregistrement DB → `video_publish_screen` → feed.

## 3. Incohérences (par gravité, avec preuves)

### CRITIQUE
1. **Upload de la vidéo BRUTE non compressée** = cause n°1 de lenteur. Studio ligne 12: « VideoCompress removed — all compression handled by Kamatera ». Or la compression Kamatera n'est jamais déclenchée (cf. #3). On uploade donc le fichier brut intégral (100–500 Mo) → jusqu'à 1 h sur réseau mobile BF.
2. **`ResumableUploadService` cassé + anti-pattern**:
   - Bug `_uploadChunk` (l.193-199): `getPublicUrl()` ne fait aucun appel réseau et ne lève jamais → chaque chunk est « skippé » sans upload.
   - `create-upload-session` crée un client service_role puis `auth.getUser()` sans JWT → user null → 401 → session jamais créée. **Preuve DB: `upload_sessions` = 0 ligne.**
   - `complete-upload-session` télécharge TOUS les chunks en RAM de l'Edge Function puis réuploade → OOM sur grosses vidéos + double transfert.
   - Conséquence: primaire ET fallback (mêmes appels) échouent pour >5 Mo → retombe sur upload direct du brut, ou échoue.
3. **`compress-video` (Kamatera) = code mort**. Seul `VideoPublishService.publishVideo()` l'appelle, et `VideoPublishService` n'est référencé nulle part (grep). De plus il appelle `app_videoasset_register_uploaded_source` avec une MAUVAISE signature (`p_video_asset_id, p_storage_bucket…`) alors que la vraie est `p_source_id, p_checksum_sha256, p_width, p_height, p_duration_ms, p_has_audio, p_validation_report`. Le service `academia-compress` (:8001) tourne 17 h pour rien.

### MAJEUR
4. **Edge Functions désynchronisées du worker réel**. `transcode-multi-resolution` crée des jobs `transcode_resolution` → **0 en base**. Le worker produit `generate_mp4/generate_hls/generate_thumbs/extract_metadata/export_watermarked`. → Edge Function morte; le studio l'appelle quand même (fire-and-forget) pour rien. `assemble-video-chunks` = doublon orphelin de `complete-upload-session`.
5. **Beaucoup de vidéos perdues/bloquées** (DB): 33 `draft` (intent sans upload), 63 `uploaded` (jamais passées `ready`), 3 `processing` → ~37 % des 258 assets non publiables. Jobs échoués: generate_mp4=19, watermark=8, hls=5, thumbs=10, metadata=2.
6. **Pipeline serveur historiquement non temps réel**: latence `done` moyenne generate_hls ≈ 43 j (max ≈ 61 j) → worker longtemps indisponible, backlog traité tardivement. Actuellement 0 backlog (worker actif), mais fiabilité passée mauvaise.
7. **Aucun trigger d'enqueue** sur `video_sources`/`video_assets` (seulement `set_updated_at`). Création de jobs opaque/fragile (orchestrée dans le worker), d'où jobs malformés.

### MOYEN
8. **Causes d'échec worker** (preuves): `Empty payload`/`Legacy job empty payload` (jobs malformés), `Watermark logo missing: /assets/images/academia.png` (asset watermark absent sur le VPS), `Duplicate 409 (video_asset_id, rendition_key)` (création de rendition NON idempotente).
9. **Schéma**: `poster_url` n'existe PAS sur `video_assets`, mais `transcode-video` (l.140) tente de l'écrire → no-op tant que poster null, casserait sinon. Posters jamais stockés sur l'asset.
10. **Double lecture audio feed↔studio**: `VideoPlayerLifecycleService` ne fait que `pause()` (MethodChannel async), jamais mute/dispose, pas de « propriétaire audio » unique → le player natif du feed peut garder/reprendre l'audio pendant que le studio joue son aperçu.

### MINEUR
11. **Sécurité**: `:8001` (compress) en HTTP public 0.0.0.0 sans auth visible; clés service_role en clair dans les scripts `.windsurf`.

## 4. État Kamatera (preuves SSH)
- `academia-compress.service` actif (:8001) — INUTILISÉ (ne reçoit que des scans internet 400/501).
- `video-worker.service` actif (`videoasset_worker.py` + `studio_video_renderer.py`) — FONCTIONNEL (produit les renditions). FFmpeg 6.1.1.
- Ressources: 4 vCPU / 9.7 Go RAM, charge ≈ 0.01 → **quasi inactif, énorme marge**.

## 5. Signatures RPC réelles (référence)
- `app_videoasset_create_upload_intent(p_origin text, p_context_type text, p_context_id uuid, p_role text='primary', p_mime_type text, p_expected_size bigint)`
- `app_videoasset_register_uploaded_source(p_source_id uuid, p_checksum_sha256 text, p_width int, p_height int, p_duration_ms int, p_has_audio bool, p_validation_report jsonb)`

## 6. Bonnes pratiques 2026 (recherche)
- **Supabase = TUS résumable natif**: endpoint `https://<ref>.storage.supabase.co/storage/v1/upload/resumable`, chunk **6 Mo obligatoire**, direct storage hostname, retryDelays, removeFingerprintOnSuccess. Package Flutter: `tus_client_dart`. ⇒ remplace le faux résumable maison.
- **TikTok/IG/YouTube**: on uploade UNE rendition compressée côté client (1080×1920, H.264 High, 30 fps, ~8–12 Mbps), jamais le brut; ABR/HLS généré côté serveur pour la lecture.
- **Lecture**: un seul player « actif » (audio focus global), preload N±1, le reste pausé+muté.

## 7. Plan proposé (résumé)
Principe: **compresser vite côté client → upload résumable rapide (TUS) → ABR serveur en tâche de fond → un seul pipeline, un seul lecteur.**
- Phase 0 — Supprimer le mort/contradictoire (VideoPublishService, assemble-video-chunks, appel transcode-multi-resolution mort), garder UN chemin.
- Phase 1 — Upload rapide: compression client au clic « Suivant » + TUS (`tus_client_dart`) → register → naviguer vers description; ABR serveur en fond.
- Phase 2 — Pipeline serveur cohérent: enqueue explicite et idempotent à l'enregistrement de la source (ON CONFLICT DO NOTHING), corriger watermark manquant + payloads vides, `transcode-video` (poster) + statut ready déterministe; option fusionner academia-compress dans le worker.
- Phase 3 — Lecture/double-audio: player unique « audio owner » (pauseAll + volume 0 + release surface), pause() awaited, interdiction de reprise feed tant que studio/preview actif.
- Phase 4 — Robustesse/UX: reprise après coupure, retries, brouillons, nettoyage des ~96 assets bloqués, gestion d'échecs worker.

## 8. Scripts d'audit créés (.windsurf)
- `audit_challenge_pipeline.py` (Supabase, lecture seule, via `admin_execute_sql`).
- `audit_kamatera_video.py` (Kamatera SSH, lecture seule).
