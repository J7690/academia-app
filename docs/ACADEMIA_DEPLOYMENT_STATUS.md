# ACADEMIA DEPLOYMENT STATUS

**Date** : 24 Juin 2026  
**Version** : 1.0

---

## ENVIRONNEMENTS

### Production
**URL** : https://thevdfcwlcqzdoybfvgs.supabase.co  
**Projet** : thevdfcwlcqzdoybfvgs  
**Clé** : service_role_key

### Kamatera
**IP** : 185.167.97.144  
**User** : root

---

## COMPOSANTS DÉPLOYÉS

### Supabase

**Tables** :
- ✅ students
- ✅ student_credits
- ✅ credit_transactions
- ✅ credit_packs
- ✅ ai_action_prices
- ✅ credit_reservations
- ✅ prep_news_sources
- ✅ prep_news_articles
- ✅ application_payments
- ✅ payment_receipts
- ✅ payment_proofs
- ✅ marketplace_payments
- ✅ challenge_*
- ✅ upload_sessions
- ✅ video_assets
- ✅ renditions
- ❌ whiteboard_projects
- ❌ whiteboard_renders

**RPCs** :
- ✅ app_student_get_credit_balance
- ✅ app_student_check_ai_access
- ✅ app_student_reserve_credits
- ✅ app_student_confirm_credits
- ✅ app_student_refund_credits
- ✅ app_student_purchase_credits
- ✅ app_student_claim_weekly_bonus
- ✅ app_admin_get_ai_usage_stats
- ✅ app_admin_manage_credit_pack
- ✅ app_admin_manage_ai_action_price
- ✅ app_admin_prep_list_news_sources
- ✅ app_admin_prep_list_news_articles
- ✅ app_admin_prep_news_stats
- ✅ app_student_declare_payment
- ✅ app_create_application_payment
- ✅ app_student_create_profile_payment
- ✅ app_admin_verify_payment
- ✅ app_admin_confirm_payment
- ✅ app_admin_get_payment_detail
- ✅ app_admin_list_payments_with_context
- ✅ app_admin_list_payment_receipts_with_context
- ✅ app_university_list_payments
- ❌ whiteboard_fetch_queued_jobs
- ❌ whiteboard_mark_processing
- ❌ whiteboard_mark_done
- ❌ whiteboard_mark_failed
- ❌ whiteboard_get_any_student_id
- ❌ whiteboard_get_project
- ❌ whiteboard_update_project
- ❌ whiteboard_list_projects
- ❌ whiteboard_delete_project

**Storage** :
- ✅ whiteboard-renders
- ✅ whiteboard-narrations
- ✅ challenge-media
- ✅ video-assets
- ✅ td-documents

**Edge Functions** :
- ✅ whiteboard-generate-storyboard
- ✅ prep-tutor-chat
- ✅ td-tutor-chat
- ✅ prep-generate-questions
- ✅ td-generate-exercises
- ✅ prep-grade-assignment
- ✅ prep-scan-subject
- ✅ td-scan-subject
- ✅ prep-compose-exam-blanc
- ✅ prep-feed-actuality

### Kamatera

**Services** :
- ✅ /opt/whiteboard-worker/ (fichiers Python présents)
- ✅ /opt/video-worker/
- ✅ /opt/bobodo-vocal/

**Processus** :
- ❌ Worker whiteboard (non actif)
- ❌ Service whiteboard (non configuré)

### Flutter

**Écrans** :
- ✅ student_challenges_tab.dart
- ✅ VideoPublishScreen
- ✅ Games Hub (en cours)

---

## COMPOSANTS NON DÉPLOYÉS

### Smart Whiteboard
- ❌ Tables whiteboard_projects, whiteboard_renders
- ❌ RPCs whiteboard_*
- ❌ Worker actif
- ❌ Pipeline fonctionnel

---

## MISES À JOUR

Ce document doit être mis à jour après chaque déploiement.

---

**Fin de ACADEMIA_DEPLOYMENT_STATUS.md**
