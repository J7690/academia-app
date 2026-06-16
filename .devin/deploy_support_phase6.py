#!/usr/bin/env python3
"""Phase 6 — Deploy read receipts + unread count RPC."""
import json, requests
from supabase_auto_manager import SupabaseAutoManager

def run_admin_sql(m, label, sql):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=60)
    d = r.json() if r.text else {}
    ok = r.status_code == 200 and isinstance(d, dict) and d.get("ok") is True
    print(f"{'✅' if ok else '❌'} {label}")
    if not ok:
        print(f"   {json.dumps(d, ensure_ascii=False, default=str)[:400]}")
    return ok

def main():
    m = SupabaseAutoManager()
    all_ok = True
    print("Phase 6 — Deploying read receipts + unread count\n")

    # 1. Update app_list_support_messages to include is_read per message
    all_ok &= run_admin_sql(m, "1. Update app_list_support_messages (add is_read)", """
CREATE OR REPLACE FUNCTION public.app_list_support_messages(
    p_conversation_id UUID,
    p_limit INTEGER DEFAULT 50,
    p_before TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $fn$
DECLARE
    v_uid UUID := auth.uid();
    v_conv RECORD;
    v_is_admin BOOLEAN;
    v_result JSONB;
BEGIN
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
    END IF;

    SELECT id, requester_user_id INTO v_conv
    FROM app.support_conversations
    WHERE id = p_conversation_id;

    IF v_conv IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'conversation_not_found');
    END IF;

    SELECT (raw_user_meta_data->>'role') = 'admin' INTO v_is_admin
    FROM auth.users WHERE id = v_uid;

    IF v_conv.requester_user_id != v_uid AND NOT COALESCE(v_is_admin, false) THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_participant');
    END IF;

    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at ASC), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT m.id, m.sender_user_id, m.sender_side, m.content, m.created_at,
               CASE
                 WHEN m.sender_side = 'requester' THEN
                   EXISTS (
                     SELECT 1 FROM app.support_read_states rs
                     WHERE rs.conversation_id = p_conversation_id
                       AND rs.user_id != v_conv.requester_user_id
                       AND rs.last_read_at >= m.created_at
                   )
                 WHEN m.sender_side = 'admin' THEN
                   EXISTS (
                     SELECT 1 FROM app.support_read_states rs
                     WHERE rs.conversation_id = p_conversation_id
                       AND rs.user_id = v_conv.requester_user_id
                       AND rs.last_read_at >= m.created_at
                   )
                 ELSE false
               END AS is_read
        FROM app.support_messages m
        WHERE m.conversation_id = p_conversation_id
          AND (p_before IS NULL OR m.created_at < p_before)
        ORDER BY m.created_at DESC
        LIMIT LEAST(p_limit, 200)
    ) t;

    RETURN jsonb_build_object('success', true, 'messages', v_result);
END;
$fn$
    """)

    # 2. Update app_admin_list_support_messages similarly
    all_ok &= run_admin_sql(m, "2. Update app_admin_list_support_messages (add is_read)", """
CREATE OR REPLACE FUNCTION public.app_admin_list_support_messages(
    p_conversation_id UUID,
    p_limit INTEGER DEFAULT 100
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $fn$
DECLARE
    v_uid UUID := auth.uid();
    v_is_admin BOOLEAN;
    v_requester_uid UUID;
    v_result JSONB;
BEGIN
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
    END IF;

    SELECT (raw_user_meta_data->>'role') = 'admin' INTO v_is_admin
    FROM auth.users WHERE id = v_uid;

    IF NOT COALESCE(v_is_admin, false) THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_admin');
    END IF;

    SELECT requester_user_id INTO v_requester_uid
    FROM app.support_conversations WHERE id = p_conversation_id;

    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at ASC), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT m.id, m.sender_user_id, m.sender_side, m.content, m.created_at,
               CASE
                 WHEN m.sender_side = 'admin' THEN
                   EXISTS (
                     SELECT 1 FROM app.support_read_states rs
                     WHERE rs.conversation_id = p_conversation_id
                       AND rs.user_id = v_requester_uid
                       AND rs.last_read_at >= m.created_at
                   )
                 WHEN m.sender_side = 'requester' THEN
                   EXISTS (
                     SELECT 1 FROM app.support_read_states rs
                     WHERE rs.conversation_id = p_conversation_id
                       AND rs.user_id != v_requester_uid
                       AND rs.last_read_at >= m.created_at
                   )
                 ELSE false
               END AS is_read
        FROM app.support_messages m
        WHERE m.conversation_id = p_conversation_id
        ORDER BY m.created_at DESC
        LIMIT LEAST(p_limit, 500)
    ) t;

    RETURN jsonb_build_object('success', true, 'messages', v_result);
END;
$fn$
    """)

    # 3. Create app_get_support_unread_count for user-side FAB badge
    all_ok &= run_admin_sql(m, "3. Create app_get_support_unread_count", """
CREATE OR REPLACE FUNCTION public.app_get_support_unread_count()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $fn$
DECLARE
    v_uid UUID := auth.uid();
    v_conv_id UUID;
    v_count INTEGER := 0;
BEGIN
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
    END IF;

    SELECT id INTO v_conv_id
    FROM app.support_conversations
    WHERE requester_user_id = v_uid AND status = 'open'
    ORDER BY created_at DESC LIMIT 1;

    IF v_conv_id IS NULL THEN
        RETURN jsonb_build_object('success', true, 'unread_count', 0);
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM app.support_messages sm
    WHERE sm.conversation_id = v_conv_id
      AND sm.sender_side = 'admin'
      AND sm.created_at > COALESCE(
          (SELECT rs.last_read_at FROM app.support_read_states rs
           WHERE rs.conversation_id = v_conv_id AND rs.user_id = v_uid),
          '1970-01-01'::timestamptz
      );

    RETURN jsonb_build_object('success', true, 'unread_count', v_count);
END;
$fn$
    """)

    # 4. Grant
    all_ok &= run_admin_sql(m, "4. Grant execute on new RPC", """
GRANT EXECUTE ON FUNCTION public.app_get_support_unread_count() TO authenticated
    """)

    # Verify
    print("\n-- Verification --")
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": """
        SELECT p.proname FROM pg_catalog.pg_proc p
        JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname LIKE '%support%'
        ORDER BY p.proname
    """}, timeout=30)
    d = r.json() if r.text else {}
    rows = d.get("rows", []) if isinstance(d, dict) else []
    rpcs = [r.get("proname") for r in rows]
    has_unread = "app_get_support_unread_count" in rpcs
    print(f"{'✅' if has_unread else '❌'} app_get_support_unread_count exists")
    print(f"Total support RPCs: {len(rpcs)}")

    print(f"\n{'✅ ALL OK' if all_ok else '⚠️ SOME FAILED'}")
    return 0 if all_ok else 1

if __name__ == "__main__":
    raise SystemExit(main())
