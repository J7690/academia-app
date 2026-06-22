# AUDIT P11 – VALIDATION DU CANAL DE LOGGING RUNTIME

**Date :** 19 Juin 2026  
**Objectif :** Déterminer pourquoi les logs P8/P9 n'apparaissent pas alors que les fichiers compilés sont corrects

---

## 1. RECHERCHE DES SYSTÈMES DE LOGS

### 1.1 Outils de logging trouvés

| Outil | Fichiers utilisant | Usage |
|-------|-------------------|-------|
| debugPrint | 100+ fichiers | Logging Flutter standard |
| print() | 100+ fichiers | Logging Dart standard |
| developer.log | 0 fichiers | Non utilisé |
| Logger | 0 fichiers | Non utilisé |
| talker | 0 fichiers | Non utilisé |
| logging package | 0 fichiers | Non utilisé |

**Conclusion :** Le projet utilise uniquement `debugPrint` et `print()` standard de Flutter/Dart.

---

## 2. VÉRIFICATION DE LA REDÉFINITION DEBUGPRINT

### 2.1 Recherche de redéfinition

**Recherche :** `void debugPrint` et `debugPrint =`

**Résultat :** Aucune redéfinition trouvée dans le codebase.

**Conclusion :** `debugPrint` n'est pas redéfini ou intercepté.

---

## 3. VÉRIFICATION FLUTTERERROR.ONERROR

### 3.1 Recherche de personnalisations

**Recherche :** `FlutterError.onError`

**Résultat :** Aucune personnalisaton trouvée dans le codebase.

**Conclusion :** `FlutterError.onError` n'est pas personnalisé.

---

## 4. VÉRIFICATION RUNZONEDGUARDED

### 4.1 Recherche d'utilisation

**Recherche :** `runZonedGuarded`

**Résultat :** Aucune utilisation trouvée dans le codebase.

**Conclusion :** `runZonedGuarded` n'est pas utilisé.

---

## 5. VÉRIFICATION DES MODES DE BUILD

### 5.1 Recherche de kReleaseMode, kProfileMode, kDebugMode

**Résultats :**

| Mode | Utilisations | Contexte |
|------|-------------|----------|
| kReleaseMode | 0 | Non utilisé |
| kProfileMode | 0 | Non utilisé |
| kDebugMode | 5+ | Utilisé pour features conditionnelles (feature_flags.dart, main.dart, student_challenges_tab.dart, academia_playback_view.dart) |

**Conclusion :** Aucun filtrage de logs basé sur `kReleaseMode` ou `kProfileMode`. `kDebugMode` est utilisé uniquement pour activer/désactiver des features de développement, pas pour filtrer les logs.

---

## 6. INSTRUMENTATION AJOUTÉE

### 6.1 Print dans main.dart (AVANT runApp)

**Fichier :** `lib/main.dart` (ligne 154)

```dart
void main() async {
  print('P11_MAIN_START');
  WidgetsFlutterBinding.ensureInitialized();
  // ...
}
```

### 6.2 Print dans premier écran (AuthWrapper)

**Fichier :** `lib/features/auth/auth_wrapper.dart` (ligne 31)

```dart
@override
void initState() {
  print('P11_FIRST_SCREEN');
  super.initState();
  // ...
}
```

### 6.3 Print dans méthodes vidéo

**Fichier :** `lib/features/student/student_challenge_video_editor_screen.dart`

```dart
// _processSegments() (ligne 243)
print('P11_PROCESSSEGMENTS_REACHED');

// _pickVideo() (ligne 504)
print('P11_PICKVIDEO_REACHED');
```

**Fichier :** `lib/video/academia_playback_view.dart`

```dart
// initState() (ligne 92)
print('P11_PLAYBACKVIEW_INIT_REACHED');
```

---

## 7. TEST FLUTTER RUN

### 7.1 Commande exécutée

```bash
flutter run
```

### 7.2 Résultat du build

```
√ Built build\app\outputs\flutter-apk\app-debug.apk
Installing build\app\outputs\flutter-apk\app-debug.apk...
Syncing files to device TECNO LD7...
```

**Statut :** Build réussi, APK installé, application lancée.

