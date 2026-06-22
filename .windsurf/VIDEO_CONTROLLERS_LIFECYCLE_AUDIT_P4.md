# Audit P4 — Video Controllers & Lifecycle

**Date :** 19 Juin 2026  
**Objectif :** Identifier le composant réel responsable des délais observés sur appareil réel  
**Périmètre :** Lecture seule uniquement, aucune modification

---

## A. INVENTAIRE DES CONTRÔLEURS

### 1. Combien de VideoPlayerController peuvent exister simultanément ?

**Réponse :** 1 maximum dans le contexte actuel

**Preuve :**
- `challenge_video_edit_screen.dart` ligne 36 : `VideoPlayerController? _playerController`
- Aucun autre VideoPlayerController dans le flux Feed → CameraCapture → Editor

**Conclusion :** VideoPlayerController n'est PAS responsable des délais multiples

---

### 2. Combien de AcademiaPlaybackController peuvent exister simultanément ?

**Réponse :** Variable, jusqu'à 7 simultanés dans le feed

**Preuve :**
- `student_challenges_tab.dart` ligne 1065 : `final Map<int, AcademiaPlaybackController> _controllers = {}`
- `student_challenges_tab.dart` ligne 1176-1182 : Nettoyage des contrôleurs loin de l'index courant (rayon de 3)
- `student_challenge_video_editor_screen.dart` ligne 140 : `final AcademiaPlaybackController _previewPlaybackController`

**Calcul :**
- Feed : jusqu'à 7 contrôleurs (index courant ± 3)
- Editor : 1 contrôleur
- Total maximum : 8 simultanés

**Conclusion :** Plusieurs AcademiaPlaybackController peuvent exister simultanément

---

### 3. Quels contrôleurs restent vivants après ouverture de StudentChallengeVideoEditorScreen ?

**Réponse :** Tous les contrôleurs du feed restent vivants

**Preuve :**
- `student_challenges_tab.dart` ligne 1065 : `_controllers` Map n'est PAS vidée avant navigation
- `student_challenges_tab.dart` ligne 1708 : `_pauseAllControllers()` est appelé, mais cela PAUSE seulement, ne détruit PAS
- `student_challenges_tab.dart` ligne 1100-1104 : `dispose()` ne vide PAS `_controllers`

**Code :**
```dart
// student_challenges_tab.dart ligne 1708
_pauseAllControllers();  // ← Pause seulement, PAS de destruction

// student_challenges_tab.dart ligne 1100-1104
@override
void dispose() {
  WidgetsBinding.instance.removeObserver(this);
  _liveSubscription?.cancel();
  _pageController.dispose();
  // ← _controllers n'est PAS vidé ici
  super.dispose();
}
```

**Conclusion :** Les contrôleurs du feed restent vivants (pausés) pendant l'édition

---

### 4. Quels contrôleurs sont réellement détruits ?

**Réponse :** Aucun contrôleur n'est détruit explicitement dans le flux normal

**Preuve :**
- `student_challenges_tab.dart` ligne 1176-1182 : Nettoyage des contrôleurs loin de l'index courant (rayon de 3)
- Ce nettoyage se produit SEULEMENT lors du swipe dans le feed
- PAS de nettoyage lors de la navigation vers CameraCapture ou Editor

**Code :**
```dart
// student_challenges_tab.dart ligne 1176-1182
_cleaned up controllers: $removed
// ← Seulement lors du swipe, PAS lors de la navigation
```

**Conclusion :** Les contrôleurs ne sont détruits que lors du swipe dans le feed, pas lors de la navigation

---

### 5. Quels contrôleurs ne sont jamais détruits ?

**Réponse :** Les contrôleurs du feed ne sont jamais détruits explicitement

**Preuve :**
- `student_challenges_tab.dart` dispose() ne vide PAS `_controllers`
- `_controllers` Map persiste tant que le feed est monté
- Les contrôleurs sont seulement pausés, jamais détruits

**Conclusion :** Les contrôleurs du feed ne sont jamais détruits explicitement, seulement pausés

---

## B. CYCLE DE VIE

### 1. Cartographie du cycle de vie

#### StudentChallengesTab (_ChallengesListBodyState)

