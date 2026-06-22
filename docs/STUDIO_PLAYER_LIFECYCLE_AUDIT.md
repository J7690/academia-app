# STUDIO_PLAYER_LIFECYCLE_AUDIT - RAPPORT

**Date :** 19 Juin 2026
**Objectif :** Identifier pourquoi une vidéo du feed continue à jouer quand l'utilisateur entre dans le Studio

---

## ANALYSE DES COMPONENTS

### 1. AcademiaPlaybackView (academia_playback_view.dart)

**Controller :**
- `VideoPlayerController? _controller` (Web/iOS uniquement)
- `MethodChannel? _nativeChannel` (Android native player)

**Lifecycle :**
- `initState()` : Attache `playbackController._state`, appelle `_init()`
- `dispose()` : Détache `playbackController._state`, nettoie `_nativeChannel`, appelle `_disposeController()`
- `_disposeController()` : Dispose le VideoPlayerController

**Problème :**
- Aucun log de création/destruction
- Pas de tracking global des controllers actifs

**Logs actuels :**
- `[AcademiaPlaybackView] build AndroidView url=...`
- `[P9_ENGINE] url=...`

---

### 2. AcademiaPlaybackEngine (academia_playback_engine.dart)

**Nature :**
- Wrapper statique simple
- Retourne un `AcademiaPlaybackView`
- Pas de state, pas de controller

**Logs actuels :**
- `[P9_ENGINE] url=...`

---

### 3. StudentChallengesTab (_ChallengeVideosFeed)

**Controllers :**
- `Map<int, AcademiaPlaybackController> _controllers` - Tracke les controllers par page index
- `PageController _pageController` - Pour le PageView

**Lifecycle :**
- `initState()` : Initialise le feed, charge les vidéos, précharge les vidéos adjacentes
- `dispose()` : Nettoie `_liveSubscription`, `_pageController` - **MAIS NE NETTOIE PAS _controllers**
- `didChangeAppLifecycleState()` : Pause/resume les controllers quand l'app va en background
- `_onPageChanged()` : Pause les controllers non actifs, nettoie les controllers loin de la page courante

**Problème :**
- `dispose()` ne pause pas les controllers dans `_controllers`
- Aucun mécanisme pour pauser les controllers quand on navigue vers une autre page (Studio)
- Les controllers dans `_controllers` restent actifs même après dispose()

**Logs actuels :**
- `[RUNTIME LIFECYCLE] _ChallengeVideosFeed initState`
- `[RUNTIME LIFECYCLE] _ChallengeVideosFeed dispose - _controllers size=...`
- `[RUNTIME PRELOAD] Page changed: ...`
- `[FEED] Lifecycle ...`

---

### 4. StudentChallengeVideoEditorScreen

**Controllers :**
- Aucun VideoPlayerController direct (utilise AcademiaPlaybackView)
- Peut créer des controllers via `_loadVideoBytes` ou `_loadVideoFile`

**Lifecycle :**
- `dispose()` : Dispose les TextEditingController, ScrollController - **MAIS NE PAUSE PAS LES CONTROLLERS VIDÉO**
- `_cleanupAndPop()` : Nettoie l'état vidéo (`_uploadedUrl = null`) mais ne pause pas les controllers externes

**Problème :**
- Ne pause pas les controllers du feed quand le Studio s'ouvre
- Ne restaure pas les controllers du feed quand le Studio ferme

---

## RACINE DU PROBLÈME

**Quand l'utilisateur navigue Feed → Studio :**

1. Le feed (_ChallengeVideosFeed) reste dans la navigation stack
2. Ses controllers dans `_controllers` ne sont pas pausés
3. Le Studio (StudentChallengeVideoEditorScreen) ne pause pas les controllers du feed
4. Les vidéos du feed continuent à jouer en arrière-plan

**Pourquoi le controller du feed n'est pas détruit :**
- `_ChallengeVideosFeed.dispose()` ne nettoie pas `_controllers`
- Les `AcademiaPlaybackController` dans `_controllers` ne sont pas disposés
- Les `VideoPlayerController` sous-jacents ne sont pas disposés

