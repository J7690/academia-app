# PHASE D.0 – FLUTTER INTEGRATION READINESS

**Date** : 23 Juin 2026  
**Phase** : D.0 – Flutter Integration Readiness  
**Mode** : AUDIT  
**Objectif** : Préparer l'intégration Flutter du Smart Whiteboard dans le parcours Challenge

---

## DIRECTIVE

**AUCUNE MODIFICATION**  
**AUCUNE ÉCRITURE DE CODE**  
**AUCUN COMMIT**

**Interdiction absolue de modifier** :
- Challenge Feed existant
- Parcours Filmer
- Parcours Importer
- Compression Kamatera existante
- Publication existante
- Bobodo existant

---

## PARTIE 1 – PARCOURS ACTUEL

### Cartographie

```
Challenge Feed (student_challenges_tab.dart)
  ↓
Bouton + central (ligne 1626)
  ↓
_openCreateVideoFromFeed (ligne 1764)
  ↓
ChallengeCameraCaptureScreen
  ↓
StudentChallengeVideoEditorScreen
  ↓
VideoPublishScreen
  ↓
Pipeline existant (compression Kamatera, publication)
```

### Observation

**Le bouton + ouvre DIRECTEMENT la caméra TikTok.**

Il n'y a PAS de choix utilisateur (Filmer vs Importer) au niveau du bouton +.

Le parcours "Importer" est intégré dans le Studio via le bouton "Changer" (ligne 4982-4985).

---

## PARTIE 2 – IDENTIFICATION BOUTON +

### Écran du bouton +

**Fichier** : `academia_app/lib/features/student/tabs/student_challenges_tab.dart`
**Ligne** : 1626

### Widget du bouton +

```dart
Expanded(
  child: GestureDetector(
    onTap: () => _openCreateVideoFromFeed(context),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: centralButtonSize,
          height: centralButtonSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(centralButtonSize / 4),
            gradient: const LinearGradient(
              colors: [Color(0xFFA3D65C), Color(0xFF1EA75C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1EA75C).withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.add,
            color: Colors.white,
            size: centralIconSize,
          ),
        ),
      ],
    ),
  ),
),
```

### Navigation actuelle

**Méthode** : `_openCreateVideoFromFeed` (ligne 1764)

**Code** :
```dart
Future<void> _openCreateVideoFromFeed(BuildContext context) async {
  if (!context.mounted) return;

  debugPrint('[RUNTIME T1] Clic sur + - _controllers size=${_controllers.length}');

  // Suspend feed audio (pause + mute) before leaving for the Studio.
  _suspendFeedAudio();

  debugPrint('[RUNTIME T2] Ouverture CameraCapture - _controllers size=${_controllers.length}');

  final segments = await Navigator.of(context).push<List<XFile>?>(
    MaterialPageRoute(
      builder: (_) => const ChallengeCameraCaptureScreen(),
    ),
  );

  if (!mounted) return;

  debugPrint('[RUNTIME T3] Retour Galerie - segments=${segments?.length ?? 0} - _controllers size=${_controllers.length}');

  // Si l'utilisateur a capturé des segments, ouvrir le Studio avec les segments
  if (segments != null && segments.isNotEmpty) {
    // Keep feed audio suspended (pause + mute) before the editor.
    _suspendFeedAudio();
    
    debugPrint('[RUNTIME T4] Vidéo sélectionnée - _controllers size=${_controllers.length}');
    
    debugPrint('[RUNTIME T5] Ouverture Editor - _controllers size=${_controllers.length}');
    
    // Log memory before opening editor
    debugPrint('[RUNTIME MEMORY] Before opening editor - ${_getMemoryInfo()}');
    
    final published = await Navigator.of(context).push<bool?>(
      MaterialPageRoute(
        builder: (_) => StudentChallengeVideoEditorScreen(
          videoType: 'free',
          initialMode: 'camera',
          initialSegments: segments,
        ),
      ),
    );

    if (!mounted) return;
    await _onReturnFromStudio(published == true);
    return;
  }

  if (!mounted) return;
  final ctrl = _controllers[_currentPage];
  if (ctrl != null && ctrl.isAttached) {
    ctrl.play();
  }
}
```

---

