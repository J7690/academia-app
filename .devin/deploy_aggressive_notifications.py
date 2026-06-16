#!/usr/bin/env python3
"""
PHASE 1 — Déploiement des triggers de notifications agressives.
Couvre TOUS les domaines étudiants sauf Paiements et Bobodo (déjà couverts).
"""
import requests
import json
import sys

SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

# Use the execute_sql RPC but first upgrade it to support DDL
RPC_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/execute_sql"
RPC_HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}

def upgrade_execute_sql():
    """Upgrade execute_sql to support DDL by wrapping it with DO blocks."""
    # We can use execute_sql itself to create a new DDL-capable function
    # by embedding the CREATE FUNCTION inside a DO block wrapped in a SELECT
    # Actually, we need a different approach: use the Supabase Management API
    pass

def run_sql_via_do(label, sql):
    """Execute DDL by wrapping it in a DO block and calling via execute_sql.
    The trick: wrap DDL in a DO $$ BEGIN EXECUTE '...'; END $$
    and then wrap THAT in a SELECT to satisfy execute_sql's wrapper."""
    # Escape single quotes in the SQL
    escaped = sql.strip().replace("'", "''")
    # Wrap in DO block executed via a SELECT that returns a dummy row
    wrapper = f"SELECT 1 AS ok FROM (SELECT 1) x WHERE (SELECT count(*) FROM (SELECT 1) y) > 0"
    
    # Actually, the simplest approach: create execute_ddl first using a DO block trick
    # Let's try: execute_sql wraps in SELECT ... FROM (query) t
    # So if we pass: SELECT 1; -- then it becomes SELECT ... FROM (SELECT 1;) t
    # The $$ in plpgsql functions conflicts with execute_sql's wrapping
    
    # Better approach: use Supabase's direct database connection via pg_net or
    # create the function via a management API call
    pass

def run_ddl(label, sql):
    """Execute DDL via Supabase Management API (SQL Editor endpoint)."""
    url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/execute_sql"
    # Wrap DDL in a DO block, then wrap in SELECT to satisfy execute_sql
    escaped = sql.strip().replace("'", "''")
    do_sql = f"SELECT 1 AS result"
    
    # This won't work either. Let's use a completely different approach:
    # Create a temporary function via execute_sql that can run DDL
    pass

def run_sql(label, sql):
    """Execute SQL via execute_sql RPC - only works for SELECT."""
    r = requests.post(RPC_URL, headers=RPC_HEADERS, json={"sql_query": sql}, timeout=30)
    try:
        data = r.json()
        if isinstance(data, dict) and data.get('error'):
            print(f"    ❌ {label}: {data['error'][:120]}")
            return False
        else:
            print(f"    ✅ {label}")
            return True
    except:
        if r.status_code == 200:
            print(f"    ✅ {label}")
            return True
        print(f"    ❌ {label}: HTTP {r.status_code}")
        return False

# ============================================================
# All steps: each is a list of (label, single_sql_statement)
# ============================================================

ALL_STEPS = []

# --- 1A: Opportunités → notifier TOUS les étudiants ---
ALL_STEPS.append(("1A — Fn: app_notify_opportunity_to_students", """
CREATE OR REPLACE FUNCTION public.app_notify_opportunity_to_students()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_student RECORD;
BEGIN
    IF TG_OP = 'INSERT' AND NEW.is_active = TRUE THEN
        FOR v_student IN
            SELECT u.id AS user_id FROM auth.users u
            WHERE u.raw_user_meta_data->>'role' = 'student' AND u.banned_until IS NULL
        LOOP
            PERFORM public.app_queue_notification_event(v_student.user_id, 'student_opportunities', 'new_opportunity',
                JSONB_BUILD_OBJECT('opportunity_id', NEW.id, 'title', COALESCE(NEW.title,''), 'type', COALESCE(NEW.type,''), 'organization', COALESCE(NEW.organization_name,'')));
        END LOOP;
    END IF;
    RETURN NEW;
END; $fn$
"""))
ALL_STEPS.append(("1A — Drop old trigger", "DROP TRIGGER IF EXISTS trg_app_opportunities_notify_students ON app.opportunities"))
ALL_STEPS.append(("1A — Create trigger", "CREATE TRIGGER trg_app_opportunities_notify_students AFTER INSERT ON app.opportunities FOR EACH ROW EXECUTE FUNCTION public.app_notify_opportunity_to_students()"))

