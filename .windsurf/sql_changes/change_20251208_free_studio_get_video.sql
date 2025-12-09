-- RPC étudiante pour récupérer une vidéo libre + overlays
-- À appliquer via: python .windsurf/apply_one_sql_via_admin_rpc.py sql_changes/change_20251208_free_studio_get_video.sql

CREATE OR REPLACE FUNCTION app_student_get_free_video(
    p_free_video_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_banned BOOLEAN;
    v_owner_id UUID;
    v_result JSONB;
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

    SELECT JSONB_BUILD_OBJECT(
        'free_video_id', fv.id,
        'user_id', fv.user_id,
        'video_url', fv.video_url,
        'video_renditions', fv.video_renditions,
        'thumbnail_url', fv.thumbnail_url,
        'title', fv.title,
        'description', fv.description,
        'created_at', fv.created_at,
        'moderation_status', fv.moderation_status,
        'overlays', (
            SELECT o.layers
            FROM app.free_video_overlays o
            WHERE o.free_video_id = fv.id
        )
    ) INTO v_result
    FROM app.free_videos fv
    WHERE fv.id = p_free_video_id
      AND fv.is_active = TRUE;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'video', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_get_free_video(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_get_free_video(UUID) TO service_role;
