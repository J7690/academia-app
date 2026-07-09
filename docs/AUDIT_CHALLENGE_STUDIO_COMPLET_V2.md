# Audit Complet du Challenge Studio - Academia
**Date**: 18 Mars 2026  
**Scope**: Architecture Flutter, Supabase, Edge Functions, Backend Python, Infrastructure Kamatera

---

## Table des Matières

1. [Vue d'ensemble de l'architecture](#vue-densemble-de-larchitecture)
2. [Composants Flutter](#composants-flutter)
3. [Composants Audio/Voix](#composants-audiovoix)
4. [Composants Animations et Graphiques](#composants-animations-et-graphiques)
5. [Composants FFmpeg et Traitement Vidéo](#composants-ffmpeg-et-traitement-vidéo)
6. [Composants Bobodo/IA](#composants-bobodoia)
7. [Composants LiveKit](#composants-livekit)
8. [Infrastructure Kamatera et Edge Functions](#infrastructure-kamatera-et-edge-functions)
9. [Tables Supabase](#tables-supabase)
10. [Recommandations](#recommandations)

---

## Vue d'ensemble de l'architecture

### Architecture hybride

Le Challenge Studio utilise une architecture hybride avec les composants suivants :

- **Flutter Client** : Interface utilisateur, capture vidéo, édition locale, prévisualisation
- **Supabase** : Base de données, stockage (Storage), Edge Functions
- **Kamatera Cloud** : Serveur LiveKit (185.167.97.144:7880), backend Python FastAPI
- **Docker/Railway** : Backend de traitement vidéo (actuellement indisponible)

### Flux vidéo simplifié

```
Capture → Édition → Upload → Transcodage → Publication
   ↓         ↓         ↓          ↓           ↓
Camera   Overlays  VideoAsset  Kamatera    Feed
```

### Observations critiques

1. **Compression locale désactivée** : La compression et le watermarking sont désactivés côté Flutter, reportés sur le backend
2. **Multi-résolution non fonctionnelle** : Le worker `academia-videoasset-worker` n'est pas déployé
3. **Backend Railway indisponible** : Le backend de traitement vidéo lourd n'est pas accessible
4. **FFmpegKit désactivé** : Le mixage audio local via FFmpegKit est désactivé

---

## Composants Flutter

### Fichiers principaux

| Fichier | Rôle | Statut |
|---------|------|--------|
| `student_challenge_video_editor_screen.dart` | Éditeur vidéo principal | ✅ Fonctionnel |
| `challenge_scientific_studio_screen.dart` | Studio scientifique (LaTeX, dessin) | ✅ Fonctionnel |
| `challenge_camera_capture_screen.dart` | Capture vidéo TikTok-style | ✅ Fonctionnel |
| `video_publish_screen.dart` | Publication TikTok-style | ✅ Fonctionnel |
| `video_overlays_layer.dart` | Rendu des overlays vidéo | ✅ Fonctionnel |

### Fonctionnalités éditeur vidéo

**StudentChallengeVideoEditorScreen** :
- Import vidéo local (compression désactivée)
- Multi-segments capture (fusion non implémentée)
- Overlays : texte, équations, stickers, AR
- Intégration du studio scientifique
- Upload via `VideoAssetUploadService`

**ChallengeCameraCaptureScreen** :
- Filtres couleur live (Normal, Chaud, Froid, N&B, Sépia, Vif)
- Timer countdown (off, 3s, 5s, 10s)
- Multi-segments avec suppression du dernier
- Flash toggle, switch caméra
- Sélecteur de vitesse (0.5x, 1x, 2x, 3x)

**VideoPublishScreen** :
- Miniature vidéo avec sélection de cover
- Caption/description et hashtags
- Sélecteur de visibilité (public, friends, private)
- Upload en arrière-plan (TikTok flow)

### Bibliothèques Flutter (pubspec.yaml)

**Vidéo** :
- `camera` - Capture vidéo
- `image_picker` - Sélection galerie
- `video_player` - Lecture vidéo
- `video_thumbnail` - Miniatures
- `ffmpeg_kit_flutter_new_audio` - FFmpeg (désactivé)

**Dessin/Scientifique** :
- `perfect_freehand` - Dessin lissé
- `flutter_math_fork` - Rendu LaTeX

**Audio** :
- `audioplayers` - Lecture audio
- `flutter_sound` - Enregistrement audio
- `flutter_tts` - Synthèse vocale
- `speech_to_text` - Reconnaissance vocale

**UI** :
- `animate_do` - Animations
- `shimmer` - Skeleton loaders
- `emoji_picker_flutter` - Sélecteur emoji

---

## Composants Audio/Voix

### Services audio

| Service | Fichier | Rôle | Statut |
|---------|---------|------|--------|
| `StudioAudioService` | `studio_audio_service.dart` | Mixage audio backend | ✅ Actif |
| `AudioMixService` | `audio_mix_service.dart` | Mixage FFmpeg local | ❌ Désactivé |
| `BobodoVocalService` | `bobodo_vocal_service.dart` | WebSocket vocal | ✅ Actif |

### StudioAudioService

```dart
static Future<Map<String, dynamic>> render({
  required String participationId,
  required List<Map<String, dynamic>> tracks,
  bool normalize = true,
  String videoType = 'challenge',
  String? freeVideoId,
})
```

- Communique avec `/studio/audio/render` via JWT
- Délègue le mixage au backend Kamatera

### AudioMixService

```dart
static Future<String?> mixAudioIntoVideo({
  required String videoPath,
  required String audioUrl,
  List<VolumeSegment> originalVolumeSegments = const [],
  List<VolumeSegment> musicVolumeSegments = const [],
})
```

- **DÉSACTIVÉ** : FFmpegKit non disponible
- Supporte DJ-style volume segments
- Télécharge audio, probe vidéo, construit commande FFmpeg

### Bobodo Vocal

- WebSocket : `ws://185.167.97.144:8000/ws`
- Speech-to-Text natif via `speech_to_text`
- TTS via `flutter_tts`
- Audio visualisation avec niveaux

---

## Composants Animations et Graphiques

### Bibliothèques d'animation

- **animate_do** : Animations d'entrée/sortie (fadeIn, slideIn, etc.)
- Utilisé dans : feeds, overlays, bobodo tab, challenges

### Dessin scientifique

**ChallengeScientificStudioScreen** :
- `SciStroke` : Traits freehand avec `perfect_freehand`
- `SciAnnotation` : Texte/LaTeX avec `flutter_math_fork`
- Coordonnées relatives (0..1) pour scalabilité
- Supporte visibilité temporelle (startMs, endMs)

**WhiteboardCanvas** :
- Canvas collaboratif pour live sessions
- Outils : stylo, surligneur, gomme
- Palette de couleurs et épaisseurs
- Synchronisation remote strokes

### Overlays vidéo

**VideoOverlaysLayer** :
- Rendu temps réel des overlays
- Intègre `SciStroke` et `SciAnnotation`
- Supporte stickers et textes

---

## Composants FFmpeg et Traitement Vidéo

### FFmpeg côté Flutter

**AudioMixService** :
- **DÉSACTIVÉ** : `_execArgs` retourne `null`
- Commentaire : "DISABLED — FFmpegKit not available"
- Fonctionnalités prévues :
  - Mixage audio dans vidéo
  - Volume segments (DJ-style)
  - Loop audio
  - Trim audio

### FFmpeg côté Backend

**StudioVideoRenderer** (`academia_bobodo_backend/studio_video_renderer.py`) :
- FastAPI endpoint `/render`
- Télécharge vidéo depuis Supabase Storage
- Transcode en multiples résolutions :
  - Main (original)
  - 480p
  - 360p
  - 240p
- Upload vers Supabase Storage
- Authentification via API key

**Hero Video Encoder** :
- Service admin pour segments Hero
- Limite de taille par segment (~50 Mo)
- Durée minimale 5 secondes

### Compression locale

**StudentChallengeVideoEditorScreen** :
```dart
// COMPRESSION DÉSACTIVÉE - Sera faite sur Kamatera après clic bouton Suivant
// _compressAndWatermarkInBackground(filePath, file.name, t0);
```

- Compression locale désactivée
- Watermarking désactivé
- Utilise fichier original pour upload

---

## Composants Bobodo/IA

### Architecture Bobodo

**BobodoProvider** (`bobodo_provider.dart`) :
- Gère session et messages côté Flutter
- RPC : `app_get_or_create_bobodo_session`
- Persistance via SharedPreferences
- Feedback système par message

**BobodoVocalService** :
- WebSocket vocal : `ws://185.167.97.144:8000/ws`
- Stream audio bidirectionnel
- Intégration avec `flutter_sound`

### Edge Function bobodo-chat

**Endpoint** : `supabase/functions/bobodo-chat/index.ts`

**Fonctionnalités** :
- Authentification via Supabase JWT
- OpenRouter pour génération IA
- Filtrage contenu sensible (terrorisme, violence, sexualité, religion, etc.)
- Blocage questions universités
- Sauvegarde messages via RPC

**Modèles OpenRouter** :
- `OPENROUTER_MODEL` : Meta-Llama-3.1-70B-Instruct
- `OPENROUTER_FALLBACK_MODEL` : Fallback
- `OPENROUTER_EMBEDDING_MODEL` : Embeddings

### Services IA

**PrepAiService** (`prep_ai_service.dart`) :
- Tuteur IA pour préparation concours
- Edge Function : `prep-tutor-chat`
- Système de crédits (HTTP 402 si insuffisants)
- Fallback mode démo

**StudioAiService** (`studio_ai_service.dart`) :
- Transcription : `/studio/ai/transcribe`
- Analyse : `/studio/ai/analyze`
- Proofreading : `/studio/ai/proofread`
- Authentification JWT

### Système de crédits

**Tables** :
- `student_credits` - Solde par étudiant
- `credit_transactions` - Historique
- `credit_packs` - Packs d'achat
- `ai_action_prices` - Prix par action
- `credit_reservations` - Réservation avant appel

**RPCs** :
- `app_student_get_credit_balance` - Solde (30 crédits bienvenue)
- `app_student_check_ai_access` - Vérification
- `app_student_reserve_credits` - Réservation
- `app_student_confirm_credits` - Confirmation
- `app_student_refund_credits` - Remboursement

---

## Composants LiveKit

### Service LiveKit

**AcademiaLivekitService** (`academia_livekit_service.dart`) :
- Point d'entrée unifié LiveKit
- Token via Edge Function `livekit-token`
- Enregistrement via `livekit-recording`
- Support sessions Academia unifiées

### Edge Functions

**livekit-token** (`supabase/functions/livekit-token/index.ts`) :
- Génération JWT LiveKit
- HMAC-SHA256 signing
- Paramètres : room, identity, permissions
- TTL configurable

**livekit-recording** :
- Egress LiveKit
- Start/stop recording
- Session type 'academia'

### Écrans LiveKit

- `LivekitRoomScreen` - Room générique
- `AcademiaClassroomScreen` - Classe virtuelle
- `AcademiaClassroomControls` - Contrôles enseignant
- `WhiteboardCanvas` - Tableau blanc collaboratif

### Configuration

- **LIVEKIT_HOST** : `185.167.97.144:7880`
- **LIVEKIT_API_KEY** : Env var
- **LIVEKIT_API_SECRET** : Env var

---

## Infrastructure Kamatera et Edge Functions

### Backend Python (academia_bobodo_backend)

**main.py** :
- FastAPI application
- Endpoints :
  - `/studio/audio/render` - Mixage audio
  - `/studio/ai/transcribe` - Transcription
  - `/studio/ai/analyze` - Analyse
  - `/studio/ai/proofread` - Proofreading
  - `/studio/video/render` - Rendu vidéo
- Intégration LiveKit SDK
- Authentification API key

**StudioVideoRenderer** :
- Télécharge vidéo depuis Supabase
- Transcode FFmpeg multi-résolution
- Upload vers Supabase Storage
- Gestion erreurs et logs

### Edge Functions Supabase

**Vidéo** :
- `transcode-video` - Pipeline léger (création rendition original)
- `compress-video` - Compression (si activée)
- `assemble-video-chunks` - Assemblage segments
- `create-upload-session` - Session upload
- `complete-upload-session` - Finalisation upload

**LiveKit** :
- `livekit-token` - Génération token
- `livekit-recording` - Enregistrement

**IA (Prep)** :
- `prep-tutor-chat` - Tuteur IA
- `prep-generate-questions` - Génération QCM
- `prep-grade-assignment` - Correction
- `prep-scan-subject` - Scan sujet
- `prep-compose-exam-blanc` - Examen blanc
- `prep-analyze-trends` - Analyse tendances
- `prep-feed-actuality` - Feed actualité

**IA (TD)** :
- `td-tutor-chat` - Tuteur TD
- `td-generate-exercises` - Exercices
- `td-scan-subject` - Scan sujet
- `td-ingest-document` - Ingestion document

**Bobodo** :
- `bobodo-chat` - Chat IA
- `bobodo-generate-embeddings` - Embeddings

**Paiement** :
- `ligdicash-initiate` - Initiation paiement
- `ligdicash-confirm` - Confirmation
- `ligdicash-callback` - Callback
- `ligdicash-payout` - Reversement

### Storage Buckets

- `video-assets` - Vidéos principales
- `challenge-media` - Médias challenges
- `hero_videos` - Vidéos Hero (admin)

---

## Tables Supabase

### Tables vidéo

**video_assets** :
- id, status, origin, context_type, context_id
- poster_url, duration_ms
- created_at, updated_at

**video_sources** :
- id, video_asset_id, storage_bucket, storage_path
- mime_type, file_size_bytes
- created_at

**video_renditions** :
- id, video_asset_id, role (main, 480p, 360p, 240p)
- storage_bucket, storage_path, mime_type
- width, height, bitrate_kbps, duration_ms
- created_at

**video_processing_jobs** :
- id, video_asset_id, status
- job_type, input_source_id
- output_rendition_id
- error_message, started_at, completed_at

### Tables challenges

**challenges** :
- id, title, description, category
- start_date, end_date, max_duration_ms
- thumbnail_url, created_by

**challenge_participations** :
- id, challenge_id, user_id
- status, submitted_at
- video_asset_id, overlays

**challenge_videos** :
- id, participation_id, video_asset_id
- video_type (main, additional)
- order_index

### Tables IA

**bobodo_sessions** :
- id, user_id, title
- created_at, updated_at

**bobodo_messages** :
- id, session_id, role (user/assistant)
- content, created_at

**td_ai_messages** :
- id, conversation_id, role
- content, subject, created_at

### Tables crédits

**student_credits** :
- user_id, balance
- total_purchased, total_consumed, total_gifted
- last_weekly_bonus

**credit_transactions** :
- id, user_id, type (purchase/consume/bonus/refund)
- amount, balance_after
- openrouter_cost_usd, model, tokens
- created_at

**credit_packs** :
- code, name, price_xof, credits
- bonus_percent, is_active

**ai_action_prices** :
- action_code, name, price_credits
- is_active

**credit_reservations** :
- id, user_id, action_code
- amount_credits, status (reserved/confirmed/refunded)
- edge_function, created_at

---

## Recommandations

### Priorité Haute

1. **Activer FFmpegKit côté Flutter**
   - Pourquoi : Permet le mixage audio local sans dépendre du backend
   - Action : Décommenter `_execArgs` dans `AudioMixService`
   - Impact : Réduit latence, améliore UX offline

2. **Déployer worker multi-résolution**
   - Pourquoi : Transcodage multi-résolution non fonctionnel
   - Action : Déployer `academia-videoasset-worker` sur Railway/Kamatera
   - Impact : Vidéos optimisées pour tous les appareils

3. **Implémenter fusion multi-segments**
   - Pourquoi : Capture multi-segments existe mais fusion non implémentée
   - Action : Ajouter logique de fusion dans `_processSegments`
   - Impact : Permet enregistrement continu avec pauses

4. **Activer compression locale**
   - Pourquoi : Upload de fichiers volumineux sans compression
   - Action : Réactiver `_compressAndWatermarkInBackground`
   - Impact : Réduit taille upload, améliore performance

### Priorité Moyenne

5. **Activer watermarking local**
   - Pourquoi : Branding vidéo non appliqué localement
   - Action : Intégrer watermark FFmpeg dans pipeline local
   - Impact : Branding cohérent avant upload

6. **Optimiser Edge Functions**
   - Pourquoi : Certaines fonctions pourraient être fusionnées
   - Action : Audit performance, fusionner fonctions similaires
   - Impact : Réduit latence, coûts

7. **Améliorer gestion erreurs upload**
   - Pourquoi : Upload TUS peut échouer sans retry robuste
   - Action : Ajouter retry avec backoff exponentiel
   - Impact : Meilleure résilience réseau

8. **Ajouter tests E2E**
   - Pourquoi : Aucun test automatisé identifié
   - Action : Créer tests pour flux capture→edit→publish
   - Impact : Détection régressions

### Priorité Basse

9. **Refactoriser overlays**
   - Pourquoi : `SciStroke` et `SciAnnotation` dupliquent logique
   - Action : Créer modèle unifié d'overlay
   - Impact : Maintenance simplifiée

10. **Ajouter analytics studio**
    - Pourquoi : Pas de tracking usage studio
    - Action : Intégrer événements analytics
    - Impact : Compréhension comportement utilisateur

11. **Optimiser animations**
    - Pourquoi : `animate_do` utilisé massivement
    - Action : Profiler performance, réduire animations lourdes
    - Impact : UI plus fluide

12. **Documenter architecture**
    - Pourquoi : Documentation dispersée
    - Action : Centraliser docs, diagrammes
    - Impact : Onboarding nouveau développeur

### Infrastructure

13. **Backup Kamatera**
    - Pourquoi : Point de défaillance unique
    - Action : Configurer backup automatique
    - Impact : Résilience infrastructure

14. **Monitoring backend**
    - Pourquoi : Pas de monitoring visible
    - Action : Intégrer Prometheus/Grafana
    - Impact : Alertes proactives

15. **CDN pour vidéos**
    - Pourquoi : Supabase Storage pas optimisé streaming
    - Action : Intégrer CDN (Cloudflare, Fastly)
    - Impact : Lecture vidéo plus rapide

---

## Conclusion

Le Challenge Studio Academia est une plateforme vidéo avancée avec des fonctionnalités riches (capture, édition, overlays, IA, live). Cependant, plusieurs composants critiques sont désactivés ou non déployés (FFmpegKit local, worker multi-résolution, compression locale).

**Points forts** :
- Architecture modulaire bien conçue
- Intégration Supabase robuste
- Fonctionnalités IA avancées (Bobodo, Prep)
- LiveKit intégré pour sessions live

**Points à améliorer** :
- Réactiver composants locaux désactivés
- Déployer infrastructure backend manquante
- Implémenter fusion multi-segments
- Ajouter tests et monitoring

**Recommandation prioritaire** : Commencer par activer FFmpegKit et déployer le worker multi-résolution pour améliorer l'expérience utilisateur et la performance vidéo.