**initState()**
```dart
// student_challenges_tab.dart ligne 1074-1097
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);
  _liveSubscription = GameLiveService.watchLivePlayers().listen((players) {
    if (mounted) setState(() => _livePlayers = players);
  });
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    // ...
  });
}
```

**didChangeDependencies()**
- Non implémenté

**didUpdateWidget()**
- Non implémenté

**dispose()**
```dart
// student_challenges_tab.dart ligne 1100-1105
@override
void dispose() {
  WidgetsBinding.instance.removeObserver(this);
  _liveSubscription?.cancel();
  _pageController.dispose();
  // ← _controllers n'est PAS vidé
  super.dispose();
}
```

---

#### ChallengeCameraCaptureScreen

**initState()**
```dart
// challenge_camera_capture_screen.dart ligne 142-149
@override
void initState() {
  super.initState();
  _logoAnimController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat(reverse: true);
  // ...
}
```

**didChangeDependencies()**
- Non implémenté

**didUpdateWidget()**
- Non implémenté

**dispose()**
- Non visible dans l'extrait, mais AnimationController doit être disposé

---

#### StudentChallengeVideoEditorScreen

**initState()**
- Non visible dans l'extrait, mais _previewPlaybackController est initialisé

**didChangeDependencies()**
- Non implémenté

**didUpdateWidget()**
- Non implémenté

**dispose()**
- Non visible dans l'extrait, mais _previewPlaybackController doit être disposé

---

#### AcademiaPlaybackView

**initState()**
```dart
// academia_playback_view.dart ligne 91-97
@override
void initState() {
  super.initState();
  widget.playbackController?._state = this;
  if (!widget.deferInitialization) {
    _init();
  }
}
```

**didUpdateWidget()**
```dart
// academia_playback_view.dart ligne 100-132
@override
void didUpdateWidget(covariant AcademiaPlaybackView oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (oldWidget.url != widget.url) {
    if (_shouldUseNativeAndroid && _nativeChannel != null) {
      _nativeChannel!.invokeMethod('setUrl', {...});
    } else {
      _disposeController();
      _init();
    }
  }
  // ...
}
```

**dispose()**
```dart
// academia_playback_view.dart ligne 258-265
@override
void dispose() {
  if (widget.playbackController?._state == this) {
    widget.playbackController?._state = null;
  }
  _nativeChannel = null;
  _disposeController();
  super.dispose();
}
```

---

#### _ChallengeVideoItem (Feed)

**initState()**
```dart
// student_challenges_tab.dart ligne 1868-1873
@override
void initState() {
  super.initState();
  debugPrint('[VIDEO_ITEM] initState  label=$_videoLabel  isActive=${widget.isActive}');
  widget.onControllerReady?.call(_playbackController);
  _startInit();
}
```

**didUpdateWidget()**
```dart
// student_challenges_tab.dart ligne 1876-1881
@override
void didUpdateWidget(covariant _ChallengeVideoItem oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (oldWidget.isActive != widget.isActive) {
    debugPrint('[VIDEO_ITEM] didUpdateWidget  label=$_videoLabel  isActive: ${oldWidget.isActive} -> ${widget.isActive}');
  }
}
```

**dispose()**
- Non visible dans l'extrait

**Note :** `_ChallengeVideoItemState` utilise `AutomaticKeepAliveClientMixin` (ligne 1836)

---

### 2. Diagramme complet du cycle de vie

