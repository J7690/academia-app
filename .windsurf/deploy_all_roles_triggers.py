#!/usr/bin/env python3
"""
Deploy notification triggers for ALL roles:
- Admin: notified of everything from students, universities, commercials, instructors
- University: notified of interactions concerning their programs/applications
- Instructor: notified of interactions concerning their courses/TD
- Commercial: notified of referrals and commissions
"""
import requests
import time

PROJECT_REF = "thevdfcwlcqzdoybfvgs"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

RPC_URL = f"https://{PROJECT_REF}.supabase.co/rest/v1/rpc/execute_sql"
HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}

def inject_ddl(label, ddl_sql):
    payload = f"SELECT 1) t; {ddl_sql}; SELECT * FROM (SELECT 1"
    r = requests.post(RPC_URL, headers=HEADERS, json={"sql_query": payload}, timeout=60)
    result = r.json()
    if isinstance(result, dict) and result.get('error'):
        print(f"  ❌ {label}: {result['error'][:200]}")
        return False
    else:
        print(f"  ✅ {label}")
        return True

STEPS = []

# ============================================================
# ADMIN NOTIFICATIONS — notifié de TOUT
# ============================================================

# A1: Nouveau compte créé (any role)
STEPS.append(("ADMIN — Fn: notify_admin_new_account", """
CREATE OR REPLACE FUNCTION public.app_notify_admin_new_account()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_admin RECORD; v_new_role TEXT;
BEGIN
    v_new_role := COALESCE(NEW.raw_user_meta_data->>'role', 'unknown');
    IF v_new_role != 'admin' THEN
        FOR v_admin IN
            SELECT u.id AS user_id FROM auth.users u
            WHERE u.raw_user_meta_data->>'role' = 'admin' AND u.banned_until IS NULL
        LOOP
            PERFORM public.app_queue_notification_event(v_admin.user_id, 'admin_accounts', 'new_account',
                JSONB_BUILD_OBJECT('new_user_id', NEW.id, 'role', v_new_role, 'email', COALESCE(NEW.email,'')));
        END LOOP;
    END IF;
    RETURN NEW;
END; $fn$
"""))
STEPS.append(("ADMIN — Drop new_account trigger", "DROP TRIGGER IF EXISTS trg_admin_new_account_notify ON auth.users"))
STEPS.append(("ADMIN — Create new_account trigger", "CREATE TRIGGER trg_admin_new_account_notify AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.app_notify_admin_new_account()"))

# A2: Nouvelle candidature
STEPS.append(("ADMIN — Fn: notify_admin_new_application", """
CREATE OR REPLACE FUNCTION public.app_notify_admin_new_application()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_admin RECORD; v_student_name TEXT; v_program_name TEXT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT s.full_name INTO v_student_name FROM app.students s WHERE s.id = NEW.student_id;
        SELECT p.name INTO v_program_name FROM app.programs p WHERE p.id = NEW.program_id;
        FOR v_admin IN
            SELECT u.id AS user_id FROM auth.users u
            WHERE u.raw_user_meta_data->>'role' = 'admin' AND u.banned_until IS NULL
        LOOP
            PERFORM public.app_queue_notification_event(v_admin.user_id, 'admin_applications', 'new_application',
                JSONB_BUILD_OBJECT('application_id', NEW.id, 'student_name', COALESCE(v_student_name,''), 'program_name', COALESCE(v_program_name,''), 'student_id', NEW.student_id));
        END LOOP;
    END IF;
    RETURN NEW;
END; $fn$
"""))
STEPS.append(("ADMIN — Drop new_application trigger", "DROP TRIGGER IF EXISTS trg_admin_new_application_notify ON app.applications"))
STEPS.append(("ADMIN — Create new_application trigger", "CREATE TRIGGER trg_admin_new_application_notify AFTER INSERT ON app.applications FOR EACH ROW EXECUTE FUNCTION public.app_notify_admin_new_application()"))

