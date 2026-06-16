#!/usr/bin/env python3
"""Phase 1 — Déploiement du module Support (messagerie admin-only).
Crée les tables, RLS, index, et RPC dans Supabase via admin_execute_sql.
"""

import json
import sys
import requests
from supabase_auto_manager import SupabaseAutoManager


def run_admin_sql(manager, label, sql):
    url = f"{manager.url}/rest/v1/rpc/admin_execute_sql"
    sql_clean = sql.strip()
    # admin_execute_sql n'aime pas les trailing semicolons dans certains cas,
    # mais on envoie tel quel car il gère les blocs DO/CREATE.
    try:
        r = requests.post(url, headers=manager.headers, json={"p_sql": sql_clean}, timeout=60)
        data = r.json() if r.text else {}
        print(f"\n{'='*60}")
        print(f"DEPLOY: {label}")
        print(f"{'='*60}")
        if r.status_code == 200:
            if isinstance(data, dict) and data.get("ok") is True:
                print(f"  ✅ OK")
                return True
            elif isinstance(data, dict) and data.get("ok") is False:
                print(f"  ❌ SQL Error: {json.dumps(data, ensure_ascii=False)[:500]}")
                return False
            else:
                print(f"  ✅ OK (response: {str(data)[:200]})")
                return True
        else:
            print(f"  ❌ HTTP {r.status_code}: {str(data)[:400]}")
            return False
    except Exception as e:
        print(f"  ❌ Exception: {e}")
        return False


# ── SQL statements ──

SQL_TABLES = """
-- 1. Support conversations
CREATE TABLE IF NOT EXISTS app.support_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_user_id UUID NOT NULL REFERENCES auth.users(id),
    requester_role TEXT NOT NULL,
    requester_display_name TEXT NOT NULL DEFAULT '',
    requester_email TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_message_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_support_conv_requester
    ON app.support_conversations(requester_user_id);
CREATE INDEX IF NOT EXISTS idx_support_conv_status
    ON app.support_conversations(status);

-- 2. Support messages
CREATE TABLE IF NOT EXISTS app.support_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES app.support_conversations(id) ON DELETE CASCADE,
    sender_user_id UUID NOT NULL REFERENCES auth.users(id),
    sender_side TEXT NOT NULL CHECK (sender_side IN ('requester', 'admin')),
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_support_msg_conv
    ON app.support_messages(conversation_id, created_at DESC);

-- 3. Support read states
CREATE TABLE IF NOT EXISTS app.support_read_states (
    conversation_id UUID NOT NULL REFERENCES app.support_conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id),
    last_read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (conversation_id, user_id)
)
"""

SQL_RLS = """
-- RLS
ALTER TABLE app.support_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.support_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.support_read_states ENABLE ROW LEVEL SECURITY;

-- support_conversations: requester sees own, admin sees all
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'support_conv_select' AND tablename = 'support_conversations') THEN
    CREATE POLICY support_conv_select ON app.support_conversations
      FOR SELECT USING (
        requester_user_id = auth.uid()
        OR (SELECT raw_user_meta_data->>'role' FROM auth.users WHERE id = auth.uid()) = 'admin'
      );
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'support_conv_insert' AND tablename = 'support_conversations') THEN
    CREATE POLICY support_conv_insert ON app.support_conversations
      FOR INSERT WITH CHECK (requester_user_id = auth.uid());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'support_conv_update' AND tablename = 'support_conversations') THEN
    CREATE POLICY support_conv_update ON app.support_conversations
      FOR UPDATE USING (
        requester_user_id = auth.uid()
        OR (SELECT raw_user_meta_data->>'role' FROM auth.users WHERE id = auth.uid()) = 'admin'
      );
  END IF;
END $$;

-- support_messages: participant sees own conv, admin sees all
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'support_msg_select' AND tablename = 'support_messages') THEN
    CREATE POLICY support_msg_select ON app.support_messages
      FOR SELECT USING (
        EXISTS (
          SELECT 1 FROM app.support_conversations c
          WHERE c.id = support_messages.conversation_id
          AND (c.requester_user_id = auth.uid()
               OR (SELECT raw_user_meta_data->>'role' FROM auth.users WHERE id = auth.uid()) = 'admin')
        )
      );
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'support_msg_insert' AND tablename = 'support_messages') THEN
    CREATE POLICY support_msg_insert ON app.support_messages
      FOR INSERT WITH CHECK (sender_user_id = auth.uid());
  END IF;
END $$;

-- support_read_states: own only
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'support_read_select' AND tablename = 'support_read_states') THEN
    CREATE POLICY support_read_select ON app.support_read_states
      FOR SELECT USING (user_id = auth.uid());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'support_read_upsert' AND tablename = 'support_read_states') THEN
    CREATE POLICY support_read_upsert ON app.support_read_states
      FOR INSERT WITH CHECK (user_id = auth.uid());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'support_read_update' AND tablename = 'support_read_states') THEN
    CREATE POLICY support_read_update ON app.support_read_states
      FOR UPDATE USING (user_id = auth.uid());
  END IF;
END $$;

-- Grants
GRANT SELECT, INSERT, UPDATE ON app.support_conversations TO authenticated;
GRANT SELECT, INSERT ON app.support_messages TO authenticated;
GRANT SELECT, INSERT, UPDATE ON app.support_read_states TO authenticated;
GRANT ALL ON app.support_conversations TO service_role;
GRANT ALL ON app.support_messages TO service_role;
GRANT ALL ON app.support_read_states TO service_role
"""

