#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Deploy UGC moderation system for Google Play compliance.
Creates: content_reports, user_blocks, user_mutes, banned_words + RPCs.
"""
import sys, json, requests
sys.stdout.reconfigure(encoding='utf-8')
from supabase_auto_manager import SupabaseAutoManager
m = SupabaseAutoManager()

def ddl(label, q, timeout=180):
    r = requests.post(f"{m.url}/rest/v1/rpc/execute_ddl",
        headers=m.headers, json={"ddl_query": q.strip()}, timeout=timeout).json()
    ok = not (isinstance(r, dict) and r.get("code"))
    err = r.get("message") if isinstance(r, dict) else None
    print(f"  [{'OK' if ok else 'FAIL'}] {label}" + (f" -- {str(err)[:150]}" if err else ""))
    return r

# ══════════════════════════════════════════════════════════
# 1. content_reports — generic report table for all content
# ══════════════════════════════════════════════════════════
print("=== 1. content_reports ===")
ddl("create_content_reports", """
CREATE TABLE IF NOT EXISTS app.content_reports (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id uuid NOT NULL REFERENCES auth.users(id),
    content_type text NOT NULL,
    content_id uuid NOT NULL,
    target_user_id uuid,
    reason text NOT NULL,
    details text,
    status text NOT NULL DEFAULT 'pending',
    admin_notes text,
    resolved_by uuid,
    resolved_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_content_reports_status ON app.content_reports(status);
CREATE INDEX IF NOT EXISTS idx_content_reports_type ON app.content_reports(content_type);
CREATE INDEX IF NOT EXISTS idx_content_reports_reporter ON app.content_reports(reporter_id);
ALTER TABLE app.content_reports ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='content_reports' AND policyname='student_own_reports') THEN
        CREATE POLICY student_own_reports ON app.content_reports FOR SELECT TO authenticated USING (reporter_id = auth.uid());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='content_reports' AND policyname='student_insert_reports') THEN
        CREATE POLICY student_insert_reports ON app.content_reports FOR INSERT TO authenticated WITH CHECK (reporter_id = auth.uid());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='content_reports' AND policyname='service_role_all_reports') THEN
        CREATE POLICY service_role_all_reports ON app.content_reports FOR ALL TO service_role USING (true) WITH CHECK (true);
    END IF;
END $$;
""")

# ══════════════════════════════════════════════════════════
# 2. user_blocks — block between users
# ══════════════════════════════════════════════════════════
print("\n=== 2. user_blocks ===")
ddl("create_user_blocks", """
CREATE TABLE IF NOT EXISTS app.user_blocks (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    blocker_id uuid NOT NULL REFERENCES auth.users(id),
    blocked_id uuid NOT NULL REFERENCES auth.users(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE(blocker_id, blocked_id),
    CHECK(blocker_id != blocked_id)
);
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocker ON app.user_blocks(blocker_id);
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocked ON app.user_blocks(blocked_id);
ALTER TABLE app.user_blocks ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='user_blocks' AND policyname='user_own_blocks') THEN
        CREATE POLICY user_own_blocks ON app.user_blocks FOR ALL TO authenticated
            USING (blocker_id = auth.uid()) WITH CHECK (blocker_id = auth.uid());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='user_blocks' AND policyname='sr_all_blocks') THEN
        CREATE POLICY sr_all_blocks ON app.user_blocks FOR ALL TO service_role USING (true) WITH CHECK (true);
    END IF;