## PARTIE 3 – POINT D'INSERTION EXACT

### Analyse

**Le bouton + ouvre DIRECTEMENT la caméra TikTok.**

Il n'y a PAS de modal de choix utilisateur au niveau du bouton +.

Le parcours "Importer" est intégré dans le Studio via le bouton "Changer" (ligne 4982-4985) :
```dart
_moreToolItem(Icons.video_file_outlined, 'Changer', const Color(0xFFFF9800), () {
  Navigator.of(ctx).pop();
  _pickVideo();
}),
```

### Point d'insertion

**Fichier** : `student_challenges_tab.dart`
**Méthode** : `_openCreateVideoFromFeed` (ligne 1764)

### Modification requise

**Remplacer** l'ouverture directe de `ChallengeCameraCaptureScreen` par un modal avec 3 choix :
1. Filmer (parcours existant)
2. Importer (parcours existant via Studio)
3. Smart Whiteboard (nouveau parcours)

### Impact

**Aucun impact sur les parcours existants** :
- Parcours Filmer : inchangé
- Parcours Importer : inchangé (via Studio)

---

## PARTIE 4 – ÉCRANS DÉJÀ CRÉÉS

### Répertoire

**Chemin** : `academia_app/lib/features/challenge/smart_whiteboard/`

### Contenu

```
smart_whiteboard/
  models/
    storyboard_models.dart (1115 lignes)
  providers/ (vide)
  services/ (vide)
  widgets/ (vide)
```

### Écrans

**Aucun écran Smart Whiteboard n'existe.**

### Modèles existants

**Fichier** : `storyboard_models.dart` (1115 lignes)

**Contenu** :
- Enums (ProjectStatus, RendererId, ThemeId, NarrationMode, RenderJobStatus, BlockType)
- ExportSettings
- Resolution
- Narration
- Block (et sous-types : TitleBlock, ParagraphBlock, FormulaBlock, DefinitionBlock, ExerciseBlock, CorrectionBlock)
- Scene
- Storyboard
- WhiteboardProject
- RenderJob

**Conformité** : ✅ 100% conforme au Data Contract

---

## PARTIE 5 – PROVIDERS, SERVICES, MODÈLES EXISTANTS

### Modèles

**Existants** : ✅ storyboard_models.dart (tous les modèles du Data Contract)

### Providers

**Existants** : ❌ Aucun

### Services

**Existants** : ❌ Aucun

---

## PARTIE 6 – FUTUR PARCOURS SMART WHITEBOARD

### Cartographie

```
Challenge Feed
  ↓
Bouton + central
  ↓
Modal (Filmer / Importer / Smart Whiteboard)
  ↓
Smart Whiteboard Input
  ↓
Storyboard Editor
  ↓
Narration Editor
  ↓
Render Job Creation
  ↓
Render Job Monitoring (attente rendu)
  ↓
VideoPublishScreen (réutilisation)
  ↓
Pipeline existant (compression Kamatera, publication)
```

### Réutilisation

**VideoPublishScreen** : ✅ Réutilisable (pipeline existant)

---

## PARTIE 7 – POINTS DE NAVIGATION

### Nouveaux points de navigation

1. **Modal choix** (student_challenges_tab.dart)
   - _openCreateVideoFromFeed modifié
   - Affiche modal avec 3 choix

2. **Smart Whiteboard Input** (nouveau fichier)
   - smart_whiteboard_input_screen.dart
   - Sujet, thème, renderer

3. **Storyboard Editor** (nouveau fichier)
   - smart_whiteboard_storyboard_editor_screen.dart
   - Éditeur de scènes et blocs

4. **Narration Editor** (nouveau fichier)
   - smart_whiteboard_narration_editor_screen.dart
   - Mode narration, TTS, enregistrement

5. **Render Job Monitoring** (nouveau fichier)
   - smart_whiteboard_render_monitor_screen.dart
   - Suivi du statut de rendu

6. **VideoPublishScreen** (réutilisation)
   - video_publish_screen.dart
   - Pipeline existant

---

## PARTIE 8 – COMPOSANTS MANQUANTS

### CRITIQUE

