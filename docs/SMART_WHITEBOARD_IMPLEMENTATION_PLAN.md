# SMART WHITEBOARD IA V1 – PLAN D'IMPLÉMENTATION

**Version** : 1.0  
**Date** : 23 Juin 2026  
**Mode** : LECTURE SEULE  
**Objectif** : Préparation du chantier de développement

---

## DIRECTIVE PERMANENTE

Toute validation concernant Supabase, Kamatera Cloud, Docker, FFmpeg, Backend Python, RPC, Buckets, Tables, Edge Functions doit être effectuée exclusivement via les RPC Python administrateurs présents dans `.windsurf`.

Aucune hypothèse autorisée.

---

## PARTIE 1 – ORDRE DE CRÉATION

### 1.1 Dossiers

**Ordre de création** :

1. `academia_app/lib/features/challenge/smart_whiteboard/`
2. `academia_app/lib/features/challenge/smart_whiteboard/widgets/`
3. `academia_app/lib/features/challenge/smart_whiteboard/providers/`
4. `academia_app/lib/features/challenge/smart_whiteboard/services/`
5. `academia_app/lib/features/challenge/smart_whiteboard/models/`
6. `academia_bobodo_backend/whiteboard/`

### 1.2 Fichiers (Flutter)

**Ordre de création** :

1. `academia_app/lib/features/challenge/smart_whiteboard/models/storyboard_models.dart`
2. `academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_service.dart`
3. `academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_narration_service.dart`
4. `academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_render_service.dart`
5. `academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart`
6. `academia_app/lib/features/challenge/smart_whiteboard/widgets/whiteboard_block_widget.dart`
7. `academia_app/lib/features/challenge/smart_whiteboard/smart_whiteboard_input_screen.dart`
8. `academia_app/lib/features/challenge/smart_whiteboard/smart_whiteboard_editor_screen.dart`
9. `academia_app/lib/features/challenge/smart_whiteboard/smart_whiteboard_preview_screen.dart`

### 1.3 Fichiers (Supabase)

**Ordre de création** :

1. `supabase/migrations/20260623000001_create_whiteboard_projects.sql`
2. `supabase/migrations/20260623000002_create_whiteboard_renders.sql`
3. `supabase/migrations/20260623000003_create_whiteboard_rpcs.sql`
4. `supabase/migrations/20260623000004_create_whiteboard_buckets.sql`
5. `supabase/migrations/20260623000005_create_whiteboard_rls.sql`

### 1.4 Fichiers (Kamatera)

**Ordre de création** :

1. `academia_bobodo_backend/whiteboard/whiteboard_main.py`
2. `academia_bobodo_backend/whiteboard/whiteboard_render_worker.py`
3. `academia_bobodo_backend/whiteboard/image_generator.py`
4. `academia_bobodo_backend/whiteboard/video_assembler.py`
5. `academia_bobodo_backend/whiteboard/requirements.txt`
6. `academia_bobodo_backend/whiteboard/Dockerfile`
7. `academia_bobodo_backend/docker-compose.whiteboard.yml`

### 1.5 Fichiers (Edge Functions)

**Ordre de création** :

1. `supabase/functions/whiteboard-render/index.ts`

---

## PARTIE 2 – DÉPENDANCES

### 2.1 Modèles Storyboard

**Dépend de** : Aucun

**Utilisé par** :
- SmartWhiteboardService
- SmartWhiteboardProvider
- SmartWhiteboardEditorScreen
- SmartWhiteboardPreviewScreen

### 2.2 SmartWhiteboardService

**Dépend de** :
- Modèles Storyboard
- Supabase client
- RPCs Supabase

**Utilisé par** :
- SmartWhiteboardProvider
- SmartWhiteboardInputScreen
- SmartWhiteboardEditorScreen
- SmartWhiteboardPreviewScreen

### 2.3 SmartWhiteboardNarrationService

**Dépend de** :
- Supabase Storage client
- flutter_sound (package)
- flutter_tts (package)

**Utilisé par** :
- SmartWhiteboardPreviewScreen

### 2.4 SmartWhiteboardRenderService

**Dépend de** :
- SmartWhiteboardService
- RPCs Supabase

**Utilisé par** :
- SmartWhiteboardProvider
- SmartWhiteboardPreviewScreen

### 2.5 SmartWhiteboardProvider

**Dépend de** :
- Modèles Storyboard
- SmartWhiteboardService
- SmartWhiteboardRenderService

**Utilisé par** :
- SmartWhiteboardInputScreen
- SmartWhiteboardEditorScreen
- SmartWhiteboardPreviewScreen

### 2.6 WhiteboardBlockWidget

**Dépend de** :
- Modèles Storyboard
- flutter_math_fork (package)

**Utilisé par** :
- SmartWhiteboardEditorScreen
- SmartWhiteboardPreviewScreen