END $$;
""")

# ══════════════════════════════════════════════════════════
# 3. user_mutes — mute (hide without blocking)
# ══════════════════════════════════════════════════════════
print("\n=== 3. user_mutes ===")
ddl("create_user_mutes", """
CREATE TABLE IF NOT EXISTS app.user_mutes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    muter_id uuid NOT NULL REFERENCES auth.users(id),
    muted_id uuid NOT NULL REFERENCES auth.users(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE(muter_id, muted_id),
    CHECK(muter_id != muted_id)
);
ALTER TABLE app.user_mutes ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='user_mutes' AND policyname='user_own_mutes') THEN
        CREATE POLICY user_own_mutes ON app.user_mutes FOR ALL TO authenticated
            USING (muter_id = auth.uid()) WITH CHECK (muter_id = auth.uid());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='user_mutes' AND policyname='sr_all_mutes') THEN
        CREATE POLICY sr_all_mutes ON app.user_mutes FOR ALL TO service_role USING (true) WITH CHECK (true);
    END IF;
END $$;
""")

# ══════════════════════════════════════════════════════════
# 4. banned_words — for automatic comment filtering
# ══════════════════════════════════════════════════════════
print("\n=== 4. banned_words ===")
ddl("create_banned_words", """
CREATE TABLE IF NOT EXISTS app.banned_words (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    word text NOT NULL UNIQUE,
    category text NOT NULL DEFAULT 'general',
    severity text NOT NULL DEFAULT 'medium',
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE app.banned_words ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='banned_words' AND policyname='sr_all_bw') THEN
        CREATE POLICY sr_all_bw ON app.banned_words FOR ALL TO service_role USING (true) WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='banned_words' AND policyname='auth_read_bw') THEN
        CREATE POLICY auth_read_bw ON app.banned_words FOR SELECT TO authenticated USING (is_active = true);
    END IF;
END $$;
""")

# Seed banned words (French insults + common offensive terms)
ddl("seed_banned_words", """
INSERT INTO app.banned_words (word, category, severity) VALUES
    ('connard', 'insult', 'high'), ('salope', 'insult', 'high'),
    ('putain', 'insult', 'high'), ('enculer', 'insult', 'high'),
    ('nique', 'insult', 'high'), ('fdp', 'insult', 'high'),
    ('ntm', 'insult', 'high'), ('batard', 'insult', 'high'),
    ('pd', 'insult', 'high'), ('pute', 'insult', 'high'),
    ('merde', 'insult', 'medium'), ('con', 'insult', 'medium'),
    ('idiot', 'insult', 'low'), ('imbecile', 'insult', 'low'),
    ('arnaque', 'scam', 'high'), ('escroquerie', 'scam', 'high'),
    ('envoie argent', 'scam', 'high'), ('transfert momo', 'scam', 'medium'),
    ('nude', 'sexual', 'high'), ('sex', 'sexual', 'high'),
    ('porn', 'sexual', 'high'), ('xxx', 'sexual', 'high'),
    ('kill', 'violence', 'high'), ('tuer', 'violence', 'high'),
    ('mourir', 'violence', 'medium'), ('suicide', 'violence', 'high'),
    ('drogue', 'drugs', 'high'), ('cocaine', 'drugs', 'high'),
    ('weed', 'drugs', 'medium'), ('cannabis', 'drugs', 'medium')
