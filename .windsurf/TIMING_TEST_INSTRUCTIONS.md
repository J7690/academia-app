# Instructions de Test de Timing - Pipeline Importation Vidéo Challenge

## Contexte

Des logs de timing ont été ajoutés dans le code pour mesurer précisément chaque étape du parcours d'importation vidéo.

## Logs Ajoutés

### student_challenge_video_editor_screen.dart

- **T0**: Vidéo sélectionnée (FilePicker)
- **T1**: Début compression VideoCompress
- **T2**: Fin compression VideoCompress
- **T3**: Début génération miniature (video_thumbnail)
- **T4**: Fin génération miniature
- **T5**: Début initialisation contrôleur vidéo
- **T6**: Vidéo initialisée (setState)
- **T7**: Début upload vers Supabase
- **T8**: Fin upload vers Supabase

### challenge_camera_capture_screen.dart

- **T_GALLERY_START**: Clic bouton galerie
- **T_GALLERY_END**: Vidéo sélectionnée dans galerie

## Procédure de Test

### Prérequis

1. APK compilé: `app-debug.apk` dans `academia_app/build/app/outputs/flutter-apk/`
2. Installer l'APK sur l'appareil de test
3. Avoir 3 vidéos de tailles différentes prêtes dans la galerie:
   - **Cas A**: ~10 MB
   - **Cas B**: ~50 MB
   - **Cas C**: ~150 MB

### Étapes pour chaque cas

1. **Ouvrir Android Studio Logcat**
   - Filtrer par: `[TIMING]`
   - Niveau: Debug/Verbose

2. **Lancer l'app Academia**

3. **Naviguer vers Challenge Feed**

4. **Cliquer sur le bouton "+"**

5. **Cliquer sur le bouton galerie (icône upload)**

6. **Sélectionner la vidéo test**

7. **Attendre que l'éditeur vidéo s'ouvre**

8. **Attendre que le bouton "Suivant" soit activé**

9. **Capturer les logs**:
   - Copier tous les logs `[TIMING]` du Logcat
   - Sauvegarder dans un fichier texte

10. **Répéter pour les 2 autres tailles de vidéo**

## Format des Logs Attendus

```
[TIMING] T_GALLERY_START - Clic bouton galerie: 2026-06-16T15:30:00.000
[TIMING] T_GALLERY_END - Vidéo sélectionnée dans galerie: 2026-06-16T15:30:02.500 (ΔT: 2500ms)
[TIMING] T0 - Vidéo sélectionnée: 2026-06-16T15:30:02.500
[TIMING] T3 - Début génération miniature: 2026-06-16T15:30:02.600 (ΔT3-T0: 100ms)
[TIMING] T4 - Fin génération miniature: 2026-06-16T15:30:04.600 (ΔT4-T3: 2000ms, taille: 15000 bytes)
[TIMING] T1 - Début compression: 2026-06-16T15:30:04.700 (ΔT1-T0: 2200ms)
[TIMING] T2 - Fin compression: 2026-06-16T15:30:14.700 (ΔT2-T1: 10000ms)
[TIMING] T5 - Début initialisation contrôleur vidéo: 2026-06-16T15:30:15.000
[TIMING] T6 - Vidéo initialisée (setState): 2026-06-16T15:30:15.500 (ΔT6-T5: 500ms)
[TIMING] T7 - Début upload: 2026-06-16T15:30:20.000
[TIMING] T8 - Fin upload: 2026-06-16T15:30:25.000 (ΔT8-T7: 5000ms)
```

## Données à Collecter

Pour chaque cas (10MB, 50MB, 150MB), noter:

| Étape | Durée (ms) | Thread (observé) |
|-------|-----------|-----------------|
| Sélection galerie | ΔT_GALLERY_END - T_GALLERY_START | UI |
| Génération miniature | ΔT4-T3 | UI |
| Compression | ΔT2-T1 | UI |
| Initialisation contrôleur | ΔT6-T5 | UI |
| Upload | ΔT8-T7 | Background |

## Livrable Attendu

Fournir les 3 fichiers de logs (un par taille de vidéo) ou un tableau récapitulatif avec les durées mesurées.

## Notes

- Les logs apparaissent dans Android Studio Logcat
- Filtrer par `[TIMING]` pour voir uniquement les logs de timing
- Les durées sont en millisecondes
- Les temps incluent la latence réseau pour l'upload
