#!/usr/bin/env python3
"""Phase 7: Deploy prep_assignments + prep_assignment_submissions tables, RPCs, RLS, Edge Function."""
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
    print(f"  {'✅' if ok else '❌'} {label} {('— ' + err[:200]) if err else ''}")
    return ok

print("=" * 60)
print("PHASE 7 — Exercices asynchrones enseignant→étudiant")
print("=" * 60)

# ═══════════════════════════════════════════════════════════════
# PART A: Create tables
# ═══════════════════════════════════════════════════════════════
print("\n--- A: Tables ---")

sql("""
    CREATE TABLE IF NOT EXISTS app.prep_assignments (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        teacher_id UUID NOT NULL REFERENCES auth.users(id),
        title TEXT NOT NULL,
        description TEXT,
        concours_type TEXT,
        subject_name TEXT,
        assignment_type TEXT NOT NULL DEFAULT 'qcm',
        content JSONB,
        attachments JSONB DEFAULT '[]'::jsonb,
        deadline TIMESTAMPTZ,
        max_score INTEGER DEFAULT 20,
        is_published BOOLEAN NOT NULL DEFAULT false,
        target_group TEXT DEFAULT 'all',
        created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
""", "CREATE prep_assignments")

sql("""
    CREATE TABLE IF NOT EXISTS app.prep_assignment_submissions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        assignment_id UUID NOT NULL REFERENCES app.prep_assignments(id) ON DELETE CASCADE,
        student_id UUID NOT NULL REFERENCES auth.users(id),
        answer_content JSONB,
        attachments JSONB DEFAULT '[]'::jsonb,
        submitted_at TIMESTAMPTZ DEFAULT now(),
        status TEXT NOT NULL DEFAULT 'submitted',
        teacher_score INTEGER,
        teacher_comment TEXT,
        teacher_graded_at TIMESTAMPTZ,
        ai_score INTEGER,
        ai_correction TEXT,
        ai_explanation TEXT,
        ai_source_chunks UUID[],
        created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        UNIQUE (assignment_id, student_id)
    )
""", "CREATE prep_assignment_submissions")

# ═══════════════════════════════════════════════════════════════
# PART B: RLS
# ═══════════════════════════════════════════════════════════════
print("\n--- B: RLS ---")

for t in ["prep_assignments", "prep_assignment_submissions"]:
    sql(f"ALTER TABLE app.{t} ENABLE ROW LEVEL SECURITY", f"ENABLE RLS {t}")
    time.sleep(0.1)

# service_role ALL
for t in ["prep_assignments", "prep_assignment_submissions"]:
    sql(f"""
        DO $$ BEGIN
            IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='sr_all_{t}' AND tablename='{t}') THEN
                EXECUTE 'CREATE POLICY sr_all_{t} ON app.{t} FOR ALL TO service_role USING (true) WITH CHECK (true)';
            END IF;
        END $$;
    """, f"service_role {t}")
    time.sleep(0.1)

# Teacher: CRUD own assignments
sql("""
    DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='teacher_all_own_assignments' AND tablename='prep_assignments') THEN
            EXECUTE 'CREATE POLICY teacher_all_own_assignments ON app.prep_assignments FOR ALL TO public USING (teacher_id = auth.uid()) WITH CHECK (teacher_id = auth.uid())';
        END IF;
    END $$;
""", "teacher ALL own prep_assignments")

# Student: SELECT published assignments
sql("""
    DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='student_select_published_assignments' AND tablename='prep_assignments') THEN
            EXECUTE 'CREATE POLICY student_select_published_assignments ON app.prep_assignments FOR SELECT TO public USING (is_published = true AND app_has_feature_access(''prep_concours''))';
        END IF;
    END $$;
""", "student SELECT published prep_assignments")

# Student: own submissions
sql("""
    DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='student_own_submissions' AND tablename='prep_assignment_submissions') THEN
            EXECUTE 'CREATE POLICY student_own_submissions ON app.prep_assignment_submissions FOR SELECT TO public USING (student_id = auth.uid())';
        END IF;
    END $$;
""", "student SELECT own submissions")

sql("""
    DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='student_insert_submission' AND tablename='prep_assignment_submissions') THEN
            EXECUTE 'CREATE POLICY student_insert_submission ON app.prep_assignment_submissions FOR INSERT TO public WITH CHECK (student_id = auth.uid())';
        END IF;
    END $$;
""", "student INSERT own submission")

# Teacher: see all submissions for their assignments
sql("""
    DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='teacher_see_submissions' AND tablename='prep_assignment_submissions') THEN
            EXECUTE 'CREATE POLICY teacher_see_submissions ON app.prep_assignment_submissions FOR ALL TO public USING (EXISTS (SELECT 1 FROM app.prep_assignments a WHERE a.id = assignment_id AND a.teacher_id = auth.uid())) WITH CHECK (EXISTS (SELECT 1 FROM app.prep_assignments a WHERE a.id = assignment_id AND a.teacher_id = auth.uid()))';
        END IF;
    END $$;
""", "teacher ALL submissions for own assignments")