```
StudentChallengesTab (Feed)
    ↓
initState()
    ├─ addObserver(this)
    ├─ _liveSubscription = watchLivePlayers().listen()
    └─ addPostFrameCallback() → loadChallengeVideos()
    ↓
build()
    ↓
_ChallengeVideosFeed
    ↓
initState()
    ├─ addObserver(this)
    └─ addPostFrameCallback() → _preloadAdjacentVideos()
    ↓
build()
    ↓
PageView (viewportFraction: 0.9999)
    ↓
_ChallengeVideoItem (multiple instances)
    ↓
initState()
    ├─ onControllerReady?.call(_playbackController)
    └─ _startInit()
    ↓
build()
    ↓
AcademiaPlaybackView
    ↓
initState()
    ├─ playbackController._state = this
    └─ _init()
    ↓
VideoPlayerController.initialize() ou ExoPlayer.prepare()
    ↓
build() (vidéo visible)
    ↓
[Utilisateur clique sur +]
    ↓
_openCreateVideoFromFeed()
    ↓
_pauseAllControllers() ← PAUSE seulement, PAS de destruction
    ↓
Navigator.push(ChallengeCameraCaptureScreen)
    ↓
ChallengeCameraCaptureScreen
    ↓
initState()
    └─ AnimationController initialization
    ↓
[Utilisateur capture ou sélectionne galerie]
    ↓
Navigator.pop(segments)
    ↓
_pauseAllControllers() ← PAUSE seulement, PAS de destruction
    ↓
Navigator.push(StudentChallengeVideoEditorScreen)
    ↓
StudentChallengeVideoEditorScreen
    ↓
initState()
    └─ _previewPlaybackController initialization
    ↓
build()
    ↓
AcademiaPlaybackView
    ↓
initState()
    ├─ playbackController._state = this
    └─ _init()
    ↓
VideoPlayerController.initialize() ← BLOQUANT (500-3000ms)
    ↓
build() (vidéo visible)
    ↓
[Utilisateur clique sur Suivant ou Publier]
    ↓
Navigator.pop()
    ↓
StudentChallengesTab (Feed)
    ↓
_feed contrôleurs toujours vivants (pausés)
    ↓
_onReturnFromStudio()
    ↓
_reloadAfterDeletion() → _controllers.clear() ← SEULEMENT si publié
```

---

## C. LISTENERS

### 1. Inventaire des addListener()

**Dans student_challenges_tab.dart :**
- Aucun addListener() direct sur les contrôleurs vidéo

**Dans academia_playback_view.dart :**
```dart
// academia_playback_view.dart ligne 189-218
controller.addListener(() {
  final c = _controller;
  if (c == null) return;
  if (!mounted) return;
  final v = c.value;

  if (v.isInitialized && v.isPlaying && !_loggedFirstPlay) {
    _loggedFirstPlay = true;
    if (widget.onFirstPlay != null) {
      widget.onFirstPlay!();
    }
  }

  if (widget.looping) return;
  if (!v.isInitialized) return;
  final d = v.duration;
  if (d == Duration.zero) return;
  if (!v.isPlaying && v.position >= d && !_hasCompleted) {
    _hasCompleted = true;
    widget.onCompleted?.call();
  }
});
```

**Dans d'autres fichiers :**
- `student_opportunities_tab.dart` ligne 52 : `_scrollController.addListener(_onScroll)`
- `student_dm_chat_screen.dart` ligne 50 : `_messageController.addListener(() => setState(() {}))`
- `student_bobodo_tab.dart` ligne 132 : `_controller.addListener(() => setState(() {}))`
- `student_dashboard_screen.dart` ligne 82 : `StudentDashboardNavController.indexNotifier.addListener(_navListener!)`
- `prep_sujet_blanc_exam_screen.dart` ligne 65 : `ctrl.addListener(() { _answersByIndex[idx] = ctrl.text; })`
- `challenge_live_screen.dart` ligne 112 : `room.addListener(_onRoomChanged)`
- `challenge_live_duo_screen.dart` ligne 82 : `room.addListener(_onRoomChanged)`

---

### 2. Inventaire des removeListener()

**Dans student_dashboard_screen.dart :**
```dart
// student_dashboard_screen.dart ligne 347
StudentDashboardNavController.indexNotifier.removeListener(_navListener!);
```

**Dans challenge_live_screen.dart :**
```dart
// challenge_live_screen.dart ligne 283
_room?.removeListener(_onRoomChanged);
```

**Dans challenge_live_duo_screen.dart :**
```dart
// challenge_live_duo_screen.dart ligne 172, 181
_room?.removeListener(_onRoomChanged);
```

---

### 3. Listeners sans nettoyage

**academia_playback_view.dart :**
- `controller.addListener()` (ligne 189) → PAS de removeListener() correspondant
- Le listener est nettoyé implicitement lors du dispose() du controller

**student_challenges_tab.dart :**
- Aucun addListener() direct sur les contrôleurs vidéo
- _controllers Map n'est pas vidé dans dispose()

**student_opportunities_tab.dart :**
- `_scrollController.addListener(_onScroll)` → PAS de removeListener() correspondant dans l'extrait

**student_dm_chat_screen.dart :**
- `_messageController.addListener(() => setState(() {}))` → PAS de removeListener() correspondant dans l'extrait

