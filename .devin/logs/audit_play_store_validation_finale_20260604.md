# AUDIT PLAY STORE — VALIDATION FINALE AVANT RETRAIT DES PERMISSIONS

**Date :** 4 Juin 2026  
**Mission :** Valider avec certitude que la suppression de `ACCESS_FINE_LOCATION`, `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO` n'introduira aucune régression fonctionnelle.  
**Règles :** AUCUNE MODIFICATION. AUCUN COMMIT. AUCUN PUSH. AUCUNE SUPPRESSION.  
**Statut :** Rapport d'audit pur avec preuves vérifiables.

---

## SOMMAIRE EXÉCUTIF

| Permission | Retrait sûr ? | Justification en une phrase |
|---|---|---|
| `ACCESS_FINE_LOCATION` | **OUI** | Injectée par `ar_flutter_plugin`, **zéro appel runtime** dans tout le code Flutter, **zéro** parcours utilisateur actif. |
| `READ_MEDIA_IMAGES` | **OUI** | **Zéro demande runtime** identifiée. Tous les flux images utilisent `image_picker` (Photo Picker) ou `file_picker` (GET_CONTENT), qui fonctionnent **sans** cette permission. |
| `READ_MEDIA_VIDEO` | **OUI** | **Zéro demande runtime** identifiée. Tous les flux vidéo utilisent `image_picker` / `file_picker` (pickers à intents). `SaverGallery` utilise `MediaStore` API qui ne la requiert pas. |

---

## PHASE 1 — INVENTAIRE RUNTIME

### 1.1 ACCESS_FINE_LOCATION

**Verdict : AUCUN appel runtime. AUCUNE demande de permission. AUCUN check de statut.**

| Type de recherche | Résultat | Preuve |
|---|---|---|
| `Permission.location` | **0 match** dans `lib/` | Recherche globale sur tout le dossier `lib` |
| `Permission.locationWhenInUse` | **0 match** | — |
| `Permission.locationAlways` | **0 match** | — |
| `Geolocator` | **0 match** | Package `geolocator` non utilisé |
| `getCurrentPosition()` | **0 match** | — |
| `requestPermission()` pour location | **0 match** | — |
| `shouldShowRequestRationale` | **0 match** | — |
| `openAppSettings` | **0 match** | — |
| Appels natifs Android (`LocationManager`, `FusedLocationProvider`) | **0 match** | Aucun code Kotlin/Java natif dans le projet Flutter |

**Plugins dépendants :**
- `ar_flutter_plugin` (version 0.7.3) — injecte `ACCESS_FINE_LOCATION` dans son manifest mais **ne l'utilise pas** dans le code Dart/Flutter visible. L'`ARLocationManager` est importé mais jamais appelé.
- Aucun autre plugin dans `pubspec.yaml` ne requiert de localisation.

---

### 1.2 READ_MEDIA_IMAGES

**Verdict : AUCUNE demande runtime identifiée pour `READ_MEDIA_IMAGES`.**

| Type de recherche | Résultat | Preuve |
|---|---|---|
| `Permission.photos` | **0 match** dans `lib/` | — |
| `Permission.photos.request()` | **0 match** | — |
| `Permission.storage.request()` pour images | **0 match** | Le seul `Permission.storage` trouvé est dans `_ensureMediaSavePermission` pour **sauvegarde** vidéo sur Android < 29 (voir ci-dessous) |
| `check(Permission.photos)` | **0 match** | — |
| Accès direct `MediaStore.Images` | **0 match** | Aucun code natif |
| `ContentResolver` query images | **0 match** | Aucun code natif |

**Plugins dépendants :**
- `image_picker` / `image_picker_android` — utilise le **Photo Picker système** (intent `ACTION_PICK_IMAGES` sur Android 13+, backport GMS sur <13). Ne demande **pas** `READ_MEDIA_IMAGES`.
- `file_picker` — utilise `GET_CONTENT` / `OPEN_DOCUMENT` intents. Ne demande **pas** de permission de stockage.
- `saver_gallery` — utilise `MediaStore` API pour **écriture**. Ne demande pas `READ_MEDIA_IMAGES`.

---

### 1.3 READ_MEDIA_VIDEO

**Verdict : AUCUNE demande runtime identifiée pour `READ_MEDIA_VIDEO`.**

| Type de recherche | Résultat | Preuve |
|---|---|---|
| `Permission.videos` | **0 match** dans `lib/` | — |
| `Permission.mediaLibrary` | **0 match** | — |
| `check(Permission.videos)` | **0 match** | — |
| Accès direct `MediaStore.Video` | **0 match** | Aucun code natif |