# A3: Message candidature (from student or university)
STEPS.append(("ADMIN — Fn: notify_admin_application_message", """
CREATE OR REPLACE FUNCTION public.app_notify_admin_application_message()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_admin RECORD;
BEGIN
    IF TG_OP = 'INSERT' AND NEW.sender_role != 'admin' THEN
        FOR v_admin IN
            SELECT u.id AS user_id FROM auth.users u
            WHERE u.raw_user_meta_data->>'role' = 'admin' AND u.banned_until IS NULL
        LOOP
            PERFORM public.app_queue_notification_event(v_admin.user_id, 'admin_applications', 'message',
                JSONB_BUILD_OBJECT('application_id', NEW.application_id, 'sender_role', NEW.sender_role));
        END LOOP;
    END IF;
    RETURN NEW;
END; $fn$
"""))
STEPS.append(("ADMIN — Drop app_msg trigger", "DROP TRIGGER IF EXISTS trg_admin_application_message_notify ON app.application_messages"))
STEPS.append(("ADMIN — Create app_msg trigger", "CREATE TRIGGER trg_admin_application_message_notify AFTER INSERT ON app.application_messages FOR EACH ROW EXECUTE FUNCTION public.app_notify_admin_application_message()"))

# A4: Paiement déclaré par étudiant
STEPS.append(("ADMIN — Fn: notify_admin_payment_declared", """
CREATE OR REPLACE FUNCTION public.app_notify_admin_payment_declared()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_admin RECORD; v_student_name TEXT;
BEGIN
    IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND NEW.status != OLD.status) THEN
        SELECT s.full_name INTO v_student_name FROM app.students s WHERE s.id = NEW.student_id;
        FOR v_admin IN
            SELECT u.id AS user_id FROM auth.users u
            WHERE u.raw_user_meta_data->>'role' = 'admin' AND u.banned_until IS NULL
        LOOP
            PERFORM public.app_queue_notification_event(v_admin.user_id, 'admin_payments', 'payment',
                JSONB_BUILD_OBJECT('payment_id', NEW.id, 'student_name', COALESCE(v_student_name,''), 'status', NEW.status, 'amount_paid', COALESCE(NEW.amount_paid,0)));
        END LOOP;
    END IF;
    RETURN NEW;
END; $fn$
"""))
STEPS.append(("ADMIN — Drop payment trigger", "DROP TRIGGER IF EXISTS trg_admin_payment_declared_notify ON app.application_payments"))
STEPS.append(("ADMIN — Create payment trigger", "CREATE TRIGGER trg_admin_payment_declared_notify AFTER INSERT OR UPDATE ON app.application_payments FOR EACH ROW EXECUTE FUNCTION public.app_notify_admin_payment_declared()"))

# A5: Participation challenge
STEPS.append(("ADMIN — Fn: notify_admin_challenge_participation", """
CREATE OR REPLACE FUNCTION public.app_notify_admin_challenge_participation()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_admin RECORD; v_challenge_title TEXT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT c.title INTO v_challenge_title FROM app.challenges c WHERE c.id = NEW.challenge_id;
        FOR v_admin IN
            SELECT u.id AS user_id FROM auth.users u
            WHERE u.raw_user_meta_data->>'role' = 'admin' AND u.banned_until IS NULL
        LOOP
            PERFORM public.app_queue_notification_event(v_admin.user_id, 'admin_challenges', 'new_participation',
                JSONB_BUILD_OBJECT('challenge_id', NEW.challenge_id, 'challenge_title', COALESCE(v_challenge_title,''), 'user_id', NEW.user_id));
        END LOOP;
    END IF;
    RETURN NEW;
END; $fn$
"""))
STEPS.append(("ADMIN — Drop challenge_part trigger", "DROP TRIGGER IF EXISTS trg_admin_challenge_participation_notify ON app.challenge_participations"))
STEPS.append(("ADMIN — Create challenge_part trigger", "CREATE TRIGGER trg_admin_challenge_participation_notify AFTER INSERT ON app.challenge_participations FOR EACH ROW EXECUTE FUNCTION public.app_notify_admin_challenge_participation()"))

