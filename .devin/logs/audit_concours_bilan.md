# AUDIT COMPLET — Système Concours Academia
## Date: 2026-04-06

---

## 1. TABLES (schema `app`)

| Table | Lignes | Rôle |
|-------|--------|------|
| `prep_subjects` | **19** | Matières (Culture Gén, Droit, Éco...) |
| `prep_questions` | **147** | Questions QCM |
| `prep_question_choices` | **0** | Choix individuels (A/B/C/D) — vide |
| `prep_source_documents` | **0** | Documents sources (PDF, texte collé) — **VIDE** |
| `prep_doc_chunks` | **0** | Chunks de contenu pour RAG — **VIDE** |
| `prep_ai_generations` | **5** | Générations IA historiques |
| `prep_attempts` | **0** | Tentatives étudiants — vide |
| `prep_student_progress` | **1** | Progression étudiants |
| `prep_ai_usage_logs` | **4** | Logs usage IA |
| `prep_ai_conversations` | **0** | Conversations tuteur IA — vide |
| `prep_student_weaknesses` | **0** | Faiblesses étudiants — vide |

### Colonnes clés `prep_source_documents`:
- `id`, `created_by`, `subject_id`, `year`, `doc_type`, `source_type`, `storage_bucket`, `storage_path`, `extracted_text`, `status`, `created_at`, `updated_at`, `concours_type`, `subject_name`, `original_filename`, `page_count`, `extraction_method`, `has_correction`

### Colonnes clés `prep_doc_chunks`:
- `id`, `source_document_id` (FK, NOT NULL), `chunk_index` (NOT NULL), `content` (NOT NULL), `metadata`, `created_at`, `embedding` (vector), `chunk_type`, `concours_type`, `subject_name`, `year`, `question_number`, `is_correction`, `token_count`

### Storage bucket:
- `prep-documents` (existe)

---

## 2. RPCs (46 total, schema `public`)

### RPCs Admin (16):
| RPC | Rôle |
|-----|------|
| `app_admin_prep_import_questions_json` | Import JSON → `prep_questions` |
| `app_admin_prep_import_text_bulk` | Coller texte → `prep_source_documents` + `prep_doc_chunks` |
| `app_admin_prep_create_subject` | Créer une matière |
| `app_admin_prep_upsert_source_document` | Créer/maj un document source |
| `app_admin_prep_update_source_document_text` | Mettre à jour le texte extrait |
| `app_admin_prep_set_source_document_status` | Changer le statut d'un doc |
| `app_admin_prep_upsert_doc_chunk` | Créer/maj un chunk |
| `app_admin_prep_list_source_documents` | Lister les docs sources |
| `app_admin_prep_list_doc_chunks` | Lister les chunks d'un doc |
| `app_admin_prep_list_ai_generations` | Lister les générations IA |
| `app_admin_prep_create_ai_generation` | Créer une génération IA |
| `app_admin_prep_set_ai_generation_status` | Changer statut génération |
| `app_admin_prep_publish_ai_generation` | Publier (→ `prep_questions`) |
| `app_admin_prep_list_entitlements` | Lister les accès |
| `app_admin_prep_ai_get_usage_summary` | Stats usage IA |
| `app_admin_prep_get_attempts_summary` | Stats tentatives |

### RPCs Étudiant (19):
| RPC | Rôle |
|-----|------|
| `app_prep_list_subjects` | Lister les matières |
| `app_prep_list_chapters` | Lister les chapitres |
| `app_prep_list_published_questions` | Questions publiées (2 overloads) |
| `app_prep_list_question_choices` | Choix d'une question |
| `app_prep_get_quiz_questions` | Quiz (par subject text, random) |
| `app_prep_get_adaptive_quiz` | Quiz adaptatif (faiblesses) |
| `app_prep_create_attempt` | Enregistrer une tentative |
| `app_prep_list_my_attempts` | Historique tentatives |
| `app_prep_get_my_subject_stats` | Stats par matière |
| `app_prep_get_student_progress` | Progression globale |
| `app_prep_sync_student_progress` | Sync progression |
| `app_prep_get_subject_stats` | Stats par matière (agrégé) |
| `app_prep_get_weakness_analysis` | Analyse faiblesses |
| `app_prep_get_my_entitlement` | Accès paywall |
| `app_prep_get_predictions` | Prédictions de sujets |
| `app_prep_get_psychotech_profile` | Profil psychotech |
| `app_prep_get_psychotech_stats` | Stats psychotech |
| `app_prep_save_psychotech_result` | Sauver résultat psychotech |
| `app_prep_update_psychotech_profile` | Maj profil psychotech |

