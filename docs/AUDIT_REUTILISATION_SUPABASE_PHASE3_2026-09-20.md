# Audit de réutilisation Supabase — phase 3

Date : 20 septembre 2026. Inspection de production en lecture seule via `.windsurf`, le chargeur existant et `public.admin_execute_sql`. Aucun déploiement relancé.

## Portée et preuves

Inventaire de 419 relations hors catalogues système, dont 325 tables et 6 vues dans `app`, 9 tables et 1 vue dans `public`. Lecture des 3 537 colonnes et 956 contraintes de ces deux schémas, des 618 politiques de `app`/`public`/`storage`, des 16 buckets et de 105 définitions de fonctions sélectionnées autour des messages, médias et documents. Aucun contenu de conversation ou fichier utilisateur consulté.

L'inventaire inclut les autres schémas ; l'analyse détaillée des colonnes et fonctions porte sur `app` et `public`, où se trouvent les fonctionnalités concernées. Il s'agit d'un audit de structure et de réutilisation, pas d'un audit de sécurité exhaustif de toute l'application ni d'un test d'accès avec chaque compte.

Preuves détaillées locales : `.windsurf/phase3_full_inventory_20260920.json`. L'audit précédent était ciblé sur la messagerie des candidatures ; il ne constituait pas cet inventaire transversal.

## Structures déjà présentes

| Structure | Constat | Réutilisation proposée |
|---|---|---|
| `app.application_messages` | Six colonnes : id, application_id, sender_role, audience, content, created_at. Lien direct vers la candidature. | Conserver cette table et son historique. Aucune nouvelle table de messages. |
| `app.applications` | Trois dates existent : last_student_read_at, last_admin_read_at, last_university_read_at. | Conserver le suivi des dernières lectures ; il permet de déduire un état lu/non lu selon destinataire et date du message. |
| `app.application_files` | Documents liés à application_id, file_type, storage_path ; aucun message_id, auteur ou audience de conversation. La RPC d'ajout existante vérifie le propriétaire étudiant. | Conserver pour les pièces du dossier. Pas interchangeable avec une pièce jointe confidentielle d'un message sans extension du modèle et des RPC. |
| `app.student_dossier_documents` | Documents liés à l'étudiant, avec statut et validation. | Conserver pour le dossier étudiant. |
| `app.direct_messages`, `direct_conversations`, `direct_message_read_states` | Médias déjà présents, mais conversation entre deux utilisateurs identifiés. | Réutilisation de conventions possible ; réaffecter les données des candidatures nécessiterait une refonte des relations et accès. |
| `app.support_messages`, `support_conversations`, `support_read_states` | type et media_url déjà présents ; relation vers un ticket de support. | Conserver pour le support, sans mélanger ses accès avec ceux des candidatures. |
| `app.td_messages` | attachment_url, read_at et deux canaux existent, mais inscription TD et rôles étudiant/enseignant/admin. | Modèle comparable, pas une table générique de pièces jointes aux candidatures. |
| `app.online_course_enrollment_messages`, `short_training_registration_messages` | Structure proche, liée respectivement aux inscriptions cours et formations courtes. | Conserver ces messageries spécialisées. |
| `app.content_assets`, `content_asset_audiences` | Ressources avec créateur, approbation, publics manager/commercial. Aucun lien natif vers le message d'une candidature. | Pas de substitution directe au stockage d'une conversation privée. |

Les autres messageries inventoriées concernent notamment les communautés, sessions, opportunités et assistants. Aucune autre table examinée ne fournit déjà le même rattachement à la candidature avec les deux audiences requises et les médias. Cela ne signifie pas qu'une refonte mutualisée serait impossible : elle dépasserait cette phase.

## Stockage existant et point de sécurité

`application-files` existe et est privé. Le code Flutter l'utilise déjà pour les pièces de candidature, les dossiers étudiants et les opportunités.

Sa politique `students_manage_own_application_files` autorise ALL au rôle authenticated avec seulement `bucket_id = 'application-files'`, en USING et WITH CHECK. Malgré son nom, elle ne vérifie ni propriétaire ni candidature. Aucune politique restrictive correspondante n'a été trouvée dans les règles Storage inspectées. Le qualificatif privé ne suffit donc pas à isoler ces fichiers entre utilisateurs connectés. C'est un constat sur la configuration, pas la preuve d'une exploitation.

