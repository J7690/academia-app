#!/usr/bin/env python3
"""Phase 8: Deploy prep_live_sessions + prep_live_participants tables, RPCs, RLS."""
import json, requests, time
from pathlib import Path

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SK, "Authorization": f"Bearer {SK}", "Content-Type": "application/json"}

def sql(q, label=""):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                       json={"p_sql": " ".join(q.split())}, timeout=60)
    body = r.json() if r.status_code == 200 else {"ok": False, "error": r.text[:500]}
    ok = isinstance(body, dict) and body.get("ok", False)
    err = body.get("error", "") if isinstance(body, dict) and not ok else ""
    print(f"  {'OK' if ok else 'ERR'} {label} {('-- ' + err[:200]) if err else ''}")
    return ok

print("=" * 60)
print("PHASE 8 -- Sessions live concours")
print("=" * 60)

# A: Tables
print("\n--- A: Tables ---")
sql("CREATE TABLE IF NOT EXISTS app.prep_live_sessions (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), teacher_id UUID NOT NULL REFERENCES auth.users(id), title TEXT NOT NULL, description TEXT, session_type TEXT NOT NULL DEFAULT 'revision', concours_type TEXT, subject_name TEXT, provider TEXT DEFAULT 'livekit', join_url TEXT, start_at TIMESTAMPTZ NOT NULL, end_at TIMESTAMPTZ, replay_url TEXT, max_participants INTEGER DEFAULT 100, status TEXT NOT NULL DEFAULT 'draft', quiz_template_id UUID REFERENCES app.prep_quiz_templates(id), is_active BOOLEAN NOT NULL DEFAULT true, created_at TIMESTAMPTZ NOT NULL DEFAULT now())", "CREATE prep_live_sessions")

sql("CREATE TABLE IF NOT EXISTS app.prep_live_participants (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), session_id UUID NOT NULL REFERENCES app.prep_live_sessions(id) ON DELETE CASCADE, student_id UUID NOT NULL REFERENCES auth.users(id), joined_at TIMESTAMPTZ DEFAULT now(), left_at TIMESTAMPTZ, quiz_score INTEGER, UNIQUE (session_id, student_id))", "CREATE prep_live_participants")

# B: RLS
print("\n--- B: RLS ---")
for t in ["prep_live_sessions", "prep_live_participants"]:
    sql(f"ALTER TABLE app.{t} ENABLE ROW LEVEL SECURITY", f"ENABLE RLS {t}")
    time.sleep(0.1)

policies = [
    ("sr_all_prep_live_sessions", "prep_live_sessions", "FOR ALL TO service_role USING (true) WITH CHECK (true)"),
    ("sr_all_prep_live_participants", "prep_live_participants", "FOR ALL TO service_role USING (true) WITH CHECK (true)"),
    ("teacher_all_own_prep_live", "prep_live_sessions", "FOR ALL TO public USING (teacher_id = auth.uid()) WITH CHECK (teacher_id = auth.uid())"),
    ("student_select_active_prep_live", "prep_live_sessions", "FOR SELECT TO public USING (is_active = true AND status IN (''approved'',''running''))"),
    ("student_own_prep_live_part", "prep_live_participants", "FOR SELECT TO public USING (student_id = auth.uid())"),
    ("student_join_prep_live", "prep_live_participants", "FOR INSERT TO public WITH CHECK (student_id = auth.uid())"),
    ("teacher_see_prep_live_part", "prep_live_participants", "FOR SELECT TO public USING (EXISTS (SELECT 1 FROM app.prep_live_sessions s WHERE s.id = session_id AND s.teacher_id = auth.uid()))"),
    ("admin_all_prep_live_sessions", "prep_live_sessions", "FOR ALL TO public USING (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>''role'' = ''admin'')) WITH CHECK (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>''role'' = ''admin''))"),
    ("admin_all_prep_live_participants", "prep_live_participants", "FOR ALL TO public USING (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>''role'' = ''admin'')) WITH CHECK (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>''role'' = ''admin''))"),
]

for pname, tname, clause in policies:
    sql(f"DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='{pname}' AND tablename='{tname}') THEN EXECUTE 'CREATE POLICY {pname} ON app.{tname} {clause}'; END IF; END $$;", f"policy {pname}")
    time.sleep(0.15)

# C: RPCs
print("\n--- C: RPCs ---")

