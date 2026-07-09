# ACADEMIA ENGINEERING LOGBOOK

**Date** : 24 Juin 2026  
**Version** : 1.0  
**Statut** : ACTIF

---

## OBJECTIF

Conserver la mémoire du raisonnement technique. Dans plusieurs mois, un nouvel agent doit comprendre :
- Pourquoi une solution a été retenue
- Pourquoi une autre a été abandonnée
- Quels problèmes réels ont été rencontrés
- Quelles erreurs ne doivent jamais être reproduites

Ce document ne remplace ni les ADR ni les rapports de phase. Il explique le contexte technique ayant conduit aux décisions.

---

## FORMAT D'ENTRÉE

Pour chaque décision technique importante, documenter systématiquement :

- **Date**
- **Phase**
- **Contexte**
- **Problème rencontré**
- **Analyse effectuée**
- **Solutions envisagées**
- **Solution retenue**
- **Raisons du choix**
- **Alternatives rejetées**
- **Conséquences**
- **Documents impactés**
- **ADR associé**
- **Contrats impactés**
- **Traçabilité**

---

## JOURNAL DES DÉCISIONS TECHNIQUES

### ENTRY-001 : Séparation Bobodo / Smart Whiteboard

**Date** : 24 Juin 2026  
**Phase** : D.6H – Knowledge Preservation Lock

**Contexte** :
Le projet Academia comprend deux modules d'IA : Bobodo Assistant et Smart Whiteboard. Bobodo est un assistant utilisateur, Smart Whiteboard est un générateur pédagogique de vidéos.

**Problème rencontré** :
Risque de confusion entre les responsabilités de Bobodo et Smart Whiteboard, notamment en ce qui concerne la génération de contenu pédagogique. Les équipes pourraient être tentées d'utiliser Bobodo pour générer des storyboards, ce qui n'est pas sa fonction.

**Analyse effectuée** :
- Analyse des besoins métier de chaque module
- Analyse des capacités des modèles d'IA
- Analyse des coûts d'OpenRouter
- Analyse de l'expérience utilisateur

**Solutions envisagées** :
1. Fusionner Bobodo et Smart Whiteboard en un seul module
2. Séparer clairement les responsabilités de chaque module
3. Utiliser Bobodo pour la génération de storyboards Smart Whiteboard

**Solution retenue** :
Séparation claire des responsabilités : Bobodo est un assistant utilisateur, Smart Whiteboard est un générateur pédagogique.

**Raisons du choix** :
- Bobodo doit se concentrer sur l'assistance utilisateur (orientation, aide, FAQ)
- Smart Whiteboard doit se concentrer sur la génération pédagogique (storyboards, vidéos)
- Éviter la confusion des responsabilités
- Permettre une évolution indépendante de chaque module
- Optimiser les coûts d'OpenRouter (modèles différents)

**Alternatives rejetées** :
- Fusion : Trop complexe, mélange des responsabilités
- Bobodo pour storyboards : Pas adapté aux besoins pédagogiques

**Conséquences** :
- Bobodo ne génère jamais de storyboards
- Smart Whiteboard n'assiste jamais les utilisateurs
- Chaque module a ses propres modèles d'IA
- Chaque module a ses propres interfaces utilisateur

**Documents impactés** :
- ACADEMIA_TECHNICAL_CONSTITUTION.md
- ACADEMIA_ARCHITECTURE_DECISIONS.md

**ADR associé** :
- ADR-001 : Séparation Bobodo / Smart Whiteboard

**Contrats impactés** :
- Aucun (décision architecturale)

**Traçabilité** :
- Bobodo Assistant : Assistant utilisateur uniquement
- Smart Whiteboard : Génération pédagogique uniquement

---

### ENTRY-002 : Utilisation d'OpenRouter comme moteur de génération pédagogique

**Date** : 24 Juin 2026  
**Phase** : D.6H – Knowledge Preservation Lock

**Contexte** :
Le Smart Whiteboard nécessite un moteur d'IA pour générer des storyboards pédagogiques à partir de sujets.