Réutiliser ce bucket est techniquement possible avec un préfixe et des règles supplémentaires correctement isolées, mais ne permet pas d'éviter une modification des politiques de `storage.objects`. Le blocage de droits rencontré resterait donc à résoudre. Durcir globalement son ancienne règle nécessite une analyse de compatibilité des trois usages existants.

`community-media` est public : inadapté en l'état à ces échanges confidentiels. Les autres buckets privés correspondent à d'autres modules et n'offrent pas déjà les droits par candidature et audience.

Recommandation : un bucket privé `application-media` dédié aux nouveaux médias, afin de limiter les effets sur les documents existants. Un bucket est un espace de fichiers dans le Storage existant, pas une nouvelle table SQL.

## Ce que contient exactement la migration préparée, non appliquée

- Zéro nouvelle table SQL.
- Quatre colonnes supplémentaires sur `app.application_messages` : `type`, `media_url` (chemin Storage), `media_mime`, `read_at`.
- Une contrainte de cohérence et un index unique partiel sur le chemin média.
- Un bucket privé `application-media`, limite de 25 Mo et liste de formats autorisés.
- Trois fonctions internes de contrôle de canal, d'accès au fichier et d'envoi.
- Quatre nouvelles signatures RPC pour envoyer les médias ; maintien des signatures texte existantes.
- Adaptation des dix RPC existantes d'envoi, liste et lecture.
- Sept politiques Storage et quatre politiques supplémentaires sur les messages, plus droits d'exécution associés.

Nuance révélée par la comparaison : `read_at` n'est pas indispensable pour simplement afficher lu/non lu, puisque les dernières lectures existent déjà dans `app.applications`. La colonne proposée apporte une date de première lecture conservée par message, ce qui est une sémantique différente. Si seul le statut lu/non lu est requis, une variante plus légère peut réutiliser les dates existantes et omettre cette colonne ; elle doit être préparée et testée avant déploiement. La migration sur disque reste inchangée à ce stade.

## État et décision

La précédente tentative a échoué sur la création de politiques Storage avec `must be owner of table objects` (42501). La vérification après échec a confirmé le retour à l'état initial. Le présent audit confirme encore les six colonnes originales et l'absence du bucket `application-media`.

Conclusion : réutiliser les tables de candidature et leurs RPC est pertinent. Il ne faut pas créer une messagerie parallèle. L'ajout d'un bucket reste une proposition de séparation des nouveaux fichiers, pas une obligation technique. Aucun nouvel accord de déploiement n'est présumé après cette demande d'audit.

## Annexe : inventaire des tables et vues de app/public

### app