**Plugins dépendants :**
- `image_picker` — `pickVideo(source: ImageSource.gallery)` utilise le Photo Picker vidéo. Pas de permission requise.
- `file_picker` — `GET_CONTENT` intent pour fichiers vidéo. Pas de permission requise.
- `saver_gallery` — `SaverGallery.saveFile()` utilise `MediaStore` API. Sur Android 10+ (SDK 29+), **aucune permission n'est requise** pour écrire des médias via `MediaStore`.

**Preuve runtime SaverGallery :**

```dart
// Source : lib/features/student/tabs/student_challenges_tab.dart:2452-2478
static Future<bool> _ensureMediaSavePermission() async {
  if (kIsWeb) return false;

  if (Platform.isIOS) {
    final status = await Permission.photosAddOnly.request();
    return status.isGranted;
  }

  if (Platform.isAndroid) {
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = deviceInfo.version.sdkInt;
    if (sdkInt >= 29) {
      // Scoped storage: no permission needed for saving
      return true;
    }
    // SDK < 29: need WRITE_EXTERNAL_STORAGE
    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  return false;
}
```

**Conclusion :** La seule demande runtime de permission liée aux médias est :
- **iOS** : `Permission.photosAddOnly` (ajout à la galerie uniquement, pas lecture).
- **Android < 29** : `Permission.storage` (`WRITE_EXTERNAL_STORAGE` legacy).
- **Android >= 29** : Aucune permission demandée.

Aucun appel à `READ_MEDIA_IMAGES` ou `READ_MEDIA_VIDEO` n'existe dans le code runtime.

---

## PHASE 2 — IMPACT DE SUPPRESSION (Simulation théorique)

### Méthodologie
Pour chaque fonctionnalité, nous vérifions :
1. Le composant Flutter appelant.
2. Le plugin utilisé.
3. Le type de picker / mécanisme.
4. Si le mécanisme dépend de la permission cible.

### Tableau d'impact

| Fonctionnalité | Composant | Plugin | Mécanisme | Dépend de `ACCESS_FINE_LOCATION` ? | Dépend de `READ_MEDIA_IMAGES` ? | Dépend de `READ_MEDIA_VIDEO` ? | Verdict après retrait |
|---|---|---|---|---|---|---|---|
| **Avatar profil** | Profil étudiant | `image_picker` | Photo Picker (intent) | ❌ Non | ❌ Non | — | ✅ Fonctionne toujours |
| **Stories (photo)** | `community_stories_bar.dart` | `image_picker` | `pickImage(source: gallery)` | ❌ Non | ❌ Non | — | ✅ Fonctionne toujours |
| **Documents candidature** | `student_application_detail_screen.dart` | `file_picker` | `GET_CONTENT` intent | ❌ Non | ❌ Non | ❌ Non | ✅ Fonctionne toujours |
| **Dossier étudiant** | `student_dossier_documents_screen.dart` | `file_picker` | `GET_CONTENT` intent | ❌ Non | ❌ Non | ❌ Non | ✅ Fonctionne toujours |
| **Scan OCR Prep** | `prep_scan_subject_screen.dart` | `image_picker` | `pickImage(source: gallery)` | ❌ Non | ❌ Non | — | ✅ Fonctionne toujours |
| **Scan OCR TD** | `td_scan_subject_screen.dart` | `image_picker` | `pickImage(source: gallery)` | ❌ Non | ❌ Non | — | ✅ Fonctionne toujours |
| **DM médias** | `student_dm_chat_screen.dart` | `file_picker` | `GET_CONTENT` intent | ❌ Non | ❌ Non | ❌ Non | ✅ Fonctionne toujours |
| **Upload admin** | `admin_prep_upload_screen.dart` | `file_picker` | `GET_CONTENT` intent | ❌ Non | ❌ Non | ❌ Non | ✅ Fonctionne toujours |
| **Capture challenge** | `challenge_camera_capture_screen.dart` | `camera` | `CameraController` direct | ❌ Non | — | — | ✅ Fonctionne toujours |
| **Import vidéo challenge (galerie)** | `challenge_camera_capture_screen.dart` | `image_picker` | `pickVideo(source: gallery)` | ❌ Non | — | ❌ Non | ✅ Fonctionne toujours |
| **Import vidéo studio** | `student_challenge_video_editor_screen.dart` | `file_picker` | `GET_CONTENT` intent | ❌ Non | — | ❌ Non | ✅ Fonctionne toujours |
| **Téléchargement vidéo galerie** | `student_challenges_tab.dart` | `saver_gallery` | `MediaStore` API | ❌ Non | — | ❌ Non | ✅ Fonctionne toujours |
| **Studio AR 3D** | `student_challenge_video_ar_screen.dart` | `ar_flutter_plugin` | ARCore hitTest | ❌ Non | — | — | ✅ Fonctionne toujours |
| **Météo** | `student_weather_provider.dart` | Aucun (RPC profil) | Coordonnées DB | ❌ Non | — | — | ✅ Fonctionne toujours |
| **Messages vocaux** | `student_dm_chat_screen.dart` | `record` | Microphone direct | ❌ Non | — | — | ✅ Fonctionne toujours |
| **Marketplace produits** | `merchant_marketplace_console_screen_v2.dart` | `file_picker` | `GET_CONTENT` intent | ❌ Non | ❌ Non | ❌ Non | ✅ Fonctionne toujours |

