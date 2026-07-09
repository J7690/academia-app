# ACADEMIA ARCHITECTURE DECISIONS

**Date** : 24 Juin 2026  
**Version** : 1.0  
**Statut** : ACTIF

---

## OBJECTIF

Ce document est le registre officiel de toutes les décisions structurantes du projet Academia. Il ne décrit pas l'état du projet mais les raisons des choix effectués.

Chaque décision d'architecture importante doit être enregistrée ici avec le format ADR (Architecture Decision Record).

---

## FORMAT ADR

Chaque décision utilise le format suivant :

### ADR-XXX

**Titre** :  
**Date** :  
**Statut** : (Proposée / Validée / Remplacée)  
**Contexte** :  
**Problème rencontré** :  
**Options étudiées** :  
**Décision retenue** :  
**Justification** :  
**Conséquences** :  
**Impact sur les composants** :  
**Références** :

---

## REGISTRE DES DÉCISIONS

### ADR-001

**Titre** : Séparation Bobodo / Smart Whiteboard  
**Date** : 24 Juin 2026  
**Statut** : Validée

**Contexte** :  
Le projet Academia comprend deux modules d'IA : Bobodo Assistant et Smart Whiteboard. Il est nécessaire de clarifier leurs responsabilités respectives pour éviter toute confusion.

**Problème rencontré** :  
Risque de confusion entre les responsabilités de Bobodo et Smart Whiteboard, notamment en ce qui concerne la génération de contenu pédagogique.

**Options étudiées** :
1. Fusionner Bobodo et Smart Whiteboard en un seul module
2. Séparer clairement les responsabilités de chaque module
3. Utiliser Bobodo pour la génération de storyboards Smart Whiteboard

**Décision retenue** :  
Séparation claire des responsabilités : Bobodo est un assistant utilisateur, Smart Whiteboard est un générateur pédagogique.

**Justification** :  
- Bobodo doit se concentrer sur l'assistance utilisateur (orientation, aide, FAQ)
- Smart Whiteboard doit se concentrer sur la génération pédagogique (storyboards, vidéos)
- Éviter la confusion des responsabilités
- Permettre une évolution indépendante de chaque module

**Conséquences** :
- Bobodo ne génère jamais de storyboards
- Smart Whiteboard n'assiste jamais les utilisateurs
- Chaque module a ses propres modèles d'IA
- Chaque module a ses propres interfaces utilisateur

**Impact sur les composants** :
- Bobodo Assistant : Assistant utilisateur uniquement
- Smart Whiteboard : Génération pédagogique uniquement
- OpenRouter : Utilisé par les deux modules avec des modèles différents

**Références** :
- ACADEMIA_TECHNICAL_CONSTITUTION.md
- Mémoire système : OBLIGATION 10 – DISTINCTION BOBODO / SMART WHITEBOARD

---

### ADR-002

**Titre** : Utilisation d'OpenRouter comme moteur de génération pédagogique  
**Date** : 24 Juin 2026  
**Statut** : Validée

**Contexte** :  
Le Smart Whiteboard nécessite un moteur d'IA pour générer des storyboards pédagogiques à partir de sujets.

**Problème rencontré** :  
Choix du moteur d'IA pour la génération de storyboards.

**Options étudiées** :
1. Utiliser OpenAI GPT-4
2. Utiliser Anthropic Claude
3. Utiliser OpenRouter (agrégateur de modèles)
4. Utiliser Google Gemini

**Décision retenue** :  
Utiliser OpenRouter comme moteur de génération pédagogique, avec Claude 3.5 Sonnet comme modèle principal.

**Justification** :
- OpenRouter permet de changer de modèle facilement
- Claude 3.5 Sonnet offre le meilleur rapport qualité/prix pour la génération pédagogique
- Flexibilité pour tester d'autres modèles si nécessaire
- Coût compétitif

**Conséquences** :
- Smart Whiteboard dépend d'OpenRouter
- Nécessité de gérer les clés API OpenRouter
- Possibilité de changer de modèle sans modifier l'architecture

**Impact sur les composants** :
- Smart Whiteboard : Utilise OpenRouter via Edge Function whiteboard-generate-storyboard
- Edge Functions : Intègrent l'API OpenRouter
- Coûts : Dépendants de la consommation OpenRouter