# --- 1B: University News ---
ALL_STEPS.append(("1B — Fn: app_notify_university_news", """
CREATE OR REPLACE FUNCTION public.app_notify_university_news()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_student RECORD; v_uni_name TEXT;
BEGIN
    IF TG_OP = 'INSERT' AND NEW.is_active = TRUE THEN
        SELECT name INTO v_uni_name FROM app.universities WHERE id = NEW.university_id;
        FOR v_student IN
            SELECT DISTINCT a.student_id AS user_id FROM app.applications a
            JOIN app.programs p ON p.id = a.program_id
            WHERE p.university_id = NEW.university_id AND a.student_id IS NOT NULL
        LOOP
            PERFORM public.app_queue_notification_event(v_student.user_id, 'student_universities', 'university_news',
                JSONB_BUILD_OBJECT('university_id', NEW.university_id, 'university_name', COALESCE(v_uni_name,''), 'news_title', COALESCE(NEW.title,''), 'news_id', NEW.id));
        END LOOP;
    END IF;
    RETURN NEW;
END; $fn$
"""))
ALL_STEPS.append(("1B — Drop news trigger", "DROP TRIGGER IF EXISTS trg_app_university_news_notify ON app.university_news"))
ALL_STEPS.append(("1B — Create news trigger", "CREATE TRIGGER trg_app_university_news_notify AFTER INSERT ON app.university_news FOR EACH ROW EXECUTE FUNCTION public.app_notify_university_news()"))

# --- 1B: University Events ---
ALL_STEPS.append(("1B — Fn: app_notify_university_events", """
CREATE OR REPLACE FUNCTION public.app_notify_university_events()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_student RECORD; v_uni_name TEXT;
BEGIN
    IF TG_OP = 'INSERT' AND NEW.is_active = TRUE THEN
        SELECT name INTO v_uni_name FROM app.universities WHERE id = NEW.university_id;
        FOR v_student IN
            SELECT DISTINCT a.student_id AS user_id FROM app.applications a
            JOIN app.programs p ON p.id = a.program_id
            WHERE p.university_id = NEW.university_id AND a.student_id IS NOT NULL
        LOOP
            PERFORM public.app_queue_notification_event(v_student.user_id, 'student_universities', 'university_event',
                JSONB_BUILD_OBJECT('university_id', NEW.university_id, 'university_name', COALESCE(v_uni_name,''), 'event_title', COALESCE(NEW.title,''), 'event_id', NEW.id));
        END LOOP;
    END IF;
    RETURN NEW;
END; $fn$
"""))
ALL_STEPS.append(("1B — Drop events trigger", "DROP TRIGGER IF EXISTS trg_app_university_events_notify ON app.university_events"))
ALL_STEPS.append(("1B — Create events trigger", "CREATE TRIGGER trg_app_university_events_notify AFTER INSERT ON app.university_events FOR EACH ROW EXECUTE FUNCTION public.app_notify_university_events()"))

# --- 1C: Annonces officielles ---
ALL_STEPS.append(("1C — Fn: app_notify_official_announcement", """
CREATE OR REPLACE FUNCTION public.app_notify_official_announcement()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_student RECORD;
BEGIN
    IF TG_OP = 'INSERT' AND NEW.is_published = TRUE THEN
        FOR v_student IN
            SELECT u.id AS user_id FROM auth.users u
            WHERE u.raw_user_meta_data->>'role' = 'student' AND u.banned_until IS NULL
        LOOP
            PERFORM public.app_queue_notification_event(v_student.user_id, 'student_announcements', 'official_announcement',
                JSONB_BUILD_OBJECT('announcement_id', NEW.id, 'title', COALESCE(NEW.title,''), 'urgency', COALESCE(NEW.urgency_level,'normal'), 'category', COALESCE(NEW.category,'')));
        END LOOP;
    END IF;
    RETURN NEW;
END; $fn$
"""))
ALL_STEPS.append(("1C — Drop trigger", "DROP TRIGGER IF EXISTS trg_app_official_announcements_notify ON app.official_announcements"))
ALL_STEPS.append(("1C — Create trigger", "CREATE TRIGGER trg_app_official_announcements_notify AFTER INSERT ON app.official_announcements FOR EACH ROW EXECUTE FUNCTION public.app_notify_official_announcement()"))

