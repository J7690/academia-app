# Plan IA Concours Réels — Analyse & Propositions
**Date** : 15 Mars 2026  
**Objectif** : Permettre l'entraînement avec des sujets réels, génération automatique de questions, corrections IA contextualisées

---

## 1. ÉTAT DES LIEUX — Ce qui existe déjà

### 1.1 Infrastructure IA en place

| Composant | Statut | Ce qu'il fait | Limitation actuelle |
|-----------|--------|---------------|---------------------|
| **Edge Function `prep-tutor-chat`** | ✅ Déployée | Chat IA tuteur via OpenRouter (même clé que Bobodo) | Répond avec des connaissances **génériques** du LLM, pas de contenu spécifique aux vrais sujets |
| **Backend Python `/ai/prep/generate`** | ✅ Code prêt | Génère des QCM via OpenRouter avec RAG | Pas déployé (Railway indisponible), les chunks RAG sont **vides** |
| **RPC `app_prep_get_rag_chunks`** | ✅ Déployée | Récupère des chunks de documents indexés pour enrichir le contexte IA | Table `prep_doc_chunks` = **0 lignes** (aucun document indexé) |
| **Tables `prep_source_documents` + `prep_doc_chunks`** | ✅ Existent | Stockent les documents source et leurs fragments texte | **Vides** — aucun pipeline d'ingestion de PDF |
| **Table `prep_ai_generations`** | ✅ Existe | Stocke les générations IA (QCM générés) | 1 seule entrée de test |
| **Table `prep_ai_usage_logs`** | ✅ Existe | Logs d'utilisation IA (rate limiting, analytics) | 4 entrées de test |
| **Bucket `prep-documents`** | ✅ Créé | Stockage PDF/images des sujets | **Vide** — pas encore d'upload |
| **RPC `app_admin_prep_upsert_source_document`** | ✅ Existe | CRUD admin pour les documents source | Fonctionnel mais pas connecté à un pipeline d'extraction |
| **RPC `app_admin_prep_upsert_doc_chunk`** | ✅ Existe | Insère des chunks texte dans la DB | Fonctionnel mais jamais appelé automatiquement |

### 1.2 Ce qui manque (le "gap")

```
FLUX ACTUEL (incomplet):
Admin upload PDF → [RIEN] → DB vide → IA génère avec connaissances génériques

FLUX CIBLE (complet):
Admin upload PDF → OCR/Extraction → Chunking → Embeddings → DB enrichie → IA génère depuis sujets réels
```

**Les 4 maillons manquants :**
1. **Pipeline d'extraction PDF** → Transformer un PDF de sujet en texte structuré
2. **Pipeline de chunking intelligent** → Découper le texte en morceaux sémantiques (par question, par section)
3. **Embeddings vectoriels** → Permettre la recherche sémantique (pgvector)
4. **Prompts spécialisés** → Adapter les prompts IA pour exploiter le contexte des vrais sujets

---

## 2. RECHERCHE EXTERNE — Comment font les grandes plateformes

### 2.1 Plateformes de référence

| Plateforme | Approche | Technologie |
|------------|----------|-------------|
| **PrepAI** (prepai.io) | Upload de PDF/texte → génération automatique de QCM, vrai/faux, fill-in-the-blank | LLM + Bloom's Taxonomy + extraction de concepts clés |
| **Questgen** (questgen.ai) | Génère jusqu'à 150 questions d'un seul texte (100k mots) | NLP avancé, multiple types de questions |
| **Quillionz** | Extraction de mots-clés → génération de questions factuelles structurées | NLP + templates de questions |
| **Eklavvya** | Analyse du syllabus + manuels PDF → QCM alignés au curriculum | IA + alignment curriculaire |

### 2.2 Architecture RAG (Retrieval-Augmented Generation) — Standard de l'industrie

```
┌─────────────────────────────────────────────────────────────┐
│  INGESTION (admin upload)                                   │
│  PDF → OCR (Mistral OCR / pdf-text) → Texte brut           │
│  → Nettoyage → Chunking sémantique (par question/section)  │
│  → Embeddings (text-embedding-3-small) → pgvector           │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  GÉNÉRATION (automatique ou à la demande)                   │
│  Prompt + Chunks pertinents (similarity search) → LLM      │
│  → QCM structuré (question + options + correction)          │
│  → Validation admin → Publication                           │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  TUTEUR IA (chat étudiant)                                  │
│  Question étudiant → Similarity search chunks pertinents    │
│  → LLM avec contexte réel → Réponse sourcée                │
│  → Indication si correct/incorrect + explication détaillée  │
└─────────────────────────────────────────────────────────────┘
```

