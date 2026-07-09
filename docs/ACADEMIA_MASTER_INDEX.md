# ACADEMIA MASTER INDEX

**Date** : 24 Juin 2026  
**Version** : 1.0

---

## OBJECTIF

Index central de tous les documents Academia pour assurer la traçabilité et éviter les audits redondants.

---

## DOCUMENTS PAR CATÉGORIE

### PHASES DE VALIDATION

- `PHASE_B2_VALIDATION.md` – Validation tables whiteboard_projects et whiteboard_renders
- `PHASE_B3_RLS_VALIDATION.md` – Validation Row Level Security
- `PHASE_B4_BUCKETS_VALIDATION.md` – Validation buckets Storage
- `PHASE_B5_RPC_VALIDATION.md` – Validation RPCs
- `PHASE_C3_VALIDATION.md` – Validation Renderer V1
- `PHASE_D3A3_REAL_GENERATION_TESTS.md` – Tests génération storyboard

### PHASES D.5 – RECONSTRUCTION SMART WHITEBOARD

- `PHASE_D5_RECONSTRUCTION.md` – État de la reconstruction
- `PHASE_D5_DEPLOYMENT_PROOF.md` – Preuves de déploiement
- `PHASE_D5_PIPELINE_PROOF.md` – Preuves pipeline
- `PHASE_D5_GO_NO_GO.md` – Matrice GO/NO-GO
- `PHASE_D5A_ADMIN_RPC_CAPABILITY_AUDIT.md` – Audit capacités RPC admin
- `PHASE_D5B_DIRECT_KAMATERA_FORENSICS.md` – Forensique Kamatera directe
- `PHASE_D5C_LIVE_EXECUTION.md` – Exécution live (BLOQUÉ)
- `PHASE_D5D_ADMIN_RPC_FORENSICS.md` – Forensique RPC admin
- `PHASE_D5I_PRODUCTION_ACTIVATION_REPORT.md` – Rapport activation production

### PHASES D.6 – PRODUCT INTEGRATION AND REAL USER VALIDATION

- `PHASE_D6A_FLUTTER_INTEGRATION_AUDIT.md` – Audit intégration Flutter
- `PHASE_D6B_REAL_USER_FLOW_TESTS.md` – Tests des 4 modes réels
- `PHASE_D6C_PEDAGOGICAL_QUALITY_AUDIT.md` – Audit qualité pédagogique
- `PHASE_D6D_VIDEO_QUALITY_AUDIT.md` – Audit qualité vidéo
- `PHASE_D6E_PERFORMANCE_AUDIT.md` – Audit performance réelle
- `PHASE_D6F_ECONOMICS_AUDIT.md` – Audit économique
- `PHASE_D6G_GO_NO_GO_BETA.md` – GO/NO-GO bêta utilisateurs
- `PHASE_D6_SUMMARY.md` – Synthèse phase D.6
- `PHASE_D6H_KNOWLEDGE_PRESERVATION_LOCK.md` – Verrouillage préservation connaissance
- `PHASE_D6I_PROJECT_CHECKPOINT_SYSTEM.md` – Système de checkpoint

### AUDITS

- `PHASE_D4A_INFRASTRUCTURE_TRUTH_AUDIT.md` – Audit infrastructure
- `PHASE_D4B_DEPLOYMENT_FORENSICS.md` – Forensique déploiement

### DOCUMENTS ARCHITECTURE

- `STUDIO_ARCHITECTURE_CURRENT_STATE.md` – Architecture Studio
- `STUDIO_FLUTTER_AUDIT.md` – Audit Flutter Studio

### DOCUMENTS PRIORITAIRES

- `AUDIT_PRIORITAIRE_STUDIO_FEED.md` – Audit prioritaire Studio Feed

### DOCUMENTS DE RÉFÉRENCE PERMANENTS

- `ACADEMIA_MASTER_INDEX.md` – Index central du projet
- `ACADEMIA_TRUTH_MATRIX.md` – Matrice de vérité unique
- `ACADEMIA_CHANGELOG.md` – Historique complet
- `ACADEMIA_DEPLOYMENT_STATUS.md` – État des déploiements
- `ACADEMIA_PROJECT_STATE.md` – État actuel du projet
- `ACADEMIA_CURRENT_CHECKPOINT.md` – Checkpoint courant (point de reprise)
- `ACADEMIA_PERMANENT_EXECUTION_PROTOCOL.md` – Protocole permanent d'exécution
- `ACADEMIA_TECHNICAL_CONSTITUTION.md` – Constitution technique
- `ACADEMIA_ARCHITECTURE_DECISIONS.md` – Registre des décisions d'architecture
- `ACADEMIA_CONTRACT_REGISTRY.md` – Registre des contrats techniques
- `ACADEMIA_TRACEABILITY_MATRIX.md` – Matrice de traçabilité
- `ACADEMIA_DOCUMENT_COHERENCE_SYSTEM.md` – Système de cohérence documentaire
- `ACADEMIA_ENGINEERING_LOGBOOK.md` – Journal des décisions techniques

---

## COMPOSANTS ACADÉMIA

### Supabase

**Tables** :
- students
- credit_transactions
- student_credits
- credit_packs
- ai_action_prices
- credit_reservations
- challenge_*
- upload_sessions
- video_assets
- renditions

**RPCs** :
- app_student_get_credit_balance
- app_student_check_ai_access
- app_student_reserve_credits
- app_student_confirm_credits
- app_student_refund_credits
- app_student_purchase_credits
- app_student_claim_weekly_bonus
- app_admin_get_ai_usage_stats
- app_admin_manage_credit_pack
- app_admin_manage_ai_action_price

**Storage** :
- whiteboard-renders
- whiteboard-narrations
- challenge-media
- video-assets

### Kamatera

**Services** :
- /opt/whiteboard-worker/ (fichiers Python présents)
- /opt/video-worker/
- /opt/bobodo-vocal/

### Edge Functions

- whiteboard-generate-storyboard
- prep-tutor-chat
- td-tutor-chat
- prep-generate-questions
- td-generate-exercises
- prep-grade-assignment
- prep-scan-subject
- td-scan-subject
- prep-compose-exam-blanc
- prep-feed-actuality

### Flutter

**Écrans** :
- student_challenges_tab.dart
- VideoPublishScreen
- Games Hub (en cours)

---

## PROTOCOLE PERMANENT

Voir mémoire système : PROTOCOLE PERMANENT ACADEMIA

---

## MISES À JOUR

Ce document doit être mis à jour après chaque phase majeure.

---

**Fin de ACADEMIA_MASTER_INDEX.md**