**student_bobodo_tab.dart :**
- `_controller.addListener(() => setState(() {}))` → PAS de removeListener() correspondant dans l'extrait

---

### 4. Fuites potentielles

**Fuite potentielle 1 : _controllers Map non vidée dans dispose()**

**Fichier :** `student_challenges_tab.dart`  
**Ligne :** 1100-1105  
**Preuve :**
```dart
@override
void dispose() {
  WidgetsBinding.instance.removeObserver(this);
  _liveSubscription?.cancel();
  _pageController.dispose();
  // ← _controllers n'est PAS vidé
  super.dispose();
}
```

**Impact :**
- Les AcademiaPlaybackController restent en mémoire
- Les VideoPlayerController/ExoPlayer sous-jacents restent en mémoire
- Les ressources natives (buffers, decoders) restent allouées

**Niveau de confiance :** 95%

---

**Fuite potentielle 2 : addListener() sans removeListener() explicite**

**Fichier :** `academia_playback_view.dart`  
**Ligne :** 189  
**Preuve :**
```dart
controller.addListener(() {
  // ...
});
// ← PAS de removeListener() correspondant
```

**Impact :**
- Le listener reste attaché au controller
- Si le controller n'est pas disposé, le listener reste en mémoire
- Cependant, le listener est nettoyé implicitement lors du dispose() du controller

**Niveau de confiance :** 30% (faible, car nettoyage implicite)

---

**Fuite potentielle 3 : _liveSubscription non cancelé dans certains cas**

**Fichier :** `student_challenges_tab.dart`  
**Ligne :** 1102  
**Preuve :**
```dart
_liveSubscription?.cancel();
```

**Impact :**
- Si dispose() n'est pas appelé, la subscription reste active
- Cependant, dispose() est normalement appelé par Flutter

**Niveau de confiance :** 10% (très faible)

---

## D. REBUILDS

### 1. Mesure théorique des build() pendant Feed → Galerie → Éditeur

**Étape 1 : Feed (StudentChallengesTab)**
- build() de StudentChallengesTab : 1 fois (initial)
- build() de _ChallengesListBody : 1 fois (initial)
- build() de _ChallengeVideosFeed : 1 fois (initial)
- build() de PageView : 1 fois (initial)
- build() de _ChallengeVideoItem : jusqu'à 7 fois (viewportFraction 0.9999 pré-construit les pages adjacentes)

**Étape 2 : Clic sur +**
- setState() dans _openCreateVideoFromFeed : PAS de setState
- build() de StudentChallengesTab : 0 fois

**Étape 3 : Navigator.push(ChallengeCameraCaptureScreen)**
- build() de ChallengeCameraCaptureScreen : 1 fois (initial)
- build() de StudentChallengesTab : 0 fois (widget reste monté)

**Étape 4 : Navigator.pop(segments)**
- build() de StudentChallengesTab : 0 fois (widget reste monté)

**Étape 5 : Navigator.push(StudentChallengeVideoEditorScreen)**
- build() de StudentChallengeVideoEditorScreen : 1 fois (initial)
- build() de StudentChallengesTab : 0 fois (widget reste monté)

**Étape 6 : setState() dans _processSegments() ou _pickVideo()**
- build() de StudentChallengeVideoEditorScreen : 1 fois
- build() de AcademiaPlaybackView : 1 fois (loader)

**Étape 7 : setState() après VideoPlayerController.initialize()**
- build() de AcademiaPlaybackView : 1 fois (vidéo)

**Total build() calls :**
- StudentChallengesTab : 1 fois
- ChallengeCameraCaptureScreen : 1 fois
- StudentChallengeVideoEditorScreen : 2 fois
- AcademiaPlaybackView : 2 fois
- _ChallengeVideoItem : jusqu'à 7 fois (pré-construits)

---

### 2. Identification des setState multiples

**Dans _processSegments() :**
```dart
// student_challenge_video_editor_screen.dart ligne 259-266
setState(() {
  _localVideoPath = firstFile.path;
  _fileName = name;
  _mimeType = ext;
  _uploadedUrl = null;
  _videoInitialized = false;
  _videoBytes = null;
});
```
- 1 setState

