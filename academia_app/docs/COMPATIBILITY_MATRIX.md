# Matrice de compatibilité — Academia Learning Engine

## Plateformes supportées

| Plateforme | Version min | Statut | Notes |
|-----------|-------------|--------|-------|
| Android | API 21 (5.0) | ✅ | LiveKit plein support |
| iOS | 13.0 | ✅ | LiveKit + screen share |
| Web (Chrome) | 90+ | ✅ | WebRTC natif |
| Web (Firefox) | 80+ | ✅ | WebRTC natif |
| Web (Safari) | 14+ | ⚠️ | Screen share limité |
| Windows | 10+ | ✅ | LiveKit desktop |
| macOS | 11+ | ✅ | LiveKit desktop |
| Linux | Ubuntu 20.04+ | ✅ | LiveKit desktop |

## Dépendances critiques

| Package | Version | Rôle |
|---------|---------|------|
| `livekit_client` | ^2.x | Audio/vidéo/data temps réel |
| `video_player` | ^2.x | Replay vidéo |
| `perfect_freehand` | ^2.0.0 | Whiteboard smooth strokes |
| `supabase_flutter` | ^2.x | Backend + Realtime |
| `provider` | ^6.x | State management |

## Modes réseau

| Réseau | Comportement |
|--------|-------------|
| WiFi stable | Full HD video + audio + whiteboard sync |
| 4G | HD adaptative (simulcast downgrade) |
| 3G/Lent | Audio only + chat texte |
| Offline | Replay depuis cache local (futur) |

## Permissions requises

### Android (`AndroidManifest.xml`)
- `INTERNET`
- `CAMERA`
- `RECORD_AUDIO`
- `MODIFY_AUDIO_SETTINGS`
- `FOREGROUND_SERVICE` (recording)

### iOS (`Info.plist`)
- `NSCameraUsageDescription`
- `NSMicrophoneUsageDescription`

## Backward compatibility

- Sessions existantes (`online_course_live_sessions`, `prep_live_sessions`) continuent via `LivekitRoomScreen`
- Nouvelles sessions `AcademiaSession` utilisent `AcademiaClassroomScreen`
- Edge Function `livekit-token` supporte les deux modes (`session_source: 'auto'`)
- Migration progressive : pas de breaking change
