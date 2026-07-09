# PHASE D.6B – REAL USER FLOW TESTS

**Date** : 24 Juin 2026  
**Phase** : D.6B – Product Integration and Real User Validation  
**Composant** : Smart Whiteboard Real User Flow Tests

---

## OBJECTIF

Tester les 4 modes réels du Smart Whiteboard pour valider le flux utilisateur complet :
- Mode A : Sujet simple
- Mode B : Texte complet
- Mode C : Plan
- Mode D : Cours existant

Pour chaque mode, tester :
- Génération
- Édition
- Sauvegarde
- Rendu
- Récupération MP4

---

## 1. MODE A – SUJET SIMPLE

### 1.1 Scénario de test

**Sujet** : "Dérivée d'une fonction"  
**Thème** : Scientifique  
**Renderer** : Scientifique  
**Narration** : Aucune

### 1.2 Procédure de test

#### Étape 1 : Création du projet
1. Ouvrir l'application Academia
2. Naviguer vers l'onglet Challenge
3. Cliquer sur le bouton "+"
4. Sélectionner "Smart Whiteboard"
5. Sélectionner "Mode A : Sujet simple"
6. Saisir "Dérivée d'une fonction" dans le champ Sujet
7. Sélectionner Thème "Scientifique"
8. Sélectionner Renderer "Scientifique"
9. Sélectionner Narration "Aucune"
10. Cliquer sur "Générer le Storyboard"

#### Étape 2 : Génération du storyboard
1. Attendre la génération (Edge Function whiteboard-generate-storyboard)
2. Vérifier que le storyboard est généré avec succès
3. Vérifier que les crédits sont déduits (15 crédits)
4. Vérifier que l'écran d'édition s'ouvre automatiquement

#### Étape 3 : Édition du storyboard
1. Vérifier que les scènes sont affichées
2. Vérifier que les blocs sont affichés (titre, paragraphe, formule, etc.)
3. Modifier le contenu d'un bloc
4. Ajouter un nouveau bloc
5. Supprimer un bloc
6. Déplacer un bloc (haut/bas)
7. Cliquer sur "Sauvegarder"

#### Étape 4 : Sauvegarde
1. Vérifier que le storyboard est sauvegardé avec succès
2. Vérifier que le message "Storyboard sauvegardé" s'affiche
3. Vérifier que l'écran se ferme

#### Étape 5 : Rendu
1. Créer un job de rendu (via SmartWhiteboardRenderService)
2. Attendre le traitement (worker Kamatera)
3. Vérifier que le statut passe de "queued" → "processing" → "done"
4. Vérifier que l'URL MP4 est générée

#### Étape 6 : Récupération MP4
1. Récupérer l'URL MP4 via SmartWhiteboardRenderService
2. Vérifier que l'URL est accessible (HTTP 200)
3. Vérifier que le fichier MP4 est valide (Content-Type: video/mp4)
4. Lire le MP4 dans l'application

### 1.3 Critères de succès

- ✅ Le projet est créé avec succès
- ✅ Le storyboard est généré avec succès
- ✅ Les crédits sont déduits correctement
- ✅ L'écran d'édition s'ouvre automatiquement
- ✅ Les scènes et blocs sont affichés correctement
- ✅ L'édition fonctionne (ajout, suppression, déplacement)
- ✅ La sauvegarde fonctionne
- ✅ Le rendu est traité avec succès
- ✅ L'URL MP4 est générée et accessible
- ✅ Le MP4 est lisible

---

## 2. MODE B – TEXTE COMPLET

### 2.1 Scénario de test

**Sujet** : "Théorème de Pythagore"  
**Contenu** : Texte complet expliquant le théorème  
**Thème** : Cahier  
**Renderer** : Cahier  
**Narration** : TTS

### 2.2 Procédure de test

#### Étape 1 : Création du projet
1. Ouvrir l'application Academia
2. Naviguer vers l'onglet Challenge
3. Cliquer sur le bouton "+"
4. Sélectionner "Smart Whiteboard"
5. Sélectionner "Mode B : Texte complet"
6. Saisir "Théorème de Pythagore" dans le champ Sujet
7. Coller le texte complet dans le champ Contenu
8. Sélectionner Thème "Cahier"
9. Sélectionner Renderer "Cahier"
10. Sélectionner Narration "TTS"
11. Cliquer sur "Générer le Storyboard"

#### Étape 2 : Génération du storyboard
1. Attendre la génération (Edge Function whiteboard-generate-storyboard)
2. Vérifier que le storyboard est généré avec succès
3. Vérifier que les crédits sont déduits (15 crédits)
4. Vérifier que l'écran d'édition s'ouvre automatiquement

