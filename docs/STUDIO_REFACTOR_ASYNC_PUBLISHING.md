# STUDIO REFACTOR - ASYNC PUBLISHING

**Date :** 19 Juin 2026
**Chantier :** F - Publication Asynchrone
**Statut :** 🚧 En cours

---

## OBJECTIF

Rendre la publication vidéo asynchrone pour éviter de bloquer l'UI pendant l'upload et le transcodage. L'utilisateur doit pouvoir publier immédiatement et voir la vidéo apparaître dans le feed avec un statut "processing", puis automatiquement se mettre à jour quand la vidéo est prête.

---

## ANALYSE ACTUELLE

### Pipeline Actuel (Synchrone)

**Fichier :** `lib/features/student/student_challenge_video_editor_screen.dart`

**Étapes bloquantes :**
1. **Ligne 934** - `await VideoAssetUploadService.ingestVideoFromBytes(...)` - Upload bloquant
2. **Ligne 1001** - `await VideoAssetUploadService.triggerTranscode(...)` - Transcodage bloquant
3. **Ligne 1016** - `await provider.fetchPlaybackForVideoAsset(...)` - Résolution playback bloquante
4. **Ligne 1034** - `await provider.fetchPlaybackForDirectUrl(...)` - Fallback bloquant

**Problème :**
- L'utilisateur attend plusieurs secondes/minutes pendant l'upload et le transcodage
- L'UI est bloquée avec des spinners
- Mauvaise UX (TikTok est instantané)

### Pipeline Cible (Asynchrone)

```
1. User clique "Publier"
2. Upload vidéo en arrière-plan (non bloquant)
3. Créer entry avec status='processing'
4. Retour immédiat à l'écran précédent
5. Feed affiche la vidéo avec indicateur "En cours de traitement"
6. Worker Kamatera traite la vidéo en arrière-plan
7. Feed se rafraîchit automatiquement quand status='ready'
```

---

## ACTIONS REQUISES

### 1. Identifier les attentes bloquantes ✅

**Fichiers concernés :**
- lib/features/student/student_challenge_video_editor_screen.dart:934 (ingestVideoFromBytes)
- lib/features/student/student_challenge_video_editor_screen.dart:1001 (triggerTranscode)
- lib/features/student/student_challenge_video_editor_screen.dart:1016 (fetchPlaybackForVideoAsset)
- lib/features/student/student_challenge_video_editor_screen.dart:1034 (fetchPlaybackForDirectUrl)

**Action :** Ces appels sont bloquants et doivent être rendus asynchrones.

### 2. Supprimer les await inutiles

**Changement proposé :**
```dart
// AVANT (bloquant)
videoAssetId = await VideoAssetUploadService.ingestVideoFromBytes(...);
final transcodeResult = await VideoAssetUploadService.triggerTranscode(...);

// APRÈS (non bloquant)
VideoAssetUploadService.ingestVideoFromBytes(...).then((id) {
  videoAssetId = id;
  // Trigger transcode en arrière-plan
  VideoAssetUploadService.triggerTranscode(videoAssetId);
});
```

### 3. Mettre le statut processing

**Action :** Créer une entry dans la table appropriée avec status='processing' immédiatement après le début de l'upload.

**Table cible :**
- `student_free_videos` (pour free videos)
- `student_challenge_participations` (pour challenge videos)

**Changement :**
```dart
// Créer entry avec status='processing' avant l'upload
final entryId = await provider.createProcessingEntry(
  contextType: _isFreeVideo ? 'free_video' : 'challenge',
  contextId: _effectiveChallengeId,
  status: 'processing',
);

// Upload en arrière-plan
VideoAssetUploadService.ingestVideoFromBytes(...).then((videoAssetId) {
  // Mettre à jour entry avec video_asset_id quand upload terminé
  provider.updateEntryWithVideoAsset(entryId, videoAssetId);
});
```

### 4. Rafraîchissement auto du feed

**Action :** Implémenter un polling ou un système de notification pour rafraîchir le feed quand status passe de 'processing' à 'ready'.

**Options :**
1. **Polling** - Interroger le feed toutes les 5-10 secondes
2. **Realtime** - Utiliser Supabase Realtime pour écouter les changements de status
3. **WebSocket** - Notification push quand la vidéo est prête

**Recommandation :** Supabase Realtime (option 2) - plus efficace et moins de charge serveur.

---

## PIPELINE DE CHANGEMENT

### Étape 1: Modifier la fonction de publication

**Fichier :** `lib/features/student/student_challenge_video_editor_screen.dart`

**Changement :**
- Retirer les `await` devant `ingestVideoFromBytes` et `triggerTranscode`
- Créer entry avec status='processing' immédiatement
- Retourner à l'écran précédent immédiatement
- Lancer l'upload en arrière-plan

### Étape 2: Ajouter le statut processing dans les providers

**Providers concernés :**
- StudentChallengesProvider
- StudentHomeProvider

**Action :** Ajouter une méthode `createProcessingEntry` et `updateEntryWithVideoAsset`.

### Étape 3: Implémenter le rafraîchissement auto

**Fichier :** `lib/providers/student_challenges_provider.dart`

**Action :** Ajouter un listener Supabase Realtime sur les tables concernées pour rafraîchir le feed quand status change.

### Étape 4: UI - Indicateur processing

**Fichier :** `lib/features/student/student_home_mobile.dart` ou similaire

**Action :** Afficher un indicateur "En cours de traitement" pour les vidéos avec status='processing'.

---

## LIVRABLES

- [ ] Identifier attentes bloquantes
- [ ] Supprimer await inutiles
- [ ] Mettre statut processing
- [ ] Rafraîchissement auto feed
- [ ] Livrable STUDIO_REFACTOR_ASYNC_PUBLISHING.md

---

**Statut :** 🚧 En cours