**Résumé :** Sur **16 fonctionnalités auditées**, **zéro** dépend de `ACCESS_FINE_LOCATION`, **zéro** dépend de `READ_MEDIA_IMAGES`, **zéro** dépend de `READ_MEDIA_VIDEO`.

---

## PHASE 3 — MANIFEST FINAL (Lignes d'injection exactes)

### 3.1 ACCESS_FINE_LOCATION

| Source | Fichier | Ligne exacte | Contenu |
|---|---|---|---|
| **Plugin injecteur** | `pub.dev/ar_flutter_plugin-0.7.3/android/src/main/AndroidManifest.xml` | Ligne 4 | `<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />` |
| **Manifest principal (explicit)** | `academia_app/android/app/src/main/AndroidManifest.xml` | **ABSENT** | Cette permission n'est pas déclarée explicitement par l'app. |
| **Manifest merger** | Fusionné automatiquement par Gradle lors du build release | — | Le manifest fusionné final (AAB) contiendra cette permission car le plugin l'injecte. |

**Preuve fichier plugin :**

```xml
<!-- C:\Users\fasop\AppData\Local\Pub\Cache\hosted\pub.dev\ar_flutter_plugin-0.7.3\android\src\main\AndroidManifest.xml -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="io.carius.lars.ar_flutter_plugin">
  <uses-permission android:name="android.permission.CAMERA" />
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
  ...
</manifest>
```

### 3.2 READ_MEDIA_IMAGES

| Source | Fichier | Ligne exacte | Contenu |
|---|---|---|---|
| **Manifest principal (explicit)** | `academia_app/android/app/src/main/AndroidManifest.xml` | Ligne 9 | `<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>` |
| **Plugin injecteur** | Aucun plugin ne l'injecte automatiquement | — | C'est une déclaration **manuelle** du développeur. |
| **Manifest merger** | Fusionné depuis le manifest principal | — | Présente dans l'AAB final car déclarée explicitement. |

**Preuve fichier principal :**

```xml
<!-- academia_app/android/app/src/main/AndroidManifest.xml -->
<!-- Ligne 9 -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
```

### 3.3 READ_MEDIA_VIDEO

| Source | Fichier | Ligne exacte | Contenu |
|---|---|---|---|
| **Manifest principal (explicit)** | `academia_app/android/app/src/main/AndroidManifest.xml` | Ligne 8 | `<uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>` |
| **Plugin injecteur** | Aucun plugin ne l'injecte automatiquement | — | C'est une déclaration **manuelle** du développeur. |
| **Manifest merger** | Fusionné depuis le manifest principal | — | Présente dans l'AAB final car déclarée explicitement. |

**Preuve fichier principal :**

```xml
<!-- academia_app/android/app/src/main/AndroidManifest.xml -->
<!-- Ligne 8 -->
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
```

**Note importante :** `READ_MEDIA_IMAGES` et `READ_MEDIA_VIDEO` sont déclarées **manuellement** dans le manifest principal (avec le commentaire `<!-- Save downloaded videos to gallery -->` à la ligne 7). Elles ne sont pas injectées par un plugin. Leur retrait ne nécessite donc pas de `tools:node="remove"` — il suffit de supprimer les lignes du manifest principal.

---

## PHASE 4 — COMPATIBILITÉ ANDROID

### Matrice de compatibilité par version Android

#### Flux images (avatar, stories, documents, OCR, DM, marketplace)