**Problème rencontré** :
Choix du moteur d'IA pour la génération de storyboards. Plusieurs options disponibles (OpenAI, Anthropic, Google, agrégateurs).

**Analyse effectuée** :
- Comparaison des coûts des différents fournisseurs
- Comparaison de la qualité des modèles
- Comparaison de la disponibilité des modèles
- Analyse de la flexibilité pour changer de modèle

**Solutions envisagées** :
1. Utiliser OpenAI GPT-4
2. Utiliser Anthropic Claude directement
3. Utiliser Google Gemini
4. Utiliser OpenRouter (agrégateur de modèles)

**Solution retenue** :
Utiliser OpenRouter comme moteur de génération pédagogique, avec Claude 3.5 Sonnet comme modèle principal.

**Raisons du choix** :
- OpenRouter permet de changer de modèle facilement
- Claude 3.5 Sonnet offre le meilleur rapport qualité/prix pour la génération pédagogique
- Flexibilité pour tester d'autres modèles si nécessaire
- Coût compétitif
- API unifiée

**Alternatives rejetées** :
- OpenAI GPT-4 : Trop cher, moins flexible
- Anthropic Claude directement : Moins flexible, dépendance unique
- Google Gemini : Qualité inférieure pour la génération pédagogique

**Conséquences** :
- Smart Whiteboard dépend d'OpenRouter
- Nécessité de gérer les clés API OpenRouter
- Possibilité de changer de modèle sans modifier l'architecture
- Coûts dépendants de la consommation OpenRouter

**Documents impactés** :
- ACADEMIA_TECHNICAL_CONSTITUTION.md
- ACADEMIA_ARCHITECTURE_DECISIONS.md
- ACADEMIA_CONTRACT_REGISTRY.md

**ADR associé** :
- ADR-002 : Utilisation d'OpenRouter comme moteur de génération pédagogique

**Contrats impactés** :
- CONTRAT-002 : Edge Function → OpenRouter

**Traçabilité** :
- Smart Whiteboard : Utilise OpenRouter via Edge Function whiteboard-generate-storyboard

---

### ENTRY-003 : Utilisation de Kamatera pour le rendu vidéo

**Date** : 24 Juin 2026  
**Phase** : D.5I – Production Activation Report

**Contexte** :
Le Smart Whiteboard nécessite de générer des vidéos à partir des storyboards. Le rendu vidéo est une opération intensive en CPU/GPU.

**Problème rencontré** :
Choix de l'infrastructure pour le rendu vidéo. Les appareils mobiles n'ont pas la capacité de rendu vidéo.

**Analyse effectuée** :
- Analyse des capacités de rendu des appareils mobiles
- Analyse des capacités de rendu de Supabase Edge Functions
- Analyse des coûts des services de rendu cloud (D-ID, Synthesia)
- Analyse des coûts d'un serveur dédié (Kamatera)

**Solutions envisagées** :
1. Effectuer le rendu sur l'appareil mobile (Flutter)
2. Effectuer le rendu sur Supabase (Edge Functions)
3. Effectuer le rendu sur un serveur dédié (Kamatera)
4. Utiliser un service de rendu cloud (D-ID, Synthesia, etc.)

**Solution retenue** :
Utiliser Kamatera comme infrastructure dédiée au rendu vidéo Smart Whiteboard.

**Raisons du choix** :
- Flutter n'a pas la capacité de rendu vidéo
- Supabase Edge Functions ne sont pas adaptées au rendu vidéo
- Kamatera offre un contrôle total sur le pipeline de rendu
- Coût compétitif par rapport aux services cloud
- Possibilité d'optimiser le pipeline
- Indépendance vis-à-vis des services cloud

**Alternatives rejetées** :
- Flutter : Pas de capacité de rendu
- Supabase Edge Functions : Pas adaptées au rendu vidéo
- Services cloud : Trop cher, dépendance externe

