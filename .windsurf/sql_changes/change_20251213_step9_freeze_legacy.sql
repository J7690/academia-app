-- Étape 9 : Freeze legacy uniquement
-- Objectif: empêcher les nouveaux writes dans colonnes legacy vidéo + journaliser toute tentative.
-- Interdictions respectées: aucun DROP, aucune purge storage, aucune suppression colonnes.
-- À appliquer via: python .windsurf/apply_one_sql_via_admin_rpc.py sql_changes/change_20251213_step9_freeze_legacy.sql

-- 1) Table de journalisation
CREATE TABLE IF NOT EXISTS app.legacy_video_write_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT NOT NULL,
  operation TEXT NOT NULL,
  column_name TEXT NOT NULL,
  old_value JSONB,
  new_value JSONB,
  actor_role TEXT,
  actor_sub TEXT,
  actor_uid UUID,
  actor_current_user TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_legacy_video_write_attempts_created_at
ON app.legacy_video_write_attempts(created_at);

-- RLS: admin/service only (no destructive policy changes; create minimal)
ALTER TABLE app.legacy_video_write_attempts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS service_role_all_legacy_video_write_attempts ON app.legacy_video_write_attempts;
CREATE POLICY service_role_all_legacy_video_write_attempts
ON app.legacy_video_write_attempts
FOR ALL
TO service_role
USING (TRUE)
WITH CHECK (TRUE);

DROP POLICY IF EXISTS admin_select_legacy_video_write_attempts ON app.legacy_video_write_attempts;
CREATE POLICY admin_select_legacy_video_write_attempts
ON app.legacy_video_write_attempts
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
);

GRANT SELECT ON app.legacy_video_write_attempts TO authenticated;
GRANT ALL ON app.legacy_video_write_attempts TO service_role;


-- 2) Trigger function générique: bloque + log
-- 2) Trigger helpers per-table (soft block + log)
-- Note: on ne RAISE PAS pour que le log soit commit (freeze silencieux, mais traçable).

CREATE OR REPLACE FUNCTION app.tg_freeze_legacy_challenge_participations()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_role TEXT := NULLIF(current_setting('request.jwt.claim.role', true), '');
  v_sub TEXT := NULLIF(current_setting('request.jwt.claim.sub', true), '');
  v_uid UUID := NULL;
