# Guide Administrateur — Fournir du contenu aux modules TD et Concours

> **Objectif** : Alimenter l'IA et les quiz de l'application avec des sujets, exercices, corrigés et cours, pour que les étudiants disposent immédiatement de contenu pertinent pour s'entraîner.
---

## Table des matières

1. [Vue d'ensemble](#1-vue-densemble)
2. [Onglet Prépa Concours — 3 modes d'import](#2-onglet-prépa-concours)
   - [Mode 1 : Import JSON structuré (0 token)](#mode-1--import-json-structuré-0-token)
   - [Mode 2 : Texte brut collé (0 token)](#mode-2--texte-brut-collé-0-token)
   - [Mode 3 : Upload PDF/Image avec OCR IA (consomme des tokens)](#mode-3--upload-pdfimage-avec-ocr-ia-consomme-des-tokens)
3. [Onglet TD — 3 modes d'import](#3-onglet-td)
   - [Mode 1 : Import JSON structuré (0 token)](#mode-1--import-json-structuré-0-token-1)
   - [Mode 2 : Texte brut collé (0 token)](#mode-2--texte-brut-collé-0-token-1)
   - [Mode 3 : Upload PDF/Image avec OCR IA (consomme des tokens)](#mode-3--upload-pdfimage-avec-ocr-ia-consomme-des-tokens-1)
4. [Format JSON détaillé](#4-format-json-détaillé)
5. [Bonnes pratiques](#5-bonnes-pratiques)
6. [FAQ](#6-faq)
7. [Architecture technique (résumé)](#7-architecture-technique)

---

## 1. Vue d'ensemble

L'administrateur dispose de **3 modes d'alimentation** pour chaque module (TD et Concours) :

| Mode | Coût tokens | Vitesse | Idéal pour |
|------|-------------|---------|------------|
| **⚡ JSON structuré** | **0 token** | Immédiat | Questions QCM prêtes à l'emploi |
| **📝 Texte brut** | **0 token** | Immédiat | Sujets, corrigés, cours à indexer |
| **📄 PDF/Image OCR** | ~2 000–8 000 tokens | 10–30 sec | Documents papier scannés |

**Recommandation** : Privilégier les modes **JSON** et **Texte brut** (gratuits) autant que possible. N'utiliser le mode OCR que pour les documents qui ne peuvent pas être recopiés.

---

## 2. Onglet Prépa Concours

### Accès à l'interface

1. Connectez-vous en tant qu'**administrateur**
2. Allez dans l'onglet **Concours** (barre de navigation du bas)
3. Dans la barre d'outils en haut, vous verrez 3 icônes :
   - **⚡ (éclair jaune)** → Import direct (0 token) — JSON et Texte brut
   - **📥 (télécharger)** → Importer document scanné
   - **📤 (upload)** → Upload PDF/Image avec OCR IA

---

### Mode 1 : Import JSON structuré (0 token)

**Quand l'utiliser** : Vous avez des questions QCM déjà rédigées (copiées d'un ancien sujet, créées manuellement, ou exportées d'un autre système).

**Étapes** :

1. Appuyez sur l'icône **⚡ (éclair jaune)** dans la barre d'outils
2. L'écran **"Import direct (0 token)"** s'ouvre avec 2 onglets
3. Restez sur l'onglet **"JSON structuré"**
4. Remplissez les métadonnées :
   - **Concours** : sélectionnez le type (ENAREF, DOUANE, etc.)
   - **Matière** : sélectionnez la matière (Culture Générale, Droit, etc.)
5. Choisissez l'une des 2 méthodes :
   - **Charger un fichier .json** : appuyez sur "Charger fichier .json" et sélectionnez votre fichier
   - **Coller directement** : collez le JSON dans le champ de texte
6. Appuyez sur **"Importer les questions"**
7. ✅ Les questions sont **immédiatement disponibles** pour les étudiants

**Format du JSON** (voir [section 4](#4-format-json-détaillé) pour plus de détails) :

```json
[
  {
    "question": "Quelle est la capitale du Burkina Faso ?",
    "options": ["Bobo-Dioulasso", "Ouagadougou", "Koudougou", "Banfora"],
    "correct_index": 1,
    "explanation": "Ouagadougou est la capitale du Burkina Faso depuis l'indépendance.",
    "difficulty": 2
  },
  {
    "question": "En quelle année le Burkina Faso a-t-il obtenu son indépendance ?",
    "options": ["1958", "1960", "1962", "1964"],
    "correct_index": 1,
    "explanation": "Le 5 août 1960, la Haute-Volta (devenue Burkina Faso) accède à l'indépendance.",
    "difficulty": 1
  }
]
```

---

### Mode 2 : Texte brut collé (0 token)

**Quand l'utiliser** : Vous avez le texte d'un sujet d'épreuve, un corrigé-type, un cours ou des annales, et vous voulez que l'IA l'utilise pour générer des questions et améliorer ses réponses.

**Étapes** :

1. Appuyez sur l'icône **⚡ (éclair jaune)**
2. Allez sur l'onglet **"Texte brut"**
3. Remplissez les métadonnées :
   - **Concours** : type de concours
   - **Matière** : matière concernée
4. Sélectionnez le **type de document** :
   - **Sujet d'épreuve** : un sujet officiel de concours
   - **Corrigé** : la correction d'un sujet
   - **Annale complète** : sujet + corrigé
   - **Support de cours** : contenu pédagogique
5. **Collez le texte** dans le champ (minimum 50 caractères)
6. Appuyez sur **"Indexer dans la base IA"**
7. ✅ Le texte est **indexé** et l'IA l'utilisera pour :
   - Générer de nouvelles questions pertinentes
   - Fournir des réponses plus précises lors des scans étudiants
   - Enrichir le contexte des corrections

**Exemple de texte à coller** :

```
CONCOURS ENAREF 2023 — Épreuve de Culture Générale

Durée : 3 heures — Coefficient : 3

PARTIE I — Questions à choix multiples (40 points)

1. Le Produit Intérieur Brut (PIB) du Burkina Faso en 2022 était d'environ :
A) 10 milliards de dollars
B) 18 milliards de dollars
C) 25 milliards de dollars
D) 35 milliards de dollars

Réponse : B

2. La monnaie utilisée au Burkina Faso est :
A) Le Naira
B) Le Cedi
C) Le Franc CFA
D) Le Shilling

Réponse : C

(suite du sujet...)
```

---

### Mode 3 : Upload PDF/Image avec OCR IA (consomme des tokens)

**Quand l'utiliser** : Vous avez un document papier (photo d'un ancien sujet, PDF scanné) que vous ne pouvez pas recopier.

**Étapes** :

1. Appuyez sur l'icône **📤 (Upload & IA)** dans la barre d'outils
2. Choisissez le type de fichier :
   - **Upload PDF** : pour les documents PDF
   - **Upload Image** : pour les photos de documents
3. Sélectionnez le fichier depuis votre appareil
4. Remplissez les métadonnées dans le dialogue :
   - Type de document (sujet, corrigé, annale, cours)
   - Concours
   - Matière
   - Année
5. Appuyez sur **"Uploader"**
6. ⏳ L'IA va :
   - Extraire le texte par OCR (reconnaissance optique)
   - Découper en morceaux indexables
   - Générer des embeddings pour la recherche sémantique
7. ✅ Le contenu est intégré dans la base de connaissances

**⚠️ Coût** : Ce mode consomme environ 2 000 à 8 000 tokens par document (OCR + embeddings). Utilisez-le uniquement pour les documents impossibles à recopier.

---

## 3. Onglet TD

### Accès à l'interface

1. Connectez-vous en tant qu'**administrateur**
2. Allez dans l'onglet **TD** (barre de navigation)
3. Dans le panneau principal, vous verrez des boutons/chips de navigation :
   - **⚡ Import direct (0 token)** (chip ambre) → JSON et Texte brut
   - **📤 Upload & IA TD** (chip violet) → Upload PDF/Image avec OCR IA

---

### Mode 1 : Import JSON structuré (0 token)

**Quand l'utiliser** : Vous avez des questions d'exercices TD déjà rédigées.

**Étapes** :

1. Appuyez sur le chip **"⚡ Import direct (0 token)"**
2. Restez sur l'onglet **"JSON structuré"**
3. Remplissez les métadonnées :
   - **Matière** : Mathématiques, Physique, Droit, etc.
   - **Niveau** : Licence 1, Master 2, BTS, etc.
   - **Université** (optionnel) : nom de l'université
4. Collez ou chargez votre JSON
5. Appuyez sur **"Importer les questions"**
6. ✅ Questions immédiatement disponibles dans le quiz TD

**Format du JSON** :

```json
[
  {
    "question": "Calculer la dérivée de f(x) = x² + 3x - 5",
    "options": ["2x + 3", "x² + 3", "2x - 5", "3x + 2"],
    "correct_index": 0,
    "explanation": "f'(x) = 2x + 3 (dérivée terme à terme)",
    "difficulty": 2,
    "subject": "Mathématiques"
  },
  {
    "question": "Quel est le principe fondamental de la dynamique ?",
    "options": [
      "F = ma",
      "E = mc²",
      "PV = nRT",
      "V = IR"
    ],
    "correct_index": 0,
    "explanation": "Le PFD (2ème loi de Newton) : la somme des forces = masse × accélération.",
    "difficulty": 1,
    "subject": "Physique"
  }
]
```

---

### Mode 2 : Texte brut collé (0 token)

**Quand l'utiliser** : Vous avez le texte d'un exercice, un corrigé-type ou un support de cours universitaire.

**Étapes** :

1. Appuyez sur **"⚡ Import direct (0 token)"**
2. Allez sur l'onglet **"Texte brut"**
3. Remplissez les métadonnées :
   - **Matière**, **Niveau**, **Université** (optionnel)
4. Sélectionnez le **type de document** :
   - **Exercice** : un exercice de TD
   - **Corrigé-type** : la correction d'un exercice
   - **Sujet d'examen** : un sujet d'examen universitaire
   - **Support de cours** : contenu pédagogique
5. Collez le texte
6. Appuyez sur **"Indexer dans la base IA"**
7. ✅ Le texte est indexé pour la génération d'exercices et les corrections IA

**Exemple** :

```
UNIVERSITÉ JOSEPH KI-ZERBO — Licence 2 Mathématiques
TD n°3 — Analyse : Suites numériques

Exercice 1 :
Soit la suite (u_n) définie par u_0 = 1 et u_{n+1} = (2u_n + 3) / (u_n + 2)
a) Montrer que la suite est bornée
b) Étudier la monotonie
c) En déduire que la suite converge et déterminer sa limite

Exercice 2 :
Soit la suite (v_n) définie par v_n = u_n - √3
a) Exprimer v_{n+1} en fonction de v_n
b) En déduire la nature de la suite (v_n)
c) Déterminer u_n en fonction de n

Corrigé :
Exercice 1 :
a) Par récurrence : si 0 < u_n < 3, alors...
(suite du corrigé)
```

---

### Mode 3 : Upload PDF/Image avec OCR IA (consomme des tokens)

Identique au mode Concours. Appuyez sur le chip **"📤 Upload & IA TD"** et suivez les mêmes étapes.

---

## 4. Format JSON détaillé

### Structure d'une question

| Champ | Type | Obligatoire | Description |
|-------|------|-------------|-------------|
| `question` | string | ✅ Oui | Le texte de la question |
| `options` | string[] | ✅ Oui | Les choix de réponse (2 à 6) |
| `correct_index` | integer | ✅ Oui | Index de la bonne réponse (0 = premier choix) |
| `explanation` | string | Recommandé | Explication de la bonne réponse |
| `difficulty` | integer | Optionnel | Difficulté de 1 (facile) à 5 (très difficile). Défaut : 2 |
| `subject` | string | Optionnel | Matière (écrase la matière globale si présente) |

### Formats acceptés

**Format 1 — Tableau simple** (recommandé) :
```json
[
  { "question": "...", "options": ["A", "B", "C", "D"], "correct_index": 0, "explanation": "..." },
  { "question": "...", "options": ["A", "B", "C", "D"], "correct_index": 2, "explanation": "..." }
]
```

**Format 2 — Objet avec métadonnées** :
```json
{
  "concours_type": "ENAREF",
  "subject": "Culture Générale",
  "year": 2024,
  "questions": [
    { "question": "...", "options": ["A", "B", "C", "D"], "correct_index": 1, "explanation": "..." }
  ]
}
```

### ⚠️ Erreurs fréquentes à éviter

| Erreur | Exemple | Correction |
|--------|---------|------------|
| `correct_index` commence à 1 | `"correct_index": 1` pour le 1er choix | Doit être `0` pour le 1er choix |
| Options vides | `"options": []` | Minimum 2 options |
| JSON mal formaté | Virgule en trop à la fin | Validez sur jsonlint.com |
| Texte trop court | `"question": "?"` | Question claire et complète |

---

## 5. Bonnes pratiques

### Priorisation du contenu

1. **Questions QCM (JSON)** — Impact immédiat, 0 token
   - Commencer par les annales des 3 dernières années
   - 20-30 questions par matière = base solide

2. **Corrigés et sujets (Texte brut)** — Enrichit l'IA, 0 token
   - Coller les corrigés officiels
   - L'IA apprend les patterns de réponse

3. **Documents papier (OCR)** — Dernier recours
   - Uniquement si le texte ne peut pas être recopié
   - Privilégier les photos nettes et bien éclairées

### Volume recommandé par matière

| Niveau | Questions QCM | Textes indexés | Résultat attendu |
|--------|--------------|----------------|------------------|
| Minimum | 20 questions | 1-2 sujets | Quiz basique fonctionnel |
| Bon | 50-100 questions | 3-5 sujets + corrigés | Quiz varié + IA pertinente |
| Excellent | 200+ questions | 10+ sujets + corrigés + cours | IA experte, quiz adaptatif optimal |

### Fréquence d'alimentation

- **Hebdomadaire** : Ajouter les nouveaux exercices/sujets de la semaine
- **Après chaque concours** : Récupérer et intégrer le sujet + corrigé
- **Début de semestre** : Alimenter les matières du nouveau programme

---

## 6. FAQ

### Q : Les questions importées sont-elles immédiatement visibles par les étudiants ?
**R** : Oui, les questions JSON sont publiées et actives dès l'import. Elles apparaissent dans le prochain quiz lancé par l'étudiant.

### Q : Le texte brut génère-t-il automatiquement des questions ?
**R** : Non, pas automatiquement. Le texte brut enrichit la **base de connaissances** de l'IA. Quand l'IA génère de nouvelles questions (via le bouton "Générer des questions"), elle s'inspire du contenu indexé pour produire des questions plus pertinentes et précises.

### Q : Puis-je importer le même sujet plusieurs fois ?
**R** : Techniquement oui, mais ce n'est pas recommandé car cela créerait des doublons. Vérifiez avant d'importer.

### Q : Comment savoir combien de questions existent dans une matière ?
**R** : Dans l'onglet Concours admin, les compteurs par matière sont affichés. Dans l'onglet TD, le quiz affiche le nombre total de questions disponibles.

### Q : L'OCR fonctionne-t-il avec des documents manuscrits ?
**R** : L'OCR (Gemini 2.0 Flash Vision) peut lire les textes imprimés et certains manuscrits lisibles. Pour les manuscrits difficiles à lire, le résultat peut être imprécis — préférez le mode Texte brut en recopiant.

### Q : Combien de tokens consomme un upload PDF/Image ?
**R** : Environ 2 000 à 8 000 tokens par document selon la longueur. Un document de 5 pages consomme environ 5 000 tokens. Les modes JSON et Texte brut consomment **0 token**.

### Q : Les imports TD et Concours sont-ils séparés ?
**R** : Oui, complètement. Les questions importées dans l'onglet Concours ne sont visibles que dans le module Concours, et inversement pour le TD.

---

## 7. Architecture technique

```
┌──────────────────────────────────────────────────┐
│                ADMINISTRATEUR                     │
│                                                  │
│  Mode 1: JSON structuré ──────┐                  │
│  Mode 2: Texte brut ──────────┤  0 token         │
│  Mode 3: PDF/Image OCR ───────┘  (tokens)        │
└──────────────────┬───────────────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────────────────┐
│              SUPABASE (Base de données)           │
│                                                  │
│  ┌─────────────────┐  ┌──────────────────┐       │
│  │ prep_questions   │  │ td_questions      │      │
│  │ (is_published)   │  │ (is_active)       │      │
│  └────────┬────────┘  └────────┬─────────┘       │
│           │                    │                  │
│  ┌────────▼────────┐  ┌───────▼──────────┐       │
│  │ prep_doc_chunks  │  │ td_doc_chunks     │      │
│  │ (RAG indexé)     │  │ (RAG indexé)      │      │
│  └─────────────────┘  └──────────────────┘       │
└──────────────────┬───────────────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────────────────┐
│                  ÉTUDIANT                         │
│                                                  │
│  Quiz Concours ← prep_questions                  │
│  Quiz TD ← td_questions                         │
│  Scanner sujet ← Edge Function (OCR + IA)        │
│  Quiz adaptatif ← faiblesses + questions ciblées │
└──────────────────────────────────────────────────┘
```

### RPCs Supabase utilisées

| RPC | Module | Rôle |
|-----|--------|------|
| `app_admin_prep_import_questions_json` | Concours | Import JSON → prep_questions |
| `app_admin_prep_import_text_bulk` | Concours | Texte brut → prep_doc_chunks |
| `app_td_admin_import_questions_json` | TD | Import JSON → td_questions |
| `app_td_admin_import_text_bulk` | TD | Texte brut → td_doc_chunks |
| `app_prep_get_quiz_questions` | Concours | Charger questions pour quiz |
| `app_td_student_get_quiz_questions` | TD | Charger questions pour quiz TD |

### Edge Functions

| Fonction | Rôle |
|----------|------|
| `prep-scan-subject` | OCR + réponses IA (concours) |
| `td-scan-subject` | OCR + correction IA (TD) |
| `prep-ingest-document` | Pipeline OCR → chunks → embeddings |
| `td-ingest-document` | Pipeline OCR → chunks → embeddings |

---

*Document généré le 30 mars 2026 — Academia App*
