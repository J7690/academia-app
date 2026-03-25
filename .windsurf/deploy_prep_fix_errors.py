#!/usr/bin/env python3
"""Fix and redeploy failed statements from the prep unification."""
import json, requests, time
from pathlib import Path

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SK, "Authorization": f"Bearer {SK}", "Content-Type": "application/json"}

def sql(q, label=""):
    clean = " ".join(q.split())
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                       json={"p_sql": clean}, timeout=60)
    body = r.json() if r.status_code == 200 else {"ok": False, "error": r.text[:500]}
    ok = isinstance(body, dict) and body.get("ok", False)
    err = body.get("error", "") if isinstance(body, dict) and not ok else ""
    print(f"  {'✅' if ok else '❌'} {label} {('— ' + err[:150]) if err else ''}")
    return ok

# ═══════════════════════════════════════════════════════════════
# FIX 1: Policies — use DO $$ block pattern instead of IF NOT EXISTS
# ═══════════════════════════════════════════════════════════════

# Helper to create policy safely
def create_policy(name, table, cmd, to_role, using_expr, check_expr=None):
    check_part = f"WITH CHECK ({check_expr})" if check_expr else ""
    return f"""
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = '{name}' AND tablename = '{table.split('.')[-1]}') THEN
        EXECUTE 'CREATE POLICY {name} ON {table} FOR {cmd} TO {to_role} USING ({using_expr}) {check_part}';
    END IF;
END $$;
"""

tables_new = [
    "prep_question_banks", "prep_exam_papers", "prep_flashcard_decks",
    "prep_flashcards", "prep_flashcard_progress", "prep_quiz_templates",
    "prep_quiz_attempts", "prep_badges", "prep_student_badges",
    "prep_ai_conversations", "prep_ai_messages", "prep_ai_config",
    "prep_student_progress",
]

print("=" * 60)
print("FIX 1: Creating service_role policies...")
for t in tables_new:
    pname = f"sr_all_{t}"
    s = f"""
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = '{pname}' AND tablename = '{t}') THEN
        EXECUTE 'CREATE POLICY {pname} ON app.{t} FOR ALL TO service_role USING (true) WITH CHECK (true)';
    END IF;
END $$;
"""
    sql(s, f"service_role {t}")
    time.sleep(0.2)

print("\nFIX 2: Creating authenticated read policies...")

# Authenticated policies with entitlement
auth_policies = [
    ("auth_select_prep_question_banks", "app.prep_question_banks", "SELECT", "public", "is_active = true AND app_has_feature_access(''prep_concours'')", None),
    ("auth_select_prep_exam_papers", "app.prep_exam_papers", "SELECT", "public", "is_active = true AND app_has_feature_access(''prep_concours'')", None),
    ("auth_select_prep_flashcard_decks", "app.prep_flashcard_decks", "SELECT", "public", "is_active = true AND app_has_feature_access(''prep_concours'')", None),
    ("auth_select_prep_flashcards", "app.prep_flashcards", "SELECT", "public", "is_active = true AND app_has_feature_access(''prep_concours'')", None),
    ("auth_select_prep_quiz_templates", "app.prep_quiz_templates", "SELECT", "public", "is_active = true AND app_has_feature_access(''prep_concours'')", None),
    ("auth_select_prep_badges", "app.prep_badges", "SELECT", "public", "is_active = true", None),
    ("auth_select_prep_ai_config", "app.prep_ai_config", "SELECT", "public", "auth.uid() IS NOT NULL", None),
    # Own-data policies
    ("auth_select_own_prep_fp", "app.prep_flashcard_progress", "SELECT", "public", "student_id = auth.uid() AND app_has_feature_access(''prep_concours'')", None),
    ("auth_insert_own_prep_fp", "app.prep_flashcard_progress", "INSERT", "public", "true", "student_id = auth.uid()"),
    ("auth_update_own_prep_fp", "app.prep_flashcard_progress", "UPDATE", "public", "student_id = auth.uid()", None),
    ("auth_select_own_prep_qa", "app.prep_quiz_attempts", "SELECT", "public", "student_id = auth.uid() AND app_has_feature_access(''prep_concours'')", None),
    ("auth_insert_own_prep_qa", "app.prep_quiz_attempts", "INSERT", "public", "true", "student_id = auth.uid()"),
    ("auth_select_own_prep_sb", "app.prep_student_badges", "SELECT", "public", "student_id = auth.uid()", None),
    ("auth_select_own_prep_aic", "app.prep_ai_conversations", "SELECT", "public", "student_id = auth.uid()", None),
    ("auth_insert_own_prep_aic", "app.prep_ai_conversations", "INSERT", "public", "true", "student_id = auth.uid()"),
    ("auth_select_own_prep_sp", "app.prep_student_progress", "SELECT", "public", "student_id = auth.uid()", None),
    ("auth_upsert_own_prep_sp", "app.prep_student_progress", "INSERT", "public", "true", "student_id = auth.uid()"),
    ("auth_update_own_prep_sp", "app.prep_student_progress", "UPDATE", "public", "student_id = auth.uid()", None),
]