### 2.7 SmartWhiteboardInputScreen

**Dépend de** :
- SmartWhiteboardProvider
- SmartWhiteboardService

**Utilisé par** : Navigation depuis student_challenges_tab.dart

### 2.8 SmartWhiteboardEditorScreen

**Dépend de** :
- SmartWhiteboardProvider
- SmartWhiteboardService
- WhiteboardBlockWidget

**Utilisé par** : Navigation depuis SmartWhiteboardInputScreen

### 2.9 SmartWhiteboardPreviewScreen

**Dépend de** :
- SmartWhiteboardProvider
- SmartWhiteboardService
- SmartWhiteboardNarrationService
- SmartWhiteboardRenderService
- WhiteboardBlockWidget

**Utilisé par** : Navigation depuis SmartWhiteboardEditorScreen

### 2.10 Tables Supabase

**Dépend de** : Aucun

**Utilisé par** :
- RPCs Supabase
- SmartWhiteboardService

### 2.11 RPCs Supabase

**Dépend de** :
- Tables Supabase

**Utilisé par** :
- SmartWhiteboardService
- Kamatera worker

### 2.12 Buckets Supabase

**Dépend de** : Aucun

**Utilisé par** :
- SmartWhiteboardNarrationService
- Kamatera worker

### 2.13 Edge Function whiteboard-render

**Dépend de** :
- RPCs Supabase
- Buckets Supabase

**Utilisé par** : Kamatera worker

### 2.14 whiteboard_main.py

**Dépend de** :
- RPCs Supabase
- Buckets Supabase
- Pillow (package)
- matplotlib (package)
- FFmpeg

**Utilisé par** : Docker Compose

### 2.15 whiteboard_render_worker.py

**Dépend de** :
- RPCs Supabase
- whiteboard_main.py

**Utilisé par** : Docker Compose

### 2.16 image_generator.py

**Dépend de** :
- Pillow (package)
- matplotlib (package)

**Utilisé par** : whiteboard_main.py

### 2.17 video_assembler.py

**Dépend de** :
- FFmpeg

**Utilisé par** : whiteboard_main.py

---

## PARTIE 3 – LOTS DE DÉVELOPPEMENT

### Lot 1 : Modèles Storyboard

**Éléments** :
- `academia_app/lib/features/challenge/smart_whiteboard/models/storyboard_models.dart`

**Dépendances** : Aucune

**Critères de réussite** :
- Modèles compilent sans erreur
- Modèles correspondent au schéma JSON défini dans SMART_WHITEBOARD_STORYBOARD_SCHEMA.md

**Critères d'échec** :
- Erreurs de compilation
- Modèles ne correspondent pas au schéma JSON

**Points de contrôle** :
- Vérifier que tous les types de blocs V1 sont définis
- Vérifier que les métadonnées V1 sont définies

---

### Lot 2 : Tables Supabase

**Éléments** :
- `supabase/migrations/20260623000001_create_whiteboard_projects.sql`
- `supabase/migrations/20260623000002_create_whiteboard_renders.sql`

**Dépendances** : Lot 1 (Modèles Storyboard)

**Validation requise** : Via RPC Python administrateurs dans `.windsurf`

**Critères de réussite** :
- Tables créées avec succès
- Tables correspondent au schéma défini dans SMART_WHITEBOARD_V1_FINAL_SPEC.md
- Tables n'existent pas déjà

**Critères d'échec** :
- Tables existent déjà
- Erreurs de création
- Tables ne correspondent pas au schéma

**Points de contrôle** :
- Via RPC : Vérifier que les tables n'existent pas déjà
- Via RPC : Vérifier que les colonnes sont correctes
- Via RPC : Vérifier que les indexes sont créés

---

### Lot 3 : RPCs Supabase

**Éléments** :
- `supabase/migrations/20260623000003_create_whiteboard_rpcs.sql`

**Dépendances** : Lot 2 (Tables Supabase)

**Validation requise** : Via RPC Python administrateurs dans `.windsurf`

**Critères de réussite** :
- RPCs créés avec succès
- RPCs correspondent au schéma défini dans SMART_WHITEBOARD_V1_FINAL_SPEC.md
- RPCs n'existent pas déjà

**Critères d'échec** :
- RPCs existent déjà
- Erreurs de création
- RPCs ne correspondent pas au schéma

**Points de contrôle** :
- Via RPC : Vérifier que les RPCs n'existent pas déjà
- Via RPC : Tester chaque RPC avec des données de test
- Via RPC : Vérifier que les retours sont corrects

---

### Lot 4 : Buckets Supabase

**Éléments** :
- `supabase/migrations/20260623000004_create_whiteboard_buckets.sql`

**Dépendances** : Aucune

**Validation requise** : Via RPC Python administrateurs dans `.windsurf`

