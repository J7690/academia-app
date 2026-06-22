# AUDIT P13 – ANALYSE DU CONFLIT ENTRE PLAYER FEED ET PLAYER PREVIEW

**Date :** 19 Juin 2026  
**Objectif :** Déterminer si l'écran noir est causé par un conflit entre le player du feed et le player de prévisualisation

---

## 1. MODIFICATIONS CODE EFFECTUÉES

### 1.1 AcademiaPlaybackView (lib/video/academia_playback_view.dart)

**Ajout instanceId :**
```dart
class _AcademiaPlaybackViewState extends State<AcademiaPlaybackView> {
  // --- P13: Instance tracking ---
  final String _instanceId = DateTime.now().millisecondsSinceEpoch.toString();
  // ...
}
```

**Logs ajoutés :**
- `[P13_CREATE] id=... url=...` dans initState()
- `[P13_DISPOSE] id=...` dans dispose()
- `[P13_UPDATE] id=... oldUrl=... newUrl=...` dans didUpdateWidget()
- `[P13_PLATFORM_VIEW_CREATED] id=... viewId=... url=...` dans onPlatformViewCreated()

### 1.2 ExoPlayerRegistry (android/app/src/main/kotlin/.../MainActivity.kt)

**Logs ajoutés :**
- `Log.e("P13_NATIVE", "PLAYERS_COUNT=${players.size}")` dans register()
- `Log.e("P13_NATIVE", "PLAYERS_COUNT=${players.size}")` dans unregister()

---

## 2. LOGS CAPTURÉS

### 2.1 Résultat de la capture

**Commande :**
```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" logcat | Select-String -Pattern "P13_|P8_|P9_"
```

**Observation :**
- Aucun log P13_ capturé
- Aucun log P8_ capturé
- Aucun log P9_ capturé

**Logs observés :**
- Logs système Android (BufferQueue, Surface, Camera2PresenceSrc)
- Logs Flutter : `[RUNTIME] _pauseAllControllers - _controllers size=22`
- Logs Flutter : `[FEED] Lifecycle AppLifecycleState.hidden → paused all controllers`

### 2.2 Analyse

**Cause probable :** L'appareil a été déconnecté avant que les logs P13 ne puissent être capturés. Les modifications de code n'ont pas été testées avec le nouveau build.

---

## 3. CHRONOLOGIE OBSERVÉE (LOGS FLUTTER)

### 3.1 Logs de pause des controllers

```
I/flutter (23136): [RUNTIME] _pauseAllControllers - _controllers size=22
I/flutter (23136): [RUNTIME] _pauseAllControllers - paused=3
I/flutter (23136): [FEED] Lifecycle AppLifecycleState.hidden → paused all controllers
I/flutter (23136): [RUNTIME] _pauseAllControllers - _controllers size=22
I/flutter (23136): [RUNTIME] _pauseAllControllers - paused=3
I/flutter (23136): [FEED] Lifecycle AppLifecycleState.inactive → paused all controllers
```

**Analyse :**
- 22 controllers sont enregistrés dans le feed
- 3 controllers sont actifs (en lecture)
- Lors du changement de lifecycle (hidden/inactive), tous les controllers sont mis en pause
- Ce comportement est normal pour gérer la transition entre feed et éditeur

---

## 4. CONCLUSIONS PARTIELLES

### 4.1 Ce que nous savons

**D'après P12 :**
- ExoPlayer reçoit les URLs locales
- Les fichiers locaux existent
- ExoPlayer n'atteint pas READY pour les fichiers locaux
- ExoPlayer fonctionne correctement pour les URLs distantes

**D'après les logs Flutter observés :**
- Le feed gère 22 controllers simultanément
- 3 controllers sont actifs en lecture
- Les controllers sont correctement mis en pause lors des transitions

### 4.2 Ce que nous ne savons pas encore

**En attente de test avec logs P13 :**
- Combien d'ExoPlayer existent simultanément pendant l'écran noir
- Le player du feed est-il encore actif pendant l'écran noir
- La preview locale possède-t-elle sa propre AndroidView
- Le player local reçoit-il réellement prepare()
- Quel player produit l'audio pendant l'écran noir

---

## 5. PROCHAINES ÉTAPES

1. **Rebuild l'application** avec les modifications P13
2. **Relancer adb logcat** avec filtre P13_
3. **Effectuer le test complet :**
   - Ouvrir le feed
   - Lire une vidéo dans le feed
   - Ouvrir l'éditeur vidéo
   - Sélectionner une vidéo locale
   - Observer l'écran noir
   - Capturer les logs P13_
4. **Analyser la chronologie** des logs P13_
5. **Conclure** sur l'existence d'un conflit

---

## 6. HYPOTHÈSES DE TRAVAIL

### Hypothèse A : Conflit de players
- Le player du feed reste actif pendant l'écran noir
- L'audio vient du player du feed
- La preview locale n'a pas de player fonctionnel

### Hypothèse B : Pas de conflit
- Le player du feed est correctement détruit
- L'audio vient de la preview locale (malgré l'écran noir)
- Le problème est purement ExoPlayer file:// (confirmé par P12)

---

## 7. MODIFICATIONS À RETIRER APRÈS TEST

Une fois le test P13 terminé et analysé :
- Retirer `_instanceId` de AcademiaPlaybackView
- Retirer les logs P13_ de AcademiaPlaybackView
- Retirer les logs P13_NATIVE de ExoPlayerRegistry
- Retirer les logs P11_ de main.dart, auth_wrapper.dart, student_challenge_video_editor_screen.dart

---

**Statut :** ⏸️ EN ATTENTE DE TEST - Modifications code effectuées mais logs non capturés (appareil déconnecté)
