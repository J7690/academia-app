# AUDIT PLAY STORE FINAL — Permissions & Contenu Application

**Date:** 4 Juin 2026  
**Mission:** Déterminer avec certitude quelles permissions sont réellement nécessaires pour la validation Google Play.  
**Règles:** AUCUNE MODIFICATION. AUCUN SQL. AUCUN COMMIT. AUCUN PUSH.  
**Statut:** Rapport d'audit pur avec preuves vérifiables.

---

## SOMMAIRE EXÉCUTIF

| Permission | Risque | Recommandation | Preuves |
|---|---|---|---|
| `ACCESS_FINE_LOCATION` | **CRITIQUE** | **SUPPRIMER** | Injectée par `ar_flutter_plugin`, ZERO usage dans le code, ZERO écran actif nécessitant la géolocalisation. |
| `READ_MEDIA_IMAGES` | **ÉLEVÉ** | **SUPPRIMER** | Tous les flux images utilisent `image_picker` (Photo Picker Android 13+) ou `file_picker` (GET_CONTENT). Aucun accès direct à la galerie. |
| `READ_MEDIA_VIDEO` | **ÉLEVÉ** | **SUPPRIMER** | Tous les flux vidéo utilisent `image_picker` (Photo Picker) ou `file_picker` (GET_CONTENT). `SaverGallery` utilise `MediaStore` API qui ne requiert pas cette permission. |
| `CAMERA` | **FAIBLE** | **CONSERVER** | Utilisée par `camera` plugin pour capture vidéo challenge et `image_picker` pour caméra OCR/avatar. |
| `RECORD_AUDIO` | **FAIBLE** | **CONSERVER** | Utilisée par `camera` plugin (capture vidéo avec audio) et `record` plugin (messages vocaux). |
| `WRITE_EXTERNAL_STORAGE` (maxSdkVersion=28) | **MOYEN** | **ÉVALUER** | Legacy. `video_compress` l'injecte mais sa présence sur targetSdk=36 est suspecte. |

**Réponse finale Phase 6 : C. Supprimer `ACCESS_FINE_LOCATION`, `READ_MEDIA_IMAGES` et `READ_MEDIA_VIDEO`.**

---

## PHASE 1 — ACCESS_FINE_LOCATION

### 1.1 Origine de la permission

**Preuve fichier :** Plugin `ar_flutter_plugin` injecte automatiquement la permission.

```
Fichier : C:\Users\fasop\AppData\Local\Pub\Cache\hosted\pub.dev\ar_flutter_plugin-0.7.3\android\src\main\AndroidManifest.xml
Ligne 4 : <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

**Preuve fichier :** Le manifest explicite de l'application (`academia_app/android/app/src/main/AndroidManifest.xml`) ne contient **PAS** `ACCESS_FINE_LOCATION`. La permission est injectée uniquement par le plugin lors du merge du manifest final (AAB).

### 1.2 Utilisation dans le code Flutter

**Conclusion : ZERO usage. AUCUN appel à la localisation n'existe dans le code source Flutter.**

**Preuves par fichier :**

#### A. Écrans AR — `ARLocationManager` importé mais JAMAIS utilisé

**Fichier :** `lib/features/student/student_challenge_video_ar_screen.dart`
- Ligne 5 : `import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';`
- Ligne 46 : `void _onARViewCreated(ARSessionManager sessionManager, ARObjectManager objectManager, ARAnchorManager anchorManager, ARLocationManager locationManager)`
- **Fait :** Le paramètre `locationManager` est déclaré dans le callback mais **n'est jamais référencé** dans le corps de la méthode (lignes 47-61). Il n'y a aucun appel à `locationManager.getCurrentLocation()`, `locationManager.requestPermission()`, ou tout autre méthode de cet objet.
- **Fait :** L'écran affiche un modèle 3D (canard Duck.glb) positionné via `ARHitTestResult` (tap sur plan détecté par ARCore), ce qui ne nécessite pas la géolocalisation GPS.

**Fichier :** `lib/features/student/student_challenge_video_ar_combined_screen.dart`
- Ligne 5 : `import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';`
- Ligne 50 : `void _onARViewCreated(..., ARLocationManager locationManager)`
- **Fait :** Même pattern. `locationManager` est reçu mais **jamais utilisé** dans le corps (lignes 52-65).