**Critères de réussite** :
- Buckets créés avec succès
- Buckets correspondent au schéma défini dans SMART_WHITEBOARD_V1_FINAL_SPEC.md
- Buckets n'existent pas déjà

**Critères d'échec** :
- Buckets existent déjà
- Erreurs de création
- Buckets ne correspondent pas au schéma

**Points de contrôle** :
- Via RPC : Vérifier que les buckets n'existent pas déjà
- Via RPC : Vérifier que les buckets sont publics/privés selon le besoin
- Via RPC : Tester l'upload d'un fichier de test

---

### Lot 5 : RLS Policies

**Éléments** :
- `supabase/migrations/20260623000005_create_whiteboard_rls.sql`

**Dépendances** : Lot 2 (Tables Supabase), Lot 3 (RPCs Supabase)

**Validation requise** : Via RPC Python administrateurs dans `.windsurf`

**Critères de réussite** :
- Policies créées avec succès
- Policies correspondent au schéma défini dans SMART_WHITEBOARD_V1_FINAL_SPEC.md
- Policies n'existent pas déjà

**Critères d'échec** :
- Policies existent déjà
- Erreurs de création
- Policies ne correspondent pas au schéma

**Points de contrôle** :
- Via RPC : Vérifier que les policies n'existent pas déjà
- Via RPC : Tester les permissions avec un utilisateur test
- Via RPC : Vérifier que les policies sont correctes

---

### Lot 6 : SmartWhiteboardService

**Éléments** :
- `academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_service.dart`

**Dépendances** : Lot 1 (Modèles Storyboard), Lot 3 (RPCs Supabase)

**Critères de réussite** :
- Service compile sans erreur
- Service peut appeler les RPCs Supabase
- Service peut créer un projet
- Service peut mettre à jour un projet
- Service peut récupérer un projet
- Service peut lister les projets
- Service peut supprimer un projet

**Critères d'échec** :
- Erreurs de compilation
- Erreurs d'appel RPC
- Service ne peut pas créer un projet

**Points de contrôle** :
- Tester la création d'un projet via RPC
- Tester la mise à jour d'un projet via RPC
- Tester la récupération d'un projet via RPC
- Tester la liste des projets via RPC
- Tester la suppression d'un projet via RPC

---

### Lot 7 : SmartWhiteboardNarrationService

**Éléments** :
- `academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_narration_service.dart`

**Dépendances** : Lot 4 (Buckets Supabase)

**Critères de réussite** :
- Service compile sans erreur
- Service peut enregistrer l'audio utilisateur
- Service peut générer du TTS
- Service peut uploader l'audio vers Supabase Storage

**Critères d'échec** :
- Erreurs de compilation
- Erreurs d'enregistrement audio
- Erreurs de génération TTS
- Erreurs d'upload

**Points de contrôle** :
- Tester l'enregistrement audio
- Tester la génération TTS
- Tester l'upload vers Supabase Storage
- Vérifier que le fichier est bien stocké dans le bucket

---

### Lot 8 : SmartWhiteboardRenderService

**Éléments** :
- `academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_render_service.dart`

**Dépendances** : Lot 3 (RPCs Supabase)

**Critères de réussite** :
- Service compile sans erreur
- Service peut créer un job de rendu
- Service peut récupérer le statut d'un rendu
- Service peut poller le statut d'un rendu

**Critères d'échec** :
- Erreurs de compilation
- Erreurs d'appel RPC
- Service ne peut pas créer un job de rendu

**Points de contrôle** :
- Tester la création d'un job de rendu via RPC
- Tester la récupération du statut d'un rendu via RPC
- Tester le polling du statut d'un rendu

---

### Lot 9 : SmartWhiteboardProvider

**Éléments** :
- `academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart`

**Dépendances** : Lot 1 (Modèles Storyboard), Lot 6 (SmartWhiteboardService), Lot 8 (SmartWhiteboardRenderService)

**Critères de réussite** :
- Provider compile sans erreur
- Provider peut gérer l'état du Storyboard
- Provider peut gérer l'état de génération Bobodo
- Provider peut gérer l'état de rendu
- Provider peut notifier les listeners

**Critères d'échec** :
- Erreurs de compilation
- Provider ne peut pas gérer l'état
- Provider ne peut pas notifier les listeners

**Points de contrôle** :
- Tester la création d'un Storyboard
- Tester la mise à jour d'un Storyboard
- Tester la création d'un job de rendu
- Tester le polling du statut de rendu

---

### Lot 10 : WhiteboardBlockWidget

**Éléments** :
- `academia_app/lib/features/challenge/smart_whiteboard/widgets/whiteboard_block_widget.dart`

**Dépendances** : Lot 1 (Modèles Storyboard)

**Critères de réussite** :
- Widget compile sans erreur
- Widget peut afficher un bloc title
- Widget peut afficher un bloc paragraph
- Widget peut afficher un bloc formula
- Widget peut afficher un bloc definition
- Widget peut afficher un bloc exercise
- Widget peut afficher un bloc correction

