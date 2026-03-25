#!/usr/bin/env python3
"""Phase A: Deploy psychotech tables + RPCs + RLS."""
import json, requests, time

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
print("PHASE A -- Psychotech Tables + RPCs")
print("=" * 60)

# Tables
print("\n--- Tables ---")
sql("CREATE TABLE IF NOT EXISTS app.prep_psychotech_results (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), student_id UUID NOT NULL REFERENCES auth.users(id), test_type TEXT NOT NULL, difficulty INTEGER NOT NULL DEFAULT 1, is_correct BOOLEAN NOT NULL, time_spent_ms INTEGER, question_data JSONB, student_answer JSONB, correct_answer JSONB, explanation TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT now())", "CREATE prep_psychotech_results")

sql("CREATE TABLE IF NOT EXISTS app.prep_psychotech_profiles (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), student_id UUID NOT NULL REFERENCES auth.users(id) UNIQUE, scores_by_type JSONB DEFAULT '{}'::jsonb, total_tests INTEGER DEFAULT 0, total_correct INTEGER DEFAULT 0, avg_time_ms INTEGER, weak_areas TEXT[] DEFAULT '{}', strong_areas TEXT[] DEFAULT '{}', current_difficulty INTEGER DEFAULT 1, predicted_score INTEGER, updated_at TIMESTAMPTZ NOT NULL DEFAULT now())", "CREATE prep_psychotech_profiles")

# RLS
print("\n--- RLS ---")
for t in ["prep_psychotech_results", "prep_psychotech_profiles"]:
    sql(f"ALTER TABLE app.{t} ENABLE ROW LEVEL SECURITY", f"ENABLE RLS {t}")
    time.sleep(0.1)

policies = [
    ("sr_all_prep_psychotech_results", "prep_psychotech_results", "FOR ALL TO service_role USING (true) WITH CHECK (true)"),
    ("sr_all_prep_psychotech_profiles", "prep_psychotech_profiles", "FOR ALL TO service_role USING (true) WITH CHECK (true)"),
    ("student_own_psychotech_results", "prep_psychotech_results", "FOR SELECT TO public USING (student_id = auth.uid())"),
    ("student_insert_psychotech_results", "prep_psychotech_results", "FOR INSERT TO public WITH CHECK (student_id = auth.uid())"),
    ("student_own_psychotech_profile", "prep_psychotech_profiles", "FOR SELECT TO public USING (student_id = auth.uid())"),
    ("student_upsert_psychotech_profile", "prep_psychotech_profiles", "FOR INSERT TO public WITH CHECK (student_id = auth.uid())"),
    ("student_update_psychotech_profile", "prep_psychotech_profiles", "FOR UPDATE TO public USING (student_id = auth.uid())"),
    ("admin_all_psychotech_results", "prep_psychotech_results", "FOR ALL TO public USING (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>''role'' = ''admin'')) WITH CHECK (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>''role'' = ''admin''))"),
    ("admin_all_psychotech_profiles", "prep_psychotech_profiles", "FOR ALL TO public USING (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>''role'' = ''admin'')) WITH CHECK (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>''role'' = ''admin''))"),
]

for pname, tname, clause in policies:
    sql(f"DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='{pname}' AND tablename='{tname}') THEN EXECUTE 'CREATE POLICY {pname} ON app.{tname} {clause}'; END IF; END $$;", f"policy {pname}")
    time.sleep(0.1)

# RPCs
print("\n--- RPCs ---")

sql("""
CREATE OR REPLACE FUNCTION public.app_prep_save_psychotech_result(
    p_test_type TEXT, p_difficulty INTEGER, p_is_correct BOOLEAN,
    p_time_spent_ms INTEGER DEFAULT NULL, p_question_data JSONB DEFAULT NULL,
    p_student_answer JSONB DEFAULT NULL, p_correct_answer JSONB DEFAULT NULL,
    p_explanation TEXT DEFAULT NULL
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $fn$
DECLARE v_id UUID;
BEGIN
    INSERT INTO app.prep_psychotech_results (student_id, test_type, difficulty, is_correct, time_spent_ms, question_data, student_answer, correct_answer, explanation)
    VALUES (auth.uid(), p_test_type, p_difficulty, p_is_correct, p_time_spent_ms, p_question_data, p_student_answer, p_correct_answer, p_explanation)
    RETURNING id INTO v_id;
    RETURN jsonb_build_object('success', true, 'id', v_id);
END; $fn$;
""", "RPC app_prep_save_psychotech_result")