# A6: Inscription formation courte
STEPS.append(("ADMIN — Fn: notify_admin_training_registration", """
CREATE OR REPLACE FUNCTION public.app_notify_admin_training_registration()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_admin RECORD; v_training_title TEXT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT t.title INTO v_training_title FROM app.short_trainings t JOIN app.short_training_sessions s ON s.training_id = t.id WHERE s.id = NEW.session_id;
        FOR v_admin IN
            SELECT u.id AS user_id FROM auth.users u
            WHERE u.raw_user_meta_data->>'role' = 'admin' AND u.banned_until IS NULL
        LOOP
            PERFORM public.app_queue_notification_event(v_admin.user_id, 'admin_short_trainings', 'new_registration',
                JSONB_BUILD_OBJECT('training_title', COALESCE(v_training_title,''), 'user_id', NEW.user_id));
        END LOOP;
    END IF;
    RETURN NEW;
END; $fn$
"""))
STEPS.append(("ADMIN — Drop training_reg trigger", "DROP TRIGGER IF EXISTS trg_admin_training_registration_notify ON app.short_training_registrations"))
STEPS.append(("ADMIN — Create training_reg trigger", "CREATE TRIGGER trg_admin_training_registration_notify AFTER INSERT ON app.short_training_registrations FOR EACH ROW EXECUTE FUNCTION public.app_notify_admin_training_registration()"))

# A7: Inscription cours en ligne
STEPS.append(("ADMIN — Fn: notify_admin_course_enrollment", """
CREATE OR REPLACE FUNCTION public.app_notify_admin_course_enrollment()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_admin RECORD; v_course_title TEXT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT c.title INTO v_course_title FROM app.online_courses c WHERE c.id = NEW.course_id;
        FOR v_admin IN
            SELECT u.id AS user_id FROM auth.users u
            WHERE u.raw_user_meta_data->>'role' = 'admin' AND u.banned_until IS NULL
        LOOP
            PERFORM public.app_queue_notification_event(v_admin.user_id, 'admin_online_courses', 'new_enrollment',
                JSONB_BUILD_OBJECT('course_title', COALESCE(v_course_title,''), 'student_id', NEW.student_id));
        END LOOP;
    END IF;
    RETURN NEW;
END; $fn$
"""))
STEPS.append(("ADMIN — Drop course_enroll trigger", "DROP TRIGGER IF EXISTS trg_admin_course_enrollment_notify ON app.online_course_enrollments"))
STEPS.append(("ADMIN — Create course_enroll trigger", "CREATE TRIGGER trg_admin_course_enrollment_notify AFTER INSERT ON app.online_course_enrollments FOR EACH ROW EXECUTE FUNCTION public.app_notify_admin_course_enrollment()"))

# A8: Demande TD
STEPS.append(("ADMIN — Fn: notify_admin_td_request", """
CREATE OR REPLACE FUNCTION public.app_notify_admin_td_request()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_admin RECORD;
BEGIN
    IF TG_OP = 'INSERT' THEN
        FOR v_admin IN
            SELECT u.id AS user_id FROM auth.users u
            WHERE u.raw_user_meta_data->>'role' = 'admin' AND u.banned_until IS NULL
        LOOP
            PERFORM public.app_queue_notification_event(v_admin.user_id, 'admin_td', 'new_request',
                JSONB_BUILD_OBJECT('student_id', NEW.student_id, 'request_id', NEW.id));
        END LOOP;
    END IF;
    RETURN NEW;
END; $fn$
"""))
STEPS.append(("ADMIN — Drop td_request trigger", "DROP TRIGGER IF EXISTS trg_admin_td_request_notify ON app.td_student_requests"))
STEPS.append(("ADMIN — Create td_request trigger", "CREATE TRIGGER trg_admin_td_request_notify AFTER INSERT ON app.td_student_requests FOR EACH ROW EXECUTE FUNCTION public.app_notify_admin_td_request()"))

