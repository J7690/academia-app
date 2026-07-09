# ACADEMIA TECHNICAL CONSTITUTION

**Date** : 24 Juin 2026  
**Version** : 1.0  
**Statut** : ACTIF

---

## OBJECTIF

Ce document est la Constitution Technique du projet Academia. Il devient la référence architecturale absolue du projet et doit être consulté avant toute intervention.

---

## 1. VISION GÉNÉRALE

### Mission d'Academia

Academia est une plateforme éducative mobile permettant aux étudiants africains d'accéder à des contenus pédagogiques de qualité, de se préparer aux concours et aux examens, et de développer leurs compétences à travers des défis interactifs.

### Grands modules du projet

1. **Smart Whiteboard** : Génération pédagogique de vidéos à partir de sujets
2. **Challenge Feed** : Diffusion et publication de vidéos challenges
3. **Crédits** : Système de monétisation et d'accès aux fonctionnalités IA
4. **Préparation Concours** : Module de préparation aux concours avec quiz et flashcards
5. **Travaux Dirigés (TD)** : Module de travaux dirigés avec scan et correction IA
6. **Jeux Économiques** : Jeux éducatifs sur les concepts économiques
7. **Bobodo Assistant** : Assistant utilisateur pour l'orientation et l'aide
8. **Streaming** : Diffusion en direct de contenus éducatifs
9. **Marketplace** : Place de marché pour les ressources pédagogiques
10. **LiveKit** : Infrastructure de communication en temps réel

### Composants critiques

- **Supabase** : Base de données, authentification, stockage, Edge Functions
- **Kamatera** : Infrastructure de rendu vidéo (Smart Whiteboard)
- **OpenRouter** : API d'IA pour la génération de storyboards
- **Flutter** : Application mobile
- **Storage** : Stockage des fichiers (vidéos, images, documents)

### Composants indépendants

- **Streaming** : Indépendant du Smart Whiteboard
- **Marketplace** : Indépendant des modules pédagogiques
- **LiveKit** : Indépendant de Supabase pour la communication temps réel

---

## 2. ARCHITECTURE OFFICIELLE

### Flux de données

```
Flutter (Application Mobile)
        ↓
    Supabase (Base de données, Auth, Storage)
        ↓
Edge Functions (Logique métier, IA)
        ↓
OpenRouter (API d'IA)
        ↓
Kamatera (Rendu vidéo)
        ↓
Storage (Stockage des vidéos)
        ↓
Flutter (Lecture des vidéos)
```

### Relations entre composants

1. **Flutter → Supabase**
   - Authentification des utilisateurs
   - Lecture/écriture des données
   - Téléchargement des fichiers

2. **Supabase → Edge Functions**
   - Appel des Edge Functions pour la logique métier
   - Génération de storyboards (Smart Whiteboard)
   - Traitement des images (TD scan)

3. **Edge Functions → OpenRouter**
   - Génération de storyboards via Claude 3.5 Sonnet
   - Génération de quiz et flashcards
   - Correction d'exercices

4. **Edge Functions → Kamatera**
   - Création de jobs de rendu
   - Polling du statut de rendu
   - Récupération des vidéos générées

5. **Kamatera → Storage**
   - Upload des vidéos générées
   - Upload des narrations audio

6. **Storage → Flutter**
   - Téléchargement des vidéos
   - Téléchargement des images
   - Téléchargement des documents

### Architecture interdite

- **Flutter ne rend jamais les vidéos** : Le rendu est exclusivement effectué par Kamatera
- **Supabase ne génère jamais les storyboards** : La génération est exclusivement effectuée par OpenRouter via Edge Functions
- **Bobodo ne génère jamais les storyboards** : Bobodo est exclusivement un assistant utilisateur
- **Kamatera n'est jamais utilisé pour autre chose que le rendu** : Kamatera est exclusivement dédié au Smart Whiteboard

---

## 3. RESPONSABILITÉ DE CHAQUE COMPOSANT

### Smart Whiteboard

**Responsabilités** :
- Génération pédagogique de vidéos
- Génération de storyboards
- Rendu vidéo
- Stockage des vidéos
- Édition de storyboards