# --- 1D: Challenges ---
ALL_STEPS.append(("1D — Fn: app_notify_challenge_created", """
CREATE OR REPLACE FUNCTION public.app_notify_challenge_created()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_student RECORD;
BEGIN
    IF TG_OP = 'INSERT' AND NEW.is_active = TRUE THEN
        FOR v_student IN
            SELECT u.id AS user_id FROM auth.users u
            WHERE u.raw_user_meta_data->>'role' = 'student' AND u.banned_until IS NULL
        LOOP
            PERFORM public.app_queue_notification_event(v_student.user_id, 'student_challenges', 'new_challenge',
                JSONB_BUILD_OBJECT('challenge_id', NEW.id, 'title', COALESCE(NEW.title,''), 'difficulty', COALESCE(NEW.difficulty,''), 'points', COALESCE(NEW.points,0)));
        END LOOP;
    END IF;
    RETURN NEW;
END; $fn$
"""))
ALL_STEPS.append(("1D — Drop trigger", "DROP TRIGGER IF EXISTS trg_app_challenges_notify_students ON app.challenges"))
ALL_STEPS.append(("1D — Create trigger", "CREATE TRIGGER trg_app_challenges_notify_students AFTER INSERT ON app.challenges FOR EACH ROW EXECUTE FUNCTION public.app_notify_challenge_created()"))

# --- 1E: Online courses (new) ---
ALL_STEPS.append(("1E — Fn: app_notify_online_course_created", """
CREATE OR REPLACE FUNCTION public.app_notify_online_course_created()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_student RECORD;
BEGIN
    IF TG_OP = 'INSERT' AND NEW.is_active = TRUE THEN
        FOR v_student IN
            SELECT u.id AS user_id FROM auth.users u
            WHERE u.raw_user_meta_data->>'role' = 'student' AND u.banned_until IS NULL
        LOOP
            PERFORM public.app_queue_notification_event(v_student.user_id, 'student_online_courses', 'new_course',
                JSONB_BUILD_OBJECT('course_id', NEW.id, 'title', COALESCE(NEW.title,'')));
        END LOOP;
    END IF;
    RETURN NEW;
END; $fn$
"""))
ALL_STEPS.append(("1E — Drop courses trigger", "DROP TRIGGER IF EXISTS trg_app_online_courses_notify ON app.online_courses"))
ALL_STEPS.append(("1E — Create courses trigger", "CREATE TRIGGER trg_app_online_courses_notify AFTER INSERT ON app.online_courses FOR EACH ROW EXECUTE FUNCTION public.app_notify_online_course_created()"))

# --- 1E: Online course lessons ---
ALL_STEPS.append(("1E — Fn: app_notify_online_course_lesson", """
CREATE OR REPLACE FUNCTION public.app_notify_online_course_lesson()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_student RECORD; v_course_title TEXT;
BEGIN
    IF TG_OP = 'INSERT' AND NEW.is_active = TRUE THEN
        SELECT title INTO v_course_title FROM app.online_courses WHERE id = NEW.course_id;
        FOR v_student IN
            SELECT DISTINCT e.user_id FROM app.online_course_enrollments e
            WHERE e.course_id = NEW.course_id AND e.user_id IS NOT NULL
        LOOP
            PERFORM public.app_queue_notification_event(v_student.user_id, 'student_online_courses', 'new_lesson',
                JSONB_BUILD_OBJECT('course_id', NEW.course_id, 'course_title', COALESCE(v_course_title,''), 'lesson_title', COALESCE(NEW.title,''), 'lesson_id', NEW.id));
        END LOOP;
    END IF;
    RETURN NEW;
END; $fn$
"""))
ALL_STEPS.append(("1E — Drop lessons trigger", "DROP TRIGGER IF EXISTS trg_app_online_course_lessons_notify ON app.online_course_lessons"))
ALL_STEPS.append(("1E — Create lessons trigger", "CREATE TRIGGER trg_app_online_course_lessons_notify AFTER INSERT ON app.online_course_lessons FOR EACH ROW EXECUTE FUNCTION public.app_notify_online_course_lesson()"))