**Critères d'échec** :
- Erreurs de compilation
- Widget ne peut pas afficher un bloc
- Erreurs d'affichage des formules LaTeX

**Points de contrôle** :
- Tester l'affichage d'un bloc title
- Tester l'affichage d'un bloc paragraph
- Tester l'affichage d'un bloc formula
- Tester l'affichage d'un bloc definition
- Tester l'affichage d'un bloc exercise
- Tester l'affichage d'un bloc correction

---

### Lot 11 : SmartWhiteboardInputScreen

**Éléments** :
- `academia_app/lib/features/challenge/smart_whiteboard/smart_whiteboard_input_screen.dart`

**Dépendances** : Lot 6 (SmartWhiteboardService), Lot 9 (SmartWhiteboardProvider)

**Critères de réussite** :
- Écran compile sans erreur
- Écran peut saisir un sujet
- Écran peut générer un Storyboard via Bobodo
- Écran peut naviguer vers l'écran d'édition

**Critères d'échec** :
- Erreurs de compilation
- Écran ne peut pas saisir un sujet
- Écran ne peut pas générer un Storyboard
- Écran ne peut pas naviguer

**Points de contrôle** :
- Tester la saisie d'un sujet
- Tester la génération d'un Storyboard via Bobodo
- Tester la navigation vers l'écran d'édition
- Vérifier que le Storyboard généré est valide

---

### Lot 12 : SmartWhiteboardEditorScreen

**Éléments** :
- `academia_app/lib/features/challenge/smart_whiteboard/smart_whiteboard_editor_screen.dart`

**Dépendances** : Lot 6 (SmartWhiteboardService), Lot 9 (SmartWhiteboardProvider), Lot 10 (WhiteboardBlockWidget)

**Critères de réussite** :
- Écran compile sans erreur
- Écran peut afficher les blocs
- Écran peut éditer le texte des blocs
- Écran peut réorganiser les blocs
- Écran peut supprimer des blocs
- Écran peut ajouter des blocs
- Écran peut naviguer vers l'écran de prévisualisation

**Critères d'échec** :
- Erreurs de compilation
- Écran ne peut pas afficher les blocs
- Écran ne peut pas éditer les blocs
- Écran ne peut pas réorganiser les blocs

**Points de contrôle** :
- Tester l'affichage des blocs
- Tester l'édition du texte des blocs
- Tester la réorganisation des blocs
- Tester la suppression des blocs
- Tester l'ajout de blocs
- Tester la navigation vers l'écran de prévisualisation

---

### Lot 13 : SmartWhiteboardPreviewScreen

**Éléments** :
- `academia_app/lib/features/challenge/smart_whiteboard/smart_whiteboard_preview_screen.dart`

**Dépendances** : Lot 6 (SmartWhiteboardService), Lot 7 (SmartWhiteboardNarrationService), Lot 8 (SmartWhiteboardRenderService), Lot 9 (SmartWhiteboardProvider), Lot 10 (WhiteboardBlockWidget)

**Critères de réussite** :
- Écran compile sans erreur
- Écran peut afficher les blocs avec animation fade_in
- Écran peut enregistrer la narration
- Écran peut générer du TTS
- Écran peut créer un job de rendu
- Écran peut poller le statut de rendu
- Écran peut naviguer vers video_publish_screen

**Critères d'échec** :
- Erreurs de compilation
- Écran ne peut pas afficher les blocs
- Écran ne peut pas enregistrer la narration
- Écran ne peut pas créer un job de rendu
- Écran ne peut pas naviguer

**Points de contrôle** :
- Tester l'affichage des blocs avec animation
- Tester l'enregistrement de la narration
- Tester la génération TTS
- Tester la création d'un job de rendu
- Tester le polling du statut de rendu
- Tester la navigation vers video_publish_screen

---

### Lot 14 : Navigation Integration

**Éléments** :
- Modification de `academia_app/lib/main.dart` (ajout des routes)
- Modification de `academia_app/lib/features/student/tabs/student_challenges_tab.dart` (ajout du bouton)

**Dépendances** : Lot 11 (SmartWhiteboardInputScreen), Lot 12 (SmartWhiteboardEditorScreen), Lot 13 (SmartWhiteboardPreviewScreen)

**Critères de réussite** :
- Routes ajoutées avec succès
- Bouton ajouté avec succès
- Navigation fonctionne
- Aucune modification des parcours existants

**Critères d'échec** :
- Erreurs de compilation
- Navigation ne fonctionne pas
- Modification des parcours existants

**Points de contrôle** :
- Tester la navigation depuis le bouton
- Tester que les parcours Filmer et Importer fonctionnent toujours
- Vérifier qu'aucun fichier protégé n'est modifié

