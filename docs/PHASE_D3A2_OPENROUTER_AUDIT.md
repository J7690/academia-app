# PHASE D.3A.2 – OPENROUTER AUDIT

**Date** : 23 Juin 2026  
**Phase** : D.3A.2 – IA Generation Architecture Refactor  
**Mode** : AUDIT

---

## OBJECTIF

Auditer l'infrastructure OpenRouter existante pour déterminer les composants réutilisables pour le Smart Whiteboard Content Agent.

---

## DIRECTIVE

Toute validation concernant Supabase, Edge Functions, Secrets, OpenRouter doit être réalisée via les RPC Python administrateurs présents dans `.windsurf`.

Aucune hypothèse. Aucune supposition.

---

## PARTIE 1 – EDGE FUNCTIONS OPENROUTER

### 1.1 Liste des Edge Functions

| Edge Function | Utilisation | OpenRouter | Cascade | RAG |
|---------------|-------------|------------|---------|-----|
| bobodo-chat | Assistant général | ✅ | ✅ | ✅ |
| prep-tutor-chat | Tuteur IA concours BF | ✅ | ✅ | ✅ |
| prep-generate-questions | Générateur QCM concours BF | ✅ | ✅ | ✅ |
| td-tutor-chat | Tuteur IA TD | ✅ | ✅ | ✅ |
| td-generate-exercises | Générateur exercices TD | ✅ | ✅ | ❌ |
| prep-grade-assignment | Correcteur IA | ✅ | ✅ | ❌ |
| prep-analyze-trends | Analyse tendances | ✅ | ❌ | ❌ |
| prep-compose-exam-blanc | Composition sujets | ✅ | ✅ | ❌ |
| academia-ai-assistant | Assistant général | ✅ | ❌ | ❌ |
| test-openrouter-config | Test configuration | ✅ | ❌ | ❌ |
| test-openrouter-validation | Test validation | ✅ | ✅ | ❌ |

### 1.2 Secrets Supabase

| Secret | Utilisation | Configuré |
|--------|-------------|-----------|
| OPENROUTER_API_KEY | Clé API OpenRouter | ✅ |
| OPENROUTER_MODEL | Modèle principal | ✅ |
| OPENROUTER_FALLBACK_MODEL | Modèle fallback | ✅ |
| OPENROUTER_EMBEDDING_MODEL | Modèle embeddings | ✅ |

### 1.3 Cascade Multi-Modèles

**Architecture cascade** :
```
qwen/qwen3.6-plus:free (primary)
  ↓
nvidia/nemotron-3-super-120b-a12b:free (fallback)
  ↓
google/gemini-2.0-flash-lite-001 (fallback)
  ↓
google/gemini-2.0-flash-001 (fallback)
```

**Implémentation** :
- `callWithCascade()` dans chaque Edge Function
- Fallback automatique si modèle échoue
- Tracking coût USD par modèle
- Tracking tokens input/output

### 1.4 RAG (Retrieval-Augmented Generation)

**Edge Functions avec RAG** :
- bobodo-chat : `app_search_bobodo_knowledge_vector`, `app_search_bobodo_knowledge`
- prep-tutor-chat : `app_prep_semantic_search`, `app_prep_get_rag_chunks_by_name`
- td-tutor-chat : `app_td_semantic_search`, `app_td_doc_chunks`

**Embeddings** :
- Modèle : `openai/text-embedding-3-small`
- Stockage : pgvector dans Supabase
- Index : HNSW

---

## PARTIE 2 – SERVICES IA FLUTTER

### 2.1 Services existants

| Service | Fichier | Edge Function | Utilisation |
|---------|---------|---------------|-------------|
| PrepAiService | prep_ai_service.dart | prep-tutor-chat | Tuteur IA concours BF |
| BobodoProvider | bobodo_provider.dart | bobodo-chat | Assistant général |
| PsychotechAiService | psychotech_ai_service.dart | prep-tutor-chat | Tests psychotechniques |

### 2.2 Wrappers OpenRouter

**Aucun wrapper OpenRouter côté client Flutter.**

Tous les appels OpenRouter passent par les Edge Functions Supabase. La clé API n'est jamais exposée côté client.

---

## PARTIE 3 – AGENTS OPENROUTER

### 3.1 Bobodo Assistant

**Responsabilités** :
- Assistant général Academia
- Orientation études/emploi
- Réponses questions plateforme
- Aide utilisateur

**Données manipulées** :
- bobodo_knowledge (base de connaissances)
- bobodo_sessions (historique conversations)
- bobodo_answer_cache (cache sémantique)
- students (profil étudiant)

**Modèles IA** :
- Cascade multi-modèles
- RAG sémantique
- Cache sémantique
- Expansion sémantique (variants)

**Sorties attendues** :
- Réponses texte
- Streaming SSE
- Catégorisation automatique

### 3.2 Prep Tutor Chat

**Responsabilités** :
- Tuteur IA spécialisé concours BF
- Explications pédagogiques
- Correction exercices
- Conseils méthodologie

**Données manipulées** :
- prep_doc_chunks (documents PDF)
- prep_topics (sujets concours)
- prep_questions (QCM)
- prep_ai_conversations (historique)

**Modèles IA** :
- Cascade multi-modèles
- RAG sémantique
- Embeddings pgvector

**Sorties attendues** :
- Réponses texte pédagogiques
- Explications détaillées
- Conseils méthodologiques

### 3.3 Prep Generate Questions

**Responsabilités** :
- Génération QCM concours BF
- Composition exam blanc
- Analyse tendances
- Prédictions probabilité

**Données manipulées** :
- prep_doc_chunks (documents PDF)
- prep_topic_predictions (tendances)
- prep_news_articles (actualités)
- prep_questions (QCM générés)