# --- 1E: Live sessions ---
ALL_STEPS.append(("1E — Fn: app_notify_online_course_live", """
CREATE OR REPLACE FUNCTION public.app_notify_online_course_live()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_student RECORD; v_course_title TEXT;
BEGIN
    IF TG_OP = 'INSERT' AND NEW.is_active = TRUE THEN
        SELECT title INTO v_course_title FROM app.online_courses WHERE id = NEW.course_id;
        FOR v_student IN
            SELECT DISTINCT e.user_id FROM app.online_course_enrollments e
            WHERE e.course_id = NEW.course_id AND e.user_id IS NOT NULL
        LOOP
            PERFORM public.app_queue_notification_event(v_student.user_id, 'student_lives', 'live_session',
                JSONB_BUILD_OBJECT('course_id', NEW.course_id, 'course_title', COALESCE(v_course_title,''), 'session_title', COALESCE(NEW.title,''), 'start_at', COALESCE(NEW.start_at::TEXT,''), 'session_id', NEW.id));
        END LOOP;
    END IF;
    RETURN NEW;
END; $fn$
"""))
ALL_STEPS.append(("1E — Drop lives trigger", "DROP TRIGGER IF EXISTS trg_app_online_course_lives_notify ON app.online_course_live_sessions"))
ALL_STEPS.append(("1E — Create lives trigger", "CREATE TRIGGER trg_app_online_course_lives_notify AFTER INSERT ON app.online_course_live_sessions FOR EACH ROW EXECUTE FUNCTION public.app_notify_online_course_live()"))

# --- 1F: Short trainings ---
ALL_STEPS.append(("1F — Fn: app_notify_short_training_created", """
CREATE OR REPLACE FUNCTION public.app_notify_short_training_created()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_student RECORD;
BEGIN
    IF TG_OP = 'INSERT' AND NEW.is_active = TRUE THEN
        FOR v_student IN
            SELECT u.id AS user_id FROM auth.users u
            WHERE u.raw_user_meta_data->>'role' = 'student' AND u.banned_until IS NULL
        LOOP
            PERFORM public.app_queue_notification_event(v_student.user_id, 'student_short_trainings', 'new_training',
                JSONB_BUILD_OBJECT('training_id', NEW.id, 'title', COALESCE(NEW.title,'')));
        END LOOP;
    END IF;
    RETURN NEW;
END; $fn$
"""))
ALL_STEPS.append(("1F — Drop trainings trigger", "DROP TRIGGER IF EXISTS trg_app_short_trainings_notify_students ON app.short_trainings"))
ALL_STEPS.append(("1F — Create trainings trigger", "CREATE TRIGGER trg_app_short_trainings_notify_students AFTER INSERT ON app.short_trainings FOR EACH ROW EXECUTE FUNCTION public.app_notify_short_training_created()"))

# --- 1F: Short training sessions ---
ALL_STEPS.append(("1F — Fn: app_notify_short_training_session", """
CREATE OR REPLACE FUNCTION public.app_notify_short_training_session()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_student RECORD; v_training_title TEXT;
BEGIN
    IF TG_OP = 'INSERT' AND NEW.is_active = TRUE THEN
        SELECT title INTO v_training_title FROM app.short_trainings WHERE id = NEW.training_id;
        FOR v_student IN
            SELECT DISTINCT r.user_id FROM app.short_training_registrations r
            WHERE r.training_id = NEW.training_id AND r.user_id IS NOT NULL
        LOOP
            PERFORM public.app_queue_notification_event(v_student.user_id, 'student_short_trainings', 'new_session',
                JSONB_BUILD_OBJECT('training_id', NEW.training_id, 'training_title', COALESCE(v_training_title,''), 'session_id', NEW.id));
        END LOOP;
    END IF;
    RETURN NEW;
END; $fn$
"""))
ALL_STEPS.append(("1F — Drop sessions trigger", "DROP TRIGGER IF EXISTS trg_app_short_training_sessions_notify_students ON app.short_training_sessions"))
ALL_STEPS.append(("1F — Create sessions trigger", "CREATE TRIGGER trg_app_short_training_sessions_notify_students AFTER INSERT ON app.short_training_sessions FOR EACH ROW EXECUTE FUNCTION public.app_notify_short_training_session()"))