---

### Lot 15 : Backend Kamatera

**Éléments** :
- `academia_bobodo_backend/whiteboard/whiteboard_main.py`
- `academia_bobodo_backend/whiteboard/whiteboard_render_worker.py`
- `academia_bobodo_backend/whiteboard/image_generator.py`
- `academia_bobodo_backend/whiteboard/video_assembler.py`
- `academia_bobodo_backend/whiteboard/requirements.txt`
- `academia_bobodo_backend/whiteboard/Dockerfile`
- `academia_bobodo_backend/docker-compose.whiteboard.yml`

**Dépendances** : Lot 3 (RPCs Supabase), Lot 4 (Buckets Supabase)

**Validation requise** : Via RPC Python administrateurs dans `.windsurf`

**Critères de réussite** :
- Backend compile sans erreur
- Backend peut télécharger un Storyboard JSON
- Backend peut télécharger une narration audio
- Backend peut générer des images PNG
- Backend peut assembler des images en MP4
- Backend peut uploader le MP4 vers Supabase Storage
- Backend peut mettre à jour le statut de rendu
- Worker peut poller les jobs de rendu

**Critères d'échec** :
- Erreurs de compilation
- Backend ne peut pas générer des images
- Backend ne peut pas assembler des images en MP4
- Worker ne peut pas poller les jobs

**Points de contrôle** :
- Via RPC : Tester la génération d'images PNG
- Via RPC : Tester l'assemblage MP4
- Via RPC : Tester l'upload vers Supabase Storage
- Via RPC : Tester le polling des jobs de rendu
- Via RPC : Vérifier que Kamatera peut exécuter FFmpeg

---

### Lot 16 : Edge Function whiteboard-render

**Éléments** :
- `supabase/functions/whiteboard-render/index.ts`

**Dépendances** : Lot 3 (RPCs Supabase), Lot 4 (Buckets Supabase)

**Critères de réussite** :
- Edge Function compile sans erreur
- Edge Function peut être déployée
- Edge Function peut être appelée
- Edge Function peut déclencher le rendu

**Critères d'échec** :
- Erreurs de compilation
- Edge Function ne peut pas être déployée
- Edge Function ne peut pas être appelée

**Points de contrôle** :
- Tester le déploiement de l'Edge Function
- Tester l'appel de l'Edge Function
- Vérifier que l'Edge Function déclenche le rendu

---

### Lot 17 : Déploiement Kamatera

**Éléments** :
- Déploiement de Docker Compose sur Kamatera
- Configuration des variables d'environnement

**Dépendances** : Lot 15 (Backend Kamatera)

**Validation requise** : Via RPC Python administrateurs dans `.windsurf`

**Critères de réussite** :
- Conteneurs démarrés avec succès
- Backend accessible via HTTP
- Worker actif
- Aucun conflit avec les services existants

**Critères d'échec** :
- Conteneurs ne démarrent pas
- Backend non accessible
- Worker non actif
- Conflit avec les services existants

**Points de contrôle** :
- Via RPC : Vérifier que les conteneurs sont actifs
- Via RPC : Vérifier que le backend est accessible
- Via RPC : Vérifier que le worker est actif
- Via RPC : Vérifier que LiveKit fonctionne toujours

---

### Lot 18 : Intégration Finale

**Éléments** :
- Test du flux complet
- Test de l'intégration avec video_publish_screen

**Dépendances** : Lot 14 (Navigation Integration), Lot 17 (Déploiement Kamatera)

**Critères de réussite** :
- Flux complet fonctionne
- MP4 généré avec succès
- Navigation vers video_publish_screen fonctionne
- Publication fonctionne
- Parcours existants non modifiés

**Critères d'échec** :
- Flux complet ne fonctionne pas
- MP4 non généré
- Navigation ne fonctionne pas
- Publication ne fonctionne pas
- Parcours existants modifiés

**Points de contrôle** :
- Tester le flux complet (sujet → Storyboard → édition → narration → rendu → publication)
- Tester que les parcours Filmer et Importer fonctionnent toujours
- Vérifier que la compression Kamatera fonctionne toujours
- Vérifier que la publication fonctionne toujours

---

## PARTIE 4 – TESTS DE VALIDATION

### 4.1 Lot 1 : Modèles Storyboard

**Critères de réussite** :
- Modèles compilent sans erreur
- Modèles correspondent au schéma JSON

**Critères d'échec** :
- Erreurs de compilation
- Modèles ne correspondent pas au schéma JSON

**Points de contrôle** :
- Vérifier que tous les types de blocs V1 sont définis
- Vérifier que les métadonnées V1 sont définies

---

### 4.2 Lot 2 : Tables Supabase

**Critères de réussite** :
- Tables créées avec succès
- Tables correspondent au schéma

**Critères d'échec** :
- Tables existent déjà
- Erreurs de création