| Composant | Description | Priorité |
|-----------|-------------|----------|
| SmartWhiteboardInputScreen | Écran de saisie du sujet, thème, renderer | CRITIQUE |
| SmartWhiteboardStoryboardEditorScreen | Éditeur de scènes et blocs | CRITIQUE |
| SmartWhiteboardNarrationEditorScreen | Éditeur de narration | CRITIQUE |
| SmartWhiteboardRenderMonitorScreen | Suivi du statut de rendu | CRITIQUE |
| WhiteboardProjectsProvider | Provider pour les projets | CRITIQUE |
| WhiteboardRenderJobsProvider | Provider pour les jobs de rendu | CRITIQUE |
| WhiteboardStoryboardService | Service pour les storyboards | CRITIQUE |
| WhiteboardRenderService | Service pour les jobs de rendu | CRITIQUE |

### MAJEUR

| Composant | Description | Priorité |
|-----------|-------------|----------|
| SceneEditorWidget | Widget d'édition de scène | MAJEUR |
| BlockEditorWidget | Widget d'édition de bloc | MAJEUR |
| NarrationModeSelector | Sélecteur de mode narration | MAJEUR |
| ThemeSelector | Sélecteur de thème | MAJEUR |
| RendererSelector | Sélecteur de renderer | MAJEUR |
| RenderJobStatusWidget | Widget de statut de rendu | MAJEUR |

### MINEUR

| Composant | Description | Priorité |
|-----------|-------------|----------|
| BlockTypeSelector | Sélecteur de type de bloc | MINEUR |
| BlockStyleEditor | Éditeur de style de bloc | MINEUR |
| SceneTransitionEditor | Éditeur de transition de scène | MINEUR |
| NarrationVoiceSelector | Sélecteur de voix TTS | MINEUR |
| ExportSettingsEditor | Éditeur de paramètres d'export | MINEUR |

---

## PARTIE 9 – POURCENTAGE RÉEL D'AVANCEMENT

### Backend

**Statut** : ✅ 100%

**Composants** :
- Tables Supabase : ✅ whiteboard_projects, whiteboard_renders
- RPCs : ✅ whiteboard_fetch_queued_jobs, whiteboard_mark_processing, whiteboard_mark_done, whiteboard_mark_failed
- Storage : ✅ whiteboard-renders bucket

### Renderer

**Statut** : ✅ 100%

**Composants** :
- whiteboard_render_worker.py : ✅ Déployé et fonctionnel
- whiteboard_png_renderer.py : ✅ Corrigé et déployé
- whiteboard_ffmpeg_assembler.py : ✅ Déployé
- whiteboard_upload_renderer.py : ✅ Déployé
- Pipeline complet : ✅ Validé (PHASE C.3J)

### Flutter

**Statut** : 5%

**Composants** :
- Modèles : ✅ storyboard_models.dart (100%)
- Écrans : ❌ 0/5 (0%)
- Providers : ❌ 0/2 (0%)
- Services : ❌ 0/2 (0%)
- Widgets : ❌ 0/5 (0%)

### UX

**Statut** : 0%

**Composants** :
- Modal choix : ❌ Non implémenté
- Navigation : ❌ Non implémentée
- Interface utilisateur : ❌ Non implémentée

### Avancement global

**Backend** : 100%  
**Renderer** : 100%  
**Flutter** : 5%  
**UX** : 0%

**Global** : 51%

---

## CONCLUSION

### Résumé

**Parcours actuel** : Bouton + → Caméra TikTok → Studio → Publication

**Point d'insertion** : Modifier `_openCreateVideoFromFeed` pour afficher un modal avec 3 choix

**Écrans créés** : Aucun (seuls les modèles existent)

**Composants manquants** : 7 CRITIQUE, 5 MAJEUR, 5 MINEUR

**Avancement** : Backend 100%, Renderer 100%, Flutter 5%, UX 0%

### Risque pour les parcours existants

**AUCUN RISQUE**

La modification du bouton + pour afficher un modal avec 3 choix n'impacte pas les parcours existants :
- Parcours Filmer : inchangé
- Parcours Importer : inchangé (via Studio)

### Critère de réussite

**✅ Être capable de démarrer l'implémentation Flutter sans risque pour les parcours Filmer et Importer.**

---

**Fin du Flutter Integration Readiness**