# A9: Message TD (from student or teacher)
STEPS.append(("ADMIN — Fn: notify_admin_td_message", """
CREATE OR REPLACE FUNCTION public.app_notify_admin_td_message()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_admin RECORD;
BEGIN
    IF TG_OP = 'INSERT' AND NEW.admin_user_id IS NULL THEN
        FOR v_admin IN
            SELECT u.id AS user_id FROM auth.users u
            WHERE u.raw_user_meta_data->>'role' = 'admin' AND u.banned_until IS NULL
        LOOP
            PERFORM public.app_queue_notification_event(v_admin.user_id, 'admin_td', 'new_message',
                JSONB_BUILD_OBJECT('enrollment_id', NEW.td_enrollment_id, 'sender_user_id', NEW.sender_user_id));
        END LOOP;
    END IF;
    RETURN NEW;
END; $fn$
"""))
STEPS.append(("ADMIN — Drop td_message trigger", "DROP TRIGGER IF EXISTS trg_admin_td_message_notify ON app.td_messages"))
STEPS.append(("ADMIN — Create td_message trigger", "CREATE TRIGGER trg_admin_td_message_notify AFTER INSERT ON app.td_messages FOR EACH ROW EXECUTE FUNCTION public.app_notify_admin_td_message()"))

# A10: Demande rejoindre communauté
STEPS.append(("ADMIN — Fn: notify_admin_community_join", """
CREATE OR REPLACE FUNCTION public.app_notify_admin_community_join()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_admin RECORD; v_community_name TEXT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT c.name INTO v_community_name FROM app.communities c WHERE c.id = NEW.community_id;
        FOR v_admin IN
            SELECT u.id AS user_id FROM auth.users u
            WHERE u.raw_user_meta_data->>'role' = 'admin' AND u.banned_until IS NULL
        LOOP
            PERFORM public.app_queue_notification_event(v_admin.user_id, 'admin_communities', 'join_request',
                JSONB_BUILD_OBJECT('community_name', COALESCE(v_community_name,''), 'user_id', NEW.user_id));
        END LOOP;
    END IF;
    RETURN NEW;
END; $fn$
"""))
STEPS.append(("ADMIN — Drop community_join trigger", "DROP TRIGGER IF EXISTS trg_admin_community_join_notify ON app.community_join_requests"))
STEPS.append(("ADMIN — Create community_join trigger", "CREATE TRIGGER trg_admin_community_join_notify AFTER INSERT ON app.community_join_requests FOR EACH ROW EXECUTE FUNCTION public.app_notify_admin_community_join()"))

# A11: Commande marketplace
STEPS.append(("ADMIN — Fn: notify_admin_marketplace_order", """
CREATE OR REPLACE FUNCTION public.app_notify_admin_marketplace_order()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_admin RECORD;
BEGIN
    IF TG_OP = 'INSERT' THEN
        FOR v_admin IN
            SELECT u.id AS user_id FROM auth.users u
            WHERE u.raw_user_meta_data->>'role' = 'admin' AND u.banned_until IS NULL
        LOOP
            PERFORM public.app_queue_notification_event(v_admin.user_id, 'admin_marketplace', 'new_order',
                JSONB_BUILD_OBJECT('order_id', NEW.id, 'student_id', NEW.student_id));
        END LOOP;
    END IF;
    RETURN NEW;
END; $fn$
"""))
STEPS.append(("ADMIN — Drop marketplace_order trigger", "DROP TRIGGER IF EXISTS trg_admin_marketplace_order_notify ON app.marketplace_orders"))
STEPS.append(("ADMIN — Create marketplace_order trigger", "CREATE TRIGGER trg_admin_marketplace_order_notify AFTER INSERT ON app.marketplace_orders FOR EACH ROW EXECUTE FUNCTION public.app_notify_admin_marketplace_order()"))