**Points de contrôle** :
- Via RPC : Vérifier que les tables n'existent pas déjà
- Via RPC : Vérifier que les colonnes sont correctes

---

### 4.3 Lot 3 : RPCs Supabase

**Critères de réussite** :
- RPCs créés avec succès
- RPCs correspondent au schéma

**Critères d'échec** :
- RPCs existent déjà
- Erreurs de création

**Points de contrôle** :
- Via RPC : Tester chaque RPC avec des données de test

---

### 4.4 Lot 4 : Buckets Supabase

**Critères de réussite** :
- Buckets créés avec succès
- Buckets correspondent au schéma

**Critères d'échec** :
- Buckets existent déjà
- Erreurs de création

**Points de contrôle** :
- Via RPC : Tester l'upload d'un fichier de test

---

### 4.5 Lot 5 : RLS Policies

**Critères de réussite** :
- Policies créées avec succès
- Policies correspondent au schéma

**Critères d'échec** :
- Policies existent déjà
- Erreurs de création

**Points de contrôle** :
- Via RPC : Tester les permissions avec un utilisateur test

---

### 4.6 Lot 6 : SmartWhiteboardService

**Critères de réussite** :
- Service compile sans erreur
- Service peut appeler les RPCs

**Critères d'échec** :
- Erreurs de compilation
- Erreurs d'appel RPC

**Points de contrôle** :
- Tester la création d'un projet via RPC

---

### 4.7 Lot 7 : SmartWhiteboardNarrationService

**Critères de réussite** :
- Service compile sans erreur
- Service peut enregistrer l'audio

**Critères d'échec** :
- Erreurs de compilation
- Erreurs d'enregistrement audio

**Points de contrôle** :
- Tester l'enregistrement audio

---

### 4.8 Lot 8 : SmartWhiteboardRenderService

**Critères de réussite** :
- Service compile sans erreur
- Service peut créer un job de rendu

**Critères d'échec** :
- Erreurs de compilation
- Erreurs d'appel RPC

**Points de contrôle** :
- Tester la création d'un job de rendu via RPC

---

### 4.9 Lot 9 : SmartWhiteboardProvider

**Critères de réussite** :
- Provider compile sans erreur
- Provider peut gérer l'état

**Critères d'échec** :
- Erreurs de compilation
- Provider ne peut pas gérer l'état

**Points de contrôle** :
- Tester la création d'un Storyboard

---

### 4.10 Lot 10 : WhiteboardBlockWidget

**Critères de réussite** :
- Widget compile sans erreur
- Widget peut afficher un bloc

**Critères d'échec** :
- Erreurs de compilation
- Widget ne peut pas afficher un bloc

**Points de contrôle** :
- Tester l'affichage d'un bloc title

---

### 4.11 Lot 11 : SmartWhiteboardInputScreen

**Critères de réussite** :
- Écran compile sans erreur
- Écran peut saisir un sujet

**Critères d'échec** :
- Erreurs de compilation
- Écran ne peut pas saisir un sujet

**Points de contrôle** :
- Tester la saisie d'un sujet

---

### 4.12 Lot 12 : SmartWhiteboardEditorScreen

**Critères de réussite** :
- Écran compile sans erreur
- Écran peut éditer les blocs

**Critères d'échec** :
- Erreurs de compilation
- Écran ne peut pas éditer les blocs

**Points de contrôle** :
- Tester l'édition du texte des blocs

---

### 4.13 Lot 13 : SmartWhiteboardPreviewScreen

**Critères de réussite** :
- Écran compile sans erreur
- Écran peut créer un job de rendu

**Critères d'échec** :
- Erreurs de compilation
- Écran ne peut pas créer un job de rendu

**Points de contrôle** :
- Tester la création d'un job de rendu

---

### 4.14 Lot 14 : Navigation Integration

**Critères de réussite** :
- Routes ajoutées avec succès
- Navigation fonctionne

**Critères d'échec** :
- Erreurs de compilation
- Navigation ne fonctionne pas

**Points de contrôle** :
- Tester la navigation depuis le bouton

---

### 4.15 Lot 15 : Backend Kamatera

**Critères de réussite** :
- Backend compile sans erreur
- Backend peut générer des images

**Critères d'échec** :
- Erreurs de compilation
- Backend ne peut pas générer des images

**Points de contrôle** :
- Via RPC : Tester la génération d'images PNG

---

### 4.16 Lot 16 : Edge Function whiteboard-render

**Critères de réussite** :
- Edge Function compile sans erreur
- Edge Function peut être déployée

**Critères d'échec** :
- Erreurs de compilation
- Edge Function ne peut pas être déployée

**Points de contrôle** :
- Tester le déploiement de l'Edge Function

---

### 4.17 Lot 17 : Déploiement Kamatera

**Critères de réussite** :
- Conteneurs démarrés avec succès
- Backend accessible

