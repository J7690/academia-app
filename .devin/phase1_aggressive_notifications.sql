-- ============================================================
-- PHASE 1 — TRIGGERS DE NOTIFICATIONS AGRESSIVES
-- Exécuter ce fichier dans le SQL Editor de Supabase
-- ============================================================

-- ============================================================
-- 1A) OPPORTUNITÉS → notifier TOUS les étudiants actifs
-- ============================================================
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
END; $fn$;

DROP TRIGGER IF EXISTS trg_app_opportunities_notify_students ON app.opportunities;
CREATE TRIGGER trg_app_opportunities_notify_students
    AFTER INSERT ON app.opportunities
    FOR EACH ROW EXECUTE FUNCTION public.app_notify_opportunity_to_students();

-- ============================================================
-- 1B) UNIVERSITY NEWS → notifier les étudiants ayant candidaté
-- ============================================================
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
END; $fn$;

DROP TRIGGER IF EXISTS trg_app_university_news_notify ON app.university_news;
CREATE TRIGGER trg_app_university_news_notify
    AFTER INSERT ON app.university_news
    FOR EACH ROW EXECUTE FUNCTION public.app_notify_university_news();

-- ============================================================
-- 1B) UNIVERSITY EVENTS → notifier les étudiants ayant candidaté
-- ============================================================
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
END; $fn$;

DROP TRIGGER IF EXISTS trg_app_university_events_notify ON app.university_events;
CREATE TRIGGER trg_app_university_events_notify
    AFTER INSERT ON app.university_events
    FOR EACH ROW EXECUTE FUNCTION public.app_notify_university_events();

-- ============================================================
-- 1C) ANNONCES OFFICIELLES → notifier TOUS les étudiants
-- ============================================================
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
END; $fn$;

DROP TRIGGER IF EXISTS trg_app_official_announcements_notify ON app.official_announcements;
CREATE TRIGGER trg_app_official_announcements_notify
    AFTER INSERT ON app.official_announcements
    FOR EACH ROW EXECUTE FUNCTION public.app_notify_official_announcement();

-- ============================================================
-- 1D) CHALLENGES → notifier TOUS les étudiants
-- ============================================================
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
END; $fn$;

DROP TRIGGER IF EXISTS trg_app_challenges_notify_students ON app.challenges;
CREATE TRIGGER trg_app_challenges_notify_students
    AFTER INSERT ON app.challenges
    FOR EACH ROW EXECUTE FUNCTION public.app_notify_challenge_created();

-- ============================================================
-- 1E) COURS EN LIGNE (nouveaux) → notifier TOUS les étudiants
-- ============================================================
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
END; $fn$;

DROP TRIGGER IF EXISTS trg_app_online_courses_notify ON app.online_courses;
CREATE TRIGGER trg_app_online_courses_notify
    AFTER INSERT ON app.online_courses
    FOR EACH ROW EXECUTE FUNCTION public.app_notify_online_course_created();

-- ============================================================
-- 1E) LEÇONS DE COURS → notifier les étudiants inscrits
-- ============================================================
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
END; $fn$;

DROP TRIGGER IF EXISTS trg_app_online_course_lessons_notify ON app.online_course_lessons;
CREATE TRIGGER trg_app_online_course_lessons_notify
    AFTER INSERT ON app.online_course_lessons
    FOR EACH ROW EXECUTE FUNCTION public.app_notify_online_course_lesson();

-- ============================================================
-- 1E) LIVES DE COURS → notifier les étudiants inscrits
-- ============================================================
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
END; $fn$;

DROP TRIGGER IF EXISTS trg_app_online_course_lives_notify ON app.online_course_live_sessions;
CREATE TRIGGER trg_app_online_course_lives_notify
    AFTER INSERT ON app.online_course_live_sessions
    FOR EACH ROW EXECUTE FUNCTION public.app_notify_online_course_live();

-- ============================================================
-- 1F) FORMATIONS COURTES → notifier TOUS les étudiants
-- ============================================================
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
END; $fn$;

DROP TRIGGER IF EXISTS trg_app_short_trainings_notify_students ON app.short_trainings;
CREATE TRIGGER trg_app_short_trainings_notify_students
    AFTER INSERT ON app.short_trainings
    FOR EACH ROW EXECUTE FUNCTION public.app_notify_short_training_created();

-- ============================================================
-- 1F) SESSIONS DE FORMATION → notifier les étudiants inscrits
-- ============================================================
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
END; $fn$;

DROP TRIGGER IF EXISTS trg_app_short_training_sessions_notify_students ON app.short_training_sessions;
CREATE TRIGGER trg_app_short_training_sessions_notify_students
    AFTER INSERT ON app.short_training_sessions
    FOR EACH ROW EXECUTE FUNCTION public.app_notify_short_training_session();

-- ============================================================
-- 1G) COMMENTAIRES OPPORTUNITÉS → notifier participants
-- ============================================================
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
END; $fn$;

DROP TRIGGER IF EXISTS trg_app_opportunity_comments_notify ON app.opportunity_comments;
CREATE TRIGGER trg_app_opportunity_comments_notify
    AFTER INSERT ON app.opportunity_comments
    FOR EACH ROW EXECUTE FUNCTION public.app_notify_opportunity_comment();

-- ============================================================
-- 1H) CONTENU ACCUEIL ÉTUDIANT → notifier TOUS les étudiants
-- ============================================================
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
END; $fn$;

DROP TRIGGER IF EXISTS trg_app_student_home_announcements_notify ON app.student_home_announcements;
CREATE TRIGGER trg_app_student_home_announcements_notify
    AFTER INSERT ON app.student_home_announcements
    FOR EACH ROW EXECUTE FUNCTION public.app_notify_student_home_content();

DROP TRIGGER IF EXISTS trg_app_student_home_videos_notify ON app.student_home_videos;
CREATE TRIGGER trg_app_student_home_videos_notify
    AFTER INSERT ON app.student_home_videos
    FOR EACH ROW EXECUTE FUNCTION public.app_notify_student_home_content();

-- ============================================================
-- VÉRIFICATION FINALE
-- ============================================================
SELECT tgname, tgrelid::regclass AS table_name,
       (SELECT proname FROM pg_proc WHERE oid = tgfoid) AS function_name
FROM pg_trigger
WHERE NOT tgisinternal
  AND tgfoid IN (SELECT oid FROM pg_proc WHERE proname LIKE 'app_notify%')
ORDER BY tgname;
