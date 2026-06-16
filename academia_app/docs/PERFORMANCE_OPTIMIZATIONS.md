# Performance Optimizations — Academia Learning Engine

## 1. LiveKit

- **Adaptive Stream** : activé (`RoomOptions.adaptiveStream = true`)
- **Dynacast** : activé (n'envoie les tracks qu'aux abonnés actifs)
- **Simulcast** : activé (3 qualités vidéo, le client choisit selon bande passante)
- **Video codec** : VP8 (compatibilité maximale)

## 2. Flutter UI

- **RepaintBoundary** : le whiteboard utilise `ClipRect` + `CustomPaint` isolé
- **Lazy grid** : `GridView.builder` pour la grille vidéo (pas de pré-rendu)
- **Scroll optimization** : `ListView.builder` pour le chat (recyclage des widgets)
- **Image caching** : avatars via `CachedNetworkImage` (package existant)

## 3. Réseau

- **Data Channel reliability** : messages chat = reliable, réactions = unreliable (perf)
- **Heartbeat** : 30s (pas plus fréquent pour limiter les appels RPC)
- **Batch messages** : chat persistant utilise Realtime + optimistic insert

## 4. Base de données

- **Indexes** : 
  - `academia_sessions(status, started_at)`
  - `academia_session_messages(session_id, created_at)`
  - `academia_session_presence(session_id, user_id)`
  - `academia_session_events(session_id, created_at)`
- **Pagination** : tous les RPCs list supportent `p_limit` + `p_before`
- **Cleanup automatique** : pg_cron `presence_cleanup` marque offline les stale > 2min

## 5. Mémoire

- **Room dispose** : appel systématique dans `_cleanup()`
- **Listener dispose** : `EventsListener` disposé avant déconnexion
- **Video controllers** : disposés dans `dispose()` du replay screen
- **Timer cancel** : tous les Timers annulés dans `dispose()`

## 6. Build size

- **Tree shaking** : imports ciblés (pas de `import 'package:livekit_client.dart'` global)
- **ProGuard/R8** : activé pour le release APK
- **Deferred loading** : le whiteboard et le replay sont des overlays lazy

## Métriques cibles

| Métrique | Cible |
|----------|-------|
| Time to first frame (connexion room) | < 3s |
| Latency audio | < 200ms |
| Heartbeat round-trip | < 500ms |
| Chat message delivery | < 1s |
| Whiteboard stroke sync | < 300ms |
| Memory (30min session) | < 200MB |