**Références** :
- ACADEMIA_TECHNICAL_CONSTITUTION.md
- PHASE_D6F_ECONOMICS_AUDIT.md

---

### ADR-003

**Titre** : Kamatera responsable du rendu vidéo  
**Date** : 24 Juin 2026  
**Statut** : Validée

**Contexte** :  
Le Smart Whiteboard nécessite de générer des vidéos à partir des storyboards. Le rendu vidéo est une opération intensive en CPU/GPU.

**Problème rencontré** :  
Choix de l'infrastructure pour le rendu vidéo.

**Options étudiées** :
1. Effectuer le rendu sur l'appareil mobile (Flutter)
2. Effectuer le rendu sur Supabase (Edge Functions)
3. Effectuer le rendu sur un serveur dédié (Kamatera)
4. Utiliser un service de rendu cloud (D-ID, Synthesia, etc.)

**Décision retenue** :  
Utiliser Kamatera comme infrastructure dédiée au rendu vidéo Smart Whiteboard.

**Justification** :
- Flutter n'a pas la capacité de rendu vidéo
- Supabase Edge Functions ne sont pas adaptées au rendu vidéo
- Kamatera offre un contrôle total sur le pipeline de rendu
- Coût compétitif par rapport aux services cloud
- Possibilité d'optimiser le pipeline

**Conséquences** :
- Smart Whiteboard dépend de Kamatera
- Nécessité de maintenir le worker Kamatera
- Dépendance à l'infrastructure Kamatera

**Impact sur les composants** :
- Kamatera : Worker Python pour le rendu vidéo
- Smart Whiteboard : Dépend de Kamatera pour le rendu
- Supabase : Orchestre les jobs de rendu

**Références** :
- ACADEMIA_TECHNICAL_CONSTITUTION.md
- PHASE_D5I_PRODUCTION_ACTIVATION_REPORT.md

---

### ADR-004

**Titre** : Flutter ne génère jamais les vidéos  
**Date** : 24 Juin 2026  
**Statut** : Validée

**Contexte** :  
L'application Flutter Academia doit afficher des vidéos générées par le Smart Whiteboard.

**Problème rencontré** :  
Définir les responsabilités de Flutter dans le pipeline de génération vidéo.

**Options étudiées** :
1. Flutter génère les vidéos localement
2. Flutter génère les vidéos via un plugin
3. Flutter affiche uniquement les vidéos générées par Kamatera

**Décision retenue** :  
Flutter affiche uniquement les vidéos générées par Kamatera, jamais de génération locale.

**Justification** :
- Flutter n'a pas les capacités de rendu vidéo
- Génération locale serait trop lourde pour les appareils mobiles
- Kamatera offre une qualité de rendu supérieure
- Centralisation du rendu pour optimiser les coûts

**Conséquences** :
- Flutter dépend de Kamatera pour les vidéos
- Aucun plugin de rendu vidéo dans Flutter
- Latence entre la demande et la disponibilité de la vidéo

**Impact sur les composants** :
- Flutter : Lecture uniquement des vidéos
- Kamatera : Rendu exclusif des vidéos
- Smart Whiteboard : Dépend de Kamatera pour le rendu

**Références** :
- ACADEMIA_TECHNICAL_CONSTITUTION.md

---

### ADR-005

**Titre** : Supabase orchestre tout le pipeline  
**Date** : 24 Juin 2026  
**Statut** : Validée

**Contexte** :  
Le Smart Whiteboard nécessite d'orchestrer plusieurs composants : génération de storyboard, rendu vidéo, stockage.

**Problème rencontré** :  
Choix de l'orchestrateur du pipeline Smart Whiteboard.

**Options étudiées** :
1. Flutter orchestre le pipeline
2. Kamatera orchestre le pipeline
3. Supabase orchestre le pipeline
4. Edge Function orchestre le pipeline

**Décision retenue** :  
Supabase orchestre tout le pipeline Smart Whiteboard via RPCs et Edge Functions.

**Justification** :
- Supabase est déjà la base de données centrale
- RPCs permettent d'orchestrer les opérations
- Edge Functions permettent d'intégrer OpenRouter
- Centralisation de l'orchestration
- Facilite le monitoring et le debugging

**Conséquences** :
- Smart Whiteboard dépend de Supabase pour l'orchestration
- Nécessité de maintenir les RPCs Supabase
- Dépendance à Supabase pour le pipeline