SQL_RPC_GET_OR_CREATE = """
CREATE OR REPLACE FUNCTION public.app_get_or_create_support_conversation()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $fn$
DECLARE
    v_uid UUID := auth.uid();
    v_role TEXT;
    v_display TEXT;
    v_email TEXT;
    v_conv_id UUID;
BEGIN
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
    END IF;

    -- Resolve role + display name
    SELECT u.email,
           COALESCE(u.raw_user_meta_data->>'role', 'student'),
           COALESCE(
               (SELECT s.full_name FROM app.students s WHERE s.id = v_uid),
               u.email
           )
    INTO v_email, v_role, v_display
    FROM auth.users u
    WHERE u.id = v_uid;

    -- Admin should not create support convs for themselves
    IF v_role = 'admin' THEN
        RETURN jsonb_build_object('success', false, 'error', 'admin_cannot_create_support');
    END IF;

    -- Try find existing open conversation
    SELECT id INTO v_conv_id
    FROM app.support_conversations
    WHERE requester_user_id = v_uid
      AND status = 'open'
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_conv_id IS NULL THEN
        INSERT INTO app.support_conversations (requester_user_id, requester_role, requester_display_name, requester_email)
        VALUES (v_uid, v_role, COALESCE(v_display, ''), COALESCE(v_email, ''))
        RETURNING id INTO v_conv_id;
    END IF;

    RETURN jsonb_build_object('success', true, 'conversation_id', v_conv_id);
END;
$fn$
"""

SQL_RPC_LIST_MESSAGES = """
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
        SELECT m.id, m.sender_user_id, m.sender_side, m.content, m.created_at
        FROM app.support_messages m
        WHERE m.conversation_id = p_conversation_id
          AND (p_before IS NULL OR m.created_at < p_before)
        ORDER BY m.created_at DESC
        LIMIT LEAST(p_limit, 200)
    ) t;

    RETURN jsonb_build_object('success', true, 'messages', v_result);
END;
$fn$
"""

SQL_RPC_SEND_MESSAGE = """
CREATE OR REPLACE FUNCTION public.app_send_support_message(
    p_conversation_id UUID,
    p_content TEXT
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

    IF TRIM(COALESCE(p_content, '')) = '' THEN
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

    INSERT INTO app.support_messages (conversation_id, sender_user_id, sender_side, content)
    VALUES (p_conversation_id, v_uid, v_side, TRIM(p_content))
    RETURNING id INTO v_msg_id;

    UPDATE app.support_conversations
    SET last_message_at = NOW()
    WHERE id = p_conversation_id;

    RETURN jsonb_build_object('success', true, 'message_id', v_msg_id);
END;
$fn$
"""

SQL_RPC_MARK_READ = """
CREATE OR REPLACE FUNCTION public.app_mark_support_read(
    p_conversation_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $fn$
DECLARE
    v_uid UUID := auth.uid();
BEGIN
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
    END IF;

    INSERT INTO app.support_read_states (conversation_id, user_id, last_read_at)
    VALUES (p_conversation_id, v_uid, NOW())
    ON CONFLICT (conversation_id, user_id)
    DO UPDATE SET last_read_at = NOW();

    RETURN jsonb_build_object('success', true);
END;
$fn$
"""