#### Étape 3 : Édition du storyboard
1. Vérifier que les scènes sont affichées
2. Vérifier que les blocs sont affichés
3. Modifier le contenu d'un bloc
4. Ajouter un nouveau bloc
5. Supprimer un bloc
6. Déplacer un bloc (haut/bas)
7. Cliquer sur "Sauvegarder"

#### Étape 4 : Sauvegarde
1. Vérifier que le storyboard est sauvegardé avec succès
2. Vérifier que le message "Storyboard sauvegardé" s'affiche
3. Vérifier que l'écran se ferme

#### Étape 5 : Rendu
1. Créer un job de rendu (via SmartWhiteboardRenderService)
2. Attendre le traitement (worker Kamatera)
3. Vérifier que le statut passe de "queued" → "processing" → "done"
4. Vérifier que l'URL MP4 est générée

#### Étape 6 : Récupération MP4
1. Récupérer l'URL MP4 via SmartWhiteboardRenderService
2. Vérifier que l'URL est accessible (HTTP 200)
3. Vérifier que le fichier MP4 est valide (Content-Type: video/mp4)
4. Lire le MP4 dans l'application

### 2.3 Critères de succès

- ✅ Le projet est créé avec succès
- ✅ Le storyboard est généré avec succès
- ✅ Les crédits sont déduits correctement
- ✅ L'écran d'édition s'ouvre automatiquement
- ✅ Les scènes et blocs sont affichés correctement
- ✅ L'édition fonctionne (ajout, suppression, déplacement)
- ✅ La sauvegarde fonctionne
- ✅ Le rendu est traité avec succès
- ✅ L'URL MP4 est générée et accessible
- ✅ Le MP4 est lisible

---

## 3. MODE C – PLAN

### 3.1 Scénario de test

**Sujet** : "Les équations différentielles"  
**Contenu** : Plan structuré (I. Définition, II. Types, III. Résolution, IV. Applications)  
**Thème** : Scientifique  
**Renderer** : Scientifique  
**Narration** : Enregistrement

### 3.2 Procédure de test

#### Étape 1 : Création du projet
1. Ouvrir l'application Academia
2. Naviguer vers l'onglet Challenge
3. Cliquer sur le bouton "+"
4. Sélectionner "Smart Whiteboard"
5. Sélectionner "Mode C : Plan"
6. Saisir "Les équations différentielles" dans le champ Sujet
7. Coller le plan dans le champ Contenu
8. Sélectionner Thème "Scientifique"
9. Sélectionner Renderer "Scientifique"
10. Sélectionner Narration "Enregistrement"
11. Cliquer sur "Générer le Storyboard"

#### Étape 2 : Génération du storyboard
1. Attendre la génération (Edge Function whiteboard-generate-storyboard)
2. Vérifier que le storyboard est généré avec succès
3. Vérifier que les crédits sont déduits (15 crédits)
4. Vérifier que l'écran d'édition s'ouvre automatiquement

#### Étape 3 : Édition du storyboard
1. Vérifier que les scènes sont affichées
2. Vérifier que les blocs sont affichés
3. Modifier le contenu d'un bloc
4. Ajouter un nouveau bloc
5. Supprimer un bloc
6. Déplacer un bloc (haut/bas)
7. Cliquer sur "Sauvegarder"

#### Étape 4 : Sauvegarde
1. Vérifier que le storyboard est sauvegardé avec succès
2. Vérifier que le message "Storyboard sauvegardé" s'affiche
3. Vérifier que l'écran se ferme

#### Étape 5 : Rendu
1. Créer un job de rendu (via SmartWhiteboardRenderService)
2. Attendre le traitement (worker Kamatera)
3. Vérifier que le statut passe de "queued" → "processing" → "done"
4. Vérifier que l'URL MP4 est générée

#### Étape 6 : Récupération MP4
1. Récupérer l'URL MP4 via SmartWhiteboardRenderService
2. Vérifier que l'URL est accessible (HTTP 200)
3. Vérifier que le fichier MP4 est valide (Content-Type: video/mp4)
4. Lire le MP4 dans l'application

### 3.3 Critères de succès

- ✅ Le projet est créé avec succès
- ✅ Le storyboard est généré avec succès
- ✅ Les crédits sont déduits correctement
- ✅ L'écran d'édition s'ouvre automatiquement
- ✅ Les scènes et blocs sont affichés correctement
- ✅ L'édition fonctionne (ajout, suppression, déplacement)
- ✅ La sauvegarde fonctionne
- ✅ Le rendu est traité avec succès
- ✅ L'URL MP4 est générée et accessible
- ✅ Le MP4 est lisible

---

## 4. MODE D – COURS EXISTANT

### 4.1 Scénario de test

**Sujet** : "La photosynthèse"  
**Contenu** : Contenu complet d'un cours existant  
**Thème** : Cahier  
**Renderer** : Cahier  
**Narration** : Aucune

### 4.2 Procédure de test

