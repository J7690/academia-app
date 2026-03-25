#!/usr/bin/env python3
"""Phase 5 TD: Deploy teacher exercise RPCs."""
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
print("PHASE 5 TD -- Teacher exercise RPCs")
print("=" * 60)

sql("""
CREATE OR REPLACE FUNCTION public.app_td_teacher_create_exercise(
    p_title TEXT, p_description TEXT DEFAULT NULL, p_subject TEXT DEFAULT NULL,
    p_assignment_type TEXT DEFAULT 'exercise', p_content JSONB DEFAULT NULL,
    p_deadline TIMESTAMPTZ DEFAULT NULL, p_max_score INTEGER DEFAULT 20,
    p_is_published BOOLEAN DEFAULT false, p_enrollment_id UUID DEFAULT NULL
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $fn$
DECLARE v_id UUID;
BEGIN
    INSERT INTO app.td_assignments (teacher_id, enrollment_id, title, description, subject, assignment_type, content, deadline, max_score, is_published)
    VALUES (auth.uid(), p_enrollment_id, p_title, p_description, p_subject, p_assignment_type, p_content, p_deadline, p_max_score, p_is_published)
    RETURNING id INTO v_id;
    RETURN jsonb_build_object('success', true, 'id', v_id);
END; $fn$;
""", "RPC app_td_teacher_create_exercise")

sql("""
CREATE OR REPLACE FUNCTION public.app_td_teacher_list_exercises()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $fn$
DECLARE v_result JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at DESC), '[]'::jsonb) INTO v_result
    FROM (
        SELECT a.*,
               (SELECT COUNT(*) FROM app.td_assignment_submissions s WHERE s.assignment_id = a.id) AS submission_count,
               (SELECT COUNT(*) FROM app.td_assignment_submissions s WHERE s.assignment_id = a.id AND s.status = 'graded') AS graded_count
        FROM app.td_assignments a WHERE a.teacher_id = auth.uid()
    ) t;
    RETURN v_result;
END; $fn$;
""", "RPC app_td_teacher_list_exercises")

sql("""
CREATE OR REPLACE FUNCTION public.app_td_teacher_list_exercise_submissions(p_assignment_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $fn$
DECLARE v_result JSONB;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM app.td_assignments WHERE id = p_assignment_id AND teacher_id = auth.uid()) THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_owner');
    END IF;
    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.submitted_at DESC), '[]'::jsonb) INTO v_result
    FROM (
        SELECT s.*, st.full_name AS student_name
        FROM app.td_assignment_submissions s
        LEFT JOIN app.students st ON st.id = s.student_id
        WHERE s.assignment_id = p_assignment_id
    ) t;
    RETURN jsonb_build_object('success', true, 'submissions', v_result);
END; $fn$;
""", "RPC app_td_teacher_list_exercise_submissions")

sql("""
CREATE OR REPLACE FUNCTION public.app_td_teacher_grade_exercise(
    p_submission_id UUID, p_score INTEGER, p_comment TEXT DEFAULT NULL
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $fn$
BEGIN
    UPDATE app.td_assignment_submissions SET
        teacher_score = p_score, teacher_comment = p_comment,
        teacher_graded_at = now(), status = 'graded'
    WHERE id = p_submission_id
      AND EXISTS (SELECT 1 FROM app.td_assignments a WHERE a.id = assignment_id AND a.teacher_id = auth.uid());
    RETURN jsonb_build_object('success', true);
END; $fn$;
""", "RPC app_td_teacher_grade_exercise")

# Verification
print("\n--- VERIFICATION ---")
sql("SELECT routine_name FROM information_schema.routines WHERE routine_name LIKE 'app_td_teacher%exercise%' OR routine_name LIKE 'app_td_teacher%local%' ORDER BY routine_name", "Teacher TD RPCs")
print("\nPhase 5 TD SQL complete!")