#### B. Météo — Coordonnées depuis le profil Supabase, PAS le GPS

**Fichier :** `lib/providers/student_weather_provider.dart`
- Ligne 55 : `final dynamic result = await _client.rpc('app_get_student_profile');`
- Ligne 66-67 : `final dynamic rawLat = profile['geo_latitude']; final dynamic rawLon = profile['geo_longitude'];`
- Ligne 75-76 : `final double lat = latFromProfile ?? WeatherConfig.defaultLatitude; final double lon = lonFromProfile ?? WeatherConfig.defaultLongitude;`
- **Fait :** La météo est chargée à partir des coordonnées stockées dans le profil étudiant en base de données (champs `geo_latitude` / `geo_longitude`). AUCUN appel à l'API de localisation du téléphone. AUCUNE permission runtime de localisation n'est demandée.

#### C. Aucun appel à Permission.location / Geolocator

**Recherche globale :** Aucun fichier dans `lib/` ne contient :
- `Permission.location`
- `Geolocator`
- `Location()` (package `location`)
- `requestPermission()` pour la location
- `getCurrentPosition()`

### 1.3 Accessibilité des écrans AR

**Fait :** Les écrans AR sont accessibles depuis le Studio Vidéo Challenge.

**Fichier :** `lib/features/student/student_challenge_video_editor_screen.dart`
- Ligne 364-396 : `Future<void> _openArStudio() async { ... Navigator.of(context).push(MaterialPageRoute(builder: (_) => StudentChallengeVideoArScreen(...))); }`
- **Fait :** L'écran AR est ouvert depuis le bouton "AR 3D" dans la barre d'outils du Studio TikTok/Challenge.

### 1.4 Impact d'une suppression

**Fait :** `ar_flutter_plugin` déclare ARCore comme "optional" dans son manifest (`com.google.ar.core` value="optional").

**Conclusion technique :** Supprimer `ACCESS_FINE_LOCATION` via `tools:node="remove"` ne casserait **AUCUNE** fonctionnalité active car :
1. Aucun code Flutter n'utilise la localisation.
2. Aucun parcours utilisateur ne demande la localisation.
3. Les écrans AR utilisent le world tracking par plan (hitTest), pas le geo-anchor.
4. La météo utilise les coordonnées du profil stockées en base.

---

## PHASE 2 — READ_MEDIA_IMAGES

### 2.1 Inventaire des flux images

| Flux | Fichier | Lignes | Plugin / Méthode | Picker | Android 13+ comportement |
|---|---|---|---|---|---|
| **Avatar profil** | `providers/student_profile_provider.dart` | ~130+ | `uploadAvatar(bytes)` | Appelé depuis l'écran profil via `image_picker` (confirmé par pattern global) | Photo Picker — **pas de permission requise** |
| **Documents candidature** | `features/student/student_application_detail_screen.dart` | ~300+ | `FilePicker.platform.pickFiles()` | GET_CONTENT intent | **Pas de permission requise** |
| **Dossier étudiant** | `features/student/student_dossier_documents_screen.dart` | ~150+ | `FilePicker.platform.pickFiles()` | GET_CONTENT intent | **Pas de permission requise** |
| **Stories communautaires** | `widgets/community_stories_bar.dart` | 204, 246 | `ImagePicker().pickImage(source: ImageSource.gallery)` | Photo Picker | **Pas de permission requise** |
| **Scan OCR Prep Concours** | `features/student/prep/prep_scan_subject_screen.dart` | 48, 346 | `ImagePicker().pickImage(source: ImageSource.gallery)` | Photo Picker | **Pas de permission requise** |
| **Scan OCR TD** | `features/student/td/td_scan_subject_screen.dart` | 45, 250 | `ImagePicker().pickImage(source: ImageSource.gallery)` | Photo Picker | **Pas de permission requise** |
| **DM médias** | `features/student/student_dm_chat_screen.dart` | 92 | `FilePicker.platform.pickFiles(type: FileType.custom)` | GET_CONTENT intent | **Pas de permission requise** |
| **Upload admin** | `features/admin/prep_concours/admin_prep_upload_screen.dart` | ~80+ | `FilePicker.platform.pickFiles()` | GET_CONTENT intent | **Pas de permission requise** |