### RPCs IA/RAG (4):
| RPC | Rôle | Besoin embeddings |
|-----|------|-------------------|
| `app_prep_semantic_search` | Recherche vectorielle dans chunks | **OUI** |
| `app_prep_get_rag_chunks` | Récupère chunks par subject_id | **NON** |
| `app_prep_ai_check_rate_limit` | Rate limiting IA | — |
| `app_prep_ai_log_usage` | Log usage IA | — |

### RPCs Étudiants additionnelles (5):
| RPC | Rôle |
|-----|------|
| `app_prep_student_list_assignments` | Devoirs |
| `app_prep_student_get_submission` | Soumission |
| `app_prep_student_submit_assignment` | Soumettre devoir |
| `app_prep_student_list_live_sessions` | Sessions live |
| `app_prep_student_join_live_session` | Rejoindre session |

---

## 3. EDGE FUNCTIONS (7)

| Edge Function | Lignes | RPCs appelées | Modèles IA | Tokens |
|---------------|--------|--------------|------------|--------|
| `prep-tutor-chat` | 365 | `app_prep_get_ai_config`, `app_prep_list_ai_messages`, `app_prep_save_ai_message`, **`app_prep_semantic_search`** | embedding-3-small + LLM | OUI |
| `prep-generate-questions` | 339 | `admin_execute_sql`, `app_prep_get_weakness_analysis`, **`app_prep_semantic_search`** | embedding-3-small + LLM | OUI |
| `prep-ingest-document` | 395 | `admin_execute_sql`, `app_admin_prep_list_source_documents`, `app_admin_prep_set_source_document_status`, `app_admin_prep_update_source_document_text` | gemini-2.0-flash + embedding-3-small | OUI |
| `prep-embed-chunks` | 110 | — | embedding-3-small | OUI |
| `prep-analyze-trends` | 267 | `admin_execute_sql` | — | — |
| `prep-scan-subject` | 233 | `admin_execute_sql` | gemini-2.0-flash | OUI |
| `prep-grade-assignment` | 167 | `admin_execute_sql` | — | — |

---

## 4. FLUTTER — Cartographie complète

### Admin (4 écrans + 1 provider):
| Fichier | Appels Supabase |
|---------|----------------|
| `admin_prep_concours_screen.dart` | Via `AdminPrepConcoursProvider` + RPCs directes (entitlements, analytics, tentatives) |
| `admin_prep_direct_import_screen.dart` | `app_admin_prep_import_questions_json`, `app_admin_prep_import_text_bulk` |
| `admin_prep_upload_screen.dart` | Via `AdminPrepConcoursProvider.upsertSourceDocument()` + `triggerIngestion()` |
| `admin_prep_import_screen.dart` | Via `AdminPrepConcoursProvider.importQuestionsFromAsset()` |
| **`admin_prep_concours_provider.dart`** | `app_admin_prep_list_source_documents`, `app_admin_prep_list_ai_generations`, `app_admin_prep_upsert_source_document`, `app_admin_prep_update_source_document_text`, `app_admin_prep_set_source_document_status`, `app_admin_prep_publish_ai_generation`, `app_admin_prep_create_ai_generation`, `app_admin_prep_set_ai_generation_status` + EF: `prep-ingest-document`, `prep-generate-questions`, `prep-analyze-trends` |