for pname, table, cmd, role, using_e, check_e in auth_policies:
    tname = table.split(".")[-1]
    if check_e:
        s = f"""
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = '{pname}' AND tablename = '{tname}') THEN
        EXECUTE 'CREATE POLICY {pname} ON {table} FOR {cmd} TO {role} USING ({using_e}) WITH CHECK ({check_e})';
    END IF;
END $$;
"""
    else:
        s = f"""
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = '{pname}' AND tablename = '{tname}') THEN
        EXECUTE 'CREATE POLICY {pname} ON {table} FOR {cmd} TO {role} USING ({using_e})';
    END IF;
END $$;
"""
    sql(s, f"policy {pname}")
    time.sleep(0.2)

# AI messages policy (complex subquery)
sql("""
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'auth_select_own_prep_aim' AND tablename = 'prep_ai_messages') THEN
        EXECUTE 'CREATE POLICY auth_select_own_prep_aim ON app.prep_ai_messages FOR SELECT TO public USING (EXISTS (SELECT 1 FROM app.prep_ai_conversations c WHERE c.id = conversation_id AND c.student_id = auth.uid()))';
    END IF;
END $$;
""", "policy auth_select_own_prep_aim")

print("\nFIX 3: Admin ALL policies...")
admin_tables = ["prep_question_banks", "prep_exam_papers", "prep_badges", "prep_ai_config"]
for t in admin_tables:
    pname = f"admin_all_{t}"
    s = f"""
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = '{pname}' AND tablename = '{t}') THEN
        EXECUTE 'CREATE POLICY {pname} ON app.{t} FOR ALL TO public USING (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>''role'' = ''admin'')) WITH CHECK (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>''role'' = ''admin''))';
    END IF;
END $$;
"""
    sql(s, f"admin {t}")
    time.sleep(0.2)

# ═══════════════════════════════════════════════════════════════
# FIX 2: Broken functions — fix syntax issues
# ═══════════════════════════════════════════════════════════════

print("\nFIX 4: Fixing broken functions...")

# D3: app_prep_create_question — fix the $$ parsing issue
sql("""
DROP FUNCTION IF EXISTS app.app_prep_create_question(UUID, TEXT, JSONB, INTEGER, TEXT, INTEGER, TEXT, TEXT, INTEGER, INTEGER);
""", "drop old app_prep_create_question")

sql("""
CREATE OR REPLACE FUNCTION app.app_prep_create_question(
    p_bank_id UUID,
    p_content TEXT,
    p_options JSONB,
    p_correct_index INTEGER,
    p_explanation TEXT DEFAULT NULL,
    p_difficulty INTEGER DEFAULT 1,
    p_subject TEXT DEFAULT NULL,
    p_image_url TEXT DEFAULT NULL,
    p_points INTEGER DEFAULT 10,
    p_time_limit_seconds INTEGER DEFAULT 60
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $fn$
DECLARE
    v_id UUID;
    v_i INTEGER;
    v_text TEXT;
    v_label TEXT;
BEGIN
    INSERT INTO app.prep_questions (
        bank_id, question, content, options, correct_index, explanation,
        difficulty, subject, image_url, points, time_limit_seconds,
        question_type, level, source, is_published, is_active, created_by
    ) VALUES (
        p_bank_id, p_content, p_content, p_options, p_correct_index, p_explanation,
        p_difficulty, p_subject, p_image_url, p_points, p_time_limit_seconds,
        'mcq', 'beginner', 'manual', true, true, auth.uid()
    )
    RETURNING id INTO v_id;

    IF p_options IS NOT NULL AND jsonb_typeof(p_options) = 'array' THEN
        FOR v_i IN 0 .. jsonb_array_length(p_options) - 1 LOOP
            v_text := p_options ->> v_i;
            v_label := chr(65 + v_i);
            INSERT INTO app.prep_question_choices (question_id, choice_label, choice_text, is_correct, sort_order)
            VALUES (v_id, v_label, v_text, v_i = p_correct_index, v_i);
        END LOOP;
    END IF;

    RETURN jsonb_build_object('success', true, 'id', v_id);
END;
$fn$;
""", "FUNCTION app.app_prep_create_question")

# D9: app_prep_create_flashcard
sql("""
DROP FUNCTION IF EXISTS app.app_prep_create_flashcard(UUID, TEXT, TEXT, TEXT, TEXT[]);
""", "drop old app_prep_create_flashcard")

sql("""
CREATE OR REPLACE FUNCTION app.app_prep_create_flashcard(
    p_deck_id UUID,
    p_front_text TEXT,
    p_back_text TEXT,
    p_subject TEXT DEFAULT NULL,
    p_tags TEXT[] DEFAULT '{}'
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $fn$
DECLARE
    v_id UUID;
BEGIN
    INSERT INTO app.prep_flashcards (deck_id, front_text, back_text, subject, tags, created_by)
    VALUES (p_deck_id, p_front_text, p_back_text, p_subject, p_tags, auth.uid())
    RETURNING id INTO v_id;

    UPDATE app.prep_flashcard_decks SET card_count = (
        SELECT COUNT(*) FROM app.prep_flashcards WHERE deck_id = p_deck_id AND is_active
    ) WHERE id = p_deck_id;

    RETURN jsonb_build_object('success', true, 'id', v_id);
END;
$fn$;
""", "FUNCTION app.app_prep_create_flashcard")