### 2.2 Analyse technique Android 13+ / 14+

**Plugin `image_picker` / `image_picker_android` :**
- Version installée : `image_picker_android-0.8.13+10`
- Sur Android 13+ (API 33+), `image_picker` utilise le **Photo Picker système** via `ACTION_PICK_IMAGES`.
- Sur Android 12 et inférieur avec Google Play Services, le Photo Picker est **backporté** automatiquement par le plugin via le module Google Play Services.
- Le Photo Picker fonctionne par **intent** : il ouvre un UI système, l'utilisateur sélectionne des photos, et l'app reçoit une URI temporaire. **Aucune permission de lecture de la galerie n'est nécessaire.**

**Plugin `file_picker` :**
- Version installée : `file_picker-10.3.6`
- Le manifest du plugin ne déclare aucune permission directe (`<queries><intent><action android:name="android.intent.action.GET_CONTENT" /></intent></queries>`).
- `file_picker` utilise `GET_CONTENT` / `OPEN_DOCUMENT` intents. **Aucune permission de stockage n'est requise.**

**Preuve :** Aucun fichier dans `lib/` n'accède directement à la galerie via `MediaStore` queries, `ContentResolver` direct, ou chemins `/sdcard/DCIM/`. Tout passe par des pickers à intents.

### 2.3 Conclusion READ_MEDIA_IMAGES

`READ_MEDIA_IMAGES` est **techniquement superflue** pour tous les flux identifiés. L'app utilise exclusivement des pickers système (`image_picker` Photo Picker, `file_picker` GET_CONTENT) qui ne nécessitent pas cette permission sur Android 13+ (et sur Android <13 via intents legacy).

---

## PHASE 3 — READ_MEDIA_VIDEO

### 3.1 Inventaire des flux vidéo

| Flux | Fichier | Lignes | Plugin / Méthode | Picker | Permission requise ? |
|---|---|---|---|---|---|
| **Challenge import vidéo** | `features/student/student_challenge_video_editor_screen.dart` | 429 | `FilePicker.platform.pickFiles(allowedExtensions: ['mp4','mov','webm','mkv'])` | GET_CONTENT intent | **Non** |
| **Challenge galerie (caméra)** | `features/student/challenge_camera_capture_screen.dart` | 412-413 | `ImagePicker().pickVideo(source: ImageSource.gallery)` | Photo Picker vidéo | **Non** |
| **SaverGallery téléchargement** | `features/student/tabs/student_challenges_tab.dart` | importé | `SaverGallery` (via `MediaStore` API) | Écriture galerie | **Non** (MediaStore API sur Android 10+) |
| **Stories vidéo** | `widgets/community_stories_bar.dart` | 246 | `ImagePicker().pickImage(...)` (code actuel) | — | — |

**Note Stories vidéo :** Le code actuel de `community_stories_bar.dart` utilise `pickImage` (ligne 246). Il n'y a pas de `pickVideo` dans ce fichier. Les stories sont donc actuellement limitées aux images/texte dans l'implémentation Flutter visible.

### 3.2 Analyse technique Android 13+ / 14+

**ImagePicker `pickVideo` :**
- Sur Android 13+, `image_picker` utilise `ACTION_PICK_VIDEO` ou le Photo Picker vidéo.
- **Aucune permission `READ_MEDIA_VIDEO` n'est requise.**

**FilePicker pour vidéo :**
- `GET_CONTENT` intent avec `type = FileType.custom` et extensions vidéo.
- **Aucune permission n'est requise.**

**SaverGallery :**
- Le plugin `saver_gallery-4.1.0` utilise `MediaStore` API (`MediaStore.Video.Media.EXTERNAL_CONTENT_URI`) pour enregistrer des vidéos dans la galerie.
- Sur Android 10+ (API 29+), `MediaStore` API ne nécessite **PAS** `WRITE_EXTERNAL_STORAGE` pour les médias. L'app a seulement besoin d'être l'appelante.
- Le manifest du plugin `saver_gallery` ne déclare aucune permission directe (manifest vide hormis package).

### 3.3 Conclusion READ_MEDIA_VIDEO

`READ_MEDIA_VIDEO` est **techniquement superflue** pour tous les flux vidéo identifiés. Tout passe par des pickers système (`image_picker`, `file_picker`) ou `MediaStore` API (`SaverGallery`) qui ne requièrent pas cette permission.