**Critères d'échec** :
- Conteneurs ne démarrent pas
- Backend non accessible

**Points de contrôle** :
- Via RPC : Vérifier que les conteneurs sont actifs

---

### 4.18 Lot 18 : Intégration Finale

**Critères de réussite** :
- Flux complet fonctionne
- Parcours existants non modifiés

**Critères d'échec** :
- Flux complet ne fonctionne pas
- Parcours existants modifiés

**Points de contrôle** :
- Tester le flux complet
- Tester que les parcours Filmer et Importer fonctionnent toujours

---

## PARTIE 5 – POINTS DE NON-RÉGRESSION

### 5.1 Parcours Filmer

**Composants à vérifier** :
- `challenge_camera_capture_screen.dart`
- `student_challenge_video_editor_screen.dart`
- `video_publish_screen.dart`

**Tests** :
- Capturer une vidéo
- Éditer la vidéo
- Publier la vidéo
- Vérifier que la vidéo est visible dans le feed

**Critères de réussite** :
- Toutes les étapes fonctionnent
- Aucune modification du comportement

**Critères d'échec** :
- Une étape ne fonctionne pas
- Modification du comportement

---

### 5.2 Parcours Importer

**Composants à vérifier** :
- `student_challenge_video_editor_screen.dart`
- `video_publish_screen.dart`

**Tests** :
- Importer une vidéo
- Éditer la vidéo
- Publier la vidéo
- Vérifier que la vidéo est visible dans le feed

**Critères de réussite** :
- Toutes les étapes fonctionnent
- Aucune modification du comportement

**Critères d'échec** :
- Une étape ne fonctionne pas
- Modification du comportement

---

### 5.3 Publication

**Composants à vérifier** :
- `video_publish_screen.dart`
- `videoasset_upload_service.dart`

**Tests** :
- Publier une vidéo
- Vérifier que la vidéo est visible dans le feed
- Vérifier que les hashtags sont corrects
- Vérifier que la visibilité est correcte

**Critères de réussite** :
- Toutes les étapes fonctionnent
- Aucune modification du comportement

**Critères d'échec** :
- Une étape ne fonctionne pas
- Modification du comportement

---

### 5.4 Compression Kamatera

**Composants à vérifier** :
- Edge Functions de compression
- Pipeline de compression

**Tests** :
- Publier une vidéo
- Vérifier que la compression fonctionne
- Vérifier que les renditions sont générées

**Critères de réussite** :
- Toutes les étapes fonctionnent
- Aucune modification du comportement

**Critères d'échec** :
- Une étape ne fonctionne pas
- Modification du comportement

---

### 5.5 Upload

**Composants à vérifier** :
- `videoasset_upload_service.dart`
- Buckets Supabase

**Tests** :
- Uploader une vidéo
- Vérifier que la vidéo est stockée
- Vérifier que les renditions sont générées

**Critères de réussite** :
- Toutes les étapes fonctionnent
- Aucune modification du comportement

**Critères d'échec** :
- Une étape ne fonctionne pas
- Modification du comportement

---

## PARTIE 6 – CHECKLIST AVANT COMMIT

### 6.1 Checklist Lot 1 : Modèles Storyboard

- [ ] Modèles compilent sans erreur
- [ ] Modèles correspondent au schéma JSON
- [ ] Tous les types de blocs V1 sont définis
- [ ] Métadonnées V1 sont définies

### 6.2 Checklist Lot 2 : Tables Supabase

- [ ] Tables créées avec succès
- [ ] Tables correspondent au schéma
- [ ] Tables n'existent pas déjà
- [ ] Colonnes sont correctes
- [ ] Indexes sont créés

### 6.3 Checklist Lot 3 : RPCs Supabase

- [ ] RPCs créés avec succès
- [ ] RPCs correspondent au schéma
- [ ] RPCs n'existent pas déjà
- [ ] Chaque RPC testé avec des données de test
- [ ] Retours sont corrects

### 6.4 Checklist Lot 4 : Buckets Supabase

- [ ] Buckets créés avec succès
- [ ] Buckets correspondent au schéma
- [ ] Buckets n'existent pas déjà
- [ ] Buckets sont publics/privés selon le besoin
- [ ] Upload d'un fichier de test fonctionne

### 6.5 Checklist Lot 5 : RLS Policies

- [ ] Policies créées avec succès
- [ ] Policies correspondent au schéma
- [ ] Policies n'existent pas déjà
- [ ] Permissions testées avec un utilisateur test
- [ ] Policies sont correctes

### 6.6 Checklist Lot 6 : SmartWhiteboardService

- [ ] Service compile sans erreur
- [ ] Service peut appeler les RPCs
- [ ] Service peut créer un projet
- [ ] Service peut mettre à jour un projet
- [ ] Service peut récupérer un projet
- [ ] Service peut lister les projets
- [ ] Service peut supprimer un projet