# A12: Opportunité postée (comment, reaction, application)
STEPS.append(("ADMIN — Fn: notify_admin_opportunity_application", """
CREATE OR REPLACE FUNCTION public.app_notify_admin_opportunity_application()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_admin RECORD; v_opp_title TEXT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT o.title INTO v_opp_title FROM app.opportunities o WHERE o.id = NEW.opportunity_id;
        FOR v_admin IN
            SELECT u.id AS user_id FROM auth.users u
            WHERE u.raw_user_meta_data->>'role' = 'admin' AND u.banned_until IS NULL
        LOOP
            PERFORM public.app_queue_notification_event(v_admin.user_id, 'admin_opportunities', 'new_application',
                JSONB_BUILD_OBJECT('opportunity_title', COALESCE(v_opp_title,''), 'student_id', NEW.student_id));
        END LOOP;
    END IF;
    RETURN NEW;
END; $fn$
"""))
STEPS.append(("ADMIN — Drop opp_application trigger", "DROP TRIGGER IF EXISTS trg_admin_opportunity_application_notify ON app.opportunity_applications"))
STEPS.append(("ADMIN — Create opp_application trigger", "CREATE TRIGGER trg_admin_opportunity_application_notify AFTER INSERT ON app.opportunity_applications FOR EACH ROW EXECUTE FUNCTION public.app_notify_admin_opportunity_application()"))

# ============================================================
# UNIVERSITY NOTIFICATIONS — interactions les concernant
# ============================================================

# U1: Nouvelle candidature vers leur université
STEPS.append(("UNI — Fn: notify_university_new_application", """
CREATE OR REPLACE FUNCTION public.app_notify_university_new_application()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_uni_user RECORD; v_uni_id UUID; v_student_name TEXT; v_program_name TEXT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT p.university_id, p.name INTO v_uni_id, v_program_name FROM app.programs p WHERE p.id = NEW.program_id;
        SELECT s.full_name INTO v_student_name FROM app.students s WHERE s.id = NEW.student_id;
        IF v_uni_id IS NOT NULL THEN
            FOR v_uni_user IN
                SELECT u.id AS user_id FROM auth.users u
                WHERE u.raw_user_meta_data->>'role' = 'university'
                  AND (u.raw_user_meta_data->>'university_id')::UUID = v_uni_id
                  AND u.banned_until IS NULL
            LOOP
                PERFORM public.app_queue_notification_event(v_uni_user.user_id, 'university_applications', 'new_application',
                    JSONB_BUILD_OBJECT('application_id', NEW.id, 'student_name', COALESCE(v_student_name,''), 'program_name', COALESCE(v_program_name,'')));
            END LOOP;
        END IF;
    END IF;
    RETURN NEW;
END; $fn$
"""))
STEPS.append(("UNI — Drop new_application trigger", "DROP TRIGGER IF EXISTS trg_uni_new_application_notify ON app.applications"))
STEPS.append(("UNI — Create new_application trigger", "CREATE TRIGGER trg_uni_new_application_notify AFTER INSERT ON app.applications FOR EACH ROW EXECUTE FUNCTION public.app_notify_university_new_application()"))

# U2: Message candidature (from student or admin)
STEPS.append(("UNI — Fn: notify_university_application_message", """
CREATE OR REPLACE FUNCTION public.app_notify_university_application_message()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_uni_user RECORD; v_uni_id UUID;
BEGIN
    IF TG_OP = 'INSERT' AND NEW.sender_role != 'university' THEN
        SELECT p.university_id INTO v_uni_id FROM app.applications a JOIN app.programs p ON p.id = a.program_id WHERE a.id = NEW.application_id;
        IF v_uni_id IS NOT NULL THEN
            FOR v_uni_user IN
                SELECT u.id AS user_id FROM auth.users u
                WHERE u.raw_user_meta_data->>'role' = 'university'
                  AND (u.raw_user_meta_data->>'university_id')::UUID = v_uni_id
                  AND u.banned_until IS NULL
            LOOP
                PERFORM public.app_queue_notification_event(v_uni_user.user_id, 'university_applications', 'message',
                    JSONB_BUILD_OBJECT('application_id', NEW.application_id, 'sender_role', NEW.sender_role));
            END LOOP;
        END IF;
    END IF;
    RETURN NEW;
END; $fn$
"""))
STEPS.append(("UNI — Drop app_msg trigger", "DROP TRIGGER IF EXISTS trg_uni_application_message_notify ON app.application_messages"))
STEPS.append(("UNI — Create app_msg trigger", "CREATE TRIGGER trg_uni_application_message_notify AFTER INSERT ON app.application_messages FOR EACH ROW EXECUTE FUNCTION public.app_notify_university_application_message()"))

