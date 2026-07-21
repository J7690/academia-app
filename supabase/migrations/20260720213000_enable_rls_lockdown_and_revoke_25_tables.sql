-- =============================================================
-- Migration sécurité : activation RLS + révocation des privilèges
-- clients sur les 25 tables exposées sans RLS (audit 2026-07-20).
-- Appliquée en production le 2026-07-20 via MCP (apply_migration).
-- Non-régression vérifiée : tous les accès applicatifs passent par
-- des fonctions SECURITY DEFINER (owner postgres) ou service_role,
-- sauf hero_renders_tv (policy admin ci-dessous, modèle app.is_admin()
-- déjà éprouvé sur hero_videos).
-- Rollback : ALTER TABLE ... DISABLE ROW LEVEL SECURITY + GRANT inverses.
-- =============================================================

ALTER TABLE app.admin_audit_log             ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.admin_users                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.commercial_milestone_claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.commercial_milestones       ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.commission_rules            ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.commission_share_config     ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.email_queue                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.hero_overlays_tv            ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.notification_events         ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.payment_audit_log           ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.prep_chunks                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.rate_limits                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.referral_tokens             ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.share_tracking              ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.user_navigation_events      ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.video_comments              ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.video_engagement_daily      ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.video_favorites             ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.video_likes                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.video_moderation_history    ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.video_reports               ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.video_upload_events         ENABLE ROW LEVEL SECURITY;

ALTER TABLE app.hero_renders_tv             ENABLE ROW LEVEL SECURITY;
CREATE POLICY hero_renders_tv_admin_select ON app.hero_renders_tv
  FOR SELECT USING (app.is_admin());

ALTER TABLE app.credit_packs                ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.prep_questions              ENABLE ROW LEVEL SECURITY;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON
  app.admin_audit_log, app.admin_users, app.commercial_milestone_claims,
  app.commercial_milestones, app.commission_rules, app.commission_share_config,
  app.email_queue, app.hero_overlays_tv, app.hero_renders_tv,
  app.notification_events, app.payment_audit_log, app.prep_chunks,
  app.rate_limits, app.referral_tokens, app.share_tracking,
  app.user_navigation_events, app.video_comments, app.video_engagement_daily,
  app.video_favorites, app.video_likes, app.video_moderation_history,
  app.video_reports, app.video_upload_events, app.credit_packs, app.prep_questions
FROM anon, authenticated;