### 2.3 Sources de sujets réels identifiées (Cameroun)

| Source | Contenu | Format |
|--------|---------|--------|
| **kamerpower.com** | Anciennes épreuves ENAM + corrigés (droit admin, culture générale) | PDF téléchargeables |
| **concourscameroon.com** | Épreuves ENS, ENSET, BAC, BEPC par série et matière | PDF |
| **cameroondeskacademy.com** | Épreuves + corrigés ENS/ENSET toutes filières | PDF |
| **touslesconcours.info** | Épreuves ENSET Bambili, gestion, informatique | PDF |
| **Manuels scolaires officiels** | Programmes MINEDUB/MINESEC | PDF/numérique |

### 2.4 Technologie clé : OpenRouter Universal PDF Support

**Découverte importante** : OpenRouter supporte nativement le traitement de PDF depuis fin 2024.
- **`mistral-ocr`** : OCR + extraction texte + images embarquées — $2/1000 pages
- **`pdf-text`** : Extraction texte seul — **gratuit**
- Fonctionne avec **tous les LLMs** disponibles sur OpenRouter
- Gère les PDFs scannés (image-only) via OCR

**Impact** : Pas besoin de serveur séparé pour l'OCR. On peut faire toute l'extraction directement via l'API OpenRouter depuis une Edge Function Supabase.

---

## 3. PROPOSITION CONCRÈTE — Architecture cible

### 3.1 Vue d'ensemble du pipeline

```
┌──────────────────────────────────────────────────────────────────────┐
│  PHASE A — INGESTION (Admin)                                        │
│                                                                      │
│  [Admin Flutter] ──upload PDF──→ [Supabase Storage: prep-documents] │
│       ↓                                                              │
│  [Edge Function: prep-ingest-document]                               │
│    1. Télécharge le PDF depuis Storage                                │
│    2. Envoie à OpenRouter (mistral-ocr ou pdf-text)                  │
│    3. Reçoit le texte extrait + métadonnées                          │
│    4. Découpe en chunks intelligents (par question, par section)      │
│    5. Génère des embeddings (text-embedding-3-small via OpenRouter)   │
│    6. Stocke chunks + embeddings dans prep_doc_chunks (pgvector)     │
│    7. Met à jour prep_source_documents.status = 'indexed'            │
└──────────────────────────────────────────────────────────────────────┘
                                ↓
┌──────────────────────────────────────────────────────────────────────┐
│  PHASE B — GÉNÉRATION AUTOMATIQUE DE QUESTIONS                      │
│                                                                      │
│  [Edge Function: prep-generate-questions]                            │
│    1. Reçoit: subject_id + concours_type + nombre_questions          │
│    2. Similarity search dans prep_doc_chunks (pgvector)              │
│    3. Récupère les chunks les plus pertinents                        │
│    4. Prompt spécialisé → OpenRouter LLM                             │
│       "À partir de ce sujet d'examen réel [ENAM 2023, Culture Gén.],│
│        génère 10 QCM avec 4 choix, indique la bonne réponse,        │
│        et fournis une explication détaillée pour chaque question."   │
│    5. Parse le JSON retourné                                         │
│    6. Insère dans prep_questions + prep_question_choices             │
│    7. Status = 'proposed' → Admin valide → 'published'               │
└──────────────────────────────────────────────────────────────────────┘
                                ↓
┌──────────────────────────────────────────────────────────────────────┐
│  PHASE C — TUTEUR IA CONTEXTUEL (Étudiant)                          │
│                                                                      │
│  [Edge Function: prep-tutor-chat] (AMÉLIORÉE)                       │
│    1. Étudiant pose une question                                     │
│    2. Similarity search dans prep_doc_chunks avec la question        │
│    3. Récupère les 5-10 chunks les plus pertinents                   │
│    4. Enrichit le prompt système avec le contexte réel               │
│    5. LLM répond avec des références aux vrais sujets                │
│    6. Si l'étudiant propose une réponse → l'IA corrige avec          │
│       explication basée sur les corrigés officiels                   │
└──────────────────────────────────────────────────────────────────────┘
```