BEGIN
  BEGIN
    v_uid := auth.uid();
  EXCEPTION WHEN OTHERS THEN
    v_uid := NULL;
  END;

  IF TG_OP = 'INSERT' THEN
    IF NEW.video_url IS NOT NULL THEN
      INSERT INTO app.legacy_video_write_attempts(table_name, operation, column_name, old_value, new_value, actor_role, actor_sub, actor_uid, actor_current_user)
      VALUES ('app.challenge_participations', TG_OP, 'video_url', NULL, to_jsonb(NEW.video_url), v_role, v_sub, v_uid, current_user);
      NEW.video_url := NULL;
    END IF;
    IF NEW.video_renditions IS NOT NULL THEN
      INSERT INTO app.legacy_video_write_attempts(table_name, operation, column_name, old_value, new_value, actor_role, actor_sub, actor_uid, actor_current_user)
      VALUES ('app.challenge_participations', TG_OP, 'video_renditions', NULL, to_jsonb(NEW.video_renditions), v_role, v_sub, v_uid, current_user);
      NEW.video_renditions := NULL;
    END IF;
    IF NEW.thumbnail_url IS NOT NULL THEN
      INSERT INTO app.legacy_video_write_attempts(table_name, operation, column_name, old_value, new_value, actor_role, actor_sub, actor_uid, actor_current_user)
      VALUES ('app.challenge_participations', TG_OP, 'thumbnail_url', NULL, to_jsonb(NEW.thumbnail_url), v_role, v_sub, v_uid, current_user);
      NEW.thumbnail_url := NULL;
    END IF;
    IF NEW.submission_url IS NOT NULL THEN
      INSERT INTO app.legacy_video_write_attempts(table_name, operation, column_name, old_value, new_value, actor_role, actor_sub, actor_uid, actor_current_user)
      VALUES ('app.challenge_participations', TG_OP, 'submission_url', NULL, to_jsonb(NEW.submission_url), v_role, v_sub, v_uid, current_user);
      NEW.submission_url := NULL;
    END IF;
  ELSE
    IF NEW.video_url IS DISTINCT FROM OLD.video_url THEN
      INSERT INTO app.legacy_video_write_attempts(table_name, operation, column_name, old_value, new_value, actor_role, actor_sub, actor_uid, actor_current_user)
      VALUES ('app.challenge_participations', TG_OP, 'video_url', to_jsonb(OLD.video_url), to_jsonb(NEW.video_url), v_role, v_sub, v_uid, current_user);
      NEW.video_url := OLD.video_url;
    END IF;
    IF NEW.video_renditions IS DISTINCT FROM OLD.video_renditions THEN
      INSERT INTO app.legacy_video_write_attempts(table_name, operation, column_name, old_value, new_value, actor_role, actor_sub, actor_uid, actor_current_user)
      VALUES ('app.challenge_participations', TG_OP, 'video_renditions', to_jsonb(OLD.video_renditions), to_jsonb(NEW.video_renditions), v_role, v_sub, v_uid, current_user);
      NEW.video_renditions := OLD.video_renditions;
    END IF;
    IF NEW.thumbnail_url IS DISTINCT FROM OLD.thumbnail_url THEN
      INSERT INTO app.legacy_video_write_attempts(table_name, operation, column_name, old_value, new_value, actor_role, actor_sub, actor_uid, actor_current_user)
      VALUES ('app.challenge_participations', TG_OP, 'thumbnail_url', to_jsonb(OLD.thumbnail_url), to_jsonb(NEW.thumbnail_url), v_role, v_sub, v_uid, current_user);
      NEW.thumbnail_url := OLD.thumbnail_url;
    END IF;
    IF NEW.submission_url IS DISTINCT FROM OLD.submission_url THEN
      INSERT INTO app.legacy_video_write_attempts(table_name, operation, column_name, old_value, new_value, actor_role, actor_sub, actor_uid, actor_current_user)
      VALUES ('app.challenge_participations', TG_OP, 'submission_url', to_jsonb(OLD.submission_url), to_jsonb(NEW.submission_url), v_role, v_sub, v_uid, current_user);
      NEW.submission_url := OLD.submission_url;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION app.tg_freeze_legacy_free_videos()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_role TEXT := NULLIF(current_setting('request.jwt.claim.role', true), '');
  v_sub TEXT := NULLIF(current_setting('request.jwt.claim.sub', true), '');
  v_uid UUID := NULL;
