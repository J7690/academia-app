-- Étape 10 (Option A) : DROP uniquement app.challenge_videos + routines DB qui référencent app.challenge_videos
-- Interdictions respectées: aucune purge storage, aucune suppression d'autres tables/colonnes.
-- Généré automatiquement par .windsurf/generate_step10_drop_challenge_videos_sql.py
-- À appliquer via: python .windsurf/apply_one_sql_via_admin_rpc.py sql_changes/change_20251213_step10_drop_challenge_videos.sql


DROP TABLE IF EXISTS app.challenge_videos;