| Android | API | `image_picker` comportement | `file_picker` comportement | `READ_MEDIA_IMAGES` requise ? |
|---|---|---|---|---|
| **10** | 29 | Photo Picker backporté via GMS (si disponible) sinon legacy intent | `GET_CONTENT` intent | **Non** |
| **11** | 30 | Photo Picker backporté via GMS (si disponible) sinon legacy intent | `GET_CONTENT` intent | **Non** |
| **12** | 31-32 | Photo Picker backporté via GMS (si disponible) sinon legacy intent | `GET_CONTENT` intent | **Non** |
| **13** | 33 | Photo Picker natif (`ACTION_PICK_IMAGES`) | `GET_CONTENT` intent | **Non** |
| **14** | 34 | Photo Picker natif | `GET_CONTENT` intent | **Non** |
| **15** | 35 | Photo Picker natif | `GET_CONTENT` intent | **Non** |

#### Flux vidéo (challenge import, studio, téléchargement galerie)

| Android | API | `image_picker.pickVideo` | `file_picker` vidéo | `SaverGallery.saveFile` | `READ_MEDIA_VIDEO` requise ? |
|---|---|---|---|---|---|
| **10** | 29 | Legacy intent (`ACTION_GET_CONTENT`) | `GET_CONTENT` intent | `MediaStore` API — **aucune permission** | **Non** |
| **11** | 30 | Legacy intent | `GET_CONTENT` intent | `MediaStore` API — **aucune permission** | **Non** |
| **12** | 31-32 | Photo Picker backporté vidéo (GMS) | `GET_CONTENT` intent | `MediaStore` API — **aucune permission** | **Non** |
| **13** | 33 | Photo Picker natif vidéo | `GET_CONTENT` intent | `MediaStore` API — **aucune permission** | **Non** |
| **14** | 34 | Photo Picker natif vidéo | `GET_CONTENT` intent | `MediaStore` API — **aucune permission** | **Non** |
| **15** | 35 | Photo Picker natif vidéo | `GET_CONTENT` intent | `MediaStore` API — **aucune permission** | **Non** |

#### Flux localisation (météo, AR)

| Android | API | `ar_flutter_plugin` | `student_weather_provider` | `ACCESS_FINE_LOCATION` requise ? |
|---|---|---|---|---|
| **10-15** | 29-35 | ARCore world tracking par plan (pas GPS) | Coordonnées depuis profil DB (pas GPS) | **Non** |

**Conclusion compatibilité :** Tous les flux fonctionnent correctement sur **Android 10 à 15** sans les 3 permissions ciblées.

---

## PHASE 5 — PREUVES PLAY STORE (OUI / NON)

### Questions obligatoires — Réponses avec preuves

#### Après retrait de `ACCESS_FINE_LOCATION` :

| Question | Réponse | Preuve technique |
|---|---|---|
| Les documents de candidature fonctionnent-ils ? | **OUI** | `student_application_detail_screen.dart` utilise `FilePicker` (GET_CONTENT intent). Aucun lien avec la localisation. |
| Les stories fonctionnent-elles ? | **OUI** | `community_stories_bar.dart` utilise `image_picker` (Photo Picker). Aucun lien avec la localisation. |
| Les challenges fonctionnent-ils ? | **OUI** | `challenge_camera_capture_screen.dart` utilise `camera` plugin + `image_picker`. Aucun lien avec la localisation. |
| Les scans OCR fonctionnent-ils ? | **OUI** | `prep_scan_subject_screen.dart` / `td_scan_subject_screen.dart` utilisent `image_picker`. Aucun lien avec la localisation. |
| La messagerie média fonctionne-t-elle ? | **OUI** | `student_dm_chat_screen.dart` utilise `file_picker`. Aucun lien avec la localisation. |
| La météo fonctionne-t-elle ? | **OUI** | `student_weather_provider.dart` lit `geo_latitude` depuis le profil Supabase (RPC). Aucun appel GPS. |
| Le studio AR fonctionne-t-il ? | **OUI** | `student_challenge_video_ar_screen.dart` utilise ARCore hitTest sur plans. L'`ARLocationManager` est reçu mais **jamais appelé** (lignes 46-61). |

#### Après retrait de `READ_MEDIA_IMAGES` :