### Étudiant (9 écrans + 5 providers + 2 services):
| Fichier | Appels Supabase |
|---------|----------------|
| `prep_concours_home_screen.dart` | Via `PrepConcoursProvider` |
| `prep_chapters_screen.dart` | Via `PrepConcoursProvider.loadChapters()` |
| `prep_training_screen.dart` | Via `PrepConcoursProvider.loadPublishedQuestions()`, `loadChoices()`, `createAttempt()` |
| `prep_exam_screen.dart` | Idem training |
| `prep_diagnostic_screen.dart` | Idem training |
| `prep_progress_screen.dart` | Via `PrepConcoursProvider.loadMySubjectStats()`, `loadMyAttempts()` |
| `prep_scan_subject_screen.dart` | EF: `prep-scan-subject` |
| `prep_exercises_tab.dart` | `app_prep_student_list_assignments`, `app_prep_student_submit_assignment` |
| `prep_lives_tab.dart` | `app_prep_student_list_live_sessions`, `app_prep_student_join_live_session` |
| `prep_psychotech_tab.dart` | `app_prep_save_psychotech_result` |
| **`prep_concours_provider.dart`** | `app_prep_list_subjects`, `app_admin_prep_create_subject`, `app_prep_list_chapters`, `app_prep_list_published_questions`, `app_prep_list_question_choices`, `app_prep_create_attempt`, `app_prep_list_my_attempts`, `app_prep_get_my_subject_stats` |
| **`prep_quiz_provider.dart`** | `app_prep_get_student_progress`, `app_prep_sync_student_progress`, `app_prep_get_subject_stats`, `app_prep_get_quiz_questions`, `app_prep_get_adaptive_quiz` |
| **`prep_weakness_provider.dart`** | `app_prep_get_weakness_analysis` |
| **`prep_ai_service.dart`** | EF: `prep-tutor-chat` |
| **`psychotech_ai_service.dart`** | EF: `prep-tutor-chat` |
| **`psychotech_profile_widget.dart`** | `app_prep_get_psychotech_profile`, `app_prep_get_psychotech_stats` |

---

## 5. FLUX D'INJECTION CONTENU → IA

### Flux actuel (PDF — consomme des tokens):
```
Admin upload PDF → Storage prep-documents
    ↓ (EF prep-ingest-document)
gemini-2.0-flash extrait le texte → TOKENS
    ↓
Chunks créés dans prep_doc_chunks AVEC embeddings (embedding-3-small) → TOKENS
    ↓
prep-tutor-chat ou prep-generate-questions → app_prep_semantic_search → TROUVE les chunks ✅
```

### Flux actuel (Texte collé — 0 token MAIS IA ne l'utilise PAS):
```
Admin colle texte → app_admin_prep_import_text_bulk (SQL pur, 0 token)
    ↓
prep_source_documents (1 ligne, status='indexed')
prep_doc_chunks (chunks de 4000 car.) — SANS embeddings
    ↓
prep-tutor-chat → app_prep_semantic_search → cherche embedding → RIEN TROUVÉ ❌
prep-generate-questions → app_prep_semantic_search → cherche embedding → RIEN TROUVÉ ❌
```

### RPC orpheline:
```
app_prep_get_rag_chunks(p_subject_id uuid) → récupère par subject_id, SANS embeddings
JAMAIS appelée par aucun Edge Function ni Flutter
```

---

## 6. PROBLÈME IDENTIFIÉ

Les 2 Edge Functions consommatrices (`prep-tutor-chat` et `prep-generate-questions`) utilisent **UNIQUEMENT** `app_prep_semantic_search` qui nécessite des embeddings vectoriels.

Le texte collé par l'admin n'a PAS d'embeddings → l'IA ne le voit jamais.

## 7. SOLUTION PROPOSÉE (additive, ne casse rien)

1. **Créer** `app_prep_get_rag_chunks_by_name(p_subject_name text)` — résout nom → UUID puis appelle la logique de `app_prep_get_rag_chunks`
2. **Modifier** `prep-tutor-chat` (lignes 255-301) — ajouter: si `app_prep_semantic_search` retourne 0 chunks → appeler `app_prep_get_rag_chunks_by_name` comme fallback
3. **Modifier** `prep-generate-questions` (lignes 119-134) — même fallback

### Ce qui NE change PAS:
- Aucune table modifiée
- Aucune RPC existante modifiée
- Aucun code Flutter modifié
- Le flux PDF avec embeddings continue de fonctionner
- Tous les écrans étudiants inchangés