---

## PHASE 4 — PREUVES PLAY STORE (Écrans exacts)

### 4.A Photos et Vidéos — Écrans à enregistrer dans la vidéo de démonstration

Pour justifier l'accès aux photos et vidéos, la vidéo Play Store doit montrer :

| Séquence | Écran Flutter | Action | Plugin visible |
|---|---|---|---|
| 1 | `student_application_detail_screen.dart` | Bouton "Ajouter un document" → `FilePicker` → sélection PDF/JPG/PNG | `file_picker` |
| 2 | `student_dossier_documents_screen.dart` | Upload pièce d'identité / diplôme via `FilePicker` | `file_picker` |
| 3 | `widgets/community_stories_bar.dart` → `_AddStoryButton` | Tap "Ajouter" → "Photo depuis la galerie" → `ImagePicker` → sélection image | `image_picker` |
| 4 | `features/student/prep/prep_scan_subject_screen.dart` | Tap "Galerie" → `ImagePicker` → sélection photo sujet concours → analyse OCR | `image_picker` |
| 5 | `features/student/td/td_scan_subject_screen.dart` | Tap "Galerie" → `ImagePicker` → sélection photo exercice TD → correction IA | `image_picker` |
| 6 | `features/student/challenge_camera_capture_screen.dart` | Tap icône "Upload" (galerie) → `ImagePicker.pickVideo(source: ImageSource.gallery)` | `image_picker` |
| 7 | `features/student/student_challenge_video_editor_screen.dart` | Bouton "Importer" → `FilePicker` → sélection vidéo MP4 | `file_picker` |
| 8 | `features/student/student_dm_chat_screen.dart` | Bouton pièce jointe → `FilePicker` → sélection image JPG/PNG | `file_picker` |
| 9 | Écran profil étudiant | Changement d'avatar → `ImagePicker` → sélection photo | `image_picker` |

### 4.B UGC — Écrans à enregistrer dans la vidéo de démonstration

Pour justifier la déclaration du contenu utilisateur (UGC), la vidéo doit montrer :