#### Étape 1 : Création du projet
1. Ouvrir l'application Academia
2. Naviguer vers l'onglet Challenge
3. Cliquer sur le bouton "+"
4. Sélectionner "Smart Whiteboard"
5. Sélectionner "Mode D : Cours existant"
6. Saisir "La photosynthèse" dans le champ Sujet
7. Coller le contenu du cours dans le champ Contenu
8. Sélectionner Thème "Cahier"
9. Sélectionner Renderer "Cahier"
10. Sélectionner Narration "Aucune"
11. Cliquer sur "Générer le Storyboard"

#### Étape 2 : Génération du storyboard
1. Attendre la génération (Edge Function whiteboard-generate-storyboard)
2. Vérifier que le storyboard est généré avec succès
3. Vérifier que les crédits sont déduits (15 crédits)
4. Vérifier que l'écran d'édition s'ouvre automatiquement

#### Étape 3 : Édition du storyboard
1. Vérifier que les scènes sont affichées
2. Vérifier que les blocs sont affichés
3. Modifier le contenu d'un bloc
4. Ajouter un nouveau bloc
5. Supprimer un bloc
6. Déplacer un bloc (haut/bas)
7. Cliquer sur "Sauvegarder"

#### Étape 4 : Sauvegarde
1. Vérifier que le storyboard est sauvegardé avec succès
2. Vérifier que le message "Storyboard sauvegardé" s'affiche
3. Vérifier que l'écran se ferme

#### Étape 5 : Rendu
1. Créer un job de rendu (via SmartWhiteboardRenderService)
2. Attendre le traitement (worker Kamatera)
3. Vérifier que le statut passe de "queued" → "processing" → "done"
4. Vérifier que l'URL MP4 est générée

#### Étape 6 : Récupération MP4
1. Récupérer l'URL MP4 via SmartWhiteboardRenderService
2. Vérifier que l'URL est accessible (HTTP 200)
3. Vérifier que le fichier MP4 est valide (Content-Type: video/mp4)
4. Lire le MP4 dans l'application

### 4.3 Critères de succès

- ✅ Le projet est créé avec succès
- ✅ Le storyboard est généré avec succès
- ✅ Les crédits sont déduits correctement
- ✅ L'écran d'édition s'ouvre automatiquement
- ✅ Les scènes et blocs sont affichés correctement
- ✅ L'édition fonctionne (ajout, suppression, déplacement)
- ✅ La sauvegarde fonctionne
- ✅ Le rendu est traité avec succès
- ✅ L'URL MP4 est générée et accessible
- ✅ Le MP4 est lisible

---

## 5. RÉSULTATS ATTENDUS

### 5.1 Tableau de résultats

| Mode | Création | Génération | Édition | Sauvegarde | Rendu | MP4 | Statut |
| ---- | -------- | ---------- | ------- | ---------- | ----- | --- | ------ |
| A | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | À tester |
| B | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | À tester |
| C | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | À tester |
| D | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | À tester |

### 5.2 Problèmes potentiels

- **Génération** : Edge Function whiteboard-generate-storyboard peut échouer si les crédits sont insuffisants
- **Édition** : L'écran d'édition peut ne pas s'ouvrir automatiquement (placeholder screen)
- **Sauvegarde** : La sauvegarde peut échouer si le storyboard n'est pas valide
- **Rendu** : Le worker Kamatera peut échouer si le storyboard est mal formé
- **MP4** : L'URL MP4 peut ne pas être accessible si le rendu échoue

---

## 6. INSTRUCTIONS DE TEST

### 6.1 Prérequis

- Application Academia installée sur un appareil Android
- Compte utilisateur avec au moins 60 crédits (4 tests × 15 crédits)
- Connexion internet stable
- Accès à Kamatera (worker actif)

### 6.2 Exécution des tests

1. Lancer l'application Academia
2. Se connecter avec un compte utilisateur
3. Vérifier le solde de crédits (≥ 60)
4. Exécuter les tests pour chaque mode (A, B, C, D)
5. Noter les résultats dans le tableau ci-dessus
6. Documenter les problèmes rencontrés

### 6.3 Rapport de test

Pour chaque mode, documenter :
- Temps de génération du storyboard
- Temps de rendu de la vidéo
- Qualité du storyboard généré
- Qualité de la vidéo rendue
- Erreurs rencontrées
- Suggestions d'amélioration

---

## 7. CONCLUSION

Les tests des 4 modes réels permettront de valider le flux utilisateur complet du Smart Whiteboard. Les résultats seront utilisés pour :

- Valider l'intégration Flutter
- Identifier les problèmes de performance
- Mesurer la qualité pédagogique
- Évaluer la qualité vidéo
- Calculer les coûts réels
- Décider du GO/NO-GO pour la bêta utilisateurs

---

**Fin de PHASE_D6B_REAL_USER_FLOW_TESTS.md**