**Conséquences** :
- Smart Whiteboard dépend de Kamatera
- Nécessité de maintenir le worker Kamatera
- Dépendance à l'infrastructure Kamatera
- Contrôle total sur le pipeline de rendu

**Documents impactés** :
- ACADEMIA_TECHNICAL_CONSTITUTION.md
- ACADEMIA_ARCHITECTURE_DECISIONS.md
- ACADEMIA_CONTRACT_REGISTRY.md
- ACADEMIA_TRACEABILITY_MATRIX.md

**ADR associé** :
- ADR-003 : Kamatera responsable du rendu vidéo

**Contrats impactés** :
- CONTRAT-005 : Storyboard → Renderer
- CONTRAT-006 : Renderer → Kamatera

**Traçabilité** :
- Kamatera : Worker Python pour le rendu vidéo
- Smart Whiteboard : Dépend de Kamatera pour le rendu

---

### ENTRY-004 : Renderer Python

**Date** : 24 Juin 2026  
**Phase** : D.5I – Production Activation Report

**Contexte** :
Le rendu vidéo nécessite de transformer les storyboards en vidéos. Plusieurs langages et frameworks sont disponibles.

**Problème rencontré** :
Choix du langage et du framework pour le renderer.

**Analyse effectuée** :
- Analyse des capacités de Python pour le traitement d'images
- Analyse des capacités de FFmpeg pour le rendu vidéo
- Analyse des alternatives (Node.js, Go, Rust)
- Analyse de la facilité de maintenance

**Solutions envisagées** :
1. Renderer en Python avec Pillow + FFmpeg
2. Renderer en Node.js avec Canvas + FFmpeg
3. Renderer en Go avec imaging + FFmpeg
4. Renderer en Rust avec image-rs + FFmpeg

**Solution retenue** :
Renderer en Python avec Pillow pour le rendu PNG et FFmpeg pour l'assemblage MP4.

**Raisons du choix** :
- Python a une excellente bibliothèque de traitement d'images (Pillow)
- FFmpeg est le standard de l'industrie pour le rendu vidéo
- Facilité de maintenance
- Large communauté
- Compatible avec Kamatera

**Alternatives rejetées** :
- Node.js : Moins de bibliothèques de traitement d'images
- Go : Plus complexe, moins de bibliothèques
- Rust : Trop complexe pour ce cas d'usage

**Conséquences** :
- Worker Kamatera en Python
- Dépendance à Pillow et FFmpeg
- Maintenance simplifiée

**Documents impactés** :
- ACADEMIA_TRACEABILITY_MATRIX.md

**ADR associé** :
- Aucun (décision technique, pas architecturale)

**Contrats impactés** :
- CONTRAT-006 : Renderer → Kamatera

**Traçabilité** :
- Kamatera : /opt/whiteboard-worker/whiteboard_png_renderer.py, whiteboard_ffmpeg_assembler.py

---

### ENTRY-005 : Pipeline Storyboard → PNG → FFmpeg → MP4

**Date** : 24 Juin 2026  
**Phase** : D.5I – Production Activation Report

**Contexte** :
Le Smart Whiteboard doit transformer des storyboards en vidéos. Le pipeline de transformation doit être défini.

**Problème rencontré** :
Choix du pipeline de transformation. Plusieurs approches possibles.

**Analyse effectuée** :
- Analyse des différentes approches de rendu
- Analyse de la qualité de rendu
- Analyse de la complexité de mise en œuvre
- Analyse des coûts

**Solutions envisagées** :
1. Storyboard → SVG → MP4
2. Storyboard → Canvas → MP4
3. Storyboard → PNG → FFmpeg → MP4
4. Storyboard → GIF → MP4

**Solution retenue** :
Pipeline Storyboard → PNG → FFmpeg → MP4.

**Raisons du choix** :
- PNG est un format standard, facile à générer
- FFmpeg est le standard de l'industrie pour le rendu vidéo
- Qualité de rendu élevée
- Flexibilité pour les codecs
- Contrôle total sur le pipeline