SQL_RPC_ADMIN_LIST_CONVERSATIONS = """
CREATE OR REPLACE FUNCTION public.app_admin_list_support_conversations(
    p_status TEXT DEFAULT NULL,
    p_role TEXT DEFAULT NULL,
    p_search TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $fn$
DECLARE
    v_uid UUID := auth.uid();
    v_is_admin BOOLEAN;
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

    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.last_message_at DESC NULLS LAST), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT
            c.id AS conversation_id,
            c.requester_user_id,
            c.requester_role,
            c.requester_display_name,
            c.requester_email,
            c.status,
            c.created_at,
            c.last_message_at,
            (SELECT sm.content FROM app.support_messages sm
             WHERE sm.conversation_id = c.id
             ORDER BY sm.created_at DESC LIMIT 1
            ) AS last_message_content,
            (SELECT sm.sender_side FROM app.support_messages sm
             WHERE sm.conversation_id = c.id
             ORDER BY sm.created_at DESC LIMIT 1
            ) AS last_message_sender_side,
            COALESCE(
                (SELECT COUNT(*) FROM app.support_messages sm
                 WHERE sm.conversation_id = c.id
                   AND sm.sender_side = 'requester'
                   AND sm.created_at > COALESCE(
                       (SELECT rs.last_read_at FROM app.support_read_states rs
                        WHERE rs.conversation_id = c.id AND rs.user_id = v_uid),
                       '1970-01-01'::timestamptz
                   )
                ), 0
            )::int AS unread_count
        FROM app.support_conversations c
        WHERE (p_status IS NULL OR c.status = p_status)
          AND (p_role IS NULL OR c.requester_role = p_role)
          AND (p_search IS NULL
               OR c.requester_display_name ILIKE '%' || p_search || '%'
               OR c.requester_email ILIKE '%' || p_search || '%')
        ORDER BY c.last_message_at DESC NULLS LAST
        LIMIT LEAST(p_limit, 200)
        OFFSET p_offset
    ) t;

    RETURN jsonb_build_object('success', true, 'conversations', v_result);
END;
$fn$
"""

SQL_RPC_ADMIN_SEND = """
CREATE OR REPLACE FUNCTION public.app_admin_send_support_message(
    p_conversation_id UUID,
    p_content TEXT
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

    IF TRIM(COALESCE(p_content, '')) = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'empty_message');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM app.support_conversations WHERE id = p_conversation_id) THEN
        RETURN jsonb_build_object('success', false, 'error', 'conversation_not_found');
    END IF;

    INSERT INTO app.support_messages (conversation_id, sender_user_id, sender_side, content)
    VALUES (p_conversation_id, v_uid, 'admin', TRIM(p_content))
    RETURNING id INTO v_msg_id;

    UPDATE app.support_conversations
    SET last_message_at = NOW()
    WHERE id = p_conversation_id;

    RETURN jsonb_build_object('success', true, 'message_id', v_msg_id);
END;
$fn$
"""

SQL_RPC_ADMIN_SET_STATUS = """
CREATE OR REPLACE FUNCTION public.app_admin_set_support_status(
    p_conversation_id UUID,
    p_status TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $fn$
DECLARE
    v_uid UUID := auth.uid();
    v_is_admin BOOLEAN;
BEGIN
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
    END IF;

    SELECT (raw_user_meta_data->>'role') = 'admin' INTO v_is_admin
    FROM auth.users WHERE id = v_uid;

    IF NOT COALESCE(v_is_admin, false) THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_admin');
    END IF;

    IF p_status NOT IN ('open', 'closed') THEN
        RETURN jsonb_build_object('success', false, 'error', 'invalid_status');
    END IF;

    UPDATE app.support_conversations
    SET status = p_status
    WHERE id = p_conversation_id;

    RETURN jsonb_build_object('success', true);
END;
$fn$
"""

SQL_RPC_ADMIN_LIST_MESSAGES = """
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

    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at ASC), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT m.id, m.sender_user_id, m.sender_side, m.content, m.created_at
        FROM app.support_messages m
        WHERE m.conversation_id = p_conversation_id
        ORDER BY m.created_at DESC
        LIMIT LEAST(p_limit, 500)
    ) t;

    RETURN jsonb_build_object('success', true, 'messages', v_result);
END;
$fn$
"""