# U3: Paiement étudiant vers leur université
STEPS.append(("UNI — Fn: notify_university_payment", """
CREATE OR REPLACE FUNCTION public.app_notify_university_payment()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_uni_user RECORD; v_student_name TEXT;
BEGIN
    IF (TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND NEW.status != OLD.status)) AND NEW.university_id IS NOT NULL THEN
        SELECT s.full_name INTO v_student_name FROM app.students s WHERE s.id = NEW.student_id;
        FOR v_uni_user IN
            SELECT u.id AS user_id FROM auth.users u
            WHERE u.raw_user_meta_data->>'role' = 'university'
              AND (u.raw_user_meta_data->>'university_id')::UUID = NEW.university_id
              AND u.banned_until IS NULL
        LOOP
            PERFORM public.app_queue_notification_event(v_uni_user.user_id, 'university_payments', 'payment_update',
                JSONB_BUILD_OBJECT('payment_id', NEW.id, 'student_name', COALESCE(v_student_name,''), 'status', NEW.status, 'amount_paid', COALESCE(NEW.amount_paid,0)));
        END LOOP;
    END IF;
    RETURN NEW;
END; $fn$
"""))
STEPS.append(("UNI — Drop payment trigger", "DROP TRIGGER IF EXISTS trg_uni_payment_notify ON app.application_payments"))
STEPS.append(("UNI — Create payment trigger", "CREATE TRIGGER trg_uni_payment_notify AFTER INSERT OR UPDATE ON app.application_payments FOR EACH ROW EXECUTE FUNCTION public.app_notify_university_payment()"))

# ============================================================
# INSTRUCTOR (ENSEIGNANT) NOTIFICATIONS
# ============================================================

# I1: Message TD de l'étudiant
STEPS.append(("INSTR — Fn: notify_instructor_td_message", """
CREATE OR REPLACE FUNCTION public.app_notify_instructor_td_message()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_teacher_uid UUID;
BEGIN
    IF TG_OP = 'INSERT' AND NEW.teacher_user_id IS NOT NULL AND NEW.sender_user_id != NEW.teacher_user_id THEN
        PERFORM public.app_queue_notification_event(NEW.teacher_user_id, 'instructor_td', 'new_message',
            JSONB_BUILD_OBJECT('enrollment_id', NEW.td_enrollment_id, 'sender_user_id', NEW.sender_user_id));
    END IF;
    RETURN NEW;
END; $fn$
"""))
STEPS.append(("INSTR — Drop td_msg trigger", "DROP TRIGGER IF EXISTS trg_instructor_td_message_notify ON app.td_messages"))
STEPS.append(("INSTR — Create td_msg trigger", "CREATE TRIGGER trg_instructor_td_message_notify AFTER INSERT ON app.td_messages FOR EACH ROW EXECUTE FUNCTION public.app_notify_instructor_td_message()"))

# I2: Nouvel inscrit à un cours en ligne de l'instructeur
STEPS.append(("INSTR — Fn: notify_instructor_course_enrollment", """
CREATE OR REPLACE FUNCTION public.app_notify_instructor_course_enrollment()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_instr RECORD; v_course_title TEXT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT c.title INTO v_course_title FROM app.online_courses c WHERE c.id = NEW.course_id;
        FOR v_instr IN
            SELECT DISTINCT oci.instructor_id AS user_id FROM app.online_course_instructors oci
            WHERE oci.course_id = NEW.course_id AND oci.instructor_id IS NOT NULL
        LOOP
            PERFORM public.app_queue_notification_event(v_instr.user_id, 'instructor_courses', 'new_enrollment',
                JSONB_BUILD_OBJECT('course_id', NEW.course_id, 'course_title', COALESCE(v_course_title,''), 'student_id', NEW.student_id));
        END LOOP;
    END IF;
    RETURN NEW;
END; $fn$
"""))
STEPS.append(("INSTR — Drop course_enroll trigger", "DROP TRIGGER IF EXISTS trg_instructor_course_enrollment_notify ON app.online_course_enrollments"))
STEPS.append(("INSTR — Create course_enroll trigger", "CREATE TRIGGER trg_instructor_course_enrollment_notify AFTER INSERT ON app.online_course_enrollments FOR EACH ROW EXECUTE FUNCTION public.app_notify_instructor_course_enrollment()"))

