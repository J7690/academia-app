#!/usr/bin/env python3
"""Deploy mention notification RPC to Supabase"""
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

# RPC to send push notifications for @mentions in a community post
run("RPC app_notify_community_mention", """
CREATE OR REPLACE FUNCTION public.app_notify_community_mention(
    p_community_id UUID,
    p_post_id UUID,
    p_content TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_author_id UUID := auth.uid();
    v_author_name TEXT;
    v_community_name TEXT;
    v_mention_match TEXT[];
    v_mentioned_user_id UUID;
    v_count INT := 0;
BEGIN
    -- Get author display name
    SELECT full_name INTO v_author_name
    FROM app.students WHERE id = v_author_id;
    IF v_author_name IS NULL THEN
        v_author_name := 'Quelqu''un';
    END IF;

    -- Get community name
    SELECT name INTO v_community_name
    FROM app.communities WHERE id = p_community_id;
    IF v_community_name IS NULL THEN
        v_community_name := 'un groupe';
    END IF;

    -- Extract all @[Name](userId) patterns from content
    -- PostgreSQL regex: find all UUIDs inside parentheses after ]
    FOR v_mention_match IN
        SELECT regexp_matches(p_content, '@\[[^\]]+\]\(([0-9a-f\-]{36})\)', 'g')
    LOOP
        v_mentioned_user_id := v_mention_match[1]::UUID;

        -- Skip self-mentions
        IF v_mentioned_user_id = v_author_id THEN
            CONTINUE;
        END IF;

        -- Verify the mentioned user is a member of this community
        IF NOT EXISTS (
            SELECT 1 FROM app.community_memberships
            WHERE community_id = p_community_id
              AND user_id = v_mentioned_user_id
              AND is_active = TRUE
        ) THEN
            CONTINUE;
        END IF;

        -- Insert notification event for the mentioned user
        INSERT INTO app.notification_events (user_id, domain, event_type, payload)
        VALUES (
            v_mentioned_user_id,
            'student_communities',
            'mention',
            jsonb_build_object(
                'community_id', p_community_id,
                'community_name', v_community_name,
                'post_id', p_post_id,
                'author_id', v_author_id,
                'author_name', v_author_name,
                'title', v_author_name || ' t''a mentionné dans ' || v_community_name,
                'body', LEFT(regexp_replace(p_content, '@\[[^\]]+\]\([^)]+\)', '', 'g'), 100)
            )
        );

        v_count := v_count + 1;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'mentions_notified', v_count);
END;
$$
""")

print("\nDONE")
