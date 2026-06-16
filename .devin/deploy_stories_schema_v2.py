#!/usr/bin/env python3
"""Deploy community_stories schema - sends each statement individually"""
import requests, json, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()
url = f"{m.url}/rest/v1/rpc/admin_execute_sql"

def run(label, sql):
    print(f"\n--- {label} ---")
    try:
        resp = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=30)
        data = resp.json() if resp.status_code == 200 else resp.text[:300]
        if isinstance(data, dict):
            if data.get("ok"):
                print(f"  OK ({data.get('mode','?')})")
                return True
            elif "already exists" in str(data.get("error", "")):
                print(f"  SKIP (already exists)")
                return True
            else:
                print(f"  ERROR: {data.get('error','?')}")
                return False
        else:
            print(f"  {str(data)[:200]}")
            return True
    except Exception as e:
        print(f"  EXCEPTION: {e}")
        return False

# 1) Create tables
ok1 = run("CREATE community_stories", """
CREATE TABLE IF NOT EXISTS app.community_stories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id UUID NOT NULL REFERENCES app.communities(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES app.students(id) ON DELETE CASCADE,
    type TEXT NOT NULL DEFAULT 'image',
    media_url TEXT,
    caption TEXT,
    bg_color TEXT,
    text_content TEXT,
    category TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '24 hours'),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
)
""")

ok2 = run("CREATE community_story_views", """
CREATE TABLE IF NOT EXISTS app.community_story_views (
    story_id UUID NOT NULL REFERENCES app.community_stories(id) ON DELETE CASCADE,
    viewer_id UUID NOT NULL REFERENCES app.students(id) ON DELETE CASCADE,
    viewed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (story_id, viewer_id)
)
""")

# 2) Indexes
run("INDEX stories community+expires", """
CREATE INDEX IF NOT EXISTS idx_community_stories_community_expires
    ON app.community_stories(community_id, expires_at)
    WHERE is_deleted = FALSE
""")

run("INDEX stories author", """
CREATE INDEX IF NOT EXISTS idx_community_stories_author
    ON app.community_stories(author_id)
""")

run("INDEX story_views story", """
CREATE INDEX IF NOT EXISTS idx_community_story_views_story
    ON app.community_story_views(story_id)
""")

# 3) Enable RLS
run("RLS community_stories", "ALTER TABLE app.community_stories ENABLE ROW LEVEL SECURITY")
run("RLS community_story_views", "ALTER TABLE app.community_story_views ENABLE ROW LEVEL SECURITY")

# 4) Policies on community_stories
run("POLICY select stories", """
CREATE POLICY student_select_community_stories ON app.community_stories
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM app.community_memberships m
            WHERE m.community_id = community_stories.community_id
              AND m.user_id = auth.uid()
              AND m.is_active = TRUE
        )
    )
""")

run("POLICY insert stories", """
CREATE POLICY student_insert_own_community_stories ON app.community_stories
    FOR INSERT WITH CHECK (author_id = auth.uid())
""")

run("POLICY delete stories", """
CREATE POLICY student_delete_own_community_stories ON app.community_stories
    FOR DELETE USING (author_id = auth.uid())
""")

run("POLICY update stories", """
CREATE POLICY student_update_own_community_stories ON app.community_stories
    FOR UPDATE USING (author_id = auth.uid())
""")

# 5) Policies on community_story_views
run("POLICY select story_views", """
CREATE POLICY student_select_own_story_views ON app.community_story_views
    FOR SELECT USING (
        viewer_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM app.community_stories s
            WHERE s.id = community_story_views.story_id
              AND s.author_id = auth.uid()
        )
    )
""")

run("POLICY insert story_views", """
CREATE POLICY student_insert_own_story_views ON app.community_story_views
    FOR INSERT WITH CHECK (viewer_id = auth.uid())
""")