sql("""
CREATE OR REPLACE FUNCTION public.app_prep_get_psychotech_profile()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $fn$
DECLARE v_result JSONB;
BEGIN
    SELECT row_to_json(t)::jsonb INTO v_result
    FROM (SELECT * FROM app.prep_psychotech_profiles WHERE student_id = auth.uid()) t;
    IF v_result IS NULL THEN
        v_result := jsonb_build_object('scores_by_type', '{}'::jsonb, 'total_tests', 0, 'total_correct', 0, 'weak_areas', '[]'::jsonb, 'strong_areas', '[]'::jsonb, 'current_difficulty', 1, 'predicted_score', 0);
    END IF;
    RETURN v_result;
END; $fn$;
""", "RPC app_prep_get_psychotech_profile")

sql("""
CREATE OR REPLACE FUNCTION public.app_prep_update_psychotech_profile(
    p_scores_by_type JSONB, p_total_tests INTEGER, p_total_correct INTEGER,
    p_avg_time_ms INTEGER DEFAULT NULL, p_weak_areas TEXT[] DEFAULT '{}',
    p_strong_areas TEXT[] DEFAULT '{}', p_current_difficulty INTEGER DEFAULT 1,
    p_predicted_score INTEGER DEFAULT NULL
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $fn$
BEGIN
    INSERT INTO app.prep_psychotech_profiles (student_id, scores_by_type, total_tests, total_correct, avg_time_ms, weak_areas, strong_areas, current_difficulty, predicted_score)
    VALUES (auth.uid(), p_scores_by_type, p_total_tests, p_total_correct, p_avg_time_ms, p_weak_areas, p_strong_areas, p_current_difficulty, p_predicted_score)
    ON CONFLICT (student_id) DO UPDATE SET
        scores_by_type = EXCLUDED.scores_by_type,
        total_tests = EXCLUDED.total_tests,
        total_correct = EXCLUDED.total_correct,
        avg_time_ms = EXCLUDED.avg_time_ms,
        weak_areas = EXCLUDED.weak_areas,
        strong_areas = EXCLUDED.strong_areas,
        current_difficulty = EXCLUDED.current_difficulty,
        predicted_score = EXCLUDED.predicted_score,
        updated_at = now();
    RETURN jsonb_build_object('success', true);
END; $fn$;
""", "RPC app_prep_update_psychotech_profile")

sql("""
CREATE OR REPLACE FUNCTION public.app_prep_get_psychotech_stats()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $fn$
DECLARE v_result JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb) INTO v_result
    FROM (
        SELECT test_type, COUNT(*) AS total, SUM(CASE WHEN is_correct THEN 1 ELSE 0 END) AS correct,
               ROUND(AVG(time_spent_ms)) AS avg_time,
               ROUND((SUM(CASE WHEN is_correct THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*),0)) * 100, 1) AS accuracy
        FROM app.prep_psychotech_results WHERE student_id = auth.uid()
        GROUP BY test_type ORDER BY total DESC
    ) t;
    RETURN jsonb_build_object('success', true, 'stats', v_result);
END; $fn$;
""", "RPC app_prep_get_psychotech_stats")

# Verification
print("\n--- VERIFICATION ---")
for t in ["prep_psychotech_results", "prep_psychotech_profiles"]:
    sql(f"SELECT COUNT(*) AS cnt FROM information_schema.tables WHERE table_schema='app' AND table_name='{t}'", f"Table {t}")

sql("SELECT COUNT(*) AS cnt FROM pg_policies WHERE schemaname='app' AND tablename IN ('prep_psychotech_results','prep_psychotech_profiles')", "RLS count")
sql("SELECT routine_name FROM information_schema.routines WHERE routine_name LIKE '%psychotech%' ORDER BY routine_name", "Psychotech RPCs")
sql("SELECT COUNT(*) AS cnt FROM information_schema.tables WHERE table_schema='app' AND table_name LIKE 'prep_%'", "Total prep_* tables")

print("\nPhase A Supabase complete!")
