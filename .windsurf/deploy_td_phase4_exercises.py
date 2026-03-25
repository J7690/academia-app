#!/usr/bin/env python3
"""Phase 4 TD: Deploy td_assignments + td_assignment_submissions + RPCs."""
import requests, time

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SK, "Authorization": f"Bearer {SK}", "Content-Type": "application/json"}

def sql(q, label=""):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                       json={"p_sql": " ".join(q.split())}, timeout=60)
    body = r.json() if r.status_code == 200 else {"ok": False, "error": r.text[:500]}
    ok = isinstance(body, dict) and body.get("ok", False)
    err = body.get("error", "") if not ok else ""
    print(f"  {'OK' if ok else 'ERR'} {label} {('-- ' + err[:200]) if err else ''}")
    return ok

print("=" * 60)
print("PHASE 4 TD -- Exercices: Tables + RPCs + RLS")
print("=" * 60)

# Tables
print("\n--- Tables ---")
sql("CREATE TABLE IF NOT EXISTS app.td_assignments (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), teacher_id UUID NOT NULL REFERENCES auth.users(id), enrollment_id UUID REFERENCES app.td_enrollments(id), title TEXT NOT NULL, description TEXT, subject TEXT, assignment_type TEXT NOT NULL DEFAULT 'exercise', content JSONB, attachments JSONB DEFAULT '[]'::jsonb, deadline TIMESTAMPTZ, max_score INTEGER DEFAULT 20, is_published BOOLEAN NOT NULL DEFAULT false, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now())", "CREATE td_assignments")

sql("CREATE TABLE IF NOT EXISTS app.td_assignment_submissions (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), assignment_id UUID NOT NULL REFERENCES app.td_assignments(id) ON DELETE CASCADE, student_id UUID NOT NULL REFERENCES auth.users(id), answer_content JSONB, attachments JSONB DEFAULT '[]'::jsonb, submitted_at TIMESTAMPTZ DEFAULT now(), status TEXT NOT NULL DEFAULT 'submitted', teacher_score INTEGER, teacher_comment TEXT, teacher_graded_at TIMESTAMPTZ, ai_score INTEGER, ai_correction TEXT, ai_explanation TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), UNIQUE(assignment_id, student_id))", "CREATE td_assignment_submissions")

# RLS
print("\n--- RLS ---")
for t in ["td_assignments", "td_assignment_submissions"]:
    sql(f"ALTER TABLE app.{t} ENABLE ROW LEVEL SECURITY", f"ENABLE RLS {t}")
    time.sleep(0.1)

policies = [
    ("sr_all_td_assignments", "td_assignments", "FOR ALL TO service_role USING (true) WITH CHECK (true)"),
    ("sr_all_td_assignment_subs", "td_assignment_submissions", "FOR ALL TO service_role USING (true) WITH CHECK (true)"),
    ("teacher_all_own_td_assignments", "td_assignments", "FOR ALL TO public USING (teacher_id = auth.uid()) WITH CHECK (teacher_id = auth.uid())"),
    ("student_select_published_td_assignments", "td_assignments", "FOR SELECT TO public USING (is_published = true)"),
    ("student_own_td_submissions", "td_assignment_submissions", "FOR SELECT TO public USING (student_id = auth.uid())"),
    ("student_insert_td_submission", "td_assignment_submissions", "FOR INSERT TO public WITH CHECK (student_id = auth.uid())"),
    ("student_update_td_submission", "td_assignment_submissions", "FOR UPDATE TO public USING (student_id = auth.uid())"),
    ("teacher_see_td_submissions", "td_assignment_submissions", "FOR ALL TO public USING (EXISTS (SELECT 1 FROM app.td_assignments a WHERE a.id = assignment_id AND a.teacher_id = auth.uid())) WITH CHECK (EXISTS (SELECT 1 FROM app.td_assignments a WHERE a.id = assignment_id AND a.teacher_id = auth.uid()))"),
    ("admin_all_td_assignments", "td_assignments", "FOR ALL TO public USING (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>''role'' = ''admin'')) WITH CHECK (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>''role'' = ''admin''))"),
    ("admin_all_td_assignment_subs", "td_assignment_submissions", "FOR ALL TO public USING (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>''role'' = ''admin'')) WITH CHECK (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>''role'' = ''admin''))"),
]

