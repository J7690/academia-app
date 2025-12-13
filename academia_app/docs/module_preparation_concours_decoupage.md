# Module "Préparation Concours" — Découpage (plan approuvé)

## Contexte
Intégrer un module "Préparation Concours" dans Academia (Flutter + Supabase) avec : cours, entraînement, examens, IA (OpenRouter + RAG), administration complète, paywall/abonnements, anti-piratage V1, analytics, et extensibilité via modules activables.

## Constats issus des audits (Déc 2025)
- RBAC côté Flutter basé sur `userMetadata['role']` avec `student`, `instructor`, `admin`, `university`.
- Live déjà intégré via LiveKit (UI student/admin + endpoint `POST /livekit/token`).
- Pattern backend existant via endpoints HTTP sous le host Supabase (`/studio/video/*`, `/livekit/token`).
- Paywall/paiement non identifié côté Flutter : à implémenter (MVP entitlements/quota puis paiement).

## Découpage

### Phase 0 — Cadrage & règles (obligatoire avant dev)
- Écrire l’audit préalable dans `.windsurf/audit/last_audit.md`.
- Fixer conventions : schéma `app`, tables `prep_*`, RPC `app_prep_*`.
- Acter l’usage de `instructor` pour le rôle "teacher" en V1 (sauf décision ultérieure).

### Phase 1 — Socle "Prépa Concours" (DB + RLS + RPC)
- Tables minimales dans `app`:
  - `prep_subjects`, `prep_chapters`
  - `prep_questions`, `prep_question_choices`
  - `prep_attempts`
  - `prep_exams`, `prep_exam_items`
- Tables pipeline IA:
  - `prep_source_documents`, `prep_doc_chunks`, `prep_ai_generations`
- RLS + grants + RPC d’accès (lecture + writes contrôlés).
- Préparer un mécanisme "modules activables" (réutilisation existant ou création).

### Phase 2 — Student UI (MVP)
- Feature Flutter `concours_prep/` avec : catalogue matières/chapitres, entraînement QCM, résultats + historique.

### Phase 3 — Admin UI (Imports + pipeline IA)
- Import ancien sujet + statuts pipeline.
- Édition du texte extrait.
- Génération lot + validation + publication.

### Phase 4 — IA V1 (OpenRouter + RAG + validation)
- Endpoints `/ai/*` sur le backend (même pattern que `/studio/*`).
- JSON strict + validation + anti-duplication + logs.

### Phase 5 — Paywall / abonnements (MVP pragmatique)
- `paywall_check` (entitlements/quota) + UI paywall.
- Paiement branché ensuite selon système retenu.

### Phase 6 — Diagnostic + Exam mode
- Diagnostic adaptatif (10–20 questions).
- Exam blanc chronométré.

### Phase 7 — Anti-piratage V1 + Analytics
- Rate-limit IA + logs.
- Watermark côté player (V1).
- Dashboards usage/conversion.
