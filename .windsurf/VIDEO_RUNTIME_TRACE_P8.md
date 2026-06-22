# AUDIT P8 – TRAÇAGE RÉEL DE LA VIDÉO LOCALE

**Date :** 19 Juin 2026  
**Objectif :** Instrumentation pour confirmer quel lecteur reçoit l'URL locale et si ExoPlayer parvient à ouvrir le fichier

---

## 1. INSTRUMENTATION AJOUTÉE

### 1.1 academia_playback_view.dart

#### Dans _init() (ligne 151)

```dart
debugPrint('[P8_INIT] url=$url isLocal=$isLocalFileUri');
```

**Objectif :** Confirmer l'URL reçue et si elle est détectée comme locale.

#### Dans build() (ligne 434)

```dart
debugPrint('[P8_BUILD] url=$url native=$_shouldUseNativeAndroid flutter=${!_shouldUseNativeAndroid}');
```

**Objectif :** Confirmer quel lecteur est utilisé (natif vs Flutter) pour l'URL donnée.

---

### 1.2 AcademiaAndroidVideoView.kt

#### Listener ExoPlayer (lignes 137-146)

```kotlin
// Add P8 listener for playback state and errors
player.addListener(object : Player.Listener {
    override fun onPlaybackStateChanged(state: Int) {
        Log.e("P8_NATIVE", "STATE=$state")
    }

    override fun onPlayerError(error: androidx.media3.common.PlaybackException) {
        Log.e("P8_NATIVE", "ERROR=${error.message}", error)
    }
})
```

**Objectif :** Capturer les changements d'état ExoPlayer et toute erreur.

**États possibles :**
- `STATE_IDLE` = 1
- `STATE_BUFFERING` = 2
- `STATE_READY` = 3
- `STATE_ENDED` = 4

#### Log setMediaItem initial (ligne 157)

```kotlin
Log.e("P8_NATIVE", "SET_MEDIA_ITEM url=$url")
```

**Objectif :** Confirmer que ExoPlayer reçoit l'URL.

#### Vérification existence fichier initial (lignes 160-163)

```kotlin
if (url.startsWith("file://")) {
    val path = android.net.Uri.parse(url).path
    Log.e("P8_NATIVE", "FILE_EXISTS=${java.io.File(path).exists()} path=$path")
}
```

**Objectif :** Vérifier si le fichier local existe physiquement.

#### Log setMediaItem dans setUrl (ligne 216)

```kotlin
Log.e("P8_NATIVE", "SET_MEDIA_ITEM (setUrl) url=$newUrl")
```

**Objectif :** Confirmer que ExoPlayer reçoit l'URL lors d'un changement via MethodChannel.

#### Vérification existence fichier dans setUrl (lignes 219-222)

```kotlin
if (newUrl.startsWith("file://")) {
    val path = android.net.Uri.parse(newUrl).path
    Log.e("P8_NATIVE", "FILE_EXISTS (setUrl)=${java.io.File(path).exists()} path=$path")
}
```

**Objectif :** Vérifier si le fichier local existe lors d'un changement d'URL.

---

## 2. LOGS ATTENDUS

### 2.1 Scénario normal (URL distante après upload)

```
[P8_INIT] url=https://... isLocal=false
[P8_BUILD] url=https://... native=true flutter=false
P8_NATIVE: SET_MEDIA_ITEM url=https://...
P8_NATIVE: STATE=2  (BUFFERING)
P8_NATIVE: STATE=3  (READY)
```

### 2.2 Scénario problème (URL locale avant upload)

#### Cas A : Flutter video_player utilisé (condition actuelle)

```
[P8_INIT] url=file:///data/.../cache/video.mp4 isLocal=true
[P8_BUILD] url=file:///data/.../cache/video.mp4 native=true flutter=false
```

**Note :** Aucun log P8_NATIVE car l'AndroidView est créée mais ExoPlayer ne reçoit pas l'URL (le code retourne dans _init() avant de créer le VideoPlayerController Flutter).

#### Cas B : Player natif utilisé (après correctif)

```
[P8_INIT] url=file:///data/.../cache/video.mp4 isLocal=true
[P8_BUILD] url=file:///data/.../cache/video.mp4 native=true flutter=false
P8_NATIVE: SET_MEDIA_ITEM url=file:///data/.../cache/video.mp4
P8_NATIVE: FILE_EXISTS=true path=/data/.../cache/video.mp4
P8_NATIVE: STATE=2  (BUFFERING)
P8_NATIVE: STATE=3  (READY)  ← Si succès
OU
P8_NATIVE: ERROR=...  ← Si échec
```