**Impact sur les composants** :
- Supabase : Orchestration du pipeline via RPCs et Edge Functions
- Smart Whiteboard : Dépend de Supabase pour l'orchestration
- Kamatera : Exécute les jobs de rendu créés par Supabase

**Références** :
- ACADEMIA_TECHNICAL_CONSTITUTION.md
- ACADEMIA_TRUTH_MATRIX.md

---

### ADR-006

**Titre** : Utilisation obligatoire des outils d'administration présents dans .windsurf  
**Date** : 24 Juin 2026  
**Statut** : Validée

**Contexte** :  
Le projet Academia a accumulé de nombreux scripts et outils d'administration dans le dossier .windsurf.

**Problème rencontré** :  
Risque de duplication des outils et d'incohérence dans les méthodes d'administration.

**Options étudiées** :
1. Créer de nouveaux outils pour chaque opération
2. Réutiliser systématiquement les outils existants dans .windsurf
3. Mélanger nouveaux outils et outils existants

**Décision retenue** :  
Utilisation obligatoire des outils d'administration présents dans .windsurf. Aucun nouvel outil ne doit être créé sans vérifier qu'un équivalent n'existe pas déjà.

**Justification** :
- Éviter la duplication des outils
- Maintenir la cohérence des méthodes d'administration
- Faciliter la maintenance
- Réduire le risque d'erreurs

**Conséquences** :
- Obligation de consulter .windsurf avant toute opération
- Interdiction de créer des doublons
- Standardisation des méthodes d'administration

**Impact sur les composants** :
- .windsurf : Dossier central des outils d'administration
- Supabase : Opérations via outils .windsurf
- Kamatera : Opérations via outils .windsurf

**Références** :
- ACADEMIA_PERMANENT_EXECUTION_PROTOCOL.md
- Mémoire système : OBLIGATION 1 – CONSULTATION DU DOSSIER .WINDSURF

---

### ADR-007

**Titre** : execute_ddl est la méthode officielle pour les opérations DDL  
**Date** : 24 Juin 2026  
**Statut** : Validée

**Contexte** :  
Le projet Academia utilise Supabase comme base de données. Les opérations DDL (CREATE TABLE, ALTER TABLE, etc.) sont nécessaires.

**Problème rencontré** :  
Choix de la méthode pour les opérations DDL sur Supabase.

**Options étudiées** :
1. Utiliser directement l'interface SQL de Supabase
2. Utiliser la CLI Supabase
3. Utiliser la RPC admin_execute_sql
4. Utiliser la RPC execute_ddl

**Décision retenue** :  
execute_ddl est la méthode officielle pour toutes les opérations DDL sur Supabase.

**Justification** :
- execute_ddl est optimisé pour les opérations DDL
- Centralisation des opérations DDL
- Traçabilité des opérations
- Sécurité (RPC admin)

**Conséquences** :
- Toutes les opérations DDL passent par execute_ddl
- Interdiction d'utiliser d'autres méthodes pour le DDL
- Dépendance à la RPC execute_ddl

**Impact sur les composants** :
- Supabase : Opérations DDL via execute_ddl
- .windsurf : Scripts utilisent execute_ddl
- Développement : Respect de cette règle

**Références** :
- ACADEMIA_PERMANENT_EXECUTION_PROTOCOL.md
- ACADEMIA_TECHNICAL_CONSTITUTION.md

---

### ADR-008

**Titre** : La mémoire officielle du projet est constituée des documents permanents et du dossier .windsurf  
**Date** : 24 Juin 2026  
**Statut** : Validée

**Contexte** :  
Le projet Academia a accumulé beaucoup d'information dans les conversations. Il est nécessaire de définir la source de vérité officielle.

**Problème rencontré** :  
Risque de perte d'information et d'incohérence entre la conversation et la documentation.

**Options étudiées** :
1. La conversation est la source de vérité
2. La documentation est la source de vérité
3. Les documents permanents et .windsurf sont la source de vérité

**Décision retenue** :  
La mémoire officielle du projet est exclusivement constituée des documents permanents (docs/) et du dossier .windsurf. La conversation n'est jamais une source de vérité.

**Justification** :
- La conversation est éphémère
- Les documents permanents sont persistants
- .windsurf contient les outils et scripts
- Éviter la perte d'information
- Assurer la traçabilité

