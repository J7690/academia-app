# AUDIT RIGOUREUX — Onglet Challenges (Flutter + Supabase)

**Date** : 21 février 2026  
**Fichiers audités** :
- `student_challenges_tab.dart` (2790 lignes)
- `student_challenge_detail_screen.dart` (851 lignes)
- `student_challenge_video_editor_screen.dart` (3820 lignes)
- `challenge_camera_capture_screen.dart` (730 lignes)
- `student_challenges_provider.dart` (1692 lignes)

---

## ARCHITECTURE ACTUELLE

```
StudentChallengesTab (TabBar)
├── Tab 0 : "Feed"  → _ChallengeVideosFeed (TikTok vertical PageView)
│   ├── _ChallengeVideoItem (lecture vidéo + overlays + actions)
│   ├── _ChallengeVideoActions (like, comment, share, report, remix)
│   └── BottomBar avec bouton "+" → _openCreateVideoFromFeed()
│
└── Tab 1 : "Challenges" → _ChallengesListBody (liste scrollable)
    ├── Recherche + filtres (type, joined)
    ├── "Mes challenges" / "Découvrir"
    └── Tile → StudentChallengeDetailScreen
        ├── Actions (rejoindre, soumettre, marquer terminé)
        ├── Vidéos de participation
        └── Leaderboard
```

---

## PROBLÈMES IDENTIFIÉS

### P1 — DEUX FLUX CAMÉRA COMPLÈTEMENT DIFFÉRENTS (CRITIQUE)

**Depuis le Feed (sous-onglet 1)** :
1. Bouton "+" → `_openCreateVideoFromFeed()`
2. Bottom sheet "Comment veux-tu créer ta vidéo ?" → camera / gallery
3. **Camera** : `ImagePicker.pickVideo(source: ImageSource.camera)` → caméra système native
4. Upload direct via `provider.uploadFreeVideo()` → `fetchPlaybackForDirectUrl()` → `createFreeVideo()`
5. Ouvre le studio en mode **"free"** : `StudentChallengeVideoEditorScreen(videoType: 'free', freeVideoId: ...)`

**Depuis Challenges (sous-onglet 2)** :
1. Tile → `StudentChallengeDetailScreen`
2. Bouton "Créer une vidéo de challenge" → `StudentChallengeVideoEditorScreen(challengeId: ..., participationId: ...)`
3. Dans le studio, bouton "Filmer" → `_handleInitialCaptureMode('camera')` → `_openCameraCaptureFlow()`
4. **Camera** : `ChallengeCameraCaptureScreen` (caméra custom avec filtres live, multi-segments, timer, flash)
5. Upload via `provider.uploadChallengeVideo()` → `fetchPlaybackForDirectUrl()` → `addChallengeVideo()`

**Divergences critiques** :
| Aspect | Feed (free) | Challenges |
|--------|-------------|------------|
| Caméra | `ImagePicker` (système) | `ChallengeCameraCaptureScreen` (custom TikTok) |
| Type vidéo | `free` | `challenge` |
| Upload bucket | `uploadFreeVideo` | `uploadChallengeVideo` |
| Création RPC | `createFreeVideo` | `addChallengeVideo` |
| Studio mode | Arrive APRÈS upload complet | Arrive AVANT upload (choix caméra/gallery dans le studio) |
| Flux | Upload → Studio | Studio → Capture → Upload |

### P2 — LE FEED NE PASSE PAS PAR LE STUDIO AVANT UPLOAD (MAJEUR)

Depuis le Feed, le flux est :
1. Caméra système → bytes
2. Upload immédiat (`uploadFreeVideo`)
3. Résolution playback (`fetchPlaybackForDirectUrl`)
4. Création free video (`createFreeVideo`)
5. **PUIS** ouverture du studio

L'utilisateur n'a **aucune chance de personnaliser** sa vidéo (filtres, textes, stickers, AR) **avant** l'upload. Le studio s'ouvre après, mais la vidéo est déjà uploadée en brut.

### P3 — ANDROID BLOQUE LES VIDÉOS BRUTES DANS LE FEED (MAJEUR)

Dans `_ChallengeVideoItemState._startInit()` (ligne 1506) :
```dart
if (isAndroid && !_selectedUrl.contains("/renders/")) {
  _setError("Android ne lit pas la vidéo brute. Rendition absente.");
  return;
}
```

Les vidéos "free" uploadées depuis le Feed n'ont **pas de renditions** (pas de `/renders/` dans l'URL). Elles sont donc **illisibles sur Android** dans le feed.

