# AUDIT PLAY STORE BLOQUANT — Permissions & Contenu de l'Application

**Date:** 4 Juin 2026  
**Mission:** Identifier précisément les éléments déclenchant les demandes Google Play (Photos/Vidéos + Contenu Application)  
**Statut:** AUCUNE MODIFICATION EFFECTUÉE — Rapport d'analyse pur

---

## PHASE 1 — INVENTAIRE DES PERMISSIONS FINALES

### Source analysée
- `academia_app/android/app/src/main/AndroidManifest.xml` (manifest explicite de l'application)
- Manifests fusionnés des plugins Flutter (pub cache audités)
- `pubspec.yaml` (dépendances)

### Tableau des permissions détectées dans l'AAB final

| Permission | Origine | Utilisée ? | Fonction concernée | Peut être supprimée ? |
|---|---|---|---|---|
| `android.permission.INTERNET` | Manifest explicite (ligne 2) | ✅ OUI | Tous les appels réseau (Supabase, FCM, API) | ❌ NON (essentielle) |
| `android.permission.CAMERA` | Manifest explicite (ligne 4) + `camera_android` plugin | ✅ OUI | Capture vidéo challenge TikTok, scan documents TD/Prépa, AR 3D | ❌ NON (core feature) |
| `android.permission.RECORD_AUDIO` | Manifest explicite (ligne 6) + `camera_android` + `record_android` plugin | ✅ OUI | Messages vocaux communautés/DM, capture vidéo challenge, live streaming | ❌ NON (core feature) |
| `android.permission.READ_MEDIA_VIDEO` | Manifest explicite (ligne 8) | ✅ OUI | Sauvegarde vidéos challenge dans la galerie (SaverGallery) | ⚠️ Discutable |
| `android.permission.READ_MEDIA_IMAGES` | Manifest explicite (ligne 9) | ✅ OUI | Upload avatar profil, upload documents dossier, stories communautaires | ⚠️ Discutable |
| `android.permission.WRITE_EXTERNAL_STORAGE` (maxSdkVersion=28) | Manifest explicite (ligne 10) + `video_compress` plugin | ✅ OUI | Compression vidéo challenge, sauvegarde galerie (legacy Android <10) | ⚠️ Peut être retirée si targetSdk>=33 bien géré |
| `android.permission.POST_NOTIFICATIONS` | Manifest explicite (ligne 12) | ✅ OUI | Push notifications FCM (messages, alertes admin, lives) | ❌ NON (core feature) |
| `android.permission.RECEIVE_BOOT_COMPLETED` | Manifest explicite (ligne 13) | ✅ OUI | FCM token refresh après reboot | ❌ NON (FCM requis) |
| `android.permission.VIBRATE` | Manifest explicite (ligne 14) | ✅ OUI | Haptic feedback notifications | ❌ NON (faible impact) |
| `android.permission.WAKE_LOCK` | Manifest explicite (ligne 15) | ✅ OUI | FCM background processing | ❌ NON (FCM requis) |
| `android.permission.FOREGROUND_SERVICE` | Manifest explicite (ligne 16) | ✅ OUI | Screen recording gameplay capture | ❌ NON (feature active) |
| `android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION` | Manifest explicite (ligne 17) | ✅ OUI | Screen recording gameplay capture | ❌ NON (feature active) |
| `android.permission.ACCESS_NETWORK_STATE` | Manifest explicite (ligne 18) | ✅ OUI | Détection connectivité offline | ❌ NON (faible impact) |
| `android.permission.ACCESS_FINE_LOCATION` | **`ar_flutter_plugin` plugin (injection automatique)** | ⚠️ IMPLICITE | AR 3D Studio (feature potentielle) | ❓ À vérifier — PAS DANS LE MANIFEST EXPLICITE |

### Permission critique non déclarée explicitement

**`ACCESS_FINE_LOCATION`** est injectée automatiquement par `ar_flutter_plugin-0.7.3` (`android/src/main/AndroidManifest.xml` ligne 4) mais **ABSENTE** du manifest explicite de l'application. Google Play la verra pourtant dans l'AAB fusionné final. C'est une permission sensible non justifiée dans la déclaration Play Console.

---

## PHASE 2 — AUDIT PHOTOS / VIDÉOS

### Fonctionnalités utilisant la galerie / médias

| Fonctionnalité | Rôle concerné | Fréquence | Nécessité métier | Technologie |
|---|---|---|---|---|
| **Avatar profil étudiant** | Étudiant | Une fois / rare | MOYENNE — identité sociale | `StudentProfileProvider.uploadAvatar()` → `community-media` bucket. Image sélectionnée via `image_picker` (photo picker intent) |
| **Stories communautaires** | Étudiant | Quotidienne | MOYENNE — engagement social | `CommunityStoriesBar` → `image_picker` pour photo/vidéo → `community-media` bucket |
| **Upload documents candidature** | Étudiant | Par candidature | HAUTE — processus admission | `FilePicker` (PDF/JPG/PNG/DOC) dans `StudentApplicationDetailScreen` et `StudentDossierDocumentsScreen` |
| **Capture vidéo Challenge TikTok** | Étudiant | Fréquente | HAUTE — core feature | `camera` package + `image_picker` pour import galerie |
| **Sauvegarde vidéo galerie** | Étudiant | Fréquente | MOYENNE — UX téléchargement | `saver_gallery` (`SaverGallery.saveVideo()`) dans `student_challenges_tab.dart` |
| **Scan sujet TD (OCR)** | Étudiant | Occasionnelle | MOYENNE — feature IA | `image_picker` pour photo sujet → Edge Function OCR |
| **Scan sujet Prépa Concours** | Étudiant | Occasionnelle | MOYENNE — feature IA | `image_picker` pour photo sujet → Edge Function OCR |
| **DM media (photos/fichiers)** | Étudiant | Fréquente | MOYENNE — messagerie | `image_picker` + `FilePicker` dans `student_dm_chat_screen.dart` |
| **Upload contenu admin** | Admin | Occasionnelle | HAUTE — gestion plateforme | `FilePicker` dans `admin_prep_upload_screen.dart`, `admin_td_upload_screen.dart`, etc. |
| **Hero vidéo / landing** | Admin | Rare | MOYENNE — marketing | `FilePicker` dans `admin_hero_video_encoder_screen.dart` |

### Répartition des usages par permission

- **READ_MEDIA_IMAGES** est utilisée pour : avatar, stories, documents candidature, scan OCR, DM media, upload admin
- **READ_MEDIA_VIDEO** est utilisée pour : stories vidéo, challenge import, sauvegarde galerie
- **WRITE_EXTERNAL_STORAGE** est utilisée pour : compression vidéo (`video_compress`), sauvegarde galerie legacy

---

## PHASE 3 — AUDIT DES PLUGINS

### Plugins injectant des permissions

| Plugin | Version | Permissions injectées | Permissions réellement utilisées | Ecart |
|---|---|---|---|---|
| `image_picker` / `image_picker_android` | 1.2.1 / 0.8.13+10 | Aucune directe ( utilise Photo Picker / Intent ) | Photo picker intent | ✅ Aligné |
| `file_picker` | 10.3.6 | Aucune directe ( utilise Intent GET_CONTENT ) | File picker intent | ✅ Aligné |
| `camera` / `camera_android` | 0.11.0 / 0.10.10+15 | `CAMERA`, `RECORD_AUDIO` | ✅ Capture vidéo + audio | ✅ Aligné |
| `video_compress` | 3.1.4 | `WRITE_EXTERNAL_STORAGE` | ✅ Compression vidéo temp | ✅ Aligné (legacy) |
| `record` / `record_android` | 6.1.2 / 1.5.1 | `RECORD_AUDIO` | ✅ Messages vocaux | ✅ Aligné |
| `saver_gallery` | 4.1.0 | Aucune directe | ✅ Sauvegarde galerie | ⚠️ Le plugin demande runtime WRITE sur <29 |
| `ar_flutter_plugin` | 0.7.3 | `CAMERA`, `ACCESS_FINE_LOCATION` | ❓ AR 3D — usage réel inconnu | ❌ **NON ALIGNÉ** — Location non justifiée |
| `ffmpeg_kit_flutter_new_audio` | 2.0.0 | Aucune | Aucune (commenté dans le code) | ✅ Aligné |
| `permission_handler` / `permission_handler_android` | 10.4.5 / 12.1.0 | Aucune (wrapper runtime uniquement) | Runtime permissions | ✅ Aligné |
| `firebase_messaging` | 16.1.2 | `POST_NOTIFICATIONS` implicite via FCM | ✅ Push notifications | ✅ Aligné |
| `flutter_local_notifications` | 18.0.1 | Aucune directe | ✅ Notifications locales | ✅ Aligné |

### Plugins présents dans pubspec.yaml mais ne demandant PAS de permissions sensibles

- `video_player` — lecture réseau uniquement
- `cached_network_image` — chargement HTTP
- `photo_view` — visualisation
- `story_view` — visualisation stories
- `share_plus` — partage via intents système
- `path_provider` — stockage interne app

---

## PHASE 4 — AUDIT PLAY STORE (Association Permission → Question)

### Demande 1 : « Autorisations liées aux photos et vidéos »

**Permissions déclenchant cette question :**
- `android.permission.READ_MEDIA_IMAGES` (Android 13+)
- `android.permission.READ_MEDIA_VIDEO` (Android 13+)
- `android.permission.WRITE_EXTERNAL_STORAGE` (legacy, mais liée au groupe médias)

**Pourquoi Google Play la demande :**
Ces 3 permissions sont classées dans la catégorie « Photos and videos » du Permission Declaration Form de Play Console. Dès qu'une seule est présente dans le manifest fusionné, Google Play exige une déclaration justifiant l'accès.

**Associtation exacte :**

| Permission Play Store | Permission AAB | Justification attendue |
|---|---|---|
| **Read access to photos and videos** | `READ_MEDIA_IMAGES` + `READ_MEDIA_VIDEO` | L'app lit des images/vidéos depuis la galerie pour : upload avatar, upload documents, stories, scan OCR, import challenge |
| **Write access to photos and videos** | `WRITE_EXTERNAL_STORAGE` (legacy) | L'app écrit des vidéos téléchargées dans la galerie utilisateur (SaverGallery) |

**Analyse de la justification actuelle :**
Le manifest explicite contient les commentaires :
- Ligne 3-4 : `<!-- Camera for image_picker (scanner TD, prep concours) -->` → CAMERA
- Ligne 7-8 : `<!-- Save downloaded videos to gallery -->` → READ_MEDIA_VIDEO

**Problème :** Le commentaire mentionne READ_MEDIA_VIDEO pour « Save downloaded videos to gallery », mais READ_MEDIA_VIDEO est une permission de **LECTURE**, pas d'écriture. L'écriture galerie se fait via `MediaStore` API (SaverGallery) qui ne nécessite pas WRITE_EXTERNAL_STORAGE sur Android 10+. La permission WRITE_EXTERNAL_STORAGE dans le manifest est donc **potentiellement superflue** pour l'usage déclaré.

### Demande 2 : « Déclaration du contenu de l'application » (App Content / UGC)

**Pourquoi Google Play la demande :**
L'app contient du **contenu généré par les utilisateurs (UGC)** visible par d'autres utilisateurs. Google Play exige une déclaration sur :
1. Type de contenu UGC présent
2. Mécanismes de signalement
3. Mécanismes de blocage
4. Processus de modération

**UGC détecté dans l'app :**

| Module | Type UGC | Visibilité | Modération | Signalement | Blocage |
|---|---|---|---|---|---|
| **Challenge TikTok** | Vidéos, commentaires | Public | ✅ Admin queue + auto | ✅ `report_content_sheet.dart` | ✅ `blockUser` |
| **Communautés** | Posts texte, images, polls | Groupe / Public | ✅ Admin + modérateurs | ✅ `report_community` RPC | ✅ Admin exclusion |
| **DM (Direct Messages)** | Texte, médias, audio | Privé (1-to-1) | — | ✅ Signalement contenu | — |
| **Stories** | Images, vidéos, texte | Groupe / Public | — | ✅ `report_content_sheet.dart` | ✅ `blockUser` |
| **Opportunités** | Publications, commentaires | Public | ✅ Admin | ✅ Signalement publication + commentaire | ✅ `blockUser` |
| **Marketplace** | Produits, avis | Public | ✅ Admin | ✅ Signalement produit + vendeur | ✅ Bloquer vendeur |
| **Lives (LiveKit)** | Audio/vidéo temps réel | Public / Groupe | ✅ Admin ban participant | ✅ Signalement | ✅ Admin ban |
| **Cours en ligne** | Contenu instructeur | Public | ✅ Admin validation | — | — |

**Conclusion UGC :** L'app contient UGC public dans au moins 6 modules distincts. Google Play demande cette déclaration car l'UGC public (vidéos challenge, posts opportunités, marketplace) est visible par tous les utilisateurs.

---

## PHASE 5 — RISQUE DE REJET

### Classification par permission / déclaration

| Élément | Risque | Justification |
|---|---|---|
| `READ_MEDIA_IMAGES` + `READ_MEDIA_VIDEO` | **ÉLEVÉ** | Pas de justification explicite dans Play Console liant ces permissions à un usage « core » indivisible. L'app pourrait utiliser le Photo Picker (Android 13+) sans ces permissions. |
| `WRITE_EXTERNAL_STORAGE` | **MOYEN** | Legacy permission. Sur Android 10+ (API 29+), `MediaStore` API ne la requiert plus. Sa présence peut être interprétée comme un signe de mauvaise pratique. |
| `ACCESS_FINE_LOCATION` (injectée AR plugin) | **CRITIQUE** | Permission sensible non déclarée explicitement, non justifiée dans le manifest, non mentionnée dans la privacy policy. Risque de rejet immédiat si Google Play la détecte sans justification. |
| Déclaration UGC (App Content) | **MOYEN** | Le système de modération existe (admin queues, signalement, blocage) mais la déclaration Play Console doit être remplie avec précision. Si mal remplie, risque de rejet. |
| `CAMERA` + `RECORD_AUDIO` | **FAIBLE** | Bien justifiées (capture vidéo, messages vocaux, scan). Risque faible si privacy policy à jour. |
| Notifications (FCM) | **FAIBLE** | Permissions standards, bien justifiées. |

### Risque global estimé
- **Si `ACCESS_FINE_LOCATION` est détectée sans justification : CRITIQUE** → Rejet probable
- **Si READ_MEDIA_* mal justifiées : ÉLEVÉ** → Suspension possible si Google considère l'usage non essentiel
- **Si UGC mal déclaré : MOYEN** → Retour avec demande de précisions

---

## PHASE 6 — PLAN DE RÉPONSE PLAY STORE (Sans modifier le code)

### 6.1 Réponse « Photos and videos »

**Question Play Console :**
> Why does your app need access to photos and videos?

**Réponse à sélectionner :**
- [x] **Core functionality** — The app needs access to photos/videos to provide its primary features.

**Justification textuelle (à copier dans Play Console) :**

```
Academia is an educational platform where students upload identity documents (passport, diplomas, CVs) for university applications, share study materials via communities, create video challenges for collaborative learning, and scan exercise sheets for AI tutoring. The READ_MEDIA_IMAGES and READ_MEDIA_VIDEO permissions are required because:

1. Document upload for university applications: Students must attach photos of identity documents, diplomas, and CVs (PDF, JPG, PNG) to their application files.
2. Community stories and posts: Students share photos and videos in study groups to collaborate on academic content.
3. AI scan correction (TD & Prep Concours): Students photograph exercise sheets and subjects for AI-powered OCR analysis and correction.
4. Video challenge studio: Students import existing videos from their gallery to edit and publish educational challenge content.
5. Profile avatar: Students select a profile photo from their gallery for their public profile.

The app does NOT use these permissions for advertising, data mining, or transferring media to third parties. All uploads go to the student's own authenticated storage bucket on Supabase.
```

**Pièces nécessaires :**
- Vidéo de démonstration (30-60s) montrant :
  1. Un étudiant ouvrant son dossier de candidature → bouton « Ajouter un document » → sélection photo depuis galerie
  2. Un étudiant dans une communauté → création d'une story avec photo
  3. Un étudiant dans le module TD → bouton « Scanner un exercice » → prise de photo
  4. Un étudiant dans le challenge → bouton « Importer depuis la galerie »

### 6.2 Réponse « App Content / UGC »

**Question Play Console :**
> Does your app contain user-generated content (UGC)?

**Réponse :**
- [x] **Yes**

**Type de contenu (à cocher) :**
- [x] Videos
- [x] Photos / Images
- [x] Text / Posts
- [x] Comments
- [x] Audio / Voice messages

**Modération (à cocher) :**
- [x] **Yes** — We have a moderation system in place.

**Justification textuelle :**

```
Academia contains user-generated content across 6 modules:

1. Challenge TikTok: Students publish educational videos publicly. Moderation: admin moderation queue, user reporting, automatic content flagging, user blocking, admin suspension.
2. Communities: Students post text, images, and polls in study groups. Moderation: community admins and moderators can delete posts, ban members. Users can report posts and groups.
3. Direct Messages: Private 1-to-1 messaging with text, images, audio. Users can report inappropriate content.
4. Stories: ephemeral photo/video/text content in communities. Users can delete their own stories. Reporting available.
5. Opportunities (social feed): public posts and comments. Moderation: admin queue, reporting, blocking.
6. Marketplace: product listings and reviews. Moderation: admin approval, reporting products and sellers, blocking sellers.

All UGC is tied to authenticated user accounts (Supabase auth). We maintain an admin_audit_log table tracking all moderation actions. Users can report content via a "Report" button (flag icon) available on every video, post, comment, product, and user profile. Users can block other users from their profile or content sheets.
```

**Pièces nécessaires :**
- Vidéo de démonstration (60-90s) montrant :
  1. Un étudiant publiant une vidéo challenge
  2. Un autre étudiant signalant la vidéo (bouton flag → choix motif → confirmation)
  3. Un étudiant bloquant un utilisateur (profil → bouton bloquer)
  4. L'admin ouvrant la queue de modération (`admin_moderation_screen.dart`) → traitement d'un signalement → suppression contenu / suspension utilisateur
  5. Montrer le `admin_audit_log` avec l'action de modération enregistrée

### 6.3 Réponse « Sensitive permissions » (si ACCESS_FINE_LOCATION détectée)

**Si Google Play demande justification pour `ACCESS_FINE_LOCATION` :**

```
The ACCESS_FINE_LOCATION permission is injected by the AR Flutter plugin (ar_flutter_plugin) used for the optional AR 3D feature in the scientific video studio. This feature allows students to place 3D educational models (molecules, geometric shapes) in their physical environment for educational video creation. Location is used ONLY to anchor AR objects in the real world via ARCore. No location data is collected, stored, or transmitted to our servers.
```

**Alternative (si l'AR n'est pas activement utilisé) :**
Demander la suppression de la permission via `<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" tools:node="remove" />` dans le manifest.

---

## ANNEXE — Fichiers sources audités

| Fichier | Lignes pertinentes | Usage média |
|---|---|---|
| `android/app/src/main/AndroidManifest.xml` | 1-18 | Permissions explicites |
| `pubspec.yaml` | 12-189 | Liste des plugins |
| `lib/features/student/tabs/student_challenges_tab.dart` | Import `saver_gallery`, `permission_handler` | Sauvegarde vidéos galerie |
| `lib/widgets/community_stories_bar.dart` | Import `image_picker` | Création stories photo/vidéo |
| `lib/providers/student_profile_provider.dart` | `uploadAvatar()` | Upload avatar |
| `lib/providers/community_stories_provider.dart` | `uploadStoryMedia()` | Upload media stories |
| `lib/features/student/student_dossier_documents_screen.dart` | `FilePicker.platform.pickFiles()` | Upload documents |
| `lib/features/student/student_application_detail_screen.dart` | `FilePicker.platform.pickFiles()` | Upload documents candidature |
| `lib/features/student/challenge_camera_capture_screen.dart` | Import `camera`, `image_picker` | Capture vidéo |
| `lib/features/student/student_challenge_video_editor_screen.dart` | Import `camera`, `file_picker`, `video_compress` | Édition vidéo |

---

*Fin du rapport. Aucune modification n'a été effectuée sur le code source.*