### 3.2 Modifications Supabase nécessaires

#### A. Extension pgvector (pour la recherche sémantique)
```sql
-- Activer pgvector
CREATE EXTENSION IF NOT EXISTS vector;

-- Ajouter colonne embedding à prep_doc_chunks
ALTER TABLE app.prep_doc_chunks 
  ADD COLUMN IF NOT EXISTS embedding vector(1536);

-- Index pour recherche rapide
CREATE INDEX IF NOT EXISTS idx_prep_doc_chunks_embedding 
  ON app.prep_doc_chunks 
  USING ivfflat (embedding vector_cosine_ops) 
  WITH (lists = 100);

-- Fonction de recherche sémantique
CREATE OR REPLACE FUNCTION public.app_prep_semantic_search(
    p_query_embedding vector(1536),
    p_subject_id UUID DEFAULT NULL,
    p_concours_type TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 10,
    p_threshold FLOAT DEFAULT 0.7
) RETURNS JSONB ...
```

#### B. Métadonnées enrichies pour les documents
```sql
-- Ajouter des colonnes de contexte aux documents source
ALTER TABLE app.prep_source_documents 
  ADD COLUMN IF NOT EXISTS concours_type TEXT,
  ADD COLUMN IF NOT EXISTS subject_name TEXT,
  ADD COLUMN IF NOT EXISTS original_filename TEXT,
  ADD COLUMN IF NOT EXISTS page_count INTEGER,
  ADD COLUMN IF NOT EXISTS extraction_method TEXT DEFAULT 'pdf-text',
  ADD COLUMN IF NOT EXISTS has_correction BOOLEAN DEFAULT false;

-- Enrichir les chunks avec plus de contexte
ALTER TABLE app.prep_doc_chunks 
  ADD COLUMN IF NOT EXISTS chunk_type TEXT DEFAULT 'content',
  ADD COLUMN IF NOT EXISTS concours_type TEXT,
  ADD COLUMN IF NOT EXISTS subject_name TEXT,
  ADD COLUMN IF NOT EXISTS year TEXT,
  ADD COLUMN IF NOT EXISTS question_number INTEGER,
  ADD COLUMN IF NOT EXISTS is_correction BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS token_count INTEGER;
```