**Conséquences** :
- Obligation de documenter dans les fichiers permanents
- Interdiction de se baser sur la conversation
- Consultation obligatoire des documents avant toute opération

**Impact sur les composants** :
- docs/ : Documentation permanente
- .windsurf/ : Outils et scripts permanents
- Conversation : Non source de vérité

**Références** :
- ACADEMIA_PERMANENT_EXECUTION_PROTOCOL.md
- ACADEMIA_TECHNICAL_CONSTITUTION.md
- PHASE_D6H_KNOWLEDGE_PRESERVATION_LOCK.md

---

### ADR-009

**Titre** : Le projet Flutter officiel est exclusivement academia_app  
**Date** : 24 Juin 2026  
**Statut** : Validée

**Contexte** :  
Le projet Academia est une application mobile Flutter. Il est nécessaire de définir le projet Flutter officiel.

**Problème rencontré** :  
Risque de confusion entre plusieurs projets Flutter.

**Options étudiées** :
1. Utiliser plusieurs projets Flutter
2. Utiliser un seul projet Flutter academia_app
3. Utiliser des modules Flutter séparés

**Décision retenue** :  
Le projet Flutter officiel est exclusivement academia_app. Aucune modification ne doit être réalisée dans un autre projet Flutter sauf demande explicite.

**Justification** :
- Simplifier la maintenance
- Éviter la dispersion du code
- Centraliser les développements
- Faciliter les tests

**Conséquences** :
- Toutes les modifications Flutter sont dans academia_app
- Interdiction de modifier d'autres projets Flutter
- Dépendance unique à academia_app

**Impact sur les composants** :
- academia_app : Projet Flutter officiel
- Autres projets Flutter : Non modifiés sans demande explicite

**Références** :
- ACADEMIA_PERMANENT_EXECUTION_PROTOCOL.md
- ACADEMIA_TECHNICAL_CONSTITUTION.md

---

### ADR-010

**Titre** : Les audits clôturés ne doivent jamais être recommencés sans nouveau besoin identifié  
**Date** : 24 Juin 2026  
**Statut** : Validée

**Contexte** :  
Le projet Academia a réalisé de nombreux audits (infrastructure, Flutter, etc.). Il est nécessaire d'éviter de refaire les audits déjà clôturés.

**Problème rencontré** :  
Risque de perte de temps à refaire des audits déjà réalisés.

**Options étudiées** :
1. Refaire systématiquement les audits
2. Ne jamais refaire les audits
3. Refaire les audits uniquement si un nouveau besoin est identifié

**Décision retenue** :  
Les audits clôturés ne doivent jamais être recommencés sans un nouveau besoin identifié. Si un audit existe déjà, il doit être lu, utilisé et complété si nécessaire.

**Justification** :
- Éviter la perte de temps
- Éviter la redondance
- Assurer la traçabilité
- Faciliter la maintenance

**Conséquences** :
- Obligation de consulter les audits existants
- Interdiction de refaire les audits clôturés
- Compléter les audits si nouveau besoin

**Impact sur les composants** :
- docs/ : Contient les audits clôturés
- Développement : Respect de cette règle
- Maintenance : Consultation des audits existants

**Références** :
- ACADEMIA_PERMANENT_EXECUTION_PROTOCOL.md
- Mémoire système : OBLIGATION 9 – QUESTION AVANT TOUT AUDIT

---

## NOUVELLE RÈGLE

À chaque décision d'architecture importante :

1. Créer un nouvel ADR avec le format ADR-XXX
2. L'ajouter à ACADEMIA_ARCHITECTURE_DECISIONS.md
3. Référencer son identifiant (ADR-011, ADR-012, etc.) dans le rapport de phase concerné

---

## RÈGLE ABSOLUE

Avant de modifier une architecture existante, vérifier si un ADR existe déjà.

Si un ADR validé existe, il est interdit de modifier cette architecture sans créer un nouvel ADR qui remplace explicitement le précédent et explique les raisons du changement.

---

## HISTORIQUE DES MODIFICATIONS

### 24 Juin 2026
- Création du registre des décisions d'architecture
- Enregistrement des 10 ADR initiales
- Définition de la nouvelle règle pour les futures décisions
- Définition de la règle absolue pour les modifications d'architecture

---

**Fin de ACADEMIA_ARCHITECTURE_DECISIONS.md**