# I3: Message forum cours en ligne (from student)
STEPS.append(("INSTR — Fn: notify_instructor_forum_message", """
CREATE OR REPLACE FUNCTION public.app_notify_instructor_forum_message()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_instr RECORD; v_course_id UUID; v_course_title TEXT;
BEGIN
    IF TG_OP = 'INSERT' AND NEW.instructor_id IS NULL THEN
        SELECT ft.course_id INTO v_course_id FROM app.online_course_forum_threads ft WHERE ft.id = NEW.thread_id;
        IF v_course_id IS NOT NULL THEN
            SELECT c.title INTO v_course_title FROM app.online_courses c WHERE c.id = v_course_id;
            FOR v_instr IN
                SELECT DISTINCT oci.instructor_id AS user_id FROM app.online_course_instructors oci
                WHERE oci.course_id = v_course_id AND oci.instructor_id IS NOT NULL
            LOOP
                PERFORM public.app_queue_notification_event(v_instr.user_id, 'instructor_courses', 'forum_message',
                    JSONB_BUILD_OBJECT('course_id', v_course_id, 'course_title', COALESCE(v_course_title,''), 'thread_id', NEW.thread_id));
            END LOOP;
        END IF;
    END IF;
    RETURN NEW;
END; $fn$
"""))
STEPS.append(("INSTR — Drop forum_msg trigger", "DROP TRIGGER IF EXISTS trg_instructor_forum_message_notify ON app.online_course_forum_messages"))
STEPS.append(("INSTR — Create forum_msg trigger", "CREATE TRIGGER trg_instructor_forum_message_notify AFTER INSERT ON app.online_course_forum_messages FOR EACH ROW EXECUTE FUNCTION public.app_notify_instructor_forum_message()"))

# I4: Nouvel inscrit TD assigné à l'enseignant
STEPS.append(("INSTR — Fn: notify_instructor_td_enrollment", """
CREATE OR REPLACE FUNCTION public.app_notify_instructor_td_enrollment()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_teacher_uid UUID;
BEGIN
    IF TG_OP = 'INSERT' AND NEW.assigned_teacher_id IS NOT NULL THEN
        SELECT t.user_id INTO v_teacher_uid FROM app.td_teachers t WHERE t.id = NEW.assigned_teacher_id;
        IF v_teacher_uid IS NOT NULL THEN
            PERFORM public.app_queue_notification_event(v_teacher_uid, 'instructor_td', 'new_enrollment',
                JSONB_BUILD_OBJECT('enrollment_id', NEW.id, 'student_id', NEW.student_id, 'program_id', NEW.program_id));
        END IF;
    ELSIF TG_OP = 'UPDATE' AND NEW.assigned_teacher_id IS NOT NULL AND NEW.assigned_teacher_id IS DISTINCT FROM OLD.assigned_teacher_id THEN
        SELECT t.user_id INTO v_teacher_uid FROM app.td_teachers t WHERE t.id = NEW.assigned_teacher_id;
        IF v_teacher_uid IS NOT NULL THEN
            PERFORM public.app_queue_notification_event(v_teacher_uid, 'instructor_td', 'new_enrollment',
                JSONB_BUILD_OBJECT('enrollment_id', NEW.id, 'student_id', NEW.student_id, 'program_id', NEW.program_id));
        END IF;
    END IF;
    RETURN NEW;
END; $fn$
"""))
STEPS.append(("INSTR — Drop td_enroll trigger", "DROP TRIGGER IF EXISTS trg_instructor_td_enrollment_notify ON app.td_enrollments"))
STEPS.append(("INSTR — Create td_enroll trigger", "CREATE TRIGGER trg_instructor_td_enrollment_notify AFTER INSERT OR UPDATE ON app.td_enrollments FOR EACH ROW EXECUTE FUNCTION public.app_notify_instructor_td_enrollment()"))