BEGIN
  BEGIN
    v_uid := auth.uid();
  EXCEPTION WHEN OTHERS THEN
    v_uid := NULL;
  END;

  IF TG_OP = 'INSERT' THEN
    IF NEW.video_url IS NOT NULL THEN
      INSERT INTO app.legacy_video_write_attempts VALUES (DEFAULT, 'app.free_videos', TG_OP, 'video_url', NULL, to_jsonb(NEW.video_url), v_role, v_sub, v_uid, current_user, NOW());
      NEW.video_url := NULL;
    END IF;
    IF NEW.video_renditions IS NOT NULL THEN
      INSERT INTO app.legacy_video_write_attempts VALUES (DEFAULT, 'app.free_videos', TG_OP, 'video_renditions', NULL, to_jsonb(NEW.video_renditions), v_role, v_sub, v_uid, current_user, NOW());
      NEW.video_renditions := NULL;
    END IF;
    IF NEW.thumbnail_url IS NOT NULL THEN
      INSERT INTO app.legacy_video_write_attempts VALUES (DEFAULT, 'app.free_videos', TG_OP, 'thumbnail_url', NULL, to_jsonb(NEW.thumbnail_url), v_role, v_sub, v_uid, current_user, NOW());
      NEW.thumbnail_url := NULL;
    END IF;
  ELSE
    IF NEW.video_url IS DISTINCT FROM OLD.video_url THEN
      INSERT INTO app.legacy_video_write_attempts VALUES (DEFAULT, 'app.free_videos', TG_OP, 'video_url', to_jsonb(OLD.video_url), to_jsonb(NEW.video_url), v_role, v_sub, v_uid, current_user, NOW());
      NEW.video_url := OLD.video_url;
    END IF;
    IF NEW.video_renditions IS DISTINCT FROM OLD.video_renditions THEN
      INSERT INTO app.legacy_video_write_attempts VALUES (DEFAULT, 'app.free_videos', TG_OP, 'video_renditions', to_jsonb(OLD.video_renditions), to_jsonb(NEW.video_renditions), v_role, v_sub, v_uid, current_user, NOW());
      NEW.video_renditions := OLD.video_renditions;
    END IF;
    IF NEW.thumbnail_url IS DISTINCT FROM OLD.thumbnail_url THEN
      INSERT INTO app.legacy_video_write_attempts VALUES (DEFAULT, 'app.free_videos', TG_OP, 'thumbnail_url', to_jsonb(OLD.thumbnail_url), to_jsonb(NEW.thumbnail_url), v_role, v_sub, v_uid, current_user, NOW());
      NEW.thumbnail_url := OLD.thumbnail_url;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION app.tg_freeze_legacy_landing_config()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_role TEXT := NULLIF(current_setting('request.jwt.claim.role', true), '');
  v_sub TEXT := NULLIF(current_setting('request.jwt.claim.sub', true), '');
  v_uid UUID := NULL;
BEGIN
  BEGIN
    v_uid := auth.uid();
  EXCEPTION WHEN OTHERS THEN
    v_uid := NULL;
  END;

  IF TG_OP = 'INSERT' THEN
    IF NEW.video_url IS NOT NULL THEN
      INSERT INTO app.legacy_video_write_attempts(table_name, operation, column_name, old_value, new_value, actor_role, actor_sub, actor_uid, actor_current_user)
      VALUES ('app.landing_config', TG_OP, 'video_url', NULL, to_jsonb(NEW.video_url), v_role, v_sub, v_uid, current_user);
      NEW.video_url := NULL;
    END IF;
  ELSE
    IF NEW.video_url IS DISTINCT FROM OLD.video_url THEN
      INSERT INTO app.legacy_video_write_attempts(table_name, operation, column_name, old_value, new_value, actor_role, actor_sub, actor_uid, actor_current_user)
      VALUES ('app.landing_config', TG_OP, 'video_url', to_jsonb(OLD.video_url), to_jsonb(NEW.video_url), v_role, v_sub, v_uid, current_user);
      NEW.video_url := OLD.video_url;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION app.tg_freeze_legacy_landing_videos()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_role TEXT := NULLIF(current_setting('request.jwt.claim.role', true), '');
  v_sub TEXT := NULLIF(current_setting('request.jwt.claim.sub', true), '');
  v_uid UUID := NULL;
BEGIN
  BEGIN
    v_uid := auth.uid();
  EXCEPTION WHEN OTHERS THEN
    v_uid := NULL;
  END;

  IF TG_OP = 'INSERT' THEN
    IF NEW.video_url IS NOT NULL THEN
      INSERT INTO app.legacy_video_write_attempts VALUES (DEFAULT, 'app.landing_videos', TG_OP, 'video_url', NULL, to_jsonb(NEW.video_url), v_role, v_sub, v_uid, current_user, NOW());
      NEW.video_url := NULL;
    END IF;
  ELSE
    IF NEW.video_url IS DISTINCT FROM OLD.video_url THEN
      INSERT INTO app.legacy_video_write_attempts VALUES (DEFAULT, 'app.landing_videos', TG_OP, 'video_url', to_jsonb(OLD.video_url), to_jsonb(NEW.video_url), v_role, v_sub, v_uid, current_user, NOW());
      NEW.video_url := OLD.video_url;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION app.tg_freeze_legacy_student_home_videos()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_role TEXT := NULLIF(current_setting('request.jwt.claim.role', true), '');
  v_sub TEXT := NULLIF(current_setting('request.jwt.claim.sub', true), '');
  v_uid UUID := NULL;
