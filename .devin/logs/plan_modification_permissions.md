# PLAN DE MODIFICATION — RETRAIT PERMISSIONS PLAY STORE

## Date
2026-06-04

## Fichiers concernés
1. `academia_app/android/app/src/main/AndroidManifest.xml` (manifest principal)
2. `academia_app/android/app/build.gradle.kts` (pas de modification, mais snapshot préventif)

## Snapshots créés
- `.windsurf/logs/AndroidManifest.xml.snapshot.before`
- `.windsurf/logs/build.gradle.kts.snapshot.before`
- `.windsurf/logs/snapshot_timestamp.txt`

## Modifications prévues

### 1. AndroidManifest.xml principal

**Action A — Ajouter namespace `tools`**
- Ligne 1 : remplacer `<manifest xmlns:android="http://schemas.android.com/apk/res/android">` par `<manifest xmlns:android="http://schemas.android.com/apk/res/android" xmlns:tools="http://schemas.android.com/tools">`

**Action B — Supprimer READ_MEDIA_VIDEO**
- Supprimer la ligne 8 : `<uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>`

**Action C — Supprimer READ_MEDIA_IMAGES**
- Supprimer la ligne 9 : `<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>`

**Action D — Bloquer ACCESS_FINE_LOCATION injectée par plugin**
- Ajouter juste après les permissions principales (après la ligne 10, ou à la place des lignes supprimées) :
  ```xml
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" tools:node="remove"/>
  ```
  Cela empêche le manifest merger d'intégrer la permission injectée par `ar_flutter_plugin`.

### 2. Autres manifests
- Debug (`android/app/src/debug/AndroidManifest.xml`) : aucune modification (seulement INTERNET).
- Profile (`android/app/src/profile/AndroidManifest.xml`) : aucune modification (seulement INTERNET).
- Plugin manifests (pub cache) : **non modifiés** — on les bloque côté app via `tools:node="remove"`.

### 3. build.gradle.kts
- Aucune modification requise pour le retrait des permissions.
- Le build release actuel (`isMinifyEnabled = true`, `isShrinkResources = true`) est conservé tel quel.

## Validation post-modification
- Build AAB avec `flutter build appbundle`.
- Extraire le manifest de l'AAB (`base/manifest/AndroidManifest.xml`) et vérifier l'absence des 3 permissions.
- Confirmer la présence de CAMERA, RECORD_AUDIO, POST_NOTIFICATIONS, INTERNET.