### P4 — `_recordVideoWithCamera()` DANS LE STUDIO NE DÉCLENCHE PAS L'UPLOAD (BUG)

Dans `student_challenge_video_editor_screen.dart` ligne 310-347, la méthode `_recordVideoWithCamera()` :
- Appelle `ImagePicker.pickVideo(source: ImageSource.camera)`
- Met à jour `_videoBytes`, `_fileName`, `_mimeType`
- **MAIS NE LANCE PAS `_uploadVideo()`** après la capture

Alors que `_pickVideo()` (gallery) appelle bien `_uploadVideo()` à la fin (ligne 384).

### P5 — BOTTOM BAR DU FEED NAVIGUE VERS `StudentChallengesTab` EN PUSH (BUG)

Ligne 1145-1158 : le bouton "Challenges" dans la bottom bar du feed fait :
```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => const StudentChallengesTab(),
  ),
);
```

Cela **empile un nouveau `StudentChallengesTab`** par-dessus le tab actuel au lieu de switcher vers le sous-onglet 2. L'utilisateur se retrouve avec une navigation imbriquée incohérente.

### P6 — PAS DE LOGS DANS LE PROVIDER CHALLENGES (DIAGNOSTIC)

Le `StudentChallengesProvider` n'a **aucun `print()` ou `debugPrint()`** dans ses méthodes principales (`loadChallenges`, `loadChallengeVideos`, `uploadFreeVideo`, `uploadChallengeVideo`, etc.), ce qui rend le debugging impossible via logcat.

### P7 — `_handleFreeVideoUpload` PASSE `mimeType: ext` AU LIEU DU VRAI MIME TYPE (BUG)

Ligne 1307-1312 :
```dart
await _handleFreeVideoUpload(
  context: context,
  bytes: bytes,
  fileName: name,
  mimeType: ext,  // ← "mp4" au lieu de "video/mp4"
);
```

Le paramètre `mimeType` reçoit l'extension du fichier (`mp4`) au lieu du vrai MIME type (`video/mp4`).

---

## PLAN DE CORRECTION

### Phase 1 — Unifier le flux caméra (P1 + P2 + P4)

**Objectif** : Un seul flux caméra → studio → upload → publish, identique depuis Feed et Challenges.

1. **Depuis le Feed** : Le bouton "+" ouvre directement `StudentChallengeVideoEditorScreen` en mode `free` (sans `freeVideoId` initial). Le studio propose alors caméra/gallery → capture → upload → personnalisation → publish.

2. **Depuis Challenges** : Identique à aujourd'hui, le studio s'ouvre avec `challengeId` + `participationId`.

3. **Dans le studio** : Unifier `_recordVideoWithCamera()` pour qu'il appelle `_uploadVideo()` après capture (comme `_pickVideo()`).

4. **Supprimer `_openCreateVideoFromFeed()`**, `_createFreeVideoFromCamera()`, `_createFreeVideoFromGallery()`, `_handleFreeVideoUpload()` — tout le flux "upload avant studio" du Feed.

### Phase 2 — Unifier la caméra (P1)

**Objectif** : Utiliser `ChallengeCameraCaptureScreen` (caméra TikTok custom) partout.

1. Dans le studio, remplacer `ImagePicker.pickVideo(source: ImageSource.camera)` par `ChallengeCameraCaptureScreen` pour le mode challenge ET free.

### Phase 3 — Corriger la navigation du Feed (P5)

1. Le bouton "Challenges" dans la bottom bar du feed doit switcher vers le sous-onglet 2 via le `TabController` parent, pas push un nouveau `StudentChallengesTab`.

### Phase 4 — Corriger le blocage Android (P3)

1. Soit retirer la restriction `/renders/` pour les vidéos free (elles n'ont pas de renditions).
2. Soit déclencher un job de rendu serveur après upload des vidéos free.

### Phase 5 — Corriger le MIME type (P7)

1. Utiliser `MimeTypeHelper` pour résoudre le vrai MIME type à partir de l'extension.

### Phase 6 — Ajouter des logs de diagnostic (P6)

1. Ajouter des `debugPrint()` dans les méthodes clés du provider pour faciliter le debugging via logcat.

---

## PRIORITÉ D'EXÉCUTION

1. **P1 + P2 + P4** : Unifier le flux (critique — l'expérience utilisateur est cassée)
2. **P5** : Navigation bottom bar (bug visible)
3. **P3** : Blocage Android renditions (vidéos illisibles)
4. **P7** : MIME type (bug silencieux)
5. **P6** : Logs diagnostic (qualité de vie)