# Admin ALL
for t in ["prep_assignments", "prep_assignment_submissions"]:
    pname = f"admin_all_{t}"
    sql(f"""
        DO $$ BEGIN
            IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='{pname}' AND tablename='{t}') THEN
                EXECUTE 'CREATE POLICY {pname} ON app.{t} FOR ALL TO public USING (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>''role'' = ''admin'')) WITH CHECK (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>''role'' = ''admin''))';
            END IF;
        END $$;
    """, f"admin ALL {t}")
    time.sleep(0.1)

# ═══════════════════════════════════════════════════════════════
# PART C: RPCs
# ═══════════════════════════════════════════════════════════════
print("\n--- C: RPCs ---")

# C1: Teacher create/update assignment
sql("""
    CREATE OR REPLACE FUNCTION app.app_prep_teacher_upsert_assignment(
        p_assignment_id UUID DEFAULT NULL,
        p_title TEXT DEFAULT NULL,
        p_description TEXT DEFAULT NULL,
        p_concours_type TEXT DEFAULT NULL,
        p_subject_name TEXT DEFAULT NULL,
        p_assignment_type TEXT DEFAULT 'qcm',
        p_content JSONB DEFAULT NULL,
        p_attachments JSONB DEFAULT '[]'::jsonb,
        p_deadline TIMESTAMPTZ DEFAULT NULL,
        p_max_score INTEGER DEFAULT 20,
        p_is_published BOOLEAN DEFAULT false,
        p_target_group TEXT DEFAULT 'all'
    ) RETURNS JSONB
    LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
    AS $fn$
    DECLARE v_id UUID;
    BEGIN
        IF p_assignment_id IS NOT NULL THEN
            UPDATE app.prep_assignments SET
                title = COALESCE(p_title, title),
                description = COALESCE(p_description, description),
                concours_type = COALESCE(p_concours_type, concours_type),
                subject_name = COALESCE(p_subject_name, subject_name),
                assignment_type = COALESCE(p_assignment_type, assignment_type),
                content = COALESCE(p_content, content),
                attachments = COALESCE(p_attachments, attachments),
                deadline = COALESCE(p_deadline, deadline),
                max_score = COALESCE(p_max_score, max_score),
                is_published = COALESCE(p_is_published, is_published),
                target_group = COALESCE(p_target_group, target_group),
                updated_at = now()
            WHERE id = p_assignment_id AND teacher_id = auth.uid()
            RETURNING id INTO v_id;
        ELSE
            INSERT INTO app.prep_assignments (teacher_id, title, description, concours_type, subject_name, assignment_type, content, attachments, deadline, max_score, is_published, target_group)
            VALUES (auth.uid(), p_title, p_description, p_concours_type, p_subject_name, p_assignment_type, p_content, p_attachments, p_deadline, p_max_score, p_is_published, p_target_group)
            RETURNING id INTO v_id;
        END IF;
        RETURN jsonb_build_object('success', true, 'id', v_id);
    END;
    $fn$;
""", "FUNCTION app_prep_teacher_upsert_assignment")

# C2: Teacher list own assignments
sql("""
    CREATE OR REPLACE FUNCTION app.app_prep_teacher_list_assignments()
    RETURNS JSONB
    LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
    AS $fn$
    DECLARE v_result JSONB;
    BEGIN
        SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at DESC), '[]'::jsonb)
        INTO v_result
        FROM (
            SELECT a.*,
                   (SELECT COUNT(*) FROM app.prep_assignment_submissions s WHERE s.assignment_id = a.id) AS submission_count,
                   (SELECT COUNT(*) FROM app.prep_assignment_submissions s WHERE s.assignment_id = a.id AND s.status = 'graded') AS graded_count
            FROM app.prep_assignments a
            WHERE a.teacher_id = auth.uid()
        ) t;
        RETURN v_result;
    END;
    $fn$;
""", "FUNCTION app_prep_teacher_list_assignments")

# C3: Teacher list submissions for an assignment
sql("""
    CREATE OR REPLACE FUNCTION app.app_prep_teacher_list_submissions(
        p_assignment_id UUID
    ) RETURNS JSONB
    LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
    AS $fn$
    DECLARE v_result JSONB;
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM app.prep_assignments WHERE id = p_assignment_id AND teacher_id = auth.uid()) THEN
            RETURN jsonb_build_object('success', false, 'error', 'not_owner');
        END IF;
        SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.submitted_at DESC), '[]'::jsonb)
        INTO v_result
        FROM (
            SELECT s.*, st.full_name AS student_name
            FROM app.prep_assignment_submissions s
            LEFT JOIN app.students st ON st.id = s.student_id
            WHERE s.assignment_id = p_assignment_id
        ) t;
        RETURN jsonb_build_object('success', true, 'submissions', v_result);
    END;
    $fn$;
""", "FUNCTION app_prep_teacher_list_submissions")