---

## CONTROLLERS ACTIFS SIMULTANÉMENT

**Scénario actuel :**
- Feed : N controllers actifs (préchargement N-3..N+3)
- Studio : 0-1 controller actif (vidéo locale)
- Total : N+1 controllers actifs simultanément

**Scénario souhaité :**
- Feed : 0 controllers actifs quand Studio ouvert
- Studio : 1 controller actif (vidéo locale)
- Total : 1 controller actif

---

## SOLUTION PROPOSÉE

### 1. Ajouter un service global de tracking des controllers

**Fichier :** `lib/services/video_player_lifecycle_service.dart`

```dart
class VideoPlayerLifecycleService {
  static final VideoPlayerLifecycleService _instance = VideoPlayerLifecycleService._internal();
  factory VideoPlayerLifecycleService() => _instance;
  VideoPlayerLifecycleService._internal();

  final Map<String, AcademiaPlaybackController> _controllers = {};
  final Map<String, String> _controllerSources = {}; // 'feed', 'studio', 'viewer'

  void registerController(String id, AcademiaPlaybackController controller, String source) {
    _controllers[id] = controller;
    _controllerSources[id] = source;
    debugPrint('[PLAYER_CREATED] id=$id source=$source total=${_controllers.length}');
  }

  void unregisterController(String id) {
    _controllers.remove(id);
    _controllerSources.remove(id);
    debugPrint('[PLAYER_DISPOSED] id=$id total=${_controllers.length}');
  }

  void pauseAll() {
    for (final entry in _controllers.entries) {
      if (entry.value.isAttached) {
        entry.value.pause();
        debugPrint('[PLAYER_PAUSED] id=${entry.key} source=${_controllerSources[entry.key]}');
      }
    }
  }

  void pauseFeed() {
    for (final entry in _controllers.entries) {
      if (_controllerSources[entry.key] == 'feed' && entry.value.isAttached) {
        entry.value.pause();
        debugPrint('[PLAYER_PAUSED] id=${entry.key} source=feed');
      }
    }
  }

  void resumeFeed() {
    for (final entry in _controllers.entries) {
      if (_controllerSources[entry.key] == 'feed' && entry.value.isAttached) {
        entry.value.play();
        debugPrint('[PLAYER_RESUMED] id=${entry.key} source=feed');
      }
    }
  }

  int get activeCount => _controllers.values.where((c) => c.isAttached).length;
}
```

### 2. Modifier _ChallengeVideosFeed pour enregistrer les controllers

**Dans `_onPageChanged()` :**
```dart
// Enregistrer le controller
VideoPlayerLifecycleService().registerController(
  'feed_$newIndex',
  newCtrl!,
  'feed',
);
```

**Dans `dispose()` :**
```dart
// Nettoyer tous les controllers
for (final entry in _controllers.entries) {
  VideoPlayerLifecycleService().unregisterController('feed_${entry.key}');
}
_controllers.clear();
```

### 3. Modifier StudentChallengeVideoEditorScreen pour pauser le feed

**Dans `initState()` :**
```dart
VideoPlayerLifecycleService().pauseFeed();
```

**Dans `dispose()` :**
```dart
VideoPlayerLifecycleService().resumeFeed();
```

### 4. Ajouter des logs dans AcademiaPlaybackView

**Dans `_init()` :**
```dart
debugPrint('[PLAYER_CREATED] VideoPlayerController initialized url=$url');
```

**Dans `dispose()` :**
```dart
debugPrint('[PLAYER_DISPOSED] VideoPlayerController disposed');
```

---

## ACTIONS REQUISES

1. Créer `VideoPlayerLifecycleService`
2. Enregistrer les controllers dans `_ChallengeVideosFeed`
3. Nettoyer les controllers dans `_ChallengeVideosFeed.dispose()`
4. Appeler `pauseFeed()` dans `StudentChallengeVideoEditorScreen.initState()`
5. Appeler `resumeFeed()` dans `StudentChallengeVideoEditorScreen.dispose()`
6. Ajouter des logs dans `AcademiaPlaybackView`