# ============================================================
# COMMERCIAL NOTIFICATIONS
# ============================================================

# C1: Nouveau parrainage
STEPS.append(("COMM — Fn: notify_commercial_referral", """
CREATE OR REPLACE FUNCTION public.app_notify_commercial_referral()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
BEGIN
    IF TG_OP = 'INSERT' AND NEW.commercial_user_id IS NOT NULL THEN
        PERFORM public.app_queue_notification_event(NEW.commercial_user_id, 'commercial_referrals', 'new_referral',
            JSONB_BUILD_OBJECT('referral_id', NEW.id, 'student_id', NEW.student_id));
    END IF;
    RETURN NEW;
END; $fn$
"""))
STEPS.append(("COMM — Drop referral trigger", "DROP TRIGGER IF EXISTS trg_commercial_referral_notify ON app.user_referrals"))
STEPS.append(("COMM — Create referral trigger", "CREATE TRIGGER trg_commercial_referral_notify AFTER INSERT ON app.user_referrals FOR EACH ROW EXECUTE FUNCTION public.app_notify_commercial_referral()"))

# C2: Nouvelle commission
STEPS.append(("COMM — Fn: notify_commercial_commission", """
CREATE OR REPLACE FUNCTION public.app_notify_commercial_commission()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
BEGIN
    IF TG_OP = 'INSERT' AND NEW.commercial_user_id IS NOT NULL THEN
        PERFORM public.app_queue_notification_event(NEW.commercial_user_id, 'commercial_commissions', 'new_commission',
            JSONB_BUILD_OBJECT('commission_id', NEW.id, 'student_id', NEW.student_id));
    END IF;
    RETURN NEW;
END; $fn$
"""))
STEPS.append(("COMM — Drop commission trigger", "DROP TRIGGER IF EXISTS trg_commercial_commission_notify ON app.referral_commissions"))
STEPS.append(("COMM — Create commission trigger", "CREATE TRIGGER trg_commercial_commission_notify AFTER INSERT ON app.referral_commissions FOR EACH ROW EXECUTE FUNCTION public.app_notify_commercial_commission()"))

# ============================================================
# EXECUTION
# ============================================================
def main():
    print("=" * 60)
    print("  DEPLOYING TRIGGERS FOR ALL ROLES")
    print("  Admin + University + Instructor + Commercial")
    print("=" * 60)
    
    success = 0
    failed = 0
    
    for i, (label, ddl) in enumerate(STEPS, 1):
        print(f"\n  [{i}/{len(STEPS)}]", end=" ")
        if inject_ddl(label, ddl.strip()):
            success += 1
        else:
            failed += 1
        time.sleep(0.3)
    
    print(f"\n\n{'='*60}")
    print(f"  RESULT: {success}/{len(STEPS)} succeeded, {failed} failed")
    print(f"{'='*60}")
    
    # Verify
    print("\n  Verifying all notification triggers...")
    r = requests.post(RPC_URL, headers=HEADERS, json={
        "sql_query": "SELECT tgname, tgrelid::regclass AS tbl FROM pg_trigger WHERE NOT tgisinternal AND tgfoid IN (SELECT oid FROM pg_proc WHERE proname LIKE 'app_notify%') ORDER BY tgname"
    }, timeout=30)
    triggers = r.json()
    if isinstance(triggers, list):
        print(f"  Total notification triggers: {len(triggers)}")
        for t in triggers:
            print(f"    • {t.get('tgname','')} → {t.get('tbl','')}")

if __name__ == "__main__":
    main()