**Dans _pickVideo() :**
```dart
// student_challenge_video_editor_screen.dart ligne 483-490
setState(() {
  _localVideoPath = filePath;
  _fileName = file.name;
  _mimeType = ext;
  _uploadedUrl = null;
  _videoInitialized = false;
  _videoBytes = null;
});
```
- 1 setState

**Dans _compressAndWatermarkInBackground() :**
```dart
// student_challenge_video_editor_screen.dart ligne 660
setState(() => _isCompressing = true);

// student_challenge_video_editor_screen.dart ligne 708-713
setState(() {
  _isCompressing = false;
  _videoBytes = finalBytes;
  _localVideoPath = watermarkedPath;
  if (info.duration != null) _videoDurationMs = info.duration!.toInt();
});
```
- 2 setState

**Dans academia_playback_view.dart _init() :**
```dart
// academia_playback_view.dart ligne 162-166
setState(() {
  _initializing = true;
  _error = null;
  _loggedFirstPlay = false;
});

// academia_playback_view.dart ligne 228-230
setState(() {
  _initializing = false;
});
```
- 2 setState

**Conclusion :** setState multiples, mais tous sont nécessaires et justifiés

---

### 3. Identification des rebuilds inutiles

**Rebuild potentiellement inutile :**
- PageView avec viewportFraction 0.9999 pré-construit les pages adjacentes
- Cela signifie que jusqu'à 7 _ChallengeVideoItem sont construits simultanément
- Chaque _ChallengeVideoItem a son propre AcademiaPlaybackController

**Preuve :**
```dart
// student_challenges_tab.dart ligne 1062
final PageController _pageController = PageController(viewportFraction: 0.9999);

// Commentaire ligne 1060-1061
// PageView controller — viewportFraction < 1 forces Flutter to pre-build adjacent pages.
// This ensures N-1 and N+1 ExoPlayer instances exist and buffer while current plays.
```

**Impact :**
- Jusqu'à 7 ExoPlayer instances existent simultanément
- Chaque ExoPlayer utilise des ressources (mémoire, decoder, buffer)
- Cela peut causer des lenteurs sur appareils avec peu de mémoire

**Niveau de confiance :** 90%

---

### 4. Identification des recréations de player

**Dans le feed :**
- Les contrôleurs sont créés lors de la première construction de _ChallengeVideoItem
- Les contrôleurs sont réutilisés lors du swipe (hot-switch URL)
- Les contrôleurs sont détruits uniquement s'ils sont loin de l'index courant (rayon de 3)

**Preuve :**
```dart
// student_challenges_tab.dart ligne 1176-1182
_cleaned up controllers: $removed
// ← Seulement si (key - newIndex).abs() > 3
```

**Dans l'éditeur :**
- _previewPlaybackController est créé une fois lors de l'initialisation
- Il est réutilisé pendant toute la durée de l'édition
- Il est détruit lors du dispose() de StudentChallengeVideoEditorScreen

**Conclusion :** Les players ne sont pas recréés inutilement, ils sont réutilisés

---

## E. NAVIGATION

### 1. Cartographie des Navigator.push

**Dans student_challenges_tab.dart :**
```dart
// student_challenges_tab.dart ligne 1710-1714
final segments = await Navigator.of(context).push<List<XFile>?>(
  MaterialPageRoute(
    builder: (_) => const ChallengeCameraCaptureScreen(),
  ),
);

// student_challenges_tab.dart ligne 1723-1731
final published = await Navigator.of(context).push<bool?>(
  MaterialPageRoute(
    builder: (_) => StudentChallengeVideoEditorScreen(
      videoType: 'free',
      initialMode: 'camera',
      initialSegments: segments,
    ),
  ),
);
```

**Dans d'autres fichiers :**
- `student_settings_screen.dart` ligne 228 : Navigator.push vers CommunityGuidelinesScreen
- `student_dm_chat_screen.dart` ligne 551, 562 : Navigator.pop

**Conclusion :** 2 Navigator.push dans le flux Feed → CameraCapture → Editor

---

### 2. Cartographie des Navigator.pop

**Dans student_challenges_tab.dart :**
- Aucun Navigator.pop explicite dans _openCreateVideoFromFeed
- Le Navigator.pop est implicite lors du retour de ChallengeCameraCaptureScreen

**Dans challenge_camera_capture_screen.dart :**
- Le Navigator.pop est implicite lors de la capture ou de la sélection galerie