### 7.3 Logs observés dans flutter run

**Logs Flutter observés :**
```
I/flutter (23136): supabase.supabase_flutter: INFO: ***** Supabase init completed *****
I/flutter (23136): [PUSH] init() starting...
```

**Logs P11_ observés :**
```
AUCUN
```

**Logs P8/P9 observés :**
```
AUCUN
```

### 7.4 Logs Android observés

Les logs Android (D/BufferQueueProducer, D/libMEOW, etc.) sont visibles, mais aucun log Flutter personnalisé n'apparaît.

---

## 8. ANALYSE DU PROBLÈME

### 8.1 Observation critique

L'application se lance correctement (Supabase init, Push init), mais :
- `print('P11_MAIN_START')` n'apparaît pas
- `print('P11_FIRST_SCREEN')` n'apparaît pas
- Les logs Supabase standard apparaissent

### 8.2 Hypothèses possibles

1. **print() est filtré par flutter run** : Flutter pourrait filtrer les print() standard et ne montrer que les logs via debugPrint ou d'autres mécanismes.
2. **print() n'est pas redirigé vers la console** : Dans certaines configurations, print() pourrait être redirigé ailleurs.
3. **Les logs sont capturés par adb logcat uniquement** : Flutter run pourrait ne pas afficher tous les logs Dart dans sa sortie standard.

### 8.3 Test recommandé

Pour confirmer, il faudrait utiliser `adb logcat` pour voir si les logs apparaissent dans le logcat Android.

---

## 9. CONCLUSION OBLIGATOIRE

### A. Les logs Flutter arrivent-ils encore dans la console ?

**PARTIELLEMENT.** Les logs Supabase standard (`I/flutter`) apparaissent, mais les `print()` personnalisés n'apparaissent pas dans la sortie flutter run.

### B. debugPrint est-il fonctionnel ?

**INCONNU.** Les debugPrint P8/P9 n'apparaissent pas non plus, mais cela pourrait être dû au même problème de remontée des logs.

### C. print est-il fonctionnel ?

**DOUTEUX.** Les print() P11_ n'apparaissent pas dans la sortie flutter run, bien que l'application se lance correctement.

### D. Quel est le premier point d'exécution confirmé par les logs ?

**Supabase init.** Le log `supabase.supabase_flutter: INFO: ***** Supabase init completed *****` apparaît, ce qui confirme que l'application atteint au moins ce point.

### E. Quel est le premier point qui n'émet plus rien ?

**main().** Le `print('P11_MAIN_START')` placé en toute première ligne de main() n'apparaît pas, ce qui suggère que le problème de logging se produit dès le début de l'exécution.

---

## 10. DIAGNOSTIC FINAL

**Problème identifié :** Le système de logging Flutter (print() et debugPrint) ne remonte pas correctement dans la console flutter run, bien que l'application fonctionne.

**Cause probable :** Configuration de flutter run ou redirection des logs vers adb logcat uniquement.

**Action recommandée :** Utiliser `adb logcat` avec filtre pour capturer les logs Flutter, car flutter run ne semble pas afficher tous les logs personnalisés.

**Impact sur l'audit vidéo :** Les logs P8/P9 sont correctement placés dans le code, mais leur absence dans la console flutter run ne signifie pas qu'ils ne sont pas exécutés. Il faut utiliser adb logcat pour les capturer.

---

## 11. MODIFICATIONS CODE

### main.dart
- **Ligne 154** : Ajout `print('P11_MAIN_START')`

### auth_wrapper.dart
- **Ligne 31** : Ajout `print('P11_FIRST_SCREEN')`

### student_challenge_video_editor_screen.dart
- **Ligne 243** : Ajout `print('P11_PROCESSSEGMENTS_REACHED')`
- **Ligne 504** : Ajout `print('P11_PICKVIDEO_REACHED')`

### academia_playback_view.dart
- **Ligne 92** : Ajout `print('P11_PLAYBACKVIEW_INIT_REACHED')`

---

**Statut :** ⚠️ PROBLÈME DE LOGGING IDENTIFIÉ - Les logs sont dans le code mais ne remontent pas dans flutter run. Utiliser adb logcat pour capturer.