# C4: Teacher grade a submission
sql("""
    CREATE OR REPLACE FUNCTION app.app_prep_teacher_grade_submission(
        p_submission_id UUID,
        p_score INTEGER,
        p_comment TEXT DEFAULT NULL
    ) RETURNS JSONB
    LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
    AS $fn$
    BEGIN
        UPDATE app.prep_assignment_submissions SET
            teacher_score = p_score,
            teacher_comment = p_comment,
            teacher_graded_at = now(),
            status = 'graded'
        WHERE id = p_submission_id
          AND EXISTS (SELECT 1 FROM app.prep_assignments a WHERE a.id = assignment_id AND a.teacher_id = auth.uid());
        RETURN jsonb_build_object('success', true);
    END;
    $fn$;
""", "FUNCTION app_prep_teacher_grade_submission")

# C5: Student list available assignments
sql("""
    CREATE OR REPLACE FUNCTION public.app_prep_student_list_assignments()
    RETURNS JSONB
    LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
    AS $fn$
    DECLARE v_result JSONB;
    BEGIN
        SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.deadline DESC NULLS LAST, t.created_at DESC), '[]'::jsonb)
        INTO v_result
        FROM (
            SELECT a.id, a.title, a.description, a.concours_type, a.subject_name,
                   a.assignment_type, a.deadline, a.max_score, a.created_at,
                   (SELECT jsonb_build_object('id', s.id, 'status', s.status, 'teacher_score', s.teacher_score, 'submitted_at', s.submitted_at)
                    FROM app.prep_assignment_submissions s WHERE s.assignment_id = a.id AND s.student_id = auth.uid()
                    LIMIT 1) AS my_submission
            FROM app.prep_assignments a
            WHERE a.is_published = true
        ) t;
        RETURN v_result;
    END;
    $fn$;
""", "FUNCTION app_prep_student_list_assignments")

# C6: Student submit answer
sql("""
    CREATE OR REPLACE FUNCTION public.app_prep_student_submit_assignment(
        p_assignment_id UUID,
        p_answer_content JSONB DEFAULT NULL,
        p_attachments JSONB DEFAULT '[]'::jsonb
    ) RETURNS JSONB
    LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
    AS $fn$
    DECLARE v_id UUID;
    BEGIN
        INSERT INTO app.prep_assignment_submissions (assignment_id, student_id, answer_content, attachments, status)
        VALUES (p_assignment_id, auth.uid(), p_answer_content, p_attachments, 'submitted')
        ON CONFLICT (assignment_id, student_id) DO UPDATE SET
            answer_content = COALESCE(EXCLUDED.answer_content, app.prep_assignment_submissions.answer_content),
            attachments = COALESCE(EXCLUDED.attachments, app.prep_assignment_submissions.attachments),
            submitted_at = now(),
            status = 'submitted'
        RETURNING id INTO v_id;
        RETURN jsonb_build_object('success', true, 'id', v_id);
    END;
    $fn$;
""", "FUNCTION app_prep_student_submit_assignment")

# C7: Student get own submission detail
sql("""
    CREATE OR REPLACE FUNCTION public.app_prep_student_get_submission(
        p_assignment_id UUID
    ) RETURNS JSONB
    LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
    AS $fn$
    DECLARE v_result JSONB;
    BEGIN
        SELECT row_to_json(t)::jsonb INTO v_result
        FROM (
            SELECT s.*, a.title AS assignment_title, a.description AS assignment_description,
                   a.content AS assignment_content, a.max_score
            FROM app.prep_assignment_submissions s
            JOIN app.prep_assignments a ON a.id = s.assignment_id
            WHERE s.assignment_id = p_assignment_id AND s.student_id = auth.uid()
        ) t;
        RETURN COALESCE(v_result, jsonb_build_object('success', false, 'error', 'not_found'));
    END;
    $fn$;
""", "FUNCTION app_prep_student_get_submission")

# ═══════════════════════════════════════════════════════════════
# VERIFICATION
# ═══════════════════════════════════════════════════════════════
print("\n--- VERIFICATION ---")
for t in ["prep_assignments", "prep_assignment_submissions"]:
    sql(f"SELECT COUNT(*) AS cnt FROM information_schema.tables WHERE table_schema='app' AND table_name='{t}'", f"Table {t}")

sql("SELECT COUNT(*) AS cnt FROM pg_policies WHERE schemaname='app' AND tablename IN ('prep_assignments','prep_assignment_submissions')", "RLS count")

sql("SELECT routine_name FROM information_schema.routines WHERE routine_name LIKE '%prep_%assignment%' OR routine_name LIKE '%prep_%submission%' ORDER BY routine_name", "Assignment RPCs")

print("\n✅ Phase 7 deployment complete!")