**Technologies** :
- OpenRouter (Claude 3.5 Sonnet)
- Kamatera (Worker Python)
- Supabase (Tables, RPCs, Storage)
- Flutter (UI)

**Interdictions** :
- Ne pas utiliser Bobodo pour la génération
- Ne pas utiliser Flutter pour le rendu
- Ne pas contourner OpenRouter

---

### Bobodo Assistant

**Responsabilités** :
- Assistant utilisateur
- Orientation
- Aide plateforme
- FAQ
- Assistance étudiante

**Technologies** :
- OpenRouter (modèles de chat)
- Supabase (Base de connaissances)
- Flutter (UI)

**Interdictions** :
- Ne jamais générer de storyboards
- Ne jamais rendre de vidéos
- Ne jamais intervenir dans le Smart Whiteboard

---

### Challenge Feed

**Responsabilités** :
- Diffusion de vidéos challenges
- Publication de vidéos
- Lecture de vidéos
- Commentaires et likes

**Technologies** :
- Supabase (Tables, Storage)
- Flutter (UI)
- Kamatera (Compression vidéo)

**Interdictions** :
- Ne pas utiliser le Smart Whiteboard pour les challenges
- Ne pas mélanger avec le Smart Whiteboard

---

### Crédits

**Responsabilités** :
- Gestion des crédits utilisateurs
- Réservation de crédits
- Confirmation de crédits
- Remboursement de crédits
- Achat de packs de crédits

**Technologies** :
- Supabase (Tables, RPCs)
- Flutter (UI)

**Interdictions** :
- Ne pas créer de système de paiement alternatif
- Ne pas contourner les RPCs de gestion des crédits

---

### Préparation Concours

**Responsabilités** :
- Génération de quiz
- Génération de flashcards
- Scan de sujets
- Correction IA
- Indexation de documents

**Technologies** :
- Edge Functions (prep-*)
- OpenRouter (Gemini 2.0 Flash Vision)
- Supabase (Tables, Storage)
- Flutter (UI)

**Interdictions** :
- Ne pas utiliser le Smart Whiteboard pour la génération de quiz
- Ne pas mélanger avec le module TD

---

### Travaux Dirigés (TD)

**Responsabilités** :
- Scan de sujets
- Correction IA
- Import de questions
- Indexation de documents

**Technologies** :
- Edge Functions (td-*)
- OpenRouter (Gemini 2.0 Flash Vision)
- Supabase (Tables, Storage)
- Flutter (UI)

**Interdictions** :
- Ne pas utiliser le Smart Whiteboard pour la correction
- Ne pas mélanger avec le module Préparation Concours

---

### Jeux Économiques

**Responsabilités** :
- Jeux éducatifs sur les concepts économiques
- Tournois
- Classements
- Récompenses

**Technologies** :
- Flutter (UI, Flame engine)
- Supabase (Tables, RPCs)

**Interdictions** :
- Ne pas utiliser le Smart Whiteboard pour les jeux
- Ne pas mélanger avec le Challenge Feed

---

### Streaming

**Responsabilités** :
- Diffusion en direct
- Chat en direct
- Enregistrement des streams

**Technologies** :
- LiveKit
- Flutter (UI)
- Kamatera (Streaming server)

**Interdictions** :
- Ne pas dépendre du Smart Whiteboard
- Ne pas dépendre de Supabase pour le streaming

---

### Marketplace

**Responsabilités** :
- Vente de ressources pédagogiques
- Achat de ressources
- Gestion des paiements

**Technologies** :
- Supabase (Tables, RPCs)
- Flutter (UI)

**Interdictions** :
- Ne pas mélanger avec les crédits
- Ne pas dépendre du Smart Whiteboard

---

### LiveKit

**Responsabilités** :
- Communication en temps réel
- Audio/vidéo
- Chat

**Technologies** :
- LiveKit SDK
- Flutter (UI)

**Interdictions** :
- Ne pas dépendre de Supabase pour la communication
- Ne pas dépendre du Smart Whiteboard

---

## 4. ARCHITECTURE VERROUILLÉE

### Décisions qui ne doivent plus être remises en question