---

## 3. ÉTAT DU FICHHER LOCAL

Le log `FILE_EXISTS` indiquera :
- `true` si le fichier existe et est accessible
- `false` si le fichier n'existe pas ou n'est pas accessible

**Chemins attendus :**
- `/data/user/0/com.academia.nexiomgroup.app/cache/...` (cache temporaire)
- `/data/user/0/com.academia.nexiomgroup.app/files/...` (fichiers persistants)

---

## 4. PREMIÈRE ERREUR EXOPLAYER OBSERVÉE

Si ExoPlayer échoue à lire le fichier local, le listener capturera :

```
P8_NATIVE: ERROR=... stacktrace=...
```

**Erreurs possibles :**
- `Source error` : DataSource ne peut pas lire l'URI
- `Renderer error` : Décodeur ne peut pas décoder le codec
- `Unexpected runtime error` : Erreur inattendue

---

## 5. INSTRUCTIONS POUR TEST

1. **Compiler l'APK** avec les nouvelles instrumentations
2. **Installer sur device**
3. **Ouvrir logcat** avec filtre : `adb logcat | grep -E "P8_|P6_"`
4. **Sélectionner une vidéo locale** (galerie ou caméra)
5. **Observer les logs** :
   - `[P8_INIT]` → URL reçue par Flutter
   - `[P8_BUILD]` → Lecteur choisi
   - `P8_NATIVE: SET_MEDIA_ITEM` → URL reçue par ExoPlayer
   - `P8_NATIVE: FILE_EXISTS` → Existence du fichier
   - `P8_NATIVE: STATE` → État ExoPlayer
   - `P8_NATIVE: ERROR` → Erreur ExoPlayer (si applicable)

---

## 6. RÉSULTATS ATTENDUS

### Si l'hypothèse P7 est correcte :

```
[P8_INIT] url=file:///... isLocal=true
[P8_BUILD] url=file:///... native=true flutter=false
```

**Aucun log P8_NATIVE** car l'AndroidView est créée mais ExoPlayer n'est jamais initialisé avec l'URL locale (le code Flutter retourne dans _init() avant).

### Si le correctif P7 Solution 1 est appliqué :

```
[P8_INIT] url=file:///... isLocal=true
[P8_BUILD] url=file:///... native=true flutter=false
P8_NATIVE: SET_MEDIA_ITEM url=file:///...
P8_NATIVE: FILE_EXISTS=true path=/data/...
P8_NATIVE: STATE=2
P8_NATIVE: STATE=3
```

**Vidéo visible** si ExoPlayer peut lire le fichier.

### Si ExoPlayer ne peut pas lire file:// :

```
[P8_INIT] url=file:///... isLocal=true
[P8_BUILD] url=file:///... native=true flutter=false
P8_NATIVE: SET_MEDIA_ITEM url=file:///...
P8_NATIVE: FILE_EXISTS=true path=/data/...
P8_NATIVE: ERROR=Source error: ...
```

**Nécessite Solution 2 (correction DataSource).**

---

## 7. PROCHAINES ÉTAPES

1. **Compiler et tester** pour obtenir les logs réels
2. **Analyser les logs** pour confirmer l'hypothèse
3. **Appliquer le correctif approprié** (Solution 1, 2 ou 3)
4. **Retester** pour confirmer la résolution
5. **Retirer les logs P8** une fois le problème résolu

---

## 8. MODIFICATIONS CODE

### academia_playback_view.dart
- **Ligne 151** : Ajout `debugPrint('[P8_INIT] ...')`
- **Ligne 434** : Ajout `debugPrint('[P8_BUILD] ...')`

### AcademiaAndroidVideoView.kt
- **Lignes 137-146** : Ajout listener ExoPlayer avec logs
- **Ligne 157** : Ajout `Log.e("P8_NATIVE", "SET_MEDIA_ITEM ...")`
- **Lignes 160-163** : Ajout vérification existence fichier
- **Ligne 216** : Ajout `Log.e("P8_NATIVE", "SET_MEDIA_ITEM (setUrl) ...")`
- **Lignes 219-222** : Ajout vérification existence fichier dans setUrl

---

**Statut :** Instrumentation ajoutée, en attente de test runtime