SQL_GRANTS = """
GRANT EXECUTE ON FUNCTION public.app_get_or_create_support_conversation() TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_list_support_messages(UUID, INTEGER, TIMESTAMPTZ) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_send_support_message(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_mark_support_read(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_list_support_conversations(TEXT, TEXT, TEXT, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_send_support_message(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_set_support_status(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_list_support_messages(UUID, INTEGER) TO authenticated
"""

SQL_REALTIME = """
ALTER PUBLICATION supabase_realtime ADD TABLE app.support_messages
"""


def main():
    m = SupabaseAutoManager()
    all_ok = True

    steps = [
        ("1. Tables support_*", SQL_TABLES),
        ("2. RLS policies + grants tables", SQL_RLS),
        ("3. RPC app_get_or_create_support_conversation", SQL_RPC_GET_OR_CREATE),
        ("4. RPC app_list_support_messages", SQL_RPC_LIST_MESSAGES),
        ("5. RPC app_send_support_message", SQL_RPC_SEND_MESSAGE),
        ("6. RPC app_mark_support_read", SQL_RPC_MARK_READ),
        ("7. RPC app_admin_list_support_conversations", SQL_RPC_ADMIN_LIST_CONVERSATIONS),
        ("8. RPC app_admin_send_support_message", SQL_RPC_ADMIN_SEND),
        ("9. RPC app_admin_set_support_status", SQL_RPC_ADMIN_SET_STATUS),
        ("10. RPC app_admin_list_support_messages", SQL_RPC_ADMIN_LIST_MESSAGES),
        ("11. GRANT EXECUTE on all RPCs", SQL_GRANTS),
        ("12. Realtime publication", SQL_REALTIME),
    ]

    for label, sql in steps:
        ok = run_admin_sql(m, label, sql)
        if not ok:
            all_ok = False

    # ── Verification ──
    print(f"\n{'='*60}")
    print("VÉRIFICATION POST-DÉPLOIEMENT")
    print(f"{'='*60}")

    verif_sql = """SELECT table_name FROM information_schema.tables
                   WHERE table_schema = 'app' AND table_name LIKE 'support_%'
                   ORDER BY table_name"""
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": verif_sql.strip()}, timeout=30)
    data = r.json() if r.text else {}
    rows = data.get("rows", []) if isinstance(data, dict) else []
    tables_found = [row.get("table_name") for row in rows] if isinstance(rows, list) else []
    print(f"  Tables support_*: {tables_found}")
    expected = ["support_conversations", "support_messages", "support_read_states"]
    for t in expected:
        if t in tables_found:
            print(f"    ✅ {t}")
        else:
            print(f"    ❌ {t} MANQUANT")
            all_ok = False

    verif_rpc = """SELECT p.proname FROM pg_catalog.pg_proc p
                   JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
                   WHERE n.nspname = 'public' AND p.proname LIKE '%support%'
                   ORDER BY p.proname"""
    r2 = requests.post(url, headers=m.headers, json={"p_sql": verif_rpc.strip()}, timeout=30)
    data2 = r2.json() if r2.text else {}
    rows2 = data2.get("rows", []) if isinstance(data2, dict) else []
    rpcs_found = [row.get("proname") for row in rows2] if isinstance(rows2, list) else []
    print(f"  RPCs support: {rpcs_found}")
    expected_rpcs = [
        "app_get_or_create_support_conversation",
        "app_list_support_messages",
        "app_send_support_message",
        "app_mark_support_read",
        "app_admin_list_support_conversations",
        "app_admin_send_support_message",
        "app_admin_set_support_status",
        "app_admin_list_support_messages",
    ]
    for rpc in expected_rpcs:
        if rpc in rpcs_found:
            print(f"    ✅ {rpc}")
        else:
            print(f"    ❌ {rpc} MANQUANT")
            all_ok = False

    print(f"\n{'='*60}")
    if all_ok:
        print("✅ PHASE 1 DÉPLOYÉE ET VÉRIFIÉE AVEC SUCCÈS")
    else:
        print("⚠️ CERTAINS ÉLÉMENTS ONT ÉCHOUÉ — VOIR CI-DESSUS")
    print(f"{'='*60}")

    return 0 if all_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