### 6.7 Checklist Lot 7 : SmartWhiteboardNarrationService

- [ ] Service compile sans erreur
- [ ] Service peut enregistrer l'audio utilisateur
- [ ] Service peut générer du TTS
- [ ] Service peut uploader l'audio vers Supabase Storage
- [ ] Fichier est bien stocké dans le bucket

### 6.8 Checklist Lot 8 : SmartWhiteboardRenderService

- [ ] Service compile sans erreur
- [ ] Service peut créer un job de rendu
- [ ] Service peut récupérer le statut d'un rendu
- [ ] Service peut poller le statut d'un rendu

### 6.9 Checklist Lot 9 : SmartWhiteboardProvider

- [ ] Provider compile sans erreur
- [ ] Provider peut gérer l'état du Storyboard
- [ ] Provider peut gérer l'état de génération Bobodo
- [ ] Provider peut gérer l'état de rendu
- [ ] Provider peut notifier les listeners

### 6.10 Checklist Lot 10 : WhiteboardBlockWidget

- [ ] Widget compile sans erreur
- [ ] Widget peut afficher un bloc title
- [ ] Widget peut afficher un bloc paragraph
- [ ] Widget peut afficher un bloc formula
- [ ] Widget peut afficher un bloc definition
- [ ] Widget peut afficher un bloc exercise
- [ ] Widget peut afficher un bloc correction

### 6.11 Checklist Lot 11 : SmartWhiteboardInputScreen

- [ ] Écran compile sans erreur
- [ ] Écran peut saisir un sujet
- [ ] Écran peut générer un Storyboard via Bobodo
- [ ] Écran peut naviguer vers l'écran d'édition
- [ ] Storyboard généré est valide

### 6.12 Checklist Lot 12 : SmartWhiteboardEditorScreen

- [ ] Écran compile sans erreur
- [ ] Écran peut afficher les blocs
- [ ] Écran peut éditer le texte des blocs
- [ ] Écran peut réorganiser les blocs
- [ ] Écran peut supprimer des blocs
- [ ] Écran peut ajouter des blocs
- [ ] Écran peut naviguer vers l'écran de prévisualisation

### 6.13 Checklist Lot 13 : SmartWhiteboardPreviewScreen

- [ ] Écran compile sans erreur
- [ ] Écran peut afficher les blocs avec animation fade_in
- [ ] Écran peut enregistrer la narration
- [ ] Écran peut générer du TTS
- [ ] Écran peut créer un job de rendu
- [ ] Écran peut poller le statut de rendu
- [ ] Écran peut naviguer vers video_publish_screen

### 6.14 Checklist Lot 14 : Navigation Integration

- [ ] Routes ajoutées avec succès
- [ ] Bouton ajouté avec succès
- [ ] Navigation fonctionne
- [ ] Aucune modification des parcours existants
- [ ] Parcours Filmer fonctionne toujours
- [ ] Parcours Importer fonctionne toujours

### 6.15 Checklist Lot 15 : Backend Kamatera

- [ ] Backend compile sans erreur
- [ ] Backend peut télécharger un Storyboard JSON
- [ ] Backend peut télécharger une narration audio
- [ ] Backend peut générer des images PNG
- [ ] Backend peut assembler des images en MP4
- [ ] Backend peut uploader le MP4 vers Supabase Storage
- [ ] Backend peut mettre à jour le statut de rendu
- [ ] Worker peut poller les jobs de rendu

### 6.16 Checklist Lot 16 : Edge Function whiteboard-render

- [ ] Edge Function compile sans erreur
- [ ] Edge Function peut être déployée
- [ ] Edge Function peut être appelée
- [ ] Edge Function peut déclencher le rendu

### 6.17 Checklist Lot 17 : Déploiement Kamatera

- [ ] Conteneurs démarrés avec succès
- [ ] Backend accessible via HTTP
- [ ] Worker actif
- [ ] Aucun conflit avec les services existants
- [ ] LiveKit fonctionne toujours

### 6.18 Checklist Lot 18 : Intégration Finale

- [ ] Flux complet fonctionne
- [ ] MP4 généré avec succès
- [ ] Navigation vers video_publish_screen fonctionne
- [ ] Publication fonctionne
- [ ] Parcours Filmer fonctionne toujours
- [ ] Parcours Importer fonctionne toujours
- [ ] Compression Kamatera fonctionne toujours
- [ ] Upload fonctionne toujours

---

## CONCLUSION

Ce plan d'implémentation permet de construire le Smart Whiteboard IA V1 étape par étape sans toucher aux composants protégés.

Chaque lot est indépendant et peut être validé séparément.

Les points de non-régression garantissent que les parcours existants ne sont pas modifiés.

La checklist avant commit garantit que chaque étape est validée avant de passer à la suivante.

---

**Fin du document**