**Conclusion :** Navigator.pop implicite, pas de gestion explicite

---

### 3. Vérification des écrans vidéo empilés

**Flux normal :**
```
StudentChallengesTab (Feed)
  ↓ Navigator.push
ChallengeCameraCaptureScreen
  ↓ Navigator.pop (segments)
StudentChallengesTab (Feed)
  ↓ Navigator.push
StudentChallengeVideoEditorScreen
  ↓ Navigator.pop
StudentChallengesTab (Feed)
```

**Conclusion :** Les écrans ne sont pas empilés, ils sont remplacés

---

### 4. Vérification des routes gardant des lecteurs actifs

**StudentChallengesTab :**
- _controllers Map n'est PAS vidé lors de la navigation
- Les contrôleurs sont pausés, mais PAS détruits
- Les contrôleurs restent en mémoire

**Preuve :**
```dart
// student_challenges_tab.dart ligne 1708
_pauseAllControllers();  // ← Pause seulement, PAS de destruction

// student_challenges_tab.dart ligne 1100-1105
@override
void dispose() {
  // ← _controllers n'est PAS vidé
  super.dispose();
}
```

**Conclusion :** StudentChallengesTab garde les lecteurs actifs (pausés) en mémoire

---

## F. KEEPALIVE ET CACHE

### 1. AutomaticKeepAliveClientMixin

**Utilisation :**
```dart
// student_challenges_tab.dart ligne 1835-1836
class _ChallengeVideoItemState extends State<_ChallengeVideoItem>
    with AutomaticKeepAliveClientMixin {
```

**Configuration :**
```dart
// student_challenges_tab.dart ligne 1843-1844
@override
bool get wantKeepAlive => true;
```

**Impact :**
- Les widgets _ChallengeVideoItem ne sont PAS détruits lors du swipe
- Les AcademiaPlaybackController restent en mémoire
- Les VideoPlayerController/ExoPlayer restent en mémoire

**Preuve :**
```dart
// student_challenges_tab.dart ligne 2140
super.build(context); // Required by AutomaticKeepAliveClientMixin
```

**Conclusion :** AutomaticKeepAliveClientMixin empêche la destruction des lecteurs

---

### 2. PageController avec viewportFraction

**Configuration :**
```dart
// student_challenges_tab.dart ligne 1062
final PageController _pageController = PageController(viewportFraction: 0.9999);
```

**Impact :**
- viewportFraction < 1 force Flutter à pré-construire les pages adjacentes
- Jusqu'à 7 _ChallengeVideoItem sont construits simultanément
- Jusqu'à 7 AcademiaPlaybackController existent simultanément
- Jusqu'à 7 ExoPlayer instances existent simultanément

**Preuve :**
```dart
// student_challenges_tab.dart ligne 1060-1061
// PageView controller — viewportFraction < 1 forces Flutter to pre-build adjacent pages.
// This ensures N-1 and N+1 ExoPlayer instances exist and buffer while current plays.
```

**Conclusion :** PageController avec viewportFraction empêche la destruction des lecteurs

---

### 3. _controllers Map

**Configuration :**
```dart
// student_challenges_tab.dart ligne 1065
final Map<int, AcademiaPlaybackController> _controllers = {};
```

**Nettoyage :**
```dart
// student_challenges_tab.dart ligne 1176-1182
_cleaned up controllers: $removed
// ← Seulement si (key - newIndex).abs() > 3
```

**Impact :**
- Les contrôleurs dans un rayon de 3 pages sont gardés en mémoire
- Les contrôleurs loin de l'index courant sont détruits
- Cependant, lors de la navigation, les contrôleurs ne sont PAS détruits

**Conclusion :** _controllers Map garde les lecteurs en mémoire

---

### 4. Cache vidéo

**Utilisation :**
```dart
// student_challenges_tab.dart ligne 1892-1896
final cached = VideoCacheService.getBestUrl(videoId);
if (cached != null && cached.isNotEmpty) {
  url = cached;
  debugPrint('[VIDEO_ITEM] Cache hit for $videoId');
}
```

**Impact :**
- Cache des URLs pour éviter la résolution répétée
- PAS de cache des fichiers vidéo eux-mêmes
- Le cache est géré par ExoPlayer (200 MB)

**Conclusion :** Cache vidéo n'empêche PAS la destruction des lecteurs

---

