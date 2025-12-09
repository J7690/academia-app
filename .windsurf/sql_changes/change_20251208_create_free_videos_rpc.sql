-- RPC étudiante pour créer une vidéo libre dans app.free_videos
-- À appliquer via: python .windsurf/apply_one_sql_via_admin_rpc.py sql_changes/change_20251208_create_free_videos_rpc.sql

CREATE OR REPLACE FUNCTION app_student_create_free_video(
    p_video_url TEXT,
    p_video_renditions JSONB DEFAULT NULL,
    p_thumbnail_url TEXT DEFAULT NULL,
    p_title TEXT DEFAULT NULL,
    p_description TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_banned BOOLEAN;
    v_video_id UUID;
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

    IF p_video_url IS NULL OR LENGTH(TRIM(p_video_url)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_video_url');
    END IF;

    INSERT INTO app.free_videos (
        user_id,
        video_url,
        video_renditions,
        thumbnail_url,
        title,
        description,
        moderation_status,
        moderation_flags,
        moderated_by_admin_id,
        moderated_at
    ) VALUES (
        v_user_id,
        TRIM(p_video_url),
        p_video_renditions,
        NULLIF(TRIM(COALESCE(p_thumbnail_url, '')), ''),
        NULLIF(TRIM(COALESCE(p_title, '')), ''),
        NULLIF(TRIM(COALESCE(p_description, '')), ''),
        'published',
        NULL,
        NULL,
        NULL
    )
    RETURNING id INTO v_video_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'video_id', v_video_id);
END;
$$;

GRANT EXECUTE ON FUNCTION app_student_create_free_video(TEXT, JSONB, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_student_create_free_video(TEXT, JSONB, TEXT, TEXT, TEXT) TO service_role;