#### C. Nouvelles tables
```sql
-- Historique des corrections IA par étudiant
CREATE TABLE IF NOT EXISTS app.prep_ai_corrections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES auth.users(id),
    question_id UUID REFERENCES app.prep_questions(id),
    student_answer TEXT NOT NULL,
    is_correct BOOLEAN,
    ai_correction TEXT NOT NULL,
    ai_explanation TEXT,
    source_chunks UUID[],  -- IDs des chunks utilisés pour la correction
    confidence_score FLOAT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### 3.3 Nouvelles Edge Functions

| Edge Function | Rôle | Déclencheur |
|---------------|------|-------------|
| `prep-ingest-document` | Extraction PDF → chunks → embeddings | Admin upload un document |
| `prep-generate-questions` | Génération QCM depuis chunks réels | Admin clique "Générer" ou automatique |
| `prep-tutor-chat` (v2) | Chat enrichi par RAG sémantique | Étudiant pose une question |

### 3.4 Modifications Flutter

| Écran | Modification |
|-------|-------------|
| **Admin: Upload de sujets** | Bouton upload PDF → Storage → trigger Edge Function → status "indexing" → "indexed" |
| **Admin: Génération IA** | Bouton "Générer QCM depuis ce sujet" → sélection concours/matière/nb questions → review → publier |
| **Étudiant: Quiz** | Les questions viennent maintenant des vrais sujets indexés (plus de démo) |
| **Étudiant: IA Tutor** | Chat enrichi avec contexte réel — l'IA cite les sources |
| **Étudiant: Sujets** | Téléchargement/consultation des PDF originaux |

---

## 4. ESTIMATION DES COÛTS

### 4.1 Coûts OpenRouter

| Opération | Coût estimé | Volume typique |
|-----------|-------------|----------------|
| **Extraction PDF** (mistral-ocr) | $2 / 1000 pages | 50 sujets × 10 pages = 500 pages → **$1** |
| **Extraction PDF** (pdf-text) | **Gratuit** | Suffisant pour les PDFs texte (non scannés) |
| **Embeddings** (text-embedding-3-small) | $0.02 / 1M tokens | ~500 chunks × 500 tokens = 250K tokens → **$0.005** |
| **Génération QCM** (Claude/GPT-4o) | ~$0.01-0.05 / question | 500 questions → **$5-25** |
| **Chat tuteur** (Claude Haiku/Sonnet) | ~$0.001-0.01 / message | 1000 messages/mois → **$1-10** |

**Coût total estimé** : **$10-40/mois** pour une utilisation modérée (50 sujets, 500 questions, 1000 conversations).

### 4.2 Coûts Supabase

- **pgvector** : Inclus dans le plan Supabase (extension PostgreSQL gratuite)
- **Storage** : 1 GB inclus (plan gratuit), suffisant pour ~200 PDFs de sujets
- **Edge Functions** : 500K invocations/mois incluses (plan gratuit)

---

## 5. PLAN D'IMPLÉMENTATION PAR PHASES

### Phase 1 : Infrastructure pgvector + schéma enrichi (1 jour)
- Activer pgvector sur Supabase
- Ajouter colonnes embedding + métadonnées aux tables existantes
- Créer la fonction de recherche sémantique
- Créer la table `prep_ai_corrections`

### Phase 2 : Edge Function `prep-ingest-document` (2 jours)
- Télécharger PDF depuis Storage
- Extraire texte via OpenRouter (pdf-text gratuit, mistral-ocr pour scans)
- Chunking intelligent (par question, par section)
- Générer embeddings via OpenRouter
- Stocker chunks + embeddings dans pgvector
- Mettre à jour le statut du document

### Phase 3 : Edge Function `prep-generate-questions` (2 jours)
- Recherche sémantique des chunks pertinents
- Prompt spécialisé pour génération QCM réaliste
- Parsing JSON structuré
- Insertion dans prep_questions + prep_question_choices
- Workflow admin : proposed → review → published

### Phase 4 : Amélioration `prep-tutor-chat` v2 (1 jour)
- Ajouter recherche sémantique dans le chat
- Enrichir le prompt avec les chunks pertinents
- L'IA cite ses sources (sujet, année, question)
- Correction contextuelle : l'étudiant propose, l'IA corrige avec explications

### Phase 5 : Flutter — UI Admin d'ingestion (1 jour)
- Écran upload PDF avec métadonnées (concours, matière, année)
- Suivi du statut d'indexation
- Bouton "Générer QCM" avec paramètres
- Review et publication des questions générées

### Phase 6 : Flutter — UI Étudiant enrichie (1 jour)
- Les quiz utilisent les vraies questions (déjà connecté)
- Le tuteur IA affiche les sources de ses réponses
- Accès aux PDF originaux des sujets
- Historique des corrections IA personnalisées

**Total estimé : 8 jours de développement**

---

## 6. CE QUI NE CHANGE PAS

- **L'architecture Supabase-first** : tout passe par les RPCs et Edge Functions
- **OpenRouter comme gateway IA** : même clé API, zéro config supplémentaire
- **Le fallback démo** : si la DB est vide, les questions démo restent disponibles
- **La gamification** : XP, streaks, badges fonctionnent indépendamment du contenu
- **Le modèle admin-centric** : l'admin contrôle tout le contenu (upload, validation, publication)

---

## 7. RÉSUMÉ EXÉCUTIF

| Question | Réponse |
|----------|---------|
| **Est-ce possible dans l'architecture actuelle ?** | **OUI** — 80% de l'infrastructure existe déjà (tables, RPCs, Edge Functions, backend). Il manque principalement le pipeline d'extraction PDF et les embeddings pgvector. |
| **Qu'est-ce qui doit être ajouté ?** | 1 extension (pgvector), 2 nouvelles Edge Functions, quelques colonnes DB, et des prompts spécialisés |
| **Qu'est-ce qui doit être modifié ?** | L'Edge Function `prep-tutor-chat` (ajout RAG sémantique), l'écran admin (ajout upload PDF), l'écran étudiant (affichage sources) |
| **Comment alimenter avec des vrais sujets ?** | L'admin upload des PDF de sujets réels → l'IA les indexe automatiquement → génère des questions → les étudiants s'entraînent |
| **Coût ?** | ~$10-40/mois pour une utilisation normale |
| **Délai ?** | ~8 jours de développement |