BEGIN
  BEGIN
    v_uid := auth.uid();
  EXCEPTION WHEN OTHERS THEN
    v_uid := NULL;
  END;

  IF TG_OP = 'INSERT' THEN
    IF NEW.video_url IS NOT NULL THEN
      INSERT INTO app.legacy_video_write_attempts VALUES (DEFAULT, 'app.student_home_videos', TG_OP, 'video_url', NULL, to_jsonb(NEW.video_url), v_role, v_sub, v_uid, current_user, NOW());
      NEW.video_url := NULL;
    END IF;
  ELSE
    IF NEW.video_url IS DISTINCT FROM OLD.video_url THEN
      INSERT INTO app.legacy_video_write_attempts VALUES (DEFAULT, 'app.student_home_videos', TG_OP, 'video_url', to_jsonb(OLD.video_url), to_jsonb(NEW.video_url), v_role, v_sub, v_uid, current_user, NOW());
      NEW.video_url := OLD.video_url;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION app.tg_freeze_legacy_university_media()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_role TEXT := NULLIF(current_setting('request.jwt.claim.role', true), '');
  v_sub TEXT := NULLIF(current_setting('request.jwt.claim.sub', true), '');
  v_uid UUID := NULL;
BEGIN
  BEGIN
    v_uid := auth.uid();
  EXCEPTION WHEN OTHERS THEN
    v_uid := NULL;
  END;

  IF TG_OP = 'INSERT' THEN
    IF NEW.thumbnail_url IS NOT NULL THEN
      INSERT INTO app.legacy_video_write_attempts VALUES (DEFAULT, 'app.university_media', TG_OP, 'thumbnail_url', NULL, to_jsonb(NEW.thumbnail_url), v_role, v_sub, v_uid, current_user, NOW());
      NEW.thumbnail_url := NULL;
    END IF;
  ELSE
    IF NEW.thumbnail_url IS DISTINCT FROM OLD.thumbnail_url THEN
      INSERT INTO app.legacy_video_write_attempts VALUES (DEFAULT, 'app.university_media', TG_OP, 'thumbnail_url', to_jsonb(OLD.thumbnail_url), to_jsonb(NEW.thumbnail_url), v_role, v_sub, v_uid, current_user, NOW());
      NEW.thumbnail_url := OLD.thumbnail_url;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION app.tg_freeze_legacy_challenge_participation_videos()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_role TEXT := NULLIF(current_setting('request.jwt.claim.role', true), '');
  v_sub TEXT := NULLIF(current_setting('request.jwt.claim.sub', true), '');
  v_uid UUID := NULL;