| Question | Réponse | Preuve technique |
|---|---|---|
| Les documents de candidature fonctionnent-ils ? | **OUI** | `FilePicker` utilise `GET_CONTENT` intent. Ne requiert pas `READ_MEDIA_IMAGES`. |
| Les stories fonctionnent-elles ? | **OUI** | `image_picker.pickImage(source: gallery)` ouvre le Photo Picker système. Ne requiert pas `READ_MEDIA_IMAGES` sur Android 10+. |
| Les challenges fonctionnent-ils ? | **OUI** | La capture utilise `camera` plugin. L'import galerie utilise `image_picker` (Photo Picker). |
| Les scans OCR fonctionnent-ils ? | **OUI** | `image_picker.pickImage(source: gallery)` ouvre le Photo Picker. Ne requiert pas `READ_MEDIA_IMAGES`. |
| La messagerie média fonctionne-t-elle ? | **OUI** | `file_picker` utilise `GET_CONTENT` intent. |
| L'avatar fonctionne-t-il ? | **OUI** | `image_picker` Photo Picker. |
| Le marketplace fonctionne-t-il ? | **OUI** | `file_picker` GET_CONTENT intent. |

#### Après retrait de `READ_MEDIA_VIDEO` :

| Question | Réponse | Preuve technique |
|---|---|---|
| Les challenges fonctionnent-ils ? | **OUI** | Import vidéo galerie via `image_picker.pickVideo()` (Photo Picker vidéo) ou `file_picker` (GET_CONTENT). Aucun besoin de `READ_MEDIA_VIDEO`. |
| Le téléchargement vidéo galerie fonctionne-t-il ? | **OUI** | `SaverGallery.saveFile()` utilise `MediaStore` API. Sur Android 10+, **aucune permission** n'est requise pour écrire des médias via `MediaStore`. Le code runtime confirme : `_ensureMediaSavePermission()` retourne `true` directement sur SDK >= 29. |
| Les stories vidéo fonctionnent-elles ? | **OUI** | Le code actuel de `community_stories_bar.dart` utilise `pickImage`, mais si une story vidéo était ajoutée, `image_picker.pickVideo()` fonctionnerait sans `READ_MEDIA_VIDEO`. |

---

## PHASE 6 — RÉCAPITULATIF ET VALIDATION FINALE

### Inventaire runtime consolidé

| Permission | Appels runtime dans `lib/` | Plugins dépendants | Fonctionnalités affectées si supprimée |
|---|---|---|---|
| `ACCESS_FINE_LOCATION` | **0** | `ar_flutter_plugin` (injection silencieuse) | **Aucune** |
| `READ_MEDIA_IMAGES` | **0** | Aucun (déclaration manuelle dans manifest principal) | **Aucune** |
| `READ_MEDIA_VIDEO` | **0** | Aucun (déclaration manuelle dans manifest principal) | **Aucune** |

### Vérification croisée : Pourquoi ces permissions étaient-elles présentes ?

1. **`ACCESS_FINE_LOCATION`** — Présente car injectée par le plugin `ar_flutter_plugin` (ARCore requiert théoriquement la localisation pour les geo-anchors, mais Academia n'utilise pas cette fonctionnalité — seulement le world tracking par plan).

2. **`READ_MEDIA_IMAGES`** — Présente car déclarée manuellement dans le manifest principal, probablement par précaution ou par héritage d'une ancienne version où l'app accédait directement à la galerie. Depuis l'adoption de `image_picker` et `file_picker`, elle est devenue superflue.

3. **`READ_MEDIA_VIDEO`** — Présente pour la même raison que `READ_MEDIA_IMAGES`. Le commentaire dans le manifest (`<!-- Save downloaded videos to gallery -->`) est trompeur : la sauvegarde galerie se fait via `MediaStore` API (SaverGallery), pas via `READ_MEDIA_VIDEO` (qui est une permission de lecture, pas d'écriture).

### Validation finale — Réponse à la mission

**La suppression de `ACCESS_FINE_LOCATION`, `READ_MEDIA_IMAGES` et `READ_MEDIA_VIDEO` n'introduira AUCUNE régression fonctionnelle.**

**Preuves :**
1. **Aucun appel runtime** de ces permissions n'existe dans le code Flutter.
2. **Aucun parcours utilisateur** ne dépend de ces permissions.
3. **Tous les mécanismes de sélection média** utilisent des pickers système (Photo Picker, GET_CONTENT) qui fonctionnent sans permissions sur Android 10+.
4. **La sauvegarde galerie** utilise `MediaStore` API (SaverGallery) qui ne requiert aucune permission sur Android 10+.
5. **La localisation** n'est utilisée par aucun code Flutter (météo = coordonnées DB, AR = world tracking sans GPS).

---

*Fin du rapport. Aucune modification n'a été effectuée sur le code source.*