sql("""
CREATE OR REPLACE FUNCTION app.app_prep_teacher_upsert_live_session(
    p_session_id UUID DEFAULT NULL, p_title TEXT DEFAULT NULL, p_description TEXT DEFAULT NULL,
    p_session_type TEXT DEFAULT 'revision', p_concours_type TEXT DEFAULT NULL, p_subject_name TEXT DEFAULT NULL,
    p_provider TEXT DEFAULT 'livekit', p_join_url TEXT DEFAULT NULL, p_start_at TIMESTAMPTZ DEFAULT NULL,
    p_end_at TIMESTAMPTZ DEFAULT NULL, p_replay_url TEXT DEFAULT NULL, p_max_participants INTEGER DEFAULT 100,
    p_quiz_template_id UUID DEFAULT NULL
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $fn$
DECLARE v_id UUID;
BEGIN
    IF p_session_id IS NOT NULL THEN
        UPDATE app.prep_live_sessions SET title=COALESCE(p_title,title), description=COALESCE(p_description,description),
            session_type=COALESCE(p_session_type,session_type), concours_type=COALESCE(p_concours_type,concours_type),
            subject_name=COALESCE(p_subject_name,subject_name), provider=COALESCE(p_provider,provider),
            join_url=COALESCE(p_join_url,join_url), start_at=COALESCE(p_start_at,start_at), end_at=p_end_at,
            replay_url=p_replay_url, max_participants=COALESCE(p_max_participants,max_participants), quiz_template_id=p_quiz_template_id
        WHERE id=p_session_id AND teacher_id=auth.uid() RETURNING id INTO v_id;
    ELSE
        INSERT INTO app.prep_live_sessions (teacher_id,title,description,session_type,concours_type,subject_name,provider,join_url,start_at,end_at,replay_url,max_participants,quiz_template_id)
        VALUES (auth.uid(),p_title,p_description,p_session_type,p_concours_type,p_subject_name,p_provider,p_join_url,p_start_at,p_end_at,p_replay_url,p_max_participants,p_quiz_template_id) RETURNING id INTO v_id;
    END IF;
    RETURN jsonb_build_object('success',true,'id',v_id);
END; $fn$;
""", "FUNCTION app_prep_teacher_upsert_live_session")

sql("""
CREATE OR REPLACE FUNCTION app.app_prep_teacher_list_live_sessions() RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $fn$
DECLARE v_result JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.start_at DESC), '[]'::jsonb) INTO v_result
    FROM (SELECT s.*, (SELECT COUNT(*) FROM app.prep_live_participants p WHERE p.session_id=s.id) AS participant_count
          FROM app.prep_live_sessions s WHERE s.teacher_id=auth.uid()) t;
    RETURN v_result;
END; $fn$;
""", "FUNCTION app_prep_teacher_list_live_sessions")

sql("""
CREATE OR REPLACE FUNCTION app.app_prep_teacher_start_live_session(p_session_id UUID) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $fn$
BEGIN
    UPDATE app.prep_live_sessions SET status='running' WHERE id=p_session_id AND teacher_id=auth.uid() AND status IN ('draft','approved');
    RETURN jsonb_build_object('success',true);
END; $fn$;
""", "FUNCTION app_prep_teacher_start_live_session")

sql("""
CREATE OR REPLACE FUNCTION app.app_prep_teacher_end_live_session(p_session_id UUID) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $fn$
BEGIN
    UPDATE app.prep_live_sessions SET status='ended' WHERE id=p_session_id AND teacher_id=auth.uid() AND status='running';
    RETURN jsonb_build_object('success',true);
END; $fn$;
""", "FUNCTION app_prep_teacher_end_live_session")

sql("""
CREATE OR REPLACE FUNCTION public.app_prep_student_list_live_sessions() RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $fn$
DECLARE v_result JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.start_at ASC), '[]'::jsonb) INTO v_result
    FROM (SELECT s.id, s.title, s.description, s.session_type, s.concours_type, s.subject_name,
                 s.provider, s.join_url, s.start_at, s.end_at, s.replay_url, s.status, s.max_participants,
                 (SELECT COUNT(*) FROM app.prep_live_participants p WHERE p.session_id=s.id) AS participant_count,
                 (SELECT jsonb_build_object('joined_at',pp.joined_at,'quiz_score',pp.quiz_score) FROM app.prep_live_participants pp WHERE pp.session_id=s.id AND pp.student_id=auth.uid() LIMIT 1) AS my_participation
          FROM app.prep_live_sessions s WHERE s.is_active=true AND s.status IN ('approved','running','ended')) t;
    RETURN v_result;
END; $fn$;
""", "FUNCTION app_prep_student_list_live_sessions")

sql("""
CREATE OR REPLACE FUNCTION public.app_prep_student_join_live_session(p_session_id UUID) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $fn$
DECLARE v_id UUID;
BEGIN
    INSERT INTO app.prep_live_participants (session_id, student_id) VALUES (p_session_id, auth.uid())
    ON CONFLICT (session_id, student_id) DO UPDATE SET joined_at=now()
    RETURNING id INTO v_id;
    RETURN jsonb_build_object('success',true,'id',v_id);
END; $fn$;
""", "FUNCTION app_prep_student_join_live_session")

sql("""
CREATE OR REPLACE FUNCTION app.app_prep_admin_update_live_session_status(p_session_id UUID, p_status TEXT) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $fn$
BEGIN
    UPDATE app.prep_live_sessions SET status=p_status WHERE id=p_session_id;
    RETURN jsonb_build_object('success',true);
END; $fn$;
""", "FUNCTION app_prep_admin_update_live_session_status")

# D: Verification
print("\n--- VERIFICATION ---")
for t in ["prep_live_sessions", "prep_live_participants"]:
    sql(f"SELECT COUNT(*) AS cnt FROM information_schema.tables WHERE table_schema='app' AND table_name='{t}'", f"Table {t}")

sql("SELECT COUNT(*) AS cnt FROM pg_policies WHERE schemaname='app' AND tablename IN ('prep_live_sessions','prep_live_participants')", "RLS count")

sql("SELECT routine_name FROM information_schema.routines WHERE routine_name LIKE '%prep_%live%' ORDER BY routine_name", "Live RPCs")

sql("SELECT COUNT(*) AS cnt FROM information_schema.tables WHERE table_schema='app' AND table_name LIKE 'prep_%'", "Total prep_* tables")

print("\nPhase 8 deployment complete!")
