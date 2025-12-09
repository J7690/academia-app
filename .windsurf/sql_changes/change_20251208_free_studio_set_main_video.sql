-- RPC étudiante pour définir la vidéo principale + renditions d'une vidéo libre
-- À appliquer via: python .windsurf/apply_one_sql_via_admin_rpc.py sql_changes/change_20251208_free_studio_set_main_video.sql

CREATE OR REPLACE FUNCTION app_student_set_free_video_main_renditions(
    p_free_video_id UUID,
    p_video_url TEXT,
    p_video_renditions JSONB DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_banned BOOLEAN;
    v_owner_id UUID;
    v_url_trim TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    -- Réutilise le bannissement challenges comme bannissement global vidéo
    SELECT EXISTS (
        SELECT 1
        FROM app.challenge_user_bans b
        WHERE b.user_id = v_user_id
          AND (b.banned_until IS NULL OR b.banned_until > NOW())
    ) INTO v_is_banned;

    IF v_is_banned THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'banned_from_challenges');
    END IF;

    SELECT user_id
    INTO v_owner_id
    FROM app.free_videos
    WHERE id = p_free_video_id
      AND is_active = TRUE;

    IF v_owner_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'video_not_found');
    END IF;

    IF v_owner_id <> v_user_id THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_owner');
    END IF;

    v_url_trim := NULLIF(TRIM(COALESCE(p_video_url, '')), '');
    IF v_url_trim IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_video_url');
    END IF;

    UPDATE app.free_videos fv
    SET
        video_url = v_url_trim,
        video_renditions = COALESCE(p_video_renditions, fv.video_renditions)
    WHERE fv.id = p_free_video_id
      AND fv.is_active = TRUE;

    IF NOT FOUND THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'update_failed');
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_set_free_video_main_renditions(UUID, TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_set_free_video_main_renditions(UUID, TEXT, JSONB) TO service_role;