✓ **Smart Whiteboard utilise OpenRouter** pour la génération de storyboards
✓ **Bobodo ne génère pas les storyboards** (assistant utilisateur uniquement)
✓ **Kamatera effectue les rendus vidéo** (exclusivement Smart Whiteboard)
✓ **Supabase orchestre le pipeline** (base de données, auth, storage, Edge Functions)
✓ **Flutter ne rend jamais les vidéos** (lecture uniquement)
✓ **Les crédits sont gérés via Supabase RPCs** (pas de système alternatif)
✓ **Le scan de sujets utilise Gemini 2.0 Flash Vision** (Edge Functions)
✓ **Le streaming utilise LiveKit** (indépendant de Supabase)
✓ **Les jeux utilisent Flame engine** (pas d'alternative)
✓ **La Marketplace utilise Supabase** (pas d'alternative)

---

## 5. COMPOSANTS PROTÉGÉS

Il est interdit de casser les composants suivants :

### Composants critiques

- **Bobodo** : Assistant utilisateur
- **Challenge Feed** : Diffusion de vidéos
- **Upload** : Upload de fichiers
- **Publication** : Publication de vidéos
- **Streaming** : Diffusion en direct
- **LiveKit** : Communication en temps réel
- **TV Pro** : Interface TV
- **Marketplace** : Place de marché
- **Orientation** : Module d'orientation
- **Smart Whiteboard validé** : Infrastructure de production

### Composants secondaires

- **Crédits** : Système de monétisation
- **Préparation Concours** : Module de préparation
- **Travaux Dirigés** : Module TD
- **Jeux Économiques** : Module jeux

### Preuve de non-régression obligatoire

Toute modification d'un composant protégé doit être accompagnée d'une preuve de non-régression.

---

## 6. CHEMINS OFFICIELS

### Créer une table

```
.windsurf
    ↓
RPC admin (execute_ddl)
    ↓
Supabase
```

### Modifier une table

```
.windsurf
    ↓
RPC admin (execute_ddl)
    ↓
Supabase
```

### Créer une RPC

```
.windsurf
    ↓
RPC admin (execute_ddl)
    ↓
Supabase
```

### Déployer sur Kamatera

```
Scripts .windsurf
    ↓
SSH
    ↓
systemd
    ↓
Kamatera
```

### Vérifier Kamatera

```
Scripts .windsurf
    ↓
SSH
    ↓
ps aux / systemctl / docker
    ↓
Kamatera
```

### Créer une Edge Function

```
.windsurf
    ↓
Supabase CLI
    ↓
Supabase
```

### Modifier Flutter

```
academia_app
    ↓
Code modification
    ↓
Test
    ↓
Commit
```

### Audit Supabase

```
.windsurf
    ↓
Scripts audit
    ↓
RPC admin (admin_execute_sql)
    ↓
Supabase
```

### Audit Flutter

```
academia_app
    ↓
grep / find
    ↓
Code analysis
```

---

## 7. OUTILS OFFICIELS

### Outils Supabase

- **execute_ddl** : Exécution DDL
- **admin_execute_sql** : Exécution SQL admin
- **Scripts deploy** : Déploiement
- **Scripts verify** : Vérification
- **Scripts check** : Contrôle
- **Scripts audit** : Audit

### Outils Kamatera

- **Scripts SSH** : Connexion SSH
- **Scripts systemd** : Gestion des services
- **Scripts verify** : Vérification des fichiers
- **Scripts check** : Contrôle des processus

### Outils Flutter

- **grep** : Recherche de code
- **find** : Recherche de fichiers
- **flutter analyze** : Analyse statique
- **flutter test** : Tests

### Règle

Tous les outils existent déjà dans `.windsurf`. Aucun nouvel outil ne doit être créé sans avoir vérifié qu'un équivalent n'existe pas déjà.

---

## 8. CE QU'IL EST INTERDIT DE FAIRE

### Architecture

- Créer une nouvelle architecture
- Contourner l'architecture officielle
- Inventer un nouveau flux de données

### Administration

- Créer une nouvelle méthode d'administration
- Contourner `.windsurf`
- Contourner les RPC d'administration
- Utiliser directement Supabase sans passer par les outils officiels

### Audits

- Refaire un audit clôturé
- Ignorer un audit existant
- Partir de zéro sans consulter les audits existants

### Composants

- Modifier un composant verrouillé
- Casser un composant protégé
- Créer un doublon de composant

### RPCs

- Inventer une nouvelle RPC alors qu'une existe déjà
- Contourner les RPCs existantes
- Créer des RPCs sans passer par execute_ddl

### Code

- Créer du code dupliqué
- Ignorer les conventions de code existantes
- Modifier le code sans comprendre l'architecture

---

## 9. MÉMOIRE OFFICIELLE

La mémoire officielle du projet est exclusivement constituée de :

### Documents permanents (8 documents)

1. **docs/ACADEMIA_MASTER_INDEX.md** : Index central du projet
2. **docs/ACADEMIA_TRUTH_MATRIX.md** : Matrice de vérité unique
3. **docs/ACADEMIA_CHANGELOG.md** : Historique complet
4. **docs/ACADEMIA_DEPLOYMENT_STATUS.md** : État des déploiements
5. **docs/ACADEMIA_PROJECT_STATE.md** : État actuel du projet
6. **docs/ACADEMIA_CURRENT_CHECKPOINT.md** : Checkpoint courant
7. **docs/ACADEMIA_PERMANENT_EXECUTION_PROTOCOL.md** : Protocole d'exécution
8. **docs/ACADEMIA_TECHNICAL_CONSTITUTION.md** : Constitution technique (ce document)

### Dossiers

- **docs/** : Documentation du projet
- **.windsurf/** : Scripts et outils d'administration

### Règle absolue

La conversation n'est jamais une source de vérité. En cas de doute, toujours consulter les documents permanents et le dossier `.windsurf`.

---

## 10. RÈGLE ABSOLUE

Avant toute nouvelle phase, l'agent doit pouvoir répondre exactement :

> "J'ai consulté les documents permanents, la Constitution Technique Academia, le checkpoint courant ainsi que le dossier .windsurf. Je m'engage à respecter l'architecture officielle, à utiliser exclusivement les outils d'administration existants du projet et à ne pas remettre en cause les composants déjà validés."

Sans cette réponse, la phase est considérée invalide.

### Référence aux ADR

Avant de modifier une architecture existante, consulter obligatoirement le registre des décisions d'architecture (ACADEMIA_ARCHITECTURE_DECISIONS.md).

Si un ADR validé existe, il est interdit de modifier cette architecture sans créer un nouvel ADR qui remplace explicitement le précédent et explique les raisons du changement.

### Référence aux Contrats

Avant de modifier une RPC, une Edge Function, un Provider Flutter, un Worker Kamatera ou une table Supabase, consulter obligatoirement le registre des contrats techniques (ACADEMIA_CONTRACT_REGISTRY.md).

En cas d'absence d'un contrat, le créer avant toute modification.

### Référence à la Traçabilité

Avant toute modification importante, consulter obligatoirement la matrice de traçabilité (ACADEMIA_TRACEABILITY_MATRIX.md) pour identifier les ADR, contrats, Edge Functions, RPC, tables, écrans Flutter et services impactés.

Aucun développement ne peut être considéré terminé tant qu'il n'est pas référencé dans la matrice de traçabilité.

### Référence à la Cohérence Documentaire

À la fin de chaque phase, effectuer obligatoirement un contrôle de cohérence des 12 documents permanents selon ACADEMIA_DOCUMENT_COHERENCE_SYSTEM.md.

La clôture d'une phase est refusée si une incohérence est détectée et non corrigée.

### Référence au Journal des Décisions Techniques

Avant toute modification importante, consulter obligatoirement le journal des décisions techniques (ACADEMIA_ENGINEERING_LOGBOOK.md) afin de comprendre pourquoi l'architecture actuelle existe.

Toute phase ayant conduit à une décision technique importante doit ajouter une nouvelle entrée dans le Logbook.

---

## HISTORIQUE DES MODIFICATIONS

### 24 Juin 2026
- Création de la Constitution Technique Academia
- Définition de la vision générale
- Définition de l'architecture officielle
- Définition des responsabilités de chaque composant
- Définition de l'architecture verrouillée
- Définition des composants protégés
- Définition des chemins officiels
- Définition des outils officiels
- Définition des interdictions
- Définition de la mémoire officielle
- Définition de la règle absolue

---

**Fin de ACADEMIA_TECHNICAL_CONSTITUTION.md**