- `academia_session_events`
- `academia_session_messages`
- `academia_session_participants`
- `academia_session_summaries`
- `academia_sessions`
- `academic_events`
- `actor_balances`
- `adaptive_learning_profiles`
- `admin_audit_log`
- `admin_user_action_logs`
- `admin_users`
- `ai_action_prices`
- `analytics_events`
- `application_files`
- `application_messages`
- `application_payments`
- `applications`
- `audience_digest_state`
- `banned_words`
- `bobodo_answer_cache`
- `bobodo_conversation_memory`
- `bobodo_detected_needs`
- `bobodo_emotional_states`
- `bobodo_feedback`
- `bobodo_knowledge`
- `bobodo_messages`
- `bobodo_sessions`
- `bobodo_unanswered_questions`
- `bons_a_verifier` (vue)
- `brokerage_voucher_checks`
- `brokerage_vouchers`
- `candidatures_en_attente_de_taux` (vue)
- `challenge_comments`
- `challenge_favorites`
- `challenge_game_live_sessions`
- `challenge_likes`
- `challenge_participation_videos`
- `challenge_participations`
- `challenge_reports`
- `challenge_user_bans`
- `challenge_video_assets`
- `challenge_video_overlays`
- `challenge_video_render_jobs`
- `challenges`
- `clinical_cases`
- `clinical_rounds`
- `commercial_milestone_claims`
- `commercial_milestones`
- `commercial_profiles`
- `commission_motifs_eligibles`
- `commission_rules`
- `commission_share_config`
- `commission_taux_commercial`
- `communication_campaigns`
- `communities`
- `community_join_requests`
- `community_memberships`
- `community_poll_votes`
- `community_polls`
- `community_post_reactions`
- `community_posts`
- `community_read_states`
- `community_stories`
- `community_story_views`
- `competitive_events`
- `content_asset_access_log`
- `content_asset_audiences`
- `content_assets`
- `content_reports`
- `course_domains`
- `course_enrollments`
- `course_resources`
- `course_units`
- `courses`
- `courtages_sans_bon` (vue)
- `credit_packs`
- `credit_reservations`
- `credit_transactions`
- `direct_conversations`
- `direct_message_read_states`
- `direct_messages`
- `duels`
- `economic_indicators`
- `email_queue`
- `exercises`
- `free_video_overlays`
- `free_video_render_jobs`
- `free_videos`
- `game_results`
- `gpu_pods`
- `hero_overlay_animations`
- `hero_overlays`
- `hero_overlays_tv`
- `hero_playlist`
- `hero_renders`
- `hero_renders_tv`
- `hero_video_jobs`
- `hero_videos`
- `instructors`
- `landing_announcements`
- `landing_config`
- `landing_partners`
- `landing_videos`
- `landing_why_cards`
- `league_matches`
- `league_participations`
- `leagues`
- `legacy_video_write_attempts`
- `manager_announcement_reads`
- `manager_announcements`
- `manager_profiles`
- `marketing_attributions`
- `marketplace_cart_items`
- `marketplace_carts`
- `marketplace_categories`
- `marketplace_listing_bookmarks`
- `marketplace_listing_media`
- `marketplace_listings`
- `marketplace_merchant_balances`
- `marketplace_merchants`
- `marketplace_order_items`
- `marketplace_orders`
- `marketplace_payments`
- `marketplace_products`
- `marketplace_reviews`
- `memory_rounds`
- `merchant_profiles`
- `moderation_events`
- `notification_events`
- `official_announcements`
- `online_course_certificates`
- `online_course_enrollment_messages`
- `online_course_enrollments`
- `online_course_forum_messages`
- `online_course_forum_threads`
- `online_course_instructors`
- `online_course_lesson_media`
- `online_course_lesson_progress`
- `online_course_lessons`
- `online_course_live_session_participants`
- `online_course_live_sessions`
- `online_course_sections`
- `online_courses`
- `opportunities`
- `opportunity_applications`
- `opportunity_bookmarks`
- `opportunity_comments`
- `opportunity_inquiries`
- `opportunity_inquiry_messages`
- `opportunity_reactions`
- `opportunity_types`
- `opportunity_views`
- `orientation_availability`
- `orientation_bookings`
- `orientation_counselors`
- `orientation_leads`
- `orientation_quiz_attempts`
- `orientation_quiz_options`
- `orientation_quiz_profiles`
- `orientation_quiz_questions`
- `orientation_records`
- `orientation_responses`
- `paiements_sans_recu` (vue)
- `payment_audit_log`
- `payment_proofs`
- `payment_receipts`
- `payout_queue`
- `pharmacy_cases`
- `pharmacy_rounds`
- `platform_ledger`
- `prep_actuality_preferences`
- `prep_ai_config`
- `prep_ai_conversations`
- `prep_ai_corrections`
- `prep_ai_generations`
- `prep_ai_messages`
- `prep_ai_usage_logs`
- `prep_assignment_submissions`
- `prep_assignments`
- `prep_attempts`
- `prep_badges`
- `prep_chapters`
- `prep_chunks`
- `prep_doc_chunks`
- `prep_exam_blanc_attempts`
- `prep_exam_blancs`
- `prep_exam_items`
- `prep_exam_papers`
- `prep_exams`
- `prep_flashcard_decks`
- `prep_flashcard_progress`
- `prep_flashcards`
- `prep_live_participants`
- `prep_live_sessions`
- `prep_news_articles`
- `prep_news_sources`
- `prep_psychotech_profiles`
- `prep_psychotech_results`
- `prep_question_banks`
- `prep_question_choices`
- `prep_question_topics`
- `prep_questions`
- `prep_quiz_attempts`
- `prep_quiz_templates`
- `prep_scan_logs`
- `prep_source_documents`
- `prep_student_badges`
- `prep_student_progress`
- `prep_student_weaknesses`
- `prep_subjects`
- `prep_topic_predictions`
- `prep_topics`
- `prestation_devis`
- `programs`
- `rate_limits`
- `recus_a_verifier` (vue)
- `referral_commissions`
- `referral_tokens`
- `revenue_split_rules`
- `saisies_manuelles` (vue)
- `share_tracking`
- `short_training_messages`
- `short_training_registration_messages`
- `short_training_registrations`
- `short_training_sessions`
- `short_trainings`
- `student_credits`
- `student_dossier_documents`
- `student_home_announcements`
- `student_home_slots`
- `student_home_videos`
- `students`
- `studio_config`
- `studio_jobs`
- `subscription_plans`
- `subscriptions`
- `support_conversations`
- `support_messages`
- `support_read_states`
- `td_ai_config`
- `td_ai_conversations`
- `td_ai_messages`
- `td_assignment_submissions`
- `td_assignments`
- `td_attendance`
- `td_badges`
- `td_collections`
- `td_daily_goals`
- `td_discipline_colors`
- `td_doc_chunks`
- `td_enrollments`
- `td_exam_papers`
- `td_fields`
- `td_flashcard_decks`
- `td_flashcard_progress`
- `td_flashcards`
- `td_generated_assignments`
- `td_leaderboard_cache`
- `td_local_group_members`
- `td_local_groups`
- `td_messages`
- `td_physical_sessions`
- `td_programs`
- `td_question_banks`
- `td_questions`
- `td_quiz_attempts`
- `td_quiz_templates`
- `td_resource_progress`
- `td_resources`
- `td_scan_logs`
- `td_session_occurrences`
- `td_sessions`
- `td_source_documents`
- `td_streaks`
- `td_student_badges`
- `td_student_profiles`
- `td_student_progress`
- `td_student_requests`
- `td_teacher_availability`
- `td_teacher_profiles`
- `td_teachers`
- `td_xp_log`
- `text_posts`
- `tournament_matches`
- `tournament_participants`
- `tournament_rewards`
- `tournaments`
- `universities`
- `university_events`
- `university_media`
- `university_news`
- `university_site_banners`
- `university_site_blocks`
- `university_site_config`
- `university_staff`
- `upload_sessions`
- `user_admin_status`
- `user_announcement_reads`
- `user_blocks`
- `user_device_tokens`
- `user_event_follows`
- `user_feature_entitlements`
- `user_invitations`
- `user_mutes`
- `user_navigation_events`
- `user_notification_state`
- `user_presence`
- `user_referrals`
- `video_asset_contexts`
- `video_asset_legacy_map`
- `video_assets`
- `video_comments`
- `video_engagement_daily`
- `video_favorites`
- `video_heatmap_events`
- `video_likes`
- `video_moderation_history`
- `video_playback_errors`
- `video_processing_jobs`
- `video_reactions`
- `video_renditions`
- `video_reports`
- `video_shares`
- `video_sources`
- `video_upload_events`
- `video_views`
- `whiteboard_ai_generations`
- `whiteboard_engine_health`
- `whiteboard_projects`
- `whiteboard_renders`
- `whiteboard_workers`

### public

- `bobodo_chat_function_view` (vue)
- `credit_packs`
- `edge_functions_code`
- `flutter_test`
- `rpc_test_users`
- `rpc_test_users_062962`
- `rpc_test_users_063097`
- `rpc_validation_test`
- `sms_hook_debug_log`
- `test_flutter`

### Buckets existants

| Bucket | Accès public |
|---|---|
| `application-files` | Non |
| `challenge-media` | Oui |
| `community-media` | Oui |
| `hero_videos` | Oui |
| `landing-media` | Oui |
| `marketing` | Oui |
| `marketplace-media` | Oui |
| `partner-media` | Non |
| `prep-documents` | Oui |
| `studio-moteur` | Oui |
| `studio-visuel` | Non |
| `td-documents` | Non |
| `university-media` | Oui |
| `video-assets` | Oui |
| `whiteboard-narrations` | Non |
| `whiteboard-renders` | Oui |