# 6) RPCs for stories
run("RPC create_story", """
CREATE OR REPLACE FUNCTION public.app_student_create_community_story(
    p_community_id UUID,
    p_type TEXT DEFAULT 'image',
    p_media_url TEXT DEFAULT NULL,
    p_caption TEXT DEFAULT NULL,
    p_bg_color TEXT DEFAULT NULL,
    p_text_content TEXT DEFAULT NULL,
    p_category TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_story_id UUID;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM app.community_memberships
        WHERE community_id = p_community_id AND user_id = v_user_id AND is_active = TRUE
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not a member');
    END IF;

    INSERT INTO app.community_stories (community_id, author_id, type, media_url, caption, bg_color, text_content, category)
    VALUES (p_community_id, v_user_id, p_type, p_media_url, p_caption, p_bg_color, p_text_content, p_category)
    RETURNING id INTO v_story_id;

    RETURN jsonb_build_object('success', true, 'story_id', v_story_id);
END;
$$
""")

run("RPC list_stories", """
CREATE OR REPLACE FUNCTION public.app_student_list_community_stories(
    p_community_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_result JSONB;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM app.community_memberships
        WHERE community_id = p_community_id AND user_id = v_user_id AND is_active = TRUE
    ) THEN
        RETURN '[]'::JSONB;
    END IF;

    SELECT COALESCE(jsonb_agg(row_to_json(t)::JSONB ORDER BY t.created_at DESC), '[]'::JSONB)
    INTO v_result
    FROM (
        SELECT
            s.id,
            s.community_id,
            s.author_id,
            s.type,
            s.media_url,
            s.caption,
            s.bg_color,
            s.text_content,
            s.category,
            s.created_at,
            s.expires_at,
            st.full_name AS author_name,
            st.avatar_url AS author_avatar_url,
            EXISTS (
                SELECT 1 FROM app.community_story_views sv
                WHERE sv.story_id = s.id AND sv.viewer_id = v_user_id
            ) AS viewed_by_me,
            (SELECT COUNT(*) FROM app.community_story_views sv WHERE sv.story_id = s.id) AS view_count
        FROM app.community_stories s
        JOIN app.students st ON st.id = s.author_id
        WHERE s.community_id = p_community_id
          AND s.is_deleted = FALSE
          AND s.expires_at > NOW()
    ) t;

    RETURN v_result;
END;
$$
""")

run("RPC mark_story_viewed", """
CREATE OR REPLACE FUNCTION public.app_student_mark_story_viewed(
    p_story_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    INSERT INTO app.community_story_views (story_id, viewer_id)
    VALUES (p_story_id, v_user_id)
    ON CONFLICT (story_id, viewer_id) DO NOTHING;

    RETURN jsonb_build_object('success', true);
END;
$$
""")

run("RPC list_story_viewers", """
CREATE OR REPLACE FUNCTION public.app_student_list_story_viewers(
    p_story_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_result JSONB;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM app.community_stories
        WHERE id = p_story_id AND author_id = v_user_id
    ) THEN
        RETURN '[]'::JSONB;
    END IF;

    SELECT COALESCE(jsonb_agg(row_to_json(t)::JSONB), '[]'::JSONB)
    INTO v_result
    FROM (
        SELECT sv.viewer_id, sv.viewed_at, st.full_name, st.avatar_url
        FROM app.community_story_views sv
        JOIN app.students st ON st.id = sv.viewer_id
        WHERE sv.story_id = p_story_id
        ORDER BY sv.viewed_at DESC
    ) t;

    RETURN v_result;
END;
$$
""")

run("RPC delete_own_story", """
CREATE OR REPLACE FUNCTION public.app_student_delete_own_story(
    p_story_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    UPDATE app.community_stories
    SET is_deleted = TRUE
    WHERE id = p_story_id AND author_id = v_user_id;

    RETURN jsonb_build_object('success', true);
END;
$$
""")

print("\n" + "=" * 50)
print("DEPLOYMENT COMPLETE")