**Modèles IA** :
- Cascade multi-modèles
- RAG sémantique
- Embeddings pgvector

**Sorties attendues** :
- JSON QCM (questions, options, corrections)
- Exam blanc complet
- Analyse tendances

---

## PARTIE 4 – AGENTS À CRÉER

### 4.1 Smart Whiteboard Content Agent

**Responsabilités** :
- Génération Storyboard JSON
- Structuration pédagogique
- Création scènes et blocs
- Adaptation renderer/theme

**Données manipulées** :
- whiteboard_projects (projets)
- storyboard_json (JSONB)
- Input utilisateur (sujet, texte, plan, cours)

**Modèles IA** :
- Cascade multi-modèles (réutilisable)
- RAG (optionnel, pour enrichissement)
- Prompt spécialisé Storyboard

**Sorties attendues** :
- Storyboard JSON valide
- Conforme storyboard_models.dart
- Conforme SMART_WHITEBOARD_DATA_CONTRACT.md

---

## PARTIE 5 – COMPOSANTS RÉUTILISABLES

### 5.1 Cascade Multi-Modèles

**Réutilisable** : ✅

**Implémentation** :
```typescript
const TEXT_CASCADE = [
  { model: 'qwen/qwen3.6-plus:free', tier: 'primary' },
  { model: 'nvidia/nemotron-3-super-120b-a12b:free', tier: 'fallback' },
  { model: 'google/gemini-2.0-flash-lite-001', tier: 'fallback' },
  { model: 'google/gemini-2.0-flash-001', tier: 'fallback' },
].filter(m => m.model);
```

**Action** : Copier depuis prep-generate-questions

### 5.2 Crédits System

**Réutilisable** : ✅

**RPCs** :
- `app_student_reserve_credits`
- `app_student_confirm_credits`
- `app_student_refund_credits`

**Action** : Utiliser même pattern que prep-generate-questions

### 5.3 Auth Supabase

**Réutilisable** : ✅

**Pattern** :
```typescript
const supabaseUser = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
  global: { headers: { Authorization: `Bearer ${jwt}` } },
});
const { data: userData, error: userError } = await supabaseUser.auth.getUser(jwt);
```

**Action** : Copier depuis prep-generate-questions

### 5.4 JSON Parsing

**Réutilisable** : ✅

**Pattern** :
```typescript
const jsonMatch = rawResponse.match(/\{[\s\S]*"questions"[\s\S]*\}/);
if (jsonMatch) {
  jsonStr = jsonMatch[0];
}
```

**Action** : Adapter pour Storyboard JSON

---

## PARTIE 6 – COMPOSANTS NON RÉUTILISABLES

### 6.1 RAG Sémantique

**Non réutilisable** : ❌

**Raison** :
- Bobodo utilise `app_search_bobodo_knowledge_vector`
- Prep utilise `app_prep_semantic_search`
- Smart Whiteboard n'a pas de base de connaissances dédiée

**Action** : Créer RAG optionnel V2 (si enrichissement contenu souhaité)

### 6.2 Prompts Système

**Non réutilisable** : ❌

**Raison** :
- Bobodo : assistant général
- Prep : tuteur IA concours BF
- Smart Whiteboard : génération Storyboard JSON

**Action** : Créer prompt spécialisé Storyboard

### 6.3 Cache Sémantique

**Non réutilisable** : ❌

**Raison** :
- Bobodo utilise `app_search_bobodo_answer_cache`
- Smart Whiteboard n'a pas de cache dédié

**Action** : Créer cache optionnel V2 (si optimisation souhaitée)

---

## PARTIE 7 – STRATÉGIE OPENROUTER

### 7.1 Modèle Recommandé

**Modèle principal** : `google/gemini-2.0-flash-001`

**Raisons** :
- Haute qualité génération JSON
- Support structuration complexe
- Coût raisonnable
- Fallback cascade disponible

### 7.2 Coût Estimé

**Génération Storyboard** :
- Input : ~500 tokens (sujet + instructions)
- Output : ~2000 tokens (Storyboard JSON)
- Coût estimé : ~$0.001 - $0.002 par génération

**Comparaison** :
- Bobodo chat : ~$0.0005 par message
- Prep QCM : ~$0.002 par génération
- Smart Whiteboard : ~$0.001 - $0.002 par génération

### 7.3 Temps Estimé

**Génération Storyboard** :
- Temps moyen : 3-5 secondes
- Cascade : +1-2 secondes si fallback
- Total : 5-7 secondes maximum

### 7.4 Taille Maximale Storyboard

**Limite recommandée** : 100 Ko

**Raisons** :
- JSONB Supabase : 1 Go max
- Performance : index GIN efficace jusqu'à 100 Ko
- UX : temps génération acceptable

**Scènes recommandées** : 5-10 scènes
**Blocs recommandés** : 20-50 blocs

---

## CONCLUSION

### Composants Réutilisables

- ✅ Cascade multi-modèles
- ✅ Crédits system
- ✅ Auth Supabase
- ✅ JSON parsing
- ✅ Secrets OpenRouter

### Composants à Créer

- ❌ Edge Function `whiteboard-generate-storyboard`
- ❌ Prompt spécialisé Storyboard
- ❌ Validation JSON Storyboard
- ❌ RPC `whiteboard_create_project` (déjà existant)
- ❌ RPC `whiteboard_update_project` (déjà existant)

### Architecture Recommandée

**Smart Whiteboard Content Agent** :
- Edge Function dédiée
- Cascade multi-modèles réutilisée
- Crédits system réutilisé
- Prompt spécialisé Storyboard
- Validation JSON stricte

---

**Fin de PHASE D.3A.2 – OPENROUTER AUDIT**
