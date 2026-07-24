-- ============================================================================
-- Pré-rendu du filigrane à la publication (parité TikTok : téléchargement instantané)
-- Date : 2026-07-22
--
-- Objectif : préparer la rendition `export_watermarked` (logo Academia cuit,
-- style TikTok) DÈS que la vidéo est publiée/jouable et téléchargeable, au lieu
-- d'attendre la première demande de téléchargement. Le worker Kamatera existant
-- (job_type='export_watermarked') fait le rendu ; ici on se contente d'ENFILER
-- le job au bon moment.
--
-- Sécurité : toutes les fonctions avalent les exceptions (EXCEPTION WHEN OTHERS)
-- afin de ne JAMAIS bloquer l'écriture parente (transcode, mise à jour de vidéo).
-- Idempotent : n'enfile pas si une rendition est déjà prête ou un job déjà en file.
--
-- Rollback :
--   DROP TRIGGER IF EXISTS trg_prerender_watermark_on_source_ready ON app.video_renditions;
--   DROP TRIGGER IF EXISTS trg_prerender_wm_cp ON app.challenge_participations;
--   DROP TRIGGER IF EXISTS trg_prerender_wm_fv ON app.free_videos;
--   DROP FUNCTION IF EXISTS app.tg_prerender_watermark_on_source_ready();
--   DROP FUNCTION IF EXISTS app.tg_prerender_watermark_on_allow_download();
--   DROP FUNCTION IF EXISTS app.asset_is_downloadable(uuid);
--   DROP FUNCTION IF EXISTS app.enqueue_export_watermarked_job(uuid);
-- ============================================================================

-- 1) Helper : enfile un job export_watermarked si pertinent (idempotent + sûr).
CREATE OR REPLACE FUNCTION app.enqueue_export_watermarked_job(p_asset uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'app', 'public'
AS $$
BEGIN
  IF p_asset IS NULL THEN
    RETURN;
  END IF;

  -- Déjà filigrané et prêt ?
  IF EXISTS (
    SELECT 1 FROM app.video_renditions vr
    WHERE vr.video_asset_id = p_asset
      AND vr.rendition_key = 'export_watermarked'
      AND vr.kind = 'mp4'
      AND vr.status = 'ready'
  ) THEN
    RETURN;
  END IF;

  -- Déjà en file ou en cours ?
  IF EXISTS (
    SELECT 1 FROM app.video_processing_jobs j
    WHERE j.video_asset_id = p_asset
      AND j.job_type = 'export_watermarked'
      AND j.status IN ('queued', 'running')
  ) THEN
    RETURN;
  END IF;

  -- La source jouable (mp4) doit exister, sinon le worker n'aurait rien à filigraner.
  IF NOT EXISTS (
    SELECT 1 FROM app.video_renditions vr
    WHERE vr.video_asset_id = p_asset
      AND vr.kind = 'mp4'
      AND vr.status = 'ready'
  ) THEN
    RETURN;
  END IF;

  INSERT INTO app.video_processing_jobs (video_asset_id, job_type, status, payload)
  VALUES (p_asset, 'export_watermarked', 'queued', '{}'::jsonb);
EXCEPTION WHEN OTHERS THEN
  RETURN;  -- ne jamais bloquer l'appelant
END;
$$;

-- 2) Helper : la vidéo liée à cet asset autorise-t-elle le téléchargement ?
CREATE OR REPLACE FUNCTION app.asset_is_downloadable(p_asset uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'app', 'public'
AS $$
  SELECT COALESCE((
    SELECT bool_or(allow_download) FROM (
      SELECT allow_download FROM app.challenge_participations
        WHERE video_asset_id = p_asset AND is_active AND NOT is_deleted
      UNION ALL
      SELECT allow_download FROM app.free_videos
        WHERE video_asset_id = p_asset AND is_active AND NOT is_deleted
    ) s
  ), false);
$$;

-- 3) Trigger A : la source devient prête (rendition mp4_main ready) → pré-rendu
--    si la vidéo est téléchargeable.
CREATE OR REPLACE FUNCTION app.tg_prerender_watermark_on_source_ready()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'app', 'public'
AS $$
BEGIN
  IF NEW.rendition_key = 'mp4_main'
     AND NEW.kind = 'mp4'
     AND NEW.status = 'ready'
     AND NEW.video_asset_id IS NOT NULL THEN
    IF app.asset_is_downloadable(NEW.video_asset_id) THEN
      PERFORM app.enqueue_export_watermarked_job(NEW.video_asset_id);
    END IF;
  END IF;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prerender_watermark_on_source_ready ON app.video_renditions;
CREATE TRIGGER trg_prerender_watermark_on_source_ready
AFTER INSERT OR UPDATE OF status ON app.video_renditions
FOR EACH ROW
EXECUTE FUNCTION app.tg_prerender_watermark_on_source_ready();

-- 4) Trigger B : l'utilisateur active le téléchargement (allow_download → true)
--    → pré-rendu si la source est déjà prête. (Sinon, Trigger A prendra le relais.)
CREATE OR REPLACE FUNCTION app.tg_prerender_watermark_on_allow_download()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'app', 'public'
AS $$
BEGIN
  IF NEW.allow_download IS TRUE
     AND NEW.video_asset_id IS NOT NULL
     AND (TG_OP = 'INSERT' OR COALESCE(OLD.allow_download, false) IS DISTINCT FROM true) THEN
    PERFORM app.enqueue_export_watermarked_job(NEW.video_asset_id);
  END IF;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prerender_wm_cp ON app.challenge_participations;
CREATE TRIGGER trg_prerender_wm_cp
AFTER INSERT OR UPDATE OF allow_download ON app.challenge_participations
FOR EACH ROW
EXECUTE FUNCTION app.tg_prerender_watermark_on_allow_download();

DROP TRIGGER IF EXISTS trg_prerender_wm_fv ON app.free_videos;
CREATE TRIGGER trg_prerender_wm_fv
AFTER INSERT OR UPDATE OF allow_download ON app.free_videos
FOR EACH ROW
EXECUTE FUNCTION app.tg_prerender_watermark_on_allow_download();
