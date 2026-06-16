#!/usr/bin/env python3
"""Create RPCs for student to read td_questions as quiz."""
import requests

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SK, "Authorization": f"Bearer {SK}", "Content-Type": "application/json"}

def sql_raw(q, label=""):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q}, timeout=60)
    body = r.json() if r.status_code == 200 else {"ok": False, "error": r.text[:500]}
    ok = isinstance(body, dict) and body.get("ok", False)
    err = body.get("error", "") if not ok else ""
    print(f"  {'OK' if ok else 'ERR'} {label} {('-- ' + err[:200]) if err else ''}")
    return ok

print("=== TD Quiz RPCs ===")

sql_raw("""CREATE OR REPLACE FUNCTION public.app_td_student_get_quiz_questions(
  p_subject TEXT DEFAULT NULL, p_count INTEGER DEFAULT 10, p_difficulty INTEGER DEFAULT NULL
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $$
DECLARE v_result JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb) INTO v_result
  FROM (
    SELECT id, content, options, correct_index, explanation, difficulty, subject, question_type
    FROM app.td_questions
    WHERE is_active = true
      AND (p_subject IS NULL OR subject ILIKE '%' || p_subject || '%')
      AND (p_difficulty IS NULL OR difficulty <= p_difficulty)
    ORDER BY random()
    LIMIT p_count
  ) t;
  RETURN jsonb_build_object('success', true, 'questions', v_result);
END; $$;""", "RPC app_td_student_get_quiz_questions")

sql_raw("""CREATE OR REPLACE FUNCTION public.app_td_student_list_subjects()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $$
DECLARE v_result JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.cnt DESC), '[]'::jsonb) INTO v_result
  FROM (
    SELECT subject, COUNT(*) AS cnt
    FROM app.td_questions WHERE is_active = true
    GROUP BY subject ORDER BY cnt DESC
  ) t;
  RETURN jsonb_build_object('success', true, 'subjects', v_result);
END; $$;""", "RPC app_td_student_list_subjects")

print("\n--- VERIFY ---")
sql_raw("SELECT routine_name FROM information_schema.routines WHERE routine_name IN ('app_td_student_get_quiz_questions','app_td_student_list_subjects') ORDER BY routine_name", "RPCs exist")