**Alternatives rejetées** :
- SVG → MP4 : Moins de contrôle sur le rendu
- Canvas → MP4 : Plus complexe, moins de contrôle
- GIF → MP4 : Qualité inférieure

**Conséquences** :
- Pipeline en 3 étapes (PNG, FFmpeg, MP4)
- Dépendance à FFmpeg
- Contrôle total sur le pipeline

**Documents impactés** :
- ACADEMIA_CONTRACT_REGISTRY.md
- ACADEMIA_TRACEABILITY_MATRIX.md

**ADR associé** :
- Aucun (décision technique, pas architecturale)

**Contrats impactés** :
- CONTRAT-006 : Renderer → Kamatera

**Traçabilité** :
- Kamatera : whiteboard_png_renderer.py, whiteboard_ffmpeg_assembler.py

---

### ENTRY-006 : Abandon du rendu Flutter

**Date** : 24 Juin 2026  
**Phase** : D.6H – Knowledge Preservation Lock

**Contexte** :
L'application Flutter Academia doit afficher des vidéos générées par le Smart Whiteboard.

**Problème rencontré** :
Définir les responsabilités de Flutter dans le pipeline de génération vidéo.

**Analyse effectuée** :
- Analyse des capacités de rendu vidéo de Flutter
- Analyse des capacités des appareils mobiles
- Analyse de l'impact sur la batterie
- Analyse de la qualité de rendu

**Solutions envisagées** :
1. Flutter génère les vidéos localement
2. Flutter génère les vidéos via un plugin
3. Flutter affiche uniquement les vidéos générées par Kamatera

**Solution retenue** :
Flutter affiche uniquement les vidéos générées par Kamatera, jamais de génération locale.

**Raisons du choix** :
- Flutter n'a pas les capacités de rendu vidéo
- Génération locale serait trop lourde pour les appareils mobiles
- Impact négatif sur la batterie
- Kamatera offre une qualité de rendu supérieure
- Centralisation du rendu pour optimiser les coûts

**Alternatives rejetées** :
- Génération locale : Pas de capacité, trop lourd
- Plugin : Pas de capacité, trop lourd

**Conséquences** :
- Flutter dépend de Kamatera pour les vidéos
- Aucun plugin de rendu vidéo dans Flutter
- Latence entre la demande et la disponibilité de la vidéo

**Documents impactés** :
- ACADEMIA_TECHNICAL_CONSTITUTION.md
- ACADEMIA_ARCHITECTURE_DECISIONS.md
- ACADEMIA_CONTRACT_REGISTRY.md

**ADR associé** :
- ADR-004 : Flutter ne génère jamais les vidéos

**Contrats impactés** :
- CONTRAT-008 : Storage → Flutter

**Traçabilité** :
- Flutter : Lecture uniquement des vidéos
- Kamatera : Rendu exclusif des vidéos

---

### ENTRY-007 : Choix de execute_ddl

**Date** : 24 Juin 2026  
**Phase** : D.6H – Knowledge Preservation Lock

**Contexte** :
Le projet Academia utilise Supabase comme base de données. Les opérations DDL (CREATE TABLE, ALTER TABLE, etc.) sont nécessaires.

**Problème rencontré** :
Choix de la méthode pour les opérations DDL sur Supabase.

**Analyse effectuée** :
- Analyse des différentes méthodes d'administration Supabase
- Analyse de la sécurité des différentes méthodes
- Analyse de la traçabilité des opérations
- Analyse de la facilité d'utilisation

**Solutions envisagées** :
1. Utiliser directement l'interface SQL de Supabase
2. Utiliser la CLI Supabase
3. Utiliser la RPC admin_execute_sql
4. Utiliser la RPC execute_ddl

**Solution retenue** :
execute_ddl est la méthode officielle pour toutes les opérations DDL sur Supabase.

**Raisons du choix** :
- execute_ddl est optimisé pour les opérations DDL
- Centralisation des opérations DDL
- Traçabilité des opérations
- Sécurité (RPC admin)
- Intégration avec le système .windsurf