ON CONFLICT (word) DO NOTHING;
""")

# ══════════════════════════════════════════════════════════
# 5. RPCs — Report content (generic)
# ══════════════════════════════════════════════════════════
print("\n=== 5. RPCs ===")
ddl("rpc_report_content", """
CREATE OR REPLACE FUNCTION public.app_student_report_content(
    p_content_type text,
    p_content_id uuid,
    p_reason text,
    p_details text DEFAULT NULL,
    p_target_user_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_uid uuid := auth.uid();
BEGIN
    IF v_uid IS NULL THEN RETURN jsonb_build_object('error','not_authenticated'); END IF;
    IF p_content_type NOT IN ('video','image','comment','live','user','post','message') THEN
        RETURN jsonb_build_object('error','invalid_content_type');
    END IF;
    IF p_reason NOT IN ('nudity','violence','harassment','spam','scam','inappropriate','fake_profile','hate_speech','other') THEN
        RETURN jsonb_build_object('error','invalid_reason');
    END IF;
    IF EXISTS (SELECT 1 FROM app.content_reports WHERE reporter_id=v_uid AND content_type=p_content_type AND content_id=p_content_id) THEN
        RETURN jsonb_build_object('error','already_reported');
    END IF;
    INSERT INTO app.content_reports (reporter_id, content_type, content_id, reason, details, target_user_id)
    VALUES (v_uid, p_content_type, p_content_id, p_reason, p_details, p_target_user_id);
    RETURN jsonb_build_object('success', true);
END; $fn$;
""")

ddl("rpc_block_user", """
CREATE OR REPLACE FUNCTION public.app_student_block_user(p_blocked_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_uid uuid := auth.uid();
BEGIN
    IF v_uid IS NULL THEN RETURN jsonb_build_object('error','not_authenticated'); END IF;
    IF v_uid = p_blocked_id THEN RETURN jsonb_build_object('error','cannot_block_self'); END IF;
    INSERT INTO app.user_blocks (blocker_id, blocked_id) VALUES (v_uid, p_blocked_id) ON CONFLICT DO NOTHING;
    RETURN jsonb_build_object('success', true);
END; $fn$;
""")

ddl("rpc_unblock_user", """
CREATE OR REPLACE FUNCTION public.app_student_unblock_user(p_blocked_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_uid uuid := auth.uid();
BEGIN
    IF v_uid IS NULL THEN RETURN jsonb_build_object('error','not_authenticated'); END IF;
    DELETE FROM app.user_blocks WHERE blocker_id = v_uid AND blocked_id = p_blocked_id;
    RETURN jsonb_build_object('success', true);
END; $fn$;
""")

ddl("rpc_mute_user", """
CREATE OR REPLACE FUNCTION public.app_student_mute_user(p_muted_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_uid uuid := auth.uid();
BEGIN
    IF v_uid IS NULL THEN RETURN jsonb_build_object('error','not_authenticated'); END IF;
    INSERT INTO app.user_mutes (muter_id, muted_id) VALUES (v_uid, p_muted_id) ON CONFLICT DO NOTHING;
    RETURN jsonb_build_object('success', true);
END; $fn$;
""")

ddl("rpc_unmute_user", """
CREATE OR REPLACE FUNCTION public.app_student_unmute_user(p_muted_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_uid uuid := auth.uid();
BEGIN
    IF v_uid IS NULL THEN RETURN jsonb_build_object('error','not_authenticated'); END IF;
    DELETE FROM app.user_mutes WHERE muter_id = v_uid AND muted_id = p_muted_id;
    RETURN jsonb_build_object('success', true);
END; $fn$;
""")

ddl("rpc_list_blocked", """
CREATE OR REPLACE FUNCTION public.app_student_list_blocked_users()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_uid uuid := auth.uid();
BEGIN
    IF v_uid IS NULL THEN RETURN '[]'::jsonb; END IF;
    RETURN COALESCE((
        SELECT jsonb_agg(jsonb_build_object('user_id', ub.blocked_id, 'blocked_at', ub.created_at,
            'display_name', COALESCE(s.full_name, 'Utilisateur')))
        FROM app.user_blocks ub LEFT JOIN app.students s ON s.id = ub.blocked_id
        WHERE ub.blocker_id = v_uid
    ), '[]'::jsonb);
END; $fn$;
""")

ddl("rpc_check_content_banned", """
CREATE OR REPLACE FUNCTION public.app_check_content_for_banned_words(p_text text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE
    v_lower text := LOWER(COALESCE(p_text, ''));
    v_found text[] := '{}';
    v_word RECORD;
BEGIN
    FOR v_word IN SELECT word, severity FROM app.banned_words WHERE is_active = true LOOP
        IF v_lower LIKE '%' || v_word.word || '%' THEN
            v_found := array_append(v_found, v_word.word);
        END IF;
    END LOOP;
    RETURN jsonb_build_object('is_clean', array_length(v_found, 1) IS NULL, 'flagged_words', to_jsonb(v_found));
END; $fn$;
""")

ddl("rpc_admin_list_reports", """
CREATE OR REPLACE FUNCTION public.app_admin_list_content_reports(
    p_status text DEFAULT NULL,
    p_content_type text DEFAULT NULL,
    p_limit integer DEFAULT 50
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $fn$
BEGIN
    RETURN COALESCE((
        SELECT jsonb_agg(row_to_json(t)::jsonb)
        FROM (
            SELECT cr.id, cr.content_type, cr.content_id, cr.reason, cr.details,
                   cr.status, cr.created_at, cr.admin_notes,
                   s_reporter.full_name AS reporter_name,
                   s_target.full_name AS target_name
            FROM app.content_reports cr
            LEFT JOIN app.students s_reporter ON s_reporter.id = cr.reporter_id
            LEFT JOIN app.students s_target ON s_target.id = cr.target_user_id
            WHERE (p_status IS NULL OR cr.status = p_status)
              AND (p_content_type IS NULL OR cr.content_type = p_content_type)
            ORDER BY cr.created_at DESC LIMIT LEAST(p_limit, 100)
        ) t
    ), '[]'::jsonb);
END; $fn$;
""")

ddl("rpc_admin_resolve_report", """
CREATE OR REPLACE FUNCTION public.app_admin_resolve_content_report(
    p_report_id uuid,
    p_status text,
    p_admin_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $fn$
BEGIN
    UPDATE app.content_reports SET
        status = p_status, admin_notes = p_admin_notes,
        resolved_by = auth.uid(), resolved_at = now()
    WHERE id = p_report_id;
    RETURN jsonb_build_object('success', true);
END; $fn$;
""")

ddl("rpc_admin_suspend_user", """
CREATE OR REPLACE FUNCTION public.app_admin_suspend_user(
    p_user_id uuid,
    p_reason text,
    p_duration_hours integer DEFAULT 24
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $fn$
BEGIN
    UPDATE app.user_admin_status SET
        is_suspended = true, suspended_reason = p_reason,
        suspended_at = now(), updated_at = now()
    WHERE user_id = p_user_id;
    IF NOT FOUND THEN
        INSERT INTO app.user_admin_status (user_id, is_suspended, suspended_reason, suspended_at, updated_at)
        VALUES (p_user_id, true, p_reason, now(), now());
    END IF;
    RETURN jsonb_build_object('success', true, 'suspended_until',
        (now() + (p_duration_hours || ' hours')::interval)::text);
END; $fn$;
""")

ddl("rpc_admin_unsuspend_user", """
CREATE OR REPLACE FUNCTION public.app_admin_unsuspend_user(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $fn$
BEGIN
    UPDATE app.user_admin_status SET
        is_suspended = false, reactivated_at = now(), updated_at = now()
    WHERE user_id = p_user_id;
    RETURN jsonb_build_object('success', true);
END; $fn$;
""")

# Verify
print("\n=== VERIFICATION ===")
for t in ["content_reports", "user_blocks", "user_mutes", "banned_words"]:
    r = requests.post(f"{m.url}/rest/v1/rpc/admin_execute_sql",
        headers=m.headers, json={"p_sql": f"SELECT 1 FROM pg_tables WHERE schemaname='app' AND tablename='{t}'"}, timeout=30).json()
    print(f"  {t}: {'EXISTS' if r.get('rows') else 'MISSING'}")

r = requests.post(f"{m.url}/rest/v1/rpc/admin_execute_sql",
    headers=m.headers, json={"p_sql": "SELECT count(*)::int AS n FROM app.banned_words"}, timeout=30).json()
print(f"  Banned words: {r.get('rows', [{}])[0].get('n', 0) if r.get('rows') else 'ERR'}")

print("\n[OK] Supabase UGC moderation deployed")