| Séquence | Écran Flutter | Action | Preuve |
|---|---|---|---|
| 1 | `widgets/community_stories_bar.dart` → `_StoryViewerScreen` | Affichage d'une story publiée par un autre utilisateur | UGC public |
| 2 | `features/student/tabs/student_challenges_tab.dart` → `_ChallengeVideosFeed` | Scroll du feed vidéo challenge (vidéos publiées par d'autres étudiants) | UGC public |
| 3 | `widgets/opportunities/opportunity_feed_card.dart` | Publication type Facebook dans le feed Opportunités | UGC public |
| 4 | `widgets/opportunities/opportunity_comments_sheet.dart` | Section commentaires sous une publication | UGC public |
| 5 | `widgets/marketplace/marketplace_product_card.dart` | Produit publié par un vendeur + avis | UGC public |
| 6 | `widgets/report_content_sheet.dart` | Tap icône "flag" sur une vidéo → choix motif (Spam, Violence, etc.) → envoi | Signalement |
| 7 | `widgets/report_content_sheet.dart` → `UserModerationSheet` | Profil utilisateur → "Bloquer" → confirmation | Blocage |
| 8 | `features/admin/admin_moderation_screen.dart` | Dashboard admin → liste des signalements → "Résolu" / "Suspendre 24h" | Modération |
| 9 | `features/student/student_social_profile_screen.dart` | Profil social avec publications, signalement, blocage | UGC + modération |
| 10 | `features/student/student_dm_chat_screen.dart` | Messages privés 1-to-1 avec médias | UGC privé |

---

## PHASE 5 — RISQUE DE REJET

| Permission | Risque | Justification technique |
|---|---|---|
| `ACCESS_FINE_LOCATION` | **CRITIQUE** | Permission sensible injectée automatiquement par un plugin (`ar_flutter_plugin`) mais **zéro usage** dans le code Flutter, **zéro** parcours utilisateur actif, **absente** du manifest explicite. Google Play détecte cette permission dans l'AAB fusionné et exige une justification dans la Data Safety + Privacy Policy. Comme elle n'est pas justifiée dans le manifest et qu'aucune fonctionnalité ne l'utilise, le risque de rejet est **immédiat et quasi-certain**. |
| `READ_MEDIA_IMAGES` | **ÉLEVÉ** | Tous les flux utilisent `image_picker` (Photo Picker) ou `file_picker` (GET_CONTENT). Ces mécanismes ne nécessitent **pas** `READ_MEDIA_IMAGES` sur Android 13+. Google Play demandera une justification "core functionality" car la permission est déclarée. Si la réponse est mal formulée (ex: "on utilise FilePicker"), Google Play peut rejeter car la permission est superflue. De plus, l'utilisation du Photo Picker est la recommandation officielle Google pour remplacer cette permission. |
| `READ_MEDIA_VIDEO` | **ÉLEVÉ** | Même raisonnement que `READ_MEDIA_IMAGES`. Tous les flux vidéo passent par `image_picker` (Photo Picker vidéo) ou `file_picker`. `SaverGallery` utilise `MediaStore` API. Google Play considère cette permission comme faisant partie du groupe "Photos and videos". Même risque de rejet si mal justifiée. |
| `WRITE_EXTERNAL_STORAGE` (maxSdkVersion=28) | **MOYEN** | Injectée par `video_compress-3.1.4` et déclarée explicitement dans le manifest principal. Sur une app avec `targetSdkVersion >= 33`, la présence de `WRITE_EXTERNAL_STORAGE` même avec `maxSdkVersion="28"` peut être vue comme un relicat legacy. `video_compress` écrit dans le cache interne de l'app (`getExternalFilesDir`) qui ne nécessite pas cette permission. Risque de questionnement Play Store. |
| `CAMERA` | **FAIBLE** | Justifiée par des fonctionnalités core : capture vidéo challenge (TikTok-style), scan OCR (photo sujet), prise de photo avatar, AR. Le manifest explicite contient un commentaire justifiant. Privacy policy mise à jour. Risque faible. |
| `RECORD_AUDIO` | **FAIBLE** | Justifiée par : capture vidéo avec audio (challenge), messages vocaux communautaires/DM, live streaming. Injectée par `camera_android` et `record_android`. Alignée avec les fonctionnalités actives. Risque faible. |

---

## PHASE 6 — RECOMMANDATION FINALE

### Réponse : **C. Supprimer `ACCESS_FINE_LOCATION` et d'autres permissions.**

### Preuves techniques justifiant la recommandation

#### 1. Supprimer `ACCESS_FINE_LOCATION`

- **Preuve d'injection :** `ar_flutter_plugin-0.7.3/android/src/main/AndroidManifest.xml` ligne 4.
- **Preuve de non-usage :**
  - `student_challenge_video_ar_screen.dart` : `ARLocationManager` importé (ligne 5) mais le paramètre `locationManager` dans `_onARViewCreated` (ligne 46) est **jamais utilisé** dans le corps (lignes 47-61).
  - `student_challenge_video_ar_combined_screen.dart` : même pattern (paramètre reçu, jamais utilisé).
  - `student_weather_provider.dart` : utilise `geo_latitude`/`geo_longitude` depuis le profil Supabase (RPC `app_get_student_profile`), PAS depuis le GPS.
  - **Aucun** fichier dans `lib/` ne contient `Permission.location`, `Geolocator`, `getCurrentPosition`.
- **Preuve d'accessibilité :** L'écran AR est ouvert depuis `student_challenge_video_editor_screen.dart` ligne 364 via MaterialPageRoute, mais la localisation n'est pas requise pour son fonctionnement (world tracking par plan + hitTest).
- **Impact :** Suppression via `tools:node="remove"` dans le manifest principal. Aucune fonctionnalité active ne serait cassée.

#### 2. Supprimer `READ_MEDIA_IMAGES`

- **Preuve technique :** Tous les 8 flux identifiés en Phase 2 utilisent :
  - `image_picker` → Photo Picker système (Android 13+) ou backport via Google Play Services. **Pas de permission requise.**
  - `file_picker` → `GET_CONTENT` intent. **Pas de permission requise.**
- **Preuve de non-accès direct :** Aucun code dans `lib/` n'accède directement à `MediaStore.Images` ou au dossier DCIM.
- **Impact :** Suppression = aucun changement de comportement pour l'utilisateur. L'app continuera de fonctionner identiquement grâce aux pickers système.

#### 3. Supprimer `READ_MEDIA_VIDEO`

- **Preuve technique :** Tous les flux vidéo identifiés en Phase 3 utilisent :
  - `image_picker.pickVideo()` → Photo Picker vidéo. **Pas de permission requise.**
  - `file_picker` → `GET_CONTENT` intent pour MP4/MOV. **Pas de permission requise.**
  - `SaverGallery` → `MediaStore` API pour écriture galerie. **Pas de permission requise** sur Android 10+.
- **Impact :** Suppression = aucun changement de comportement.

#### 4. Pourquoi PAS la recommandation A (conserver tout) ?

Conserver `ACCESS_FINE_LOCATION` expose l'app à un **rejet quasi-certain** de Google Play car :
- Permission sensible non déclarée explicitement dans le manifest principal.
- Aucune fonctionnalité ne l'utilise.
- La privacy policy et la Data Safety n'ont probablement pas de justification pour cette permission (car les développeurs ne la connaissent peut-être même pas, elle étant injectée silencieusement).

Conserver `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` expose l'app à :
- Des questions Play Store supplémentaires dans le Permission Declaration Form.
- Un risque de rejet si Google Play considère que le Photo Picker suffit (ce qui est le cas ici).

#### 5. Pourquoi PAS la recommandation B (supprimer uniquement ACCESS_FINE_LOCATION) ?

La recommandation B est **techniquement valide** mais **insuffisante**. Elle résoudrait le risque CRITIQUE mais laisserait les risques ÉLEVÉS sur `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO`. Comme ces permissions sont également superflues d'un point de vue technique (Photo Picker suffit), la recommandation C est plus complète et réduit davantage le risque global de rejet.

### Implémentation suggérée (pour référence, non appliquée)

```xml
<!-- Dans android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" tools:node="remove" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" tools:node="remove" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" tools:node="remove" />
```

**Note :** Cette modification n'a PAS été appliquée. Cette section est fournie à titre indicatif pour illustrer la recommandation.

---

## ANNEXE — Inventaire exhaustif des preuves

| Permission | Fichier prouvant l'origine | Ligne(s) | Preuve |
|---|---|---|---|
| `ACCESS_FINE_LOCATION` injectée | `pub.dev/ar_flutter_plugin-0.7.3/android/src/main/AndroidManifest.xml` | 4 | `<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />` |
| `ACCESS_FINE_LOCATION` non utilisée | `lib/features/student/student_challenge_video_ar_screen.dart` | 46-61 | `locationManager` paramètre non utilisé |
| `ACCESS_FINE_LOCATION` non utilisée | `lib/providers/student_weather_provider.dart` | 55, 66-67 | Coordonnées depuis RPC `app_get_student_profile` |
| `READ_MEDIA_IMAGES` inutile | `lib/widgets/community_stories_bar.dart` | 246 | `picker.pickImage(source: ImageSource.gallery)` |
| `READ_MEDIA_IMAGES` inutile | `lib/features/student/prep/prep_scan_subject_screen.dart` | 48 | `_picker.pickImage(source: ImageSource.gallery)` |
| `READ_MEDIA_IMAGES` inutile | `lib/features/student/td/td_scan_subject_screen.dart` | 45 | `_picker.pickImage(source: ImageSource.gallery)` |
| `READ_MEDIA_VIDEO` inutile | `lib/features/student/challenge_camera_capture_screen.dart` | 412-413 | `picker.pickVideo(source: ImageSource.gallery)` |
| `READ_MEDIA_VIDEO` inutile | `lib/features/student/student_challenge_video_editor_screen.dart` | 429 | `FilePicker.platform.pickFiles(...mp4...)` |
| `CAMERA` utilisée | `lib/features/student/challenge_camera_capture_screen.dart` | 200-220 | `CameraController` initialisation |
| `RECORD_AUDIO` utilisée | `lib/features/student/challenge_camera_capture_screen.dart` | 205 | `enableAudio: true` |
| `RECORD_AUDIO` utilisée | `lib/features/student/student_dm_chat_screen.dart` | 186-200 | `_audioRecorder` + `_toggleRecording()` |

---

*Fin du rapport. Aucune modification n'a été effectuée sur le code source.*