**Alternatives rejetées** :
- Interface SQL : Pas de traçabilité, pas d'intégration
- CLI Supabase : Pas d'intégration avec .windsurf
- admin_execute_sql : Pas optimisé pour DDL

**Conséquences** :
- Toutes les opérations DDL passent par execute_ddl
- Interdiction d'utiliser d'autres méthodes pour le DDL
- Dépendance à la RPC execute_ddl

**Documents impactés** :
- ACADEMIA_PERMANENT_EXECUTION_PROTOCOL.md
- ACADEMIA_ARCHITECTURE_DECISIONS.md
- ACADEMIA_TECHNICAL_CONSTITUTION.md

**ADR associé** :
- ADR-007 : execute_ddl est la méthode officielle pour les opérations DDL

**Contrats impactés** :
- Aucun (décision d'administration)

**Traçabilité** :
- .windsurf : Scripts utilisent execute_ddl

---

### ENTRY-008 : Architecture documentaire permanente

**Date** : 24 Juin 2026  
**Phase** : D.6H – Knowledge Preservation Lock

**Contexte** :
Le projet Academia a accumulé beaucoup d'information dans les conversations. Il est nécessaire de définir la source de vérité officielle.

**Problème rencontré** :
Risque de perte d'information et d'incohérence entre la conversation et la documentation.

**Analyse effectuée** :
- Analyse des sources d'information du projet
- Analyse des risques de perte d'information
- Analyse des besoins de traçabilité
- Analyse des besoins de cohérence

**Solutions envisagées** :
1. La conversation est la source de vérité
2. La documentation est la source de vérité
3. Les documents permanents et .windsurf sont la source de vérité

**Solution retenue** :
La mémoire officielle du projet est exclusivement constituée des documents permanents (docs/) et du dossier .windsurf. La conversation n'est jamais une source de vérité.

**Raisons du choix** :
- La conversation est éphémère
- Les documents permanents sont persistants
- .windsurf contient les outils et scripts
- Éviter la perte d'information
- Assurer la traçabilité
- Assurer la cohérence

**Alternatives rejetées** :
- Conversation : Éphémère, pas de traçabilité
- Documentation seule : Ne contient pas les outils

**Conséquences** :
- Obligation de documenter dans les fichiers permanents
- Interdiction de se baser sur la conversation
- Consultation obligatoire des documents avant toute opération

**Documents impactés** :
- ACADEMIA_PERMANENT_EXECUTION_PROTOCOL.md
- ACADEMIA_ARCHITECTURE_DECISIONS.md
- ACADEMIA_TECHNICAL_CONSTITUTION.md

**ADR associé** :
- ADR-008 : La mémoire officielle du projet est constituée des documents permanents et du dossier .windsurf

**Contrats impactés** :
- Aucun (décision de processus)

**Traçabilité** :
- docs/ : Documentation permanente
- .windsurf/ : Outils et scripts permanents

---

### ENTRY-009 : Système de checkpoint

**Date** : 24 Juin 2026  
**Phase** : D.6I – Project Checkpoint System

**Contexte** :
Le projet Academia est complexe et nécessite de pouvoir reprendre le développement exactement là où il s'est arrêté, même après plusieurs semaines.

**Problème rencontré** :
Risque de perte de contexte et de redondance des audits.

**Analyse effectuée** :
- Analyse des besoins de reprise de chantier
- Analyse des risques de perte de contexte
- Analyse des besoins de traçabilité
- Analyse des meilleures pratiques de gestion de projet

**Solutions envisagées** :
1. Ne pas avoir de système de checkpoint
2. Avoir un checkpoint simple
3. Avoir un système de checkpoint complet avec protocole

**Solution retenue** :
Système de checkpoint complet avec protocole de reprise (ACADEMIA_CURRENT_CHECKPOINT.md).

**Raisons du choix** :
- Permettre une reprise immédiate du chantier
- Éviter la perte de contexte
- Éviter la redondance des audits
- Standardiser le protocole de reprise
- Faciliter la collaboration

**Alternatives rejetées** :
- Pas de checkpoint : Risque de perte de contexte
- Checkpoint simple : Insuffisant pour un projet complexe

**Conséquences** :
- Obligation de mettre à jour le checkpoint en fin de phase
- Obligation de consulter le checkpoint en début de phase
- Question obligatoire avant toute nouvelle phase

**Documents impactés** :
- ACADEMIA_CURRENT_CHECKPOINT.md
- ACADEMIA_PROJECT_STATE.md
- ACADEMIA_CHANGELOG.md

**ADR associé** :
- Aucun (décision de processus)

**Contrats impactés** :
- Aucun (décision de processus)

**Traçabilité** :
- ACADEMIA_CURRENT_CHECKPOINT.md : Point de reprise absolu

---

### ENTRY-010 : Système de cohérence documentaire

**Date** : 24 Juin 2026  
**Phase** : D.6N – Document Coherence System

**Contexte** :
Le projet Academia a maintenant 12 documents permanents. Il est nécessaire de garantir qu'ils ne divergent jamais.

**Problème rencontré** :
Risque d'incohérence entre les documents permanents après plusieurs centaines de phases.

**Analyse effectuée** :
- Analyse des risques d'incohérence
- Analyse des besoins de cohérence
- Analyse des meilleures pratiques de gestion de documentation
- Analyse des outils de contrôle de cohérence

**Solutions envisagées** :
1. Ne pas avoir de système de cohérence
2. Avoir un contrôle manuel
3. Avoir un système de cohérence automatique

**Solution retenue** :
Système de cohérence documentaire avec 7 règles et procédure de contrôle (ACADEMIA_DOCUMENT_COHERENCE_SYSTEM.md).

**Raisons du choix** :
- Garantir la cohérence des 12 documents permanents
- Standardiser le contrôle de cohérence
- Faciliter la détection des incohérences
- Faciliter la correction des incohérences
- Assurer la qualité de la documentation

**Alternatives rejetées** :
- Pas de système : Risque d'incohérence
- Contrôle manuel : Trop long, sujet aux erreurs

**Conséquences** :
- Obligation de contrôle de cohérence en fin de phase
- Obligation de corriger les incohérences
- Clôture refusée si incohérence détectée
- Sections obligatoires dans les rapports de phase

**Documents impactés** :
- ACADEMIA_DOCUMENT_COHERENCE_SYSTEM.md
- ACADEMIA_TECHNICAL_CONSTITUTION.md

**ADR associé** :
- Aucun (décision de processus)

**Contrats impactés** :
- Aucun (décision de processus)

**Traçabilité** :
- ACADEMIA_DOCUMENT_COHERENCE_SYSTEM.md : Système de cohérence

---

### ENTRY-011 : Utilisation obligatoire des outils .windsurf

**Date** : 24 Juin 2026  
**Phase** : D.6H – Knowledge Preservation Lock

**Contexte** :
Le projet Academia a accumulé de nombreux scripts et outils d'administration dans le dossier .windsurf.

**Problème rencontré** :
Risque de duplication des outils et d'incohérence dans les méthodes d'administration.

**Analyse effectuée** :
- Analyse des outils existants dans .windsurf
- Analyse des risques de duplication
- Analyse des besoins de standardisation
- Analyse des meilleures pratiques d'administration

**Solutions envisagées** :
1. Créer de nouveaux outils pour chaque opération
2. Réutiliser systématiquement les outils existants dans .windsurf
3. Mélanger nouveaux outils et outils existants

**Solution retenue** :
Utilisation obligatoire des outils d'administration présents dans .windsurf. Aucun nouvel outil ne doit être créé sans vérifier qu'un équivalent n'existe pas déjà.

**Raisons du choix** :
- Éviter la duplication des outils
- Maintenir la cohérence des méthodes d'administration
- Faciliter la maintenance
- Réduire le risque d'erreurs
- Standardiser les méthodes

**Alternatives rejetées** :
- Nouveaux outils : Duplication, incohérence
- Mélange : Incohérence, maintenance complexe

**Conséquences** :
- Obligation de consulter .windsurf avant toute opération
- Interdiction de créer des doublons
- Standardisation des méthodes d'administration

**Documents impactés** :
- ACADEMIA_PERMANENT_EXECUTION_PROTOCOL.md
- ACADEMIA_ARCHITECTURE_DECISIONS.md

**ADR associé** :
- ADR-006 : Utilisation obligatoire des outils d'administration présents dans .windsurf

**Contrats impactés** :
- Aucun (décision de processus)

**Traçabilité** :
- .windsurf : Dossier central des outils d'administration

---

### ENTRY-012 : Séparation Flutter / Backend / Worker

**Date** : 24 Juin 2026  
**Phase** : D.6H – Knowledge Preservation Lock

**Contexte** :
Le projet Academia est une application mobile avec un backend et des workers. Il est nécessaire de définir clairement les responsabilités de chaque composant.

**Problème rencontré** :
Risque de confusion entre les responsabilités de Flutter, du backend (Supabase) et des workers (Kamatera).

**Analyse effectuée** :
- Analyse des capacités de chaque composant
- Analyse des besoins de séparation des responsabilités
- Analyse des meilleures pratiques d'architecture
- Analyse des besoins de scalabilité

**Solutions envisagées** :
1. Tout faire dans Flutter
2. Tout faire dans le backend
3. Séparation claire des responsabilités

**Solution retenue** :
Séparation claire des responsabilités : Flutter (UI), Backend (Supabase), Worker (Kamatera).

**Raisons du choix** :
- Flutter : UI uniquement, pas de traitement lourd
- Supabase : Backend, base de données, orchestration
- Kamatera : Workers, traitement lourd, rendu vidéo
- Scalabilité optimale
- Maintenance simplifiée

**Alternatives rejetées** :
- Tout dans Flutter : Pas scalable, pas de capacité de traitement lourd
- Tout dans backend : Pas adapté au rendu vidéo

**Conséquences** :
- Flutter : UI uniquement
- Supabase : Backend, base de données, orchestration
- Kamatera : Workers, traitement lourd, rendu vidéo
- Architecture claire et maintenable

**Documents impactés** :
- ACADEMIA_TECHNICAL_CONSTITUTION.md

**ADR associé** :
- Aucun (décision architecturale implicite)

**Contrats impactés** :
- CONTRAT-001 : Flutter → Edge Function
- CONTRAT-005 : Storyboard → Renderer

**Traçabilité** :
- Flutter : UI
- Supabase : Backend
- Kamatera : Workers

---

## RÈGLE ABSOLUE

Avant toute modification importante, consulter également ACADEMIA_ENGINEERING_LOGBOOK.md afin de comprendre pourquoi l'architecture actuelle existe.

---

## CLÔTURE D'UNE PHASE

Toute phase ayant conduit à une décision technique importante doit ajouter une nouvelle entrée dans le Logbook.

---

## HISTORIQUE DES MODIFICATIONS

### 24 Juin 2026
- Création du journal des décisions techniques
- Documentation de 12 décisions techniques (ENTRY-001 à ENTRY-012)
- ENTRY-001 : Séparation Bobodo / Smart Whiteboard
- ENTRY-002 : Utilisation d'OpenRouter
- ENTRY-003 : Utilisation de Kamatera pour le rendu
- ENTRY-004 : Renderer Python
- ENTRY-005 : Pipeline Storyboard → PNG → FFmpeg → MP4
- ENTRY-006 : Abandon du rendu Flutter
- ENTRY-007 : Choix de execute_ddl
- ENTRY-008 : Architecture documentaire permanente
- ENTRY-009 : Système de checkpoint
- ENTRY-010 : Système de cohérence documentaire
- ENTRY-011 : Utilisation obligatoire des outils .windsurf
- ENTRY-012 : Séparation Flutter / Backend / Worker

---

**Fin de ACADEMIA_ENGINEERING_LOGBOOK.md**