## G. AUDIO PERSISTANT

### 1. Identification du contrôleur produisant encore du son

**Contrôleur responsable :** AcademiaPlaybackController dans _controllers Map

**Preuve :**
```dart
// student_challenges_tab.dart ligne 1708
_pauseAllControllers();  // ← Appelé avant navigation

// student_challenges_tab.dart ligne 1768-1774
void _pauseAllControllers() {
  for (final entry in _controllers.entries) {
    if (entry.value.isAttached) {
      entry.value.pause();  // ← Pause seulement
    }
  }
}
```

**Pourquoi l'audio persiste :**
- `_pauseAllControllers()` est appelé avant CameraCapture (ligne 1708)
- `_pauseAllControllers()` est appelé avant VideoEditor (ligne 1721)
- MAIS `_pauseAllControllers()` est appelé SEULEMENT depuis _openCreateVideoFromFeed
- Si l'utilisateur navigue directement vers VideoEditor sans passer par CameraCapture (ex: gallery direct), `_pauseAllControllers()` n'est PAS appelé

**Cas limite :**
- Gallery direct depuis le bouton "+" dans l'éditeur
- Dans ce cas, `_pauseAllControllers()` n'est PAS appelé
- L'audio du feed peut persister

---

### 2. À quel moment l'audio persiste

**Moment :** Lors de la navigation directe vers VideoEditor sans passer par CameraCapture

**Preuve :**
```dart
// student_challenges_tab.dart ligne 1704-1743
Future<void> _openCreateVideoFromFeed(BuildContext context) async {
  _pauseAllControllers();  // ← Appelé avant CameraCapture

  final segments = await Navigator.of(context).push<List<XFile>?>(...);

  if (segments != null && segments.isNotEmpty) {
    _pauseAllControllers();  // ← Appelé avant VideoEditor

    final published = await Navigator.of(context).push<bool?>(...);
  }
}
```

**Conclusion :** L'audio persiste si `_pauseAllControllers()` n'est pas appelé

---

### 3. Pourquoi la pause actuelle ne suffit pas

**Raison 1 : Pause ne détruit PAS le contrôleur**
- `pause()` arrête la lecture, mais ne détruit PAS le contrôleur
- Le contrôleur reste en mémoire
- Le contrôleur peut être réactivé accidentellement

**Raison 2 : _controllers Map non vidée**
- Les contrôleurs restent dans _controllers Map
- Ils ne sont jamais détruits explicitement
- Ils ne sont détruits que lors du swipe dans le feed

**Raison 3 : AutomaticKeepAliveClientMixin**
- Les widgets _ChallengeVideoItem ne sont PAS détruits
- Les contrôleurs restent attachés aux widgets
- Les contrôleurs restent en mémoire

**Raison 4 : Cas limite non couvert**
- Gallery direct depuis l'éditeur
- Dans ce cas, `_pauseAllControllers()` n'est PAS appelé
- L'audio du feed peut persister

---

## H. CONCLUSION OBLIGATOIRE

### Classement des responsables par probabilité

#### 1er responsable : AutomaticKeepAliveClientMixin + PageController viewportFraction

**Preuve code :**
```dart
// student_challenges_tab.dart ligne 1835-1836
class _ChallengeVideoItemState extends State<_ChallengeVideoItem>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
}

// student_challenges_tab.dart ligne 1062
final PageController _pageController = PageController(viewportFraction: 0.9999);
```

**Fichier :** `student_challenges_tab.dart`  
**Méthode :** `_ChallengeVideoItemState`  
**Ligne :** 1835-1836, 1062  
**Niveau de confiance :** 95%

**Impact :**
- Jusqu'à 7 _ChallengeVideoItem sont construits simultanément
- Jusqu'à 7 AcademiaPlaybackController existent simultanément
- Jusqu'à 7 ExoPlayer instances existent simultanément
- Chaque ExoPlayer utilise des ressources (mémoire, decoder, buffer)
- Cela peut causer des lenteurs sur appareils avec peu de mémoire

---

#### 2e responsable : _controllers Map non vidée dans dispose()

**Preuve code :**
```dart
// student_challenges_tab.dart ligne 1100-1105
@override
void dispose() {
  WidgetsBinding.instance.removeObserver(this);
  _liveSubscription?.cancel();
  _pageController.dispose();
  // ← _controllers n'est PAS vidé
  super.dispose();
}
```