# D15: app_prep_admin_toggle_question — drop old and recreate
sql("""
DROP FUNCTION IF EXISTS app.app_prep_admin_toggle_question(UUID, BOOLEAN);
""", "drop old app_prep_admin_toggle_question")

sql("""
CREATE FUNCTION app.app_prep_admin_toggle_question(
    p_question_id UUID,
    p_is_active BOOLEAN
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $fn$
BEGIN
    UPDATE app.prep_questions SET is_active = p_is_active, is_published = p_is_active, updated_at = now()
    WHERE id = p_question_id;
    RETURN jsonb_build_object('success', true);
END;
$fn$;
""", "FUNCTION app.app_prep_admin_toggle_question")

# D20: app_prep_save_ai_message
sql("""
DROP FUNCTION IF EXISTS app.app_prep_save_ai_message(UUID, TEXT, TEXT, INTEGER);
""", "drop old app_prep_save_ai_message")

sql("""
CREATE FUNCTION app.app_prep_save_ai_message(
    p_conversation_id UUID,
    p_role TEXT,
    p_content TEXT,
    p_tokens_used INTEGER DEFAULT 0
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $fn$
DECLARE
    v_id UUID;
BEGIN
    INSERT INTO app.prep_ai_messages (conversation_id, role, content, tokens_used)
    VALUES (p_conversation_id, p_role, p_content, p_tokens_used)
    RETURNING id INTO v_id;

    UPDATE app.prep_ai_conversations SET
        message_count = message_count + 1,
        total_tokens_used = total_tokens_used + p_tokens_used,
        updated_at = now()
    WHERE id = p_conversation_id;

    RETURN jsonb_build_object('success', true, 'id', v_id);
END;
$fn$;
""", "FUNCTION app.app_prep_save_ai_message")

# D24: app_prep_get_student_progress
sql("""
DROP FUNCTION IF EXISTS app.app_prep_get_student_progress();
""", "drop old app_prep_get_student_progress")

sql("""
CREATE FUNCTION app.app_prep_get_student_progress()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app'
AS $fn$
DECLARE
    v_result JSONB;
BEGIN
    SELECT row_to_json(t)::jsonb INTO v_result
    FROM (
        SELECT
            COALESCE(p.total_xp, 0) AS total_xp,
            COALESCE(p.current_streak, 0) AS current_streak,
            COALESCE(p.longest_streak, 0) AS longest_streak,
            COALESCE(p.total_correct, 0) AS total_correct,
            COALESCE(p.total_answered, 0) AS total_answered,
            p.last_activity_date,
            (SELECT COUNT(*) FROM app.prep_quiz_attempts qa WHERE qa.student_id = auth.uid()) AS quiz_count,
            (SELECT COUNT(*) FROM app.prep_student_badges sb WHERE sb.student_id = auth.uid()) AS badge_count
        FROM app.prep_student_progress p
        WHERE p.student_id = auth.uid()
    ) t;

    IF v_result IS NULL THEN
        v_result := jsonb_build_object(
            'total_xp', 0, 'current_streak', 0, 'longest_streak', 0,
            'total_correct', 0, 'total_answered', 0,
            'last_activity_date', NULL,
            'quiz_count', 0, 'badge_count', 0
        );
    END IF;

    RETURN v_result;
END;
$fn$;
""", "FUNCTION app.app_prep_get_student_progress")

# ═══════════════════════════════════════════════════════════════
# FIX 3: Storage policies
# ═══════════════════════════════════════════════════════════════

print("\nFIX 5: Storage policies...")

sql("""
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'prep_docs_select' AND tablename = 'objects') THEN
        EXECUTE 'CREATE POLICY prep_docs_select ON storage.objects FOR SELECT TO public USING (bucket_id = ''prep-documents'')';
    END IF;
END $$;
""", "storage SELECT policy")

sql("""
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'prep_docs_insert' AND tablename = 'objects') THEN
        EXECUTE 'CREATE POLICY prep_docs_insert ON storage.objects FOR INSERT TO public WITH CHECK (bucket_id = ''prep-documents'' AND auth.uid() IS NOT NULL)';
    END IF;
END $$;
""", "storage INSERT policy")

sql("""
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'prep_docs_delete' AND tablename = 'objects') THEN
        EXECUTE 'CREATE POLICY prep_docs_delete ON storage.objects FOR DELETE TO public USING (bucket_id = ''prep-documents'' AND EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>''role'' = ''admin''))';
    END IF;
END $$;
""", "storage DELETE policy")

print("\n✅ Fix deployment complete!")