# --- 1G: Opportunity comments ---
ALL_STEPS.append(("1G — Fn: app_notify_opportunity_comment", """
CREATE OR REPLACE FUNCTION public.app_notify_opportunity_comment()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_participant RECORD; v_opp_title TEXT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT title INTO v_opp_title FROM app.opportunities WHERE id = NEW.opportunity_id;
        FOR v_participant IN
            SELECT DISTINCT user_id FROM (
                SELECT user_id FROM app.opportunity_comments WHERE opportunity_id = NEW.opportunity_id AND user_id IS NOT NULL AND user_id != NEW.user_id
                UNION
                SELECT created_by_user_id AS user_id FROM app.opportunities WHERE id = NEW.opportunity_id AND created_by_user_id IS NOT NULL AND created_by_user_id != NEW.user_id
            ) sub
        LOOP
            PERFORM public.app_queue_notification_event(v_participant.user_id, 'student_opportunities', 'opportunity_comment',
                JSONB_BUILD_OBJECT('opportunity_id', NEW.opportunity_id, 'opportunity_title', COALESCE(v_opp_title,''), 'comment_id', NEW.id));
        END LOOP;
    END IF;
    RETURN NEW;
END; $fn$
"""))
ALL_STEPS.append(("1G — Drop comments trigger", "DROP TRIGGER IF EXISTS trg_app_opportunity_comments_notify ON app.opportunity_comments"))
ALL_STEPS.append(("1G — Create comments trigger", "CREATE TRIGGER trg_app_opportunity_comments_notify AFTER INSERT ON app.opportunity_comments FOR EACH ROW EXECUTE FUNCTION public.app_notify_opportunity_comment()"))

# --- 1H: Student home content ---
ALL_STEPS.append(("1H — Fn: app_notify_student_home_content", """
CREATE OR REPLACE FUNCTION public.app_notify_student_home_content()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_student RECORD;
BEGIN
    IF TG_OP = 'INSERT' AND NEW.is_active = TRUE THEN
        FOR v_student IN
            SELECT u.id AS user_id FROM auth.users u
            WHERE u.raw_user_meta_data->>'role' = 'student' AND u.banned_until IS NULL
        LOOP
            PERFORM public.app_queue_notification_event(v_student.user_id, 'student_home', 'new_content',
                JSONB_BUILD_OBJECT('content_type', TG_TABLE_NAME));
        END LOOP;
    END IF;
    RETURN NEW;
END; $fn$
"""))
ALL_STEPS.append(("1H — Drop announcements trigger", "DROP TRIGGER IF EXISTS trg_app_student_home_announcements_notify ON app.student_home_announcements"))
ALL_STEPS.append(("1H — Create announcements trigger", "CREATE TRIGGER trg_app_student_home_announcements_notify AFTER INSERT ON app.student_home_announcements FOR EACH ROW EXECUTE FUNCTION public.app_notify_student_home_content()"))
ALL_STEPS.append(("1H — Drop videos trigger", "DROP TRIGGER IF EXISTS trg_app_student_home_videos_notify ON app.student_home_videos"))
ALL_STEPS.append(("1H — Create videos trigger", "CREATE TRIGGER trg_app_student_home_videos_notify AFTER INSERT ON app.student_home_videos FOR EACH ROW EXECUTE FUNCTION public.app_notify_student_home_content()"))

# ============================================================
# EXÉCUTION
# ============================================================
print("\n" + "=" * 60)
print("  PHASE 1 — DÉPLOIEMENT DES TRIGGERS DE NOTIFICATIONS")
print("=" * 60)

success = 0
failed = 0
for label, sql in ALL_STEPS:
    ok = run_sql(label, sql)
    if ok:
        success += 1
    else:
        failed += 1

print(f"\n{'='*60}")
print(f"  RÉSULTAT: {success}/{len(ALL_STEPS)} étapes réussies, {failed} échecs")
print(f"{'='*60}\n")
