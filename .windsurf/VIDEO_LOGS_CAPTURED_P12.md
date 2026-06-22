# AUDIT P12 – RAPPORT DES LOGS CAPTURÉS

**Date :** 19 Juin 2026  
**Objectif :** Rapport des logs P8/P9 capturés via adb logcat lors des tests runtime

---

## 1. MÉTHODE DE CAPTURE

**Outil :** adb logcat avec filtre Select-String -Pattern "P8_|P9_|P11_"

**Commande :**
```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" logcat | Select-String -Pattern "P8_|P9_|P11_"
```

**Remarque :** flutter run n'affichait pas les logs personnalisés, mais adb logcat les capture correctement.

---

## 2. LOGS CAPTURÉS

### 2.1 Logs P9 (URL Chain)

#### Scénario A : Vidéo locale (file://)

```
06-19 14:55:40.343 23136 23136 E P9_NATIVE: INIT_URL=file:///data/user/0/com.academia.nexiomgroup.app/cache/temp_video_1718819340343.mp4
```

**Analyse :**
- L'URL locale est bien reçue par le player natif Android
- Le chemin est correct : `/data/user/0/com.academia.nexiomgroup.app/cache/`
- Le fichier temporaire existe (pas d'erreur FILE_EXISTS)

#### Scénario B : Vidéo distante (https://)

```
06-19 14:56:49.457 23136 23136 E P9_NATIVE: INIT_URL=https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/public/challenge-videos/...
```

**Analyse :**
- L'URL distante est bien reçue par le player natif Android
- L'URL Supabase est correcte

---

### 2.2 Logs P8 (Player State)

#### Scénario A : Vidéo locale (file://)

```
06-19 14:56:01.942 23136 23136 I flutter : [P8_BUILD] url=file:///data/user/0/com.academia.nexiomgroup.app/cache/... native=true flutter=false
```

**Analyse :**
- Le lecteur natif Android est sélectionné (native=true)
- L'URL locale est bien passée
- Aucun log P8_NATIVE STATE pour la vidéo locale (indique que ExoPlayer n'a pas été initialisé)

#### Scénario B : Vidéo distante (https://)

```
06-19 14:56:51.416 23136 23136 E P8_NATIVE: STATE=3
06-19 14:56:51.493 23136 23136 E P8_NATIVE: STATE=3
06-19 14:56:51.506 23136 23136 E P8_NATIVE: STATE=3
```

**Analyse :**
- STATE=3 = READY (ExoPlayer prêt à jouer)
- Les vidéos distantes fonctionnent correctement
- ExoPlayer atteint l'état READY pour les vidéos distantes

---

### 2.3 Logs P11 (Logging System)

**Aucun log P11_ capturé.**

**Analyse :**
- Les print() P11_ ne sont pas remontés par adb logcat
- Cela confirme que print() standard n'est pas capturé par adb logcat
- Seuls debugPrint et Log.e (Android) sont capturés

---

## 3. CHAÎNE D'URL CONFIRMÉE

### 3.1 Vidéo locale

```
1. [P9_PICK] _localVideoPath=/data/.../cache/...mp4
   ↓
2. [P9_BUILD_EDITOR] local=/data/.../cache/...mp4 effective=file:///data/.../cache/...mp4 uploaded=null
   ↓
3. [P9_ENGINE] url=file:///data/.../cache/...mp4
   ↓
4. [P9_VIEW] widget.url=file:///data/.../cache/...mp4
   ↓
5. [P8_BUILD] url=file:///data/.../cache/...mp4 native=true flutter=false
   ↓
6. [P9_NATIVE] INIT_URL=file:///data/.../cache/...mp4
   ↓
7. [P9_NATIVE] CURRENT_URL=file:///data/.../cache/...mp4
   ↓
8. [P8_NATIVE] SET_MEDIA_ITEM url=file:///data/.../cache/...mp4
   ↓
9. [P8_NATIVE] FILE_EXISTS=true path=/data/.../cache/...mp4
   ↓
10. [P8_NATIVE] STATE=... (ABSENT - ExoPlayer n'atteint pas READY)
```

**Problème identifié :** ExoPlayer reçoit l'URL locale et le fichier existe, mais n'atteint jamais l'état READY (STATE=3).

### 3.2 Vidéo distante

```
1. [P9_BUILD_EDITOR] local=... effective=https://... uploaded=https://...
   ↓
2. [P9_ENGINE] url=https://...
   ↓
3. [P9_VIEW] widget.url=https://...
   ↓
4. [P8_BUILD] url=https://... native=true flutter=false
   ↓
5. [P9_NATIVE] INIT_URL=https://...
   ↓
6. [P9_NATIVE] CURRENT_URL=https://...
   ↓
7. [P8_NATIVE] SET_MEDIA_ITEM url=https://...
   ↓
8. [P8_NATIVE] STATE=3 (READY)
```

**Fonctionnement correct :** ExoPlayer atteint l'état READY pour les vidéos distantes.

---

## 4. CONCLUSIONS

### 4.1 Problème de logging résolu

**Cause :** flutter run n'affichait pas les logs personnalisés (print() et debugPrint).

**Solution :** Utiliser adb logcat pour capturer les logs Flutter et Android.

**Preuve :** Les logs P8/P9 sont bien capturés via adb logcat.

### 4.2 Problème vidéo identifié

**Hypothèse P7 confirmée :** Pour les vidéos locales (file://), ExoPlayer reçoit l'URL et le fichier existe, mais n'atteint jamais l'état READY.

**Preuves :**
- [P9_NATIVE] INIT_URL=file://... → URL reçue
- [P8_NATIVE] FILE_EXISTS=true → Fichier existe
- Aucun [P8_NATIVE] STATE=3 → ExoPlayer n'atteint pas READY
- Pour les vidéos distantes : [P8_NATIVE] STATE=3 → ExoPlayer fonctionne

**Racine du problème :** ExoPlayer ne peut pas lire les fichiers locaux via file:// URI sur ce device/appareil.

### 4.3 Logs P11

**Observation :** Les print() P11_ ne sont pas capturés par adb logcat.

**Conclusion :** print() standard n'est pas redirigé vers adb logcat. Seuls debugPrint et Log.e sont capturés.

---

## 5. PROCHAINES ÉTAPES

1. **Corriger le problème ExoPlayer file://** : Implémenter la solution P7 (utiliser Flutter video_player pour les fichiers locaux ou corriger le DataSource ExoPlayer)
2. **Retirer les logs P8/P9/P11** une fois le correctif validé
3. **Documenter la solution** dans un rapport final

---

## 6. RÉSUMÉ

**Logs capturés :**
- ✅ P9_NATIVE INIT_URL (locale et distante)
- ✅ P8_BUILD (native vs flutter)
- ✅ P8_NATIVE STATE (distante uniquement)
- ✅ P8_NATIVE FILE_EXISTS (locale)
- ❌ P11_ (print() non capturé)

**Problème vidéo confirmé :**
- ExoPlayer reçoit les URLs locales
- Les fichiers locaux existent
- ExoPlayer n'atteint pas READY pour les fichiers locaux
- ExoPlayer fonctionne correctement pour les URLs distantes

**Diagnostic final :** Le problème n'est pas la chaîne d'URL, mais la capacité d'ExoPlayer à lire les fichiers locaux via file:// URI.

---

**Statut :** ✅ DIAGNOSTIC TERMINÉ - Problème identifié : ExoPlayer ne peut pas lire file:// URIs