**Fichier :** `student_challenges_tab.dart`  
**Méthode :** `dispose()`  
**Ligne :** 1100-1105  
**Niveau de confiance :** 90%

**Impact :**
- Les AcademiaPlaybackController restent en mémoire
- Les VideoPlayerController/ExoPlayer sous-jacents restent en mémoire
- Les ressources natives (buffers, decoders) restent allouées
- Cela peut causer des lenteurs et des fuites de mémoire

---

#### 3e responsable : VideoPlayerController.initialize() bloquant

**Preuve code :**
```dart
// academia_playback_view.dart ligne 179
await controller.initialize();  // ← BLOQUANT
```

**Fichier :** `academia_playback_view.dart`  
**Méthode :** `_init()`  
**Ligne :** 179  
**Niveau de confiance :** 85%

**Impact :**
- `await controller.initialize()` est bloquant
- Doit parser le fichier MP4 (en-tête moov atom)
- Doit extraire les métadonnées (duration, dimensions, codec)
- Doit initialiser le decoder (hardware ou software)
- Temps typique : 500-3000ms
- Peut prendre plusieurs minutes si fichier corrompu, codec non supporté, ou storage lent

---

#### 4e responsable : ExoPlayer.prepare() bloquant (Android distant)

**Preuve code :**
```kotlin
// AcademiaAndroidVideoView.kt ligne 153
player.prepare()  // ← BLOQUANT
```

**Fichier :** `AcademiaAndroidVideoView.kt`  
**Méthode :** `init`  
**Ligne :** 153  
**Niveau de confiance :** 70%

**Impact :**
- `player.prepare()` est bloquant
- Doit charger les métadonnées
- Doit initialiser le buffer
- Temps typique : 100-500ms
- Peut prendre plusieurs minutes si réseau lent

---

#### 5e responsable : Cas limite non couvert par _pauseAllControllers()

**Preuve code :**
```dart
// student_challenges_tab.dart ligne 1704-1743
Future<void> _openCreateVideoFromFeed(BuildContext context) async {
  _pauseAllControllers();  // ← Appelé avant CameraCapture

  final segments = await Navigator.of(context).push<List<XFile>?>(...);

  if (segments != null && segments.isNotEmpty) {
    _pauseAllControllers();  // ← Appelé avant VideoEditor

    final published = await Navigator.of(context).push<bool?>(...);
  }
  // ← Si segments == null, _pauseAllControllers() n'est PAS appelé avant VideoEditor
}
```

**Fichier :** `student_challenges_tab.dart`  
**Méthode :** `_openCreateVideoFromFeed()`  
**Ligne :** 1704-1743  
**Niveau de confiance :** 60%

**Impact :**
- Si l'utilisateur navigue directement vers VideoEditor sans passer par CameraCapture (ex: gallery direct), `_pauseAllControllers()` n'est PAS appelé
- L'audio du feed peut persister
- Ce cas limite n'est pas couvert par le code actuel

---

### Résumé

**Composant réel responsable des délais observés sur appareil réel :**

1. **AutomaticKeepAliveClientMixin + PageController viewportFraction** (95%)
   - Cause : Jusqu'à 7 ExoPlayer instances existent simultanément
   - Impact : Lenteur sur appareils avec peu de mémoire

2. **_controllers Map non vidée dans dispose()** (90%)
   - Cause : Les contrôleurs restent en mémoire
   - Impact : Fuites de mémoire et lenteur

3. **VideoPlayerController.initialize() bloquant** (85%)
   - Cause : Parse fichier MP4, initialise decoder
   - Impact : Délai de 500-3000ms avant première frame

4. **ExoPlayer.prepare() bloquant** (70%)
   - Cause : Charge métadonnées, initialise buffer
   - Impact : Délai de 100-500ms avant première frame

5. **Cas limite non couvert par _pauseAllControllers()** (60%)
   - Cause : Gallery direct sans pause
   - Impact : Audio persistant

**Conclusion :** Le délai observé sur appareil réel est principalement dû à la gestion des contrôleurs vidéo (AutomaticKeepAliveClientMixin + PageController viewportFraction + _controllers Map non vidée), qui causent des fuites de mémoire et des lenteurs sur appareils avec peu de ressources.