BEGIN
  BEGIN
    v_uid := auth.uid();
  EXCEPTION WHEN OTHERS THEN
    v_uid := NULL;
  END;

  IF TG_OP = 'INSERT' THEN
    IF NEW.video_url IS NOT NULL THEN
      INSERT INTO app.legacy_video_write_attempts VALUES (DEFAULT, 'app.challenge_participation_videos', TG_OP, 'video_url', NULL, to_jsonb(NEW.video_url), v_role, v_sub, v_uid, current_user, NOW());
      NEW.video_url := NULL;
    END IF;
    IF NEW.thumbnail_url IS NOT NULL THEN
      INSERT INTO app.legacy_video_write_attempts VALUES (DEFAULT, 'app.challenge_participation_videos', TG_OP, 'thumbnail_url', NULL, to_jsonb(NEW.thumbnail_url), v_role, v_sub, v_uid, current_user, NOW());
      NEW.thumbnail_url := NULL;
    END IF;
  ELSE
    IF NEW.video_url IS DISTINCT FROM OLD.video_url THEN
      INSERT INTO app.legacy_video_write_attempts VALUES (DEFAULT, 'app.challenge_participation_videos', TG_OP, 'video_url', to_jsonb(OLD.video_url), to_jsonb(NEW.video_url), v_role, v_sub, v_uid, current_user, NOW());
      NEW.video_url := OLD.video_url;
    END IF;
    IF NEW.thumbnail_url IS DISTINCT FROM OLD.thumbnail_url THEN
      INSERT INTO app.legacy_video_write_attempts VALUES (DEFAULT, 'app.challenge_participation_videos', TG_OP, 'thumbnail_url', to_jsonb(OLD.thumbnail_url), to_jsonb(NEW.thumbnail_url), v_role, v_sub, v_uid, current_user, NOW());
      NEW.thumbnail_url := OLD.thumbnail_url;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;


-- 3) Triggers (ciblés sur les tables de contenu legacy)
-- Note: on ne freeze PAS les tables d'observabilité/ops (ex: app.video_playback_errors, render_jobs)

-- challenge_participations
DROP TRIGGER IF EXISTS trg_freeze_legacy_video_on_challenge_participations ON app.challenge_participations;
CREATE TRIGGER trg_freeze_legacy_video_on_challenge_participations
BEFORE INSERT OR UPDATE ON app.challenge_participations
FOR EACH ROW
EXECUTE FUNCTION app.tg_freeze_legacy_challenge_participations();

-- free_videos
DROP TRIGGER IF EXISTS trg_freeze_legacy_video_on_free_videos ON app.free_videos;
CREATE TRIGGER trg_freeze_legacy_video_on_free_videos
BEFORE INSERT OR UPDATE ON app.free_videos
FOR EACH ROW
EXECUTE FUNCTION app.tg_freeze_legacy_free_videos();

-- landing_config
DROP TRIGGER IF EXISTS trg_freeze_legacy_video_on_landing_config ON app.landing_config;
CREATE TRIGGER trg_freeze_legacy_video_on_landing_config
BEFORE INSERT OR UPDATE ON app.landing_config
FOR EACH ROW
EXECUTE FUNCTION app.tg_freeze_legacy_landing_config();

-- landing_videos
DROP TRIGGER IF EXISTS trg_freeze_legacy_video_on_landing_videos ON app.landing_videos;
CREATE TRIGGER trg_freeze_legacy_video_on_landing_videos
BEFORE INSERT OR UPDATE ON app.landing_videos
FOR EACH ROW
EXECUTE FUNCTION app.tg_freeze_legacy_landing_videos();

-- student_home_videos
DROP TRIGGER IF EXISTS trg_freeze_legacy_video_on_student_home_videos ON app.student_home_videos;
CREATE TRIGGER trg_freeze_legacy_video_on_student_home_videos
BEFORE INSERT OR UPDATE ON app.student_home_videos
FOR EACH ROW
EXECUTE FUNCTION app.tg_freeze_legacy_student_home_videos();

-- university_media (thumbnail legacy)
DROP TRIGGER IF EXISTS trg_freeze_legacy_video_on_university_media ON app.university_media;
CREATE TRIGGER trg_freeze_legacy_video_on_university_media
BEFORE INSERT OR UPDATE ON app.university_media
FOR EACH ROW
EXECUTE FUNCTION app.tg_freeze_legacy_university_media();

-- challenge_participation_videos (multi videos)
DROP TRIGGER IF EXISTS trg_freeze_legacy_video_on_challenge_participation_videos ON app.challenge_participation_videos;
CREATE TRIGGER trg_freeze_legacy_video_on_challenge_participation_videos
BEFORE INSERT OR UPDATE ON app.challenge_participation_videos
FOR EACH ROW
EXECUTE FUNCTION app.tg_freeze_legacy_challenge_participation_videos();
