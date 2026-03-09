#!/usr/bin/env python3
"""Deploy read receipts RPC to Supabase"""
import requests, json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()
url = f"{m.url}/rest/v1/rpc/admin_execute_sql"

def run(label, sql):
    print(f"\n--- {label} ---")
    resp = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=30)
    data = resp.json() if resp.status_code == 200 else resp.text[:300]
    if isinstance(data, dict):
        if data.get("ok"):
            print(f"  OK ({data.get('mode','?')})")
        elif "already exists" in str(data.get("error", "")):
            print(f"  SKIP (already exists)")
        else:
            print(f"  ERROR: {data.get('error','?')}")
    else:
        print(f"  {str(data)[:200]}")

# RPC to get read count for a specific post
run("RPC get_post_read_info", """
CREATE OR REPLACE FUNCTION public.app_student_get_post_read_info(
    p_community_id UUID,
    p_post_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_post_created_at TIMESTAMPTZ;
    v_read_count INT;
    v_total_members INT;
BEGIN
    -- Get the post's created_at timestamp
    SELECT created_at INTO v_post_created_at
    FROM app.community_posts
    WHERE id = p_post_id AND community_id = p_community_id;

    IF v_post_created_at IS NULL THEN
        RETURN jsonb_build_object('read_count', 0, 'total_members', 0);
    END IF;

    -- Count members who have read after this post was created (excluding the author)
    SELECT COUNT(*) INTO v_read_count
    FROM app.community_read_states rs
    WHERE rs.community_id = p_community_id
      AND rs.user_id != v_user_id
      AND rs.last_read_at >= v_post_created_at;

    -- Count total active members (excluding the author)
    SELECT COUNT(*) INTO v_total_members
    FROM app.community_memberships
    WHERE community_id = p_community_id
      AND user_id != v_user_id
      AND is_active = TRUE;

    RETURN jsonb_build_object(
        'read_count', v_read_count,
        'total_members', v_total_members
    );
END;
$$
""")

# RPC to get read status for all posts of current user in a community (batch)
run("RPC get_my_posts_read_status", """
CREATE OR REPLACE FUNCTION public.app_student_get_my_posts_read_status(
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
    SELECT COALESCE(jsonb_object_agg(post_id::TEXT, read_count), '{}'::JSONB)
    INTO v_result
    FROM (
        SELECT
            p.id AS post_id,
            (
                SELECT COUNT(*)
                FROM app.community_read_states rs
                WHERE rs.community_id = p_community_id
                  AND rs.user_id != v_user_id
                  AND rs.last_read_at >= p.created_at
            ) AS read_count
        FROM app.community_posts p
        WHERE p.community_id = p_community_id
          AND p.author_id = v_user_id
          AND p.is_deleted = FALSE
        ORDER BY p.created_at DESC
        LIMIT 50
    ) sub;

    RETURN v_result;
END;
$$
""")

print("\nDONE")