for pname, tname, clause in policies:
    sql(f"DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='{pname}' AND tablename='{tname}') THEN EXECUTE 'CREATE POLICY {pname} ON app.{tname} {clause}'; END IF; END $$;", f"policy {pname}")
    time.sleep(0.1)

# RPCs
print("\n--- RPCs ---")

sql("""
CREATE OR REPLACE FUNCTION public.app_td_student_list_exercises()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $fn$
DECLARE v_result JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.deadline DESC NULLS LAST, t.created_at DESC), '[]'::jsonb) INTO v_result
    FROM (
        SELECT a.id, a.title, a.description, a.subject, a.assignment_type, a.deadline, a.max_score, a.created_at,
               s.full_name AS teacher_name,
               (SELECT jsonb_build_object('id', sub.id, 'status', sub.status, 'teacher_score', sub.teacher_score, 'ai_score', sub.ai_score, 'submitted_at', sub.submitted_at)
                FROM app.td_assignment_submissions sub WHERE sub.assignment_id = a.id AND sub.student_id = auth.uid() LIMIT 1) AS my_submission
        FROM app.td_assignments a
        LEFT JOIN app.students s ON s.id = a.teacher_id
        WHERE a.is_published = true
    ) t;
    RETURN v_result;
END; $fn$;
""", "RPC app_td_student_list_exercises")

sql("""
CREATE OR REPLACE FUNCTION public.app_td_student_submit_exercise(
    p_assignment_id UUID, p_answer_content JSONB DEFAULT NULL, p_attachments JSONB DEFAULT '[]'::jsonb
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $fn$
DECLARE v_id UUID;
BEGIN
    INSERT INTO app.td_assignment_submissions (assignment_id, student_id, answer_content, attachments, status)
    VALUES (p_assignment_id, auth.uid(), p_answer_content, p_attachments, 'submitted')
    ON CONFLICT (assignment_id, student_id) DO UPDATE SET
        answer_content = COALESCE(EXCLUDED.answer_content, app.td_assignment_submissions.answer_content),
        attachments = COALESCE(EXCLUDED.attachments, app.td_assignment_submissions.attachments),
        submitted_at = now(), status = 'submitted'
    RETURNING id INTO v_id;
    RETURN jsonb_build_object('success', true, 'id', v_id);
END; $fn$;
""", "RPC app_td_student_submit_exercise")

sql("""
CREATE OR REPLACE FUNCTION public.app_td_student_get_exercise_detail(p_assignment_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $fn$
DECLARE v_result JSONB;
BEGIN
    SELECT row_to_json(t)::jsonb INTO v_result
    FROM (
        SELECT sub.*, a.title AS assignment_title, a.description AS assignment_description,
               a.content AS assignment_content, a.max_score, a.subject
        FROM app.td_assignment_submissions sub
        JOIN app.td_assignments a ON a.id = sub.assignment_id
        WHERE sub.assignment_id = p_assignment_id AND sub.student_id = auth.uid()
    ) t;
    RETURN COALESCE(v_result, '{}'::jsonb);
END; $fn$;
""", "RPC app_td_student_get_exercise_detail")

# Verification
print("\n--- VERIFICATION ---")
for t in ["td_assignments", "td_assignment_submissions"]:
    sql(f"SELECT COUNT(*) AS cnt FROM information_schema.tables WHERE table_schema='app' AND table_name='{t}'", f"Table {t}")
sql("SELECT COUNT(*) AS cnt FROM pg_policies WHERE schemaname='app' AND tablename IN ('td_assignments','td_assignment_submissions')", "RLS count")
sql("SELECT routine_name FROM information_schema.routines WHERE routine_name LIKE 'app_td_student%exercise%' ORDER BY routine_name", "New RPCs")

print("\nPhase 4 TD SQL complete!")
