#!/usr/bin/env python3
"""Phase 7A — ALTER support_messages + UPDATE 4 RPCs pour médias."""
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
    print("Phase 7A — Deploy media support\n")

    # 1. ALTER TABLE — add type + media_url
    all_ok &= run_admin_sql(m, "1. ALTER TABLE support_messages ADD type + media_url", """
ALTER TABLE app.support_messages
    ADD COLUMN IF NOT EXISTS type TEXT NOT NULL DEFAULT 'text',
    ADD COLUMN IF NOT EXISTS media_url TEXT
    """)

    # 2. UPDATE app_send_support_message — add p_type, p_media_url
    all_ok &= run_admin_sql(m, "2. UPDATE app_send_support_message (add type/media_url)", """
CREATE OR REPLACE FUNCTION public.app_send_support_message(
    p_conversation_id UUID,
    p_content TEXT,
    p_type TEXT DEFAULT 'text',
    p_media_url TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $fn$
DECLARE
    v_uid UUID := auth.uid();
    v_conv RECORD;
    v_is_admin BOOLEAN;
    v_side TEXT;
    v_msg_id UUID;
BEGIN
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
    END IF;

    IF TRIM(COALESCE(p_content, '')) = '' AND TRIM(COALESCE(p_media_url, '')) = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'empty_message');
    END IF;

    SELECT id, requester_user_id INTO v_conv
    FROM app.support_conversations
    WHERE id = p_conversation_id;

    IF v_conv IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'conversation_not_found');
    END IF;

    SELECT (raw_user_meta_data->>'role') = 'admin' INTO v_is_admin
    FROM auth.users WHERE id = v_uid;

    IF v_conv.requester_user_id = v_uid THEN
        v_side := 'requester';
    ELSIF COALESCE(v_is_admin, false) THEN
        v_side := 'admin';
    ELSE
        RETURN jsonb_build_object('success', false, 'error', 'not_participant');
    END IF;

    INSERT INTO app.support_messages (conversation_id, sender_user_id, sender_side, content, type, media_url)
    VALUES (p_conversation_id, v_uid, v_side, TRIM(COALESCE(p_content, '')), COALESCE(p_type, 'text'), p_media_url)
    RETURNING id INTO v_msg_id;

    UPDATE app.support_conversations
    SET last_message_at = NOW()
    WHERE id = p_conversation_id;

    RETURN jsonb_build_object('success', true, 'message_id', v_msg_id);
END;
$fn$
    """)

    # 3. UPDATE app_admin_send_support_message — add p_type, p_media_url
    all_ok &= run_admin_sql(m, "3. UPDATE app_admin_send_support_message (add type/media_url)", """
CREATE OR REPLACE FUNCTION public.app_admin_send_support_message(
    p_conversation_id UUID,
    p_content TEXT,
    p_type TEXT DEFAULT 'text',
    p_media_url TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $fn$
DECLARE
    v_uid UUID := auth.uid();
    v_is_admin BOOLEAN;
    v_msg_id UUID;
BEGIN
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
    END IF;

    SELECT (raw_user_meta_data->>'role') = 'admin' INTO v_is_admin
    FROM auth.users WHERE id = v_uid;

    IF NOT COALESCE(v_is_admin, false) THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_admin');
    END IF;

    IF TRIM(COALESCE(p_content, '')) = '' AND TRIM(COALESCE(p_media_url, '')) = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'empty_message');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM app.support_conversations WHERE id = p_conversation_id) THEN
        RETURN jsonb_build_object('success', false, 'error', 'conversation_not_found');
    END IF;

    INSERT INTO app.support_messages (conversation_id, sender_user_id, sender_side, content, type, media_url)
    VALUES (p_conversation_id, v_uid, 'admin', TRIM(COALESCE(p_content, '')), COALESCE(p_type, 'text'), p_media_url)
    RETURNING id INTO v_msg_id;

    UPDATE app.support_conversations
    SET last_message_at = NOW()
    WHERE id = p_conversation_id;

    RETURN jsonb_build_object('success', true, 'message_id', v_msg_id);
END;
$fn$
    """)

    # 4. UPDATE app_list_support_messages — include type + media_url in SELECT
    all_ok &= run_admin_sql(m, "4. UPDATE app_list_support_messages (include type/media_url)", """
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
        SELECT m.id, m.sender_user_id, m.sender_side, m.content, m.type, m.media_url, m.created_at,
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

    # 5. UPDATE app_admin_list_support_messages — include type + media_url
    all_ok &= run_admin_sql(m, "5. UPDATE app_admin_list_support_messages (include type/media_url)", """
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
        SELECT m.id, m.sender_user_id, m.sender_side, m.content, m.type, m.media_url, m.created_at,
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

    # 6. GRANT on updated RPCs
    all_ok &= run_admin_sql(m, "6. GRANT EXECUTE on updated RPCs", """
GRANT EXECUTE ON FUNCTION public.app_send_support_message(UUID, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_send_support_message(UUID, TEXT, TEXT, TEXT) TO authenticated
    """)

    # Verification
    print("\n-- Vérification colonnes --")
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": """
        SELECT column_name FROM information_schema.columns
        WHERE table_schema='app' AND table_name='support_messages'
        ORDER BY ordinal_position
    """}, timeout=30)
    d = r.json() if r.text else {}
    rows = d.get("rows", []) if isinstance(d, dict) else []
    cols = [row.get("column_name") for row in rows] if isinstance(rows, list) else []
    print(f"  Colonnes: {cols}")
    has_type = "type" in cols
    has_media = "media_url" in cols
    print(f"  {'✅' if has_type else '❌'} type")
    print(f"  {'✅' if has_media else '❌'} media_url")
    if not has_type or not has_media:
        all_ok = False

    print(f"\n{'✅ ALL OK' if all_ok else '⚠️ SOME FAILED'}")
    return 0 if all_ok else 1

if __name__ == "__main__":
    raise SystemExit(main())
