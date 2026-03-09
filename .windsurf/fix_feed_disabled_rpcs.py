#!/usr/bin/env python3
"""Recreate the 8 disabled feed interaction RPCs.

Based on the active unlike/unfavorite RPCs patterns and table schemas.
Uses INSERT ... ON CONFLICT DO NOTHING for idempotent likes/favorites.
"""
import requests
from supabase_auto_manager import SupabaseAutoManager


def apply_sql(label: str, sql: str) -> bool:
    m = SupabaseAutoManager()
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    print(f"\n=== {label} ===")
    try:
        resp = requests.post(url, headers=m.headers, json={"p_sql": sql}, timeout=60)
    except Exception as exc:
        print(f"[ERROR] {exc}")
        return False
    print(f"STATUS {resp.status_code}")
    data = resp.json() if resp.status_code == 200 else resp.text[:500]
    print(data)
    return resp.status_code == 200


def main() -> int:
    # 1) app_student_like_challenge_video (INSERT into challenge_likes)
    apply_sql("LIKE_CHALLENGE_VIDEO", """
    CREATE OR REPLACE FUNCTION public.app_student_like_challenge_video(
        p_participation_id UUID
    ) RETURNS JSONB
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = public
    AS $$
    DECLARE
        v_user_id UUID := auth.uid();
        v_is_banned BOOLEAN;
    BEGIN
        IF v_user_id IS NULL THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
        END IF;

        SELECT EXISTS (
            SELECT 1 FROM app.challenge_user_bans b
            WHERE b.user_id = v_user_id
              AND (b.banned_until IS NULL OR b.banned_until > NOW())
        ) INTO v_is_banned;

        IF v_is_banned THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'banned_from_challenges');
        END IF;

        INSERT INTO app.challenge_likes (participation_id, user_id)
        VALUES (p_participation_id, v_user_id)
        ON CONFLICT DO NOTHING;

        -- Also insert into video_likes for unified feed counting
        INSERT INTO app.video_likes (video_type, video_id, user_id)
        VALUES ('challenge', p_participation_id, v_user_id)
        ON CONFLICT DO NOTHING;

        RETURN JSONB_BUILD_OBJECT('success', TRUE);
    END;
    $$;
    """)

    # 2) app_student_video_like (INSERT into video_likes)
    apply_sql("VIDEO_LIKE", """
    CREATE OR REPLACE FUNCTION public.app_student_video_like(
        p_video_type TEXT,
        p_video_id UUID
    ) RETURNS JSONB
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = public
    AS $$
    DECLARE
        v_user_id UUID := auth.uid();
        v_is_banned BOOLEAN;
        v_type TEXT := LOWER(TRIM(COALESCE(p_video_type, '')));
    BEGIN
        IF v_user_id IS NULL THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
        END IF;

        IF v_type NOT IN ('challenge', 'free') THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_video_type');
        END IF;

        SELECT EXISTS (
            SELECT 1 FROM app.challenge_user_bans b
            WHERE b.user_id = v_user_id
              AND (b.banned_until IS NULL OR b.banned_until > NOW())
        ) INTO v_is_banned;

        IF v_is_banned THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'banned_from_challenges');
        END IF;

        INSERT INTO app.video_likes (video_type, video_id, user_id)
        VALUES (v_type, p_video_id, v_user_id)
        ON CONFLICT DO NOTHING;

        -- If challenge type, also insert into challenge_likes for backward compat
        IF v_type = 'challenge' THEN
            INSERT INTO app.challenge_likes (participation_id, user_id)
            VALUES (p_video_id, v_user_id)
            ON CONFLICT DO NOTHING;
        END IF;

        RETURN JSONB_BUILD_OBJECT('success', TRUE);
    END;
    $$;
    """)

    # 3) app_student_favorite_challenge_video (INSERT into challenge_favorites)
    apply_sql("FAVORITE_CHALLENGE_VIDEO", """
    CREATE OR REPLACE FUNCTION public.app_student_favorite_challenge_video(
        p_participation_id UUID
    ) RETURNS JSONB
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = public
    AS $$
    DECLARE
        v_user_id UUID := auth.uid();
        v_is_banned BOOLEAN;
    BEGIN
        IF v_user_id IS NULL THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
        END IF;

        SELECT EXISTS (
            SELECT 1 FROM app.challenge_user_bans b
            WHERE b.user_id = v_user_id
              AND (b.banned_until IS NULL OR b.banned_until > NOW())
        ) INTO v_is_banned;

        IF v_is_banned THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'banned_from_challenges');
        END IF;

        INSERT INTO app.challenge_favorites (participation_id, user_id)
        VALUES (p_participation_id, v_user_id)
        ON CONFLICT DO NOTHING;

        -- Also insert into video_favorites for unified feed counting
        INSERT INTO app.video_favorites (video_type, video_id, user_id)
        VALUES ('challenge', p_participation_id, v_user_id)
        ON CONFLICT DO NOTHING;

        RETURN JSONB_BUILD_OBJECT('success', TRUE);
    END;
    $$;
    """)

    # 4) app_student_video_favorite (INSERT into video_favorites)
    apply_sql("VIDEO_FAVORITE", """
    CREATE OR REPLACE FUNCTION public.app_student_video_favorite(
        p_video_type TEXT,
        p_video_id UUID
    ) RETURNS JSONB
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = public
    AS $$
    DECLARE
        v_user_id UUID := auth.uid();
        v_is_banned BOOLEAN;
        v_type TEXT := LOWER(TRIM(COALESCE(p_video_type, '')));
    BEGIN
        IF v_user_id IS NULL THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
        END IF;

        IF v_type NOT IN ('challenge', 'free') THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_video_type');
        END IF;

        SELECT EXISTS (
            SELECT 1 FROM app.challenge_user_bans b
            WHERE b.user_id = v_user_id
              AND (b.banned_until IS NULL OR b.banned_until > NOW())
        ) INTO v_is_banned;

        IF v_is_banned THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'banned_from_challenges');
        END IF;

        INSERT INTO app.video_favorites (video_type, video_id, user_id)
        VALUES (v_type, p_video_id, v_user_id)
        ON CONFLICT DO NOTHING;

        IF v_type = 'challenge' THEN
            INSERT INTO app.challenge_favorites (participation_id, user_id)
            VALUES (p_video_id, v_user_id)
            ON CONFLICT DO NOTHING;
        END IF;

        RETURN JSONB_BUILD_OBJECT('success', TRUE);
    END;
    $$;
    """)

    # 5) app_student_add_challenge_comment (INSERT into video_comments)
    apply_sql("ADD_CHALLENGE_COMMENT", """
    CREATE OR REPLACE FUNCTION public.app_student_add_challenge_comment(
        p_participation_id UUID,
        p_content TEXT
    ) RETURNS JSONB
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = public
    AS $$
    DECLARE
        v_user_id UUID := auth.uid();
        v_is_banned BOOLEAN;
        v_text TEXT := TRIM(COALESCE(p_content, ''));
    BEGIN
        IF v_user_id IS NULL THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
        END IF;

        IF v_text = '' THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'empty_content');
        END IF;

        SELECT EXISTS (
            SELECT 1 FROM app.challenge_user_bans b
            WHERE b.user_id = v_user_id
              AND (b.banned_until IS NULL OR b.banned_until > NOW())
        ) INTO v_is_banned;

        IF v_is_banned THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'banned_from_challenges');
        END IF;

        INSERT INTO app.video_comments (video_type, video_id, user_id, content)
        VALUES ('challenge', p_participation_id, v_user_id, v_text);

        RETURN JSONB_BUILD_OBJECT('success', TRUE);
    END;
    $$;
    """)

    # 6) app_student_add_video_comment (INSERT into video_comments)
    apply_sql("ADD_VIDEO_COMMENT", """
    CREATE OR REPLACE FUNCTION public.app_student_add_video_comment(
        p_video_type TEXT,
        p_video_id UUID,
        p_content TEXT
    ) RETURNS JSONB
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = public
    AS $$
    DECLARE
        v_user_id UUID := auth.uid();
        v_is_banned BOOLEAN;
        v_type TEXT := LOWER(TRIM(COALESCE(p_video_type, '')));
        v_text TEXT := TRIM(COALESCE(p_content, ''));
    BEGIN
        IF v_user_id IS NULL THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
        END IF;

        IF v_type NOT IN ('challenge', 'free') THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_video_type');
        END IF;

        IF v_text = '' THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'empty_content');
        END IF;

        SELECT EXISTS (
            SELECT 1 FROM app.challenge_user_bans b
            WHERE b.user_id = v_user_id
              AND (b.banned_until IS NULL OR b.banned_until > NOW())
        ) INTO v_is_banned;

        IF v_is_banned THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'banned_from_challenges');
        END IF;

        INSERT INTO app.video_comments (video_type, video_id, user_id, content)
        VALUES (v_type, p_video_id, v_user_id, v_text);

        RETURN JSONB_BUILD_OBJECT('success', TRUE);
    END;
    $$;
    """)

    # 7) app_student_report_challenge_video (INSERT into video_reports)
    apply_sql("REPORT_CHALLENGE_VIDEO", """
    CREATE OR REPLACE FUNCTION public.app_student_report_challenge_video(
        p_participation_id UUID,
        p_reason TEXT,
        p_details TEXT DEFAULT NULL
    ) RETURNS JSONB
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = public
    AS $$
    DECLARE
        v_user_id UUID := auth.uid();
        v_is_banned BOOLEAN;
        v_reason TEXT := TRIM(COALESCE(p_reason, ''));
    BEGIN
        IF v_user_id IS NULL THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
        END IF;

        IF v_reason = '' THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'empty_reason');
        END IF;

        SELECT EXISTS (
            SELECT 1 FROM app.challenge_user_bans b
            WHERE b.user_id = v_user_id
              AND (b.banned_until IS NULL OR b.banned_until > NOW())
        ) INTO v_is_banned;

        IF v_is_banned THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'banned_from_challenges');
        END IF;

        INSERT INTO app.video_reports (video_type, video_id, reporter_id, reason, details)
        VALUES ('challenge', p_participation_id, v_user_id, v_reason, NULLIF(TRIM(COALESCE(p_details, '')), ''));

        RETURN JSONB_BUILD_OBJECT('success', TRUE);
    END;
    $$;
    """)

    # 8) app_student_report_video (INSERT into video_reports)
    apply_sql("REPORT_VIDEO", """
    CREATE OR REPLACE FUNCTION public.app_student_report_video(
        p_video_type TEXT,
        p_video_id UUID,
        p_reason TEXT,
        p_details TEXT DEFAULT NULL
    ) RETURNS JSONB
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = public
    AS $$
    DECLARE
        v_user_id UUID := auth.uid();
        v_is_banned BOOLEAN;
        v_type TEXT := LOWER(TRIM(COALESCE(p_video_type, '')));
        v_reason TEXT := TRIM(COALESCE(p_reason, ''));
    BEGIN
        IF v_user_id IS NULL THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
        END IF;

        IF v_type NOT IN ('challenge', 'free') THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_video_type');
        END IF;

        IF v_reason = '' THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'empty_reason');
        END IF;

        SELECT EXISTS (
            SELECT 1 FROM app.challenge_user_bans b
            WHERE b.user_id = v_user_id
              AND (b.banned_until IS NULL OR b.banned_until > NOW())
        ) INTO v_is_banned;

        IF v_is_banned THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'banned_from_challenges');
        END IF;

        INSERT INTO app.video_reports (video_type, video_id, reporter_id, reason, details)
        VALUES (v_type, p_video_id, v_user_id, v_reason, NULLIF(TRIM(COALESCE(p_details, '')), ''));

        RETURN JSONB_BUILD_OBJECT('success', TRUE);
    END;
    $$;
    """)

    # 9) Ensure unique constraints exist for ON CONFLICT DO NOTHING
    apply_sql("ENSURE_UNIQUE_CONSTRAINTS", """
    DO $$
    BEGIN
        -- challenge_likes: unique on (participation_id, user_id)
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint
            WHERE conrelid = 'app.challenge_likes'::regclass
              AND contype = 'u'
        ) THEN
            ALTER TABLE app.challenge_likes
            ADD CONSTRAINT challenge_likes_participation_user_unique
            UNIQUE (participation_id, user_id);
        END IF;

        -- video_likes: unique on (video_type, video_id, user_id)
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint
            WHERE conrelid = 'app.video_likes'::regclass
              AND contype = 'u'
        ) THEN
            ALTER TABLE app.video_likes
            ADD CONSTRAINT video_likes_type_id_user_unique
            UNIQUE (video_type, video_id, user_id);
        END IF;

        -- challenge_favorites: unique on (participation_id, user_id)
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint
            WHERE conrelid = 'app.challenge_favorites'::regclass
              AND contype = 'u'
        ) THEN
            ALTER TABLE app.challenge_favorites
            ADD CONSTRAINT challenge_favorites_participation_user_unique
            UNIQUE (participation_id, user_id);
        END IF;

        -- video_favorites: unique on (video_type, video_id, user_id)
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint
            WHERE conrelid = 'app.video_favorites'::regclass
              AND contype = 'u'
        ) THEN
            ALTER TABLE app.video_favorites
            ADD CONSTRAINT video_favorites_type_id_user_unique
            UNIQUE (video_type, video_id, user_id);
        END IF;
    END $$;
    """)

    print("\n\n=== DONE ===")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
