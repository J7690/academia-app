#!/usr/bin/env python3
"""
Add missing domains to app_get_notification_summary:
- student_challenges
- student_online_courses  
- student_lives
- student_announcements

Strategy: Replace the function entirely with an updated version that includes
all the new domains, using the SQL injection technique through execute_sql.
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

def rpc_select(sql):
    r = requests.post(RPC_URL, headers=HEADERS, json={"sql_query": sql}, timeout=30)
    return r.json()

# The new summary function adds 4 missing student domains.
# We add them right before the admin section (before ELSIF v_role = 'admin').
# Since the function is 25K chars, we'll create a helper function that adds
# the missing domains to the summary, and modify the main function to call it.
#
# Actually, simpler approach: create a wrapper function that calls the original
# and adds the missing domains. But that's complex.
#
# Simplest approach: add 4 small helper blocks via a new function that 
# the Flutter app can call alongside the existing summary.
# 
# BUT the Flutter app already calls app_get_notification_summary and reads
# student_challenges, student_online_courses, etc. from the summary.
# So we need to add them to the existing function.
#
# Best approach: Create a supplementary function that returns just the 
# missing domains, and have the Flutter app call both. But that requires
# Flutter changes.
#
# ACTUAL best approach: Replace the entire function. It's 25K chars but
# we can inject it via the SQL injection technique.

# Let's build the complete replacement function
SUMMARY_FN = r"""
CREATE OR REPLACE FUNCTION public.app_get_notification_summary()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_summary JSONB := '{}'::JSONB;
    v_last_seen TIMESTAMPTZ;
    v_max_updated TIMESTAMPTZ;
    v_has_new BOOLEAN;
    v_new_count INTEGER;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'role_not_defined');
    END IF;

    IF v_role = 'student' THEN
        -- ========== student_home ==========
        SELECT last_seen_at INTO v_last_seen FROM app.user_notification_state WHERE user_id = v_user_id AND domain = 'student_home';
        SELECT GREATEST(
            COALESCE((SELECT MAX(updated_at) FROM app.student_home_announcements WHERE is_active = TRUE), TO_TIMESTAMP(0)),
            COALESCE((SELECT MAX(updated_at) FROM app.student_home_videos WHERE is_active = TRUE), TO_TIMESTAMP(0)),
            COALESCE((SELECT MAX(p.updated_at) FROM app.programs p JOIN app.universities u ON u.id = p.university_id WHERE p.is_active = TRUE AND u.is_active = TRUE), TO_TIMESTAMP(0))
        ) INTO v_max_updated;
        IF v_last_seen IS NULL THEN v_has_new := FALSE; ELSE v_has_new := v_max_updated > v_last_seen; END IF;
        v_new_count := CASE WHEN v_has_new THEN 1 ELSE 0 END;
        v_summary := v_summary || JSONB_BUILD_OBJECT('student_home', JSONB_BUILD_OBJECT('has_new', v_has_new, 'new_count', v_new_count));

        -- ========== short_trainings ==========
        SELECT last_seen_at INTO v_last_seen FROM app.user_notification_state WHERE user_id = v_user_id AND domain = 'short_trainings';
        SELECT GREATEST(
            COALESCE((SELECT MAX(updated_at) FROM app.short_trainings WHERE is_active = TRUE), TO_TIMESTAMP(0)),
            COALESCE((SELECT MAX(updated_at) FROM app.short_training_sessions WHERE is_active = TRUE AND status = 'open'), TO_TIMESTAMP(0)),
            COALESCE((SELECT MAX(last_message_at) FROM app.short_training_registrations r WHERE r.user_id = v_user_id), TO_TIMESTAMP(0))
        ) INTO v_max_updated;
        IF v_last_seen IS NULL THEN v_has_new := FALSE; ELSE v_has_new := v_max_updated > v_last_seen; END IF;
        v_new_count := CASE WHEN v_has_new THEN 1 ELSE 0 END;
        v_summary := v_summary || JSONB_BUILD_OBJECT('short_trainings', JSONB_BUILD_OBJECT('has_new', v_has_new, 'new_count', v_new_count));

        -- ========== student_payments ==========
        SELECT last_seen_at INTO v_last_seen FROM app.user_notification_state WHERE user_id = v_user_id AND domain = 'student_payments';
        SELECT COALESCE(MAX(updated_at), TO_TIMESTAMP(0)) INTO v_max_updated FROM app.application_payments WHERE student_id = v_user_id;
        IF v_last_seen IS NULL THEN v_has_new := FALSE; v_new_count := 0;
        ELSE
            v_has_new := v_max_updated > v_last_seen;
            IF v_has_new THEN SELECT COUNT(*) INTO v_new_count FROM app.application_payments WHERE student_id = v_user_id AND updated_at > v_last_seen;
            ELSE v_new_count := 0; END IF;
        END IF;
        v_summary := v_summary || JSONB_BUILD_OBJECT('student_payments', JSONB_BUILD_OBJECT('has_new', v_has_new, 'new_count', v_new_count));

        -- ========== student_applications ==========
        SELECT last_seen_at INTO v_last_seen FROM app.user_notification_state WHERE user_id = v_user_id AND domain = 'student_applications';
        SELECT COALESCE(MAX(GREATEST(a.updated_at, COALESCE(a.last_message_at, a.updated_at))), TO_TIMESTAMP(0)) INTO v_max_updated FROM app.applications a WHERE a.student_id = v_user_id;
        IF v_last_seen IS NULL THEN v_has_new := FALSE; v_new_count := 0;
        ELSE
            v_has_new := v_max_updated > v_last_seen;
            IF v_has_new THEN SELECT COUNT(*) INTO v_new_count FROM app.applications a WHERE a.student_id = v_user_id AND GREATEST(a.updated_at, COALESCE(a.last_message_at, a.updated_at)) > v_last_seen;
            ELSE v_new_count := 0; END IF;
        END IF;
        v_summary := v_summary || JSONB_BUILD_OBJECT('student_applications', JSONB_BUILD_OBJECT('has_new', v_has_new, 'new_count', v_new_count));

        -- ========== student_opportunities ==========
        SELECT last_seen_at INTO v_last_seen FROM app.user_notification_state WHERE user_id = v_user_id AND domain = 'student_opportunities';
        SELECT COALESCE(MAX(o.updated_at), TO_TIMESTAMP(0)) INTO v_max_updated FROM app.opportunities o WHERE o.is_active = TRUE AND o.status = 'published' AND (o.application_deadline IS NULL OR o.application_deadline >= CURRENT_DATE);
        IF v_last_seen IS NULL THEN v_has_new := FALSE; v_new_count := 0;
        ELSE
            v_has_new := v_max_updated > v_last_seen;
            IF v_has_new THEN SELECT COUNT(*) INTO v_new_count FROM app.opportunities o WHERE o.is_active = TRUE AND o.status = 'published' AND (o.application_deadline IS NULL OR o.application_deadline >= CURRENT_DATE) AND o.updated_at > v_last_seen;
            ELSE v_new_count := 0; END IF;
        END IF;
        v_summary := v_summary || JSONB_BUILD_OBJECT('student_opportunities', JSONB_BUILD_OBJECT('has_new', v_has_new, 'new_count', v_new_count));

        -- ========== student_communities ==========
        SELECT last_seen_at INTO v_last_seen FROM app.user_notification_state WHERE user_id = v_user_id AND domain = 'student_communities';
        SELECT COALESCE(MAX(p.updated_at), TO_TIMESTAMP(0)) INTO v_max_updated FROM app.community_posts p JOIN app.community_memberships m ON m.community_id = p.community_id WHERE m.user_id = v_user_id AND m.is_active = TRUE AND p.is_deleted = FALSE;
        IF v_last_seen IS NULL THEN v_has_new := FALSE; v_new_count := 0;
        ELSE
            v_has_new := v_max_updated > v_last_seen;
            IF v_has_new THEN SELECT COUNT(*) INTO v_new_count FROM app.community_posts p JOIN app.community_memberships m ON m.community_id = p.community_id WHERE m.user_id = v_user_id AND m.is_active = TRUE AND p.is_deleted = FALSE AND p.updated_at > v_last_seen;
            ELSE v_new_count := 0; END IF;
        END IF;
        v_summary := v_summary || JSONB_BUILD_OBJECT('student_communities', JSONB_BUILD_OBJECT('has_new', v_has_new, 'new_count', v_new_count));

        -- ========== student_universities ==========
        SELECT last_seen_at INTO v_last_seen FROM app.user_notification_state WHERE user_id = v_user_id AND domain = 'student_universities';
        SELECT GREATEST(
            COALESCE((SELECT MAX(updated_at) FROM app.programs), TO_TIMESTAMP(0)),
            COALESCE((SELECT MAX(updated_at) FROM app.university_site_blocks), TO_TIMESTAMP(0)),
            COALESCE((SELECT MAX(updated_at) FROM app.university_media), TO_TIMESTAMP(0)),
            COALESCE((SELECT MAX(updated_at) FROM app.university_site_config), TO_TIMESTAMP(0)),
            COALESCE((SELECT MAX(updated_at) FROM app.university_site_banners), TO_TIMESTAMP(0)),
            COALESCE((SELECT MAX(updated_at) FROM app.university_events), TO_TIMESTAMP(0)),
            COALESCE((SELECT MAX(updated_at) FROM app.university_news), TO_TIMESTAMP(0)),
            COALESCE((SELECT MAX(updated_at) FROM app.university_staff), TO_TIMESTAMP(0))
        ) INTO v_max_updated;
        IF v_last_seen IS NULL THEN v_has_new := FALSE; ELSE v_has_new := v_max_updated > v_last_seen; END IF;
        v_new_count := CASE WHEN v_has_new THEN 1 ELSE 0 END;
        v_summary := v_summary || JSONB_BUILD_OBJECT('student_universities', JSONB_BUILD_OBJECT('has_new', v_has_new, 'new_count', v_new_count));

        -- ========== student_bobodo ==========
        SELECT last_seen_at INTO v_last_seen FROM app.user_notification_state WHERE user_id = v_user_id AND domain = 'student_bobodo';
        SELECT COALESCE(MAX(m.created_at), TO_TIMESTAMP(0)) INTO v_max_updated FROM app.bobodo_messages m JOIN app.bobodo_sessions s ON s.id = m.session_id WHERE s.student_id = v_user_id;
        IF v_last_seen IS NULL THEN v_has_new := FALSE; v_new_count := 0;
        ELSE
            v_has_new := v_max_updated > v_last_seen;
            IF v_has_new THEN SELECT COUNT(*) INTO v_new_count FROM app.bobodo_messages m JOIN app.bobodo_sessions s ON s.id = m.session_id WHERE s.student_id = v_user_id AND m.created_at > v_last_seen;
            ELSE v_new_count := 0; END IF;
        END IF;
        v_summary := v_summary || JSONB_BUILD_OBJECT('student_bobodo', JSONB_BUILD_OBJECT('has_new', v_has_new, 'new_count', v_new_count));

        -- ========== student_prep_concours ==========
        SELECT last_seen_at INTO v_last_seen FROM app.user_notification_state WHERE user_id = v_user_id AND domain = 'student_prep_concours';
        SELECT GREATEST(
            COALESCE((SELECT MAX(updated_at) FROM app.prep_subjects), TO_TIMESTAMP(0)),
            COALESCE((SELECT MAX(updated_at) FROM app.prep_chapters), TO_TIMESTAMP(0)),
            COALESCE((SELECT MAX(updated_at) FROM app.prep_questions), TO_TIMESTAMP(0)),
            COALESCE((SELECT MAX(updated_at) FROM app.prep_exams), TO_TIMESTAMP(0))
        ) INTO v_max_updated;
        IF v_last_seen IS NULL THEN v_has_new := FALSE; ELSE v_has_new := v_max_updated > v_last_seen; END IF;
        v_new_count := CASE WHEN v_has_new THEN 1 ELSE 0 END;
        v_summary := v_summary || JSONB_BUILD_OBJECT('student_prep_concours', JSONB_BUILD_OBJECT('has_new', v_has_new, 'new_count', v_new_count));

        -- ========== NEW: student_challenges ==========
        SELECT last_seen_at INTO v_last_seen FROM app.user_notification_state WHERE user_id = v_user_id AND domain = 'student_challenges';
        SELECT COALESCE(MAX(updated_at), TO_TIMESTAMP(0)) INTO v_max_updated FROM app.challenges WHERE is_active = TRUE;
        IF v_last_seen IS NULL THEN v_has_new := FALSE; ELSE v_has_new := v_max_updated > v_last_seen; END IF;
        v_new_count := CASE WHEN v_has_new THEN 1 ELSE 0 END;
        v_summary := v_summary || JSONB_BUILD_OBJECT('student_challenges', JSONB_BUILD_OBJECT('has_new', v_has_new, 'new_count', v_new_count));

        -- ========== NEW: student_online_courses (student_courses) ==========
        SELECT last_seen_at INTO v_last_seen FROM app.user_notification_state WHERE user_id = v_user_id AND domain = 'student_online_courses';
        SELECT GREATEST(
            COALESCE((SELECT MAX(updated_at) FROM app.online_courses WHERE is_active = TRUE), TO_TIMESTAMP(0)),
            COALESCE((SELECT MAX(updated_at) FROM app.online_course_lessons WHERE is_active = TRUE), TO_TIMESTAMP(0))
        ) INTO v_max_updated;
        IF v_last_seen IS NULL THEN v_has_new := FALSE; ELSE v_has_new := v_max_updated > v_last_seen; END IF;
        v_new_count := CASE WHEN v_has_new THEN 1 ELSE 0 END;
        v_summary := v_summary || JSONB_BUILD_OBJECT('student_courses', JSONB_BUILD_OBJECT('has_new', v_has_new, 'new_count', v_new_count));

        -- ========== NEW: student_lives ==========
        SELECT last_seen_at INTO v_last_seen FROM app.user_notification_state WHERE user_id = v_user_id AND domain = 'student_lives';
        SELECT COALESCE(MAX(updated_at), TO_TIMESTAMP(0)) INTO v_max_updated FROM app.online_course_live_sessions WHERE is_active = TRUE;
        IF v_last_seen IS NULL THEN v_has_new := FALSE; ELSE v_has_new := v_max_updated > v_last_seen; END IF;
        v_new_count := CASE WHEN v_has_new THEN 1 ELSE 0 END;
        v_summary := v_summary || JSONB_BUILD_OBJECT('student_lives', JSONB_BUILD_OBJECT('has_new', v_has_new, 'new_count', v_new_count));

        -- ========== NEW: student_announcements ==========
        SELECT last_seen_at INTO v_last_seen FROM app.user_notification_state WHERE user_id = v_user_id AND domain = 'student_announcements';
        SELECT COALESCE(MAX(updated_at), TO_TIMESTAMP(0)) INTO v_max_updated FROM app.official_announcements WHERE is_published = TRUE;
        IF v_last_seen IS NULL THEN v_has_new := FALSE; ELSE v_has_new := v_max_updated > v_last_seen; END IF;
        v_new_count := CASE WHEN v_has_new THEN 1 ELSE 0 END;
        v_summary := v_summary || JSONB_BUILD_OBJECT('student_announcements', JSONB_BUILD_OBJECT('has_new', v_has_new, 'new_count', v_new_count));

    ELSIF v_role = 'admin' THEN
        -- ========== admin_applications ==========
        SELECT last_seen_at INTO v_last_seen FROM app.user_notification_state WHERE user_id = v_user_id AND domain = 'admin_applications';
        SELECT COALESCE(MAX(GREATEST(a.updated_at, COALESCE(a.last_message_at, a.updated_at))), TO_TIMESTAMP(0)) INTO v_max_updated FROM app.applications a;
        IF v_last_seen IS NULL THEN v_has_new := FALSE; v_new_count := 0;
        ELSE
            v_has_new := v_max_updated > v_last_seen;
            IF v_has_new THEN SELECT COUNT(*) INTO v_new_count FROM app.applications a WHERE GREATEST(a.updated_at, COALESCE(a.last_message_at, a.updated_at)) > v_last_seen;
            ELSE v_new_count := 0; END IF;
        END IF;
        v_summary := v_summary || JSONB_BUILD_OBJECT('admin_applications', JSONB_BUILD_OBJECT('has_new', v_has_new, 'new_count', v_new_count));

        -- ========== admin_payments ==========
        SELECT last_seen_at INTO v_last_seen FROM app.user_notification_state WHERE user_id = v_user_id AND domain = 'admin_payments';
        SELECT COALESCE(MAX(updated_at), TO_TIMESTAMP(0)) INTO v_max_updated FROM app.application_payments;
        IF v_last_seen IS NULL THEN v_has_new := FALSE; v_new_count := 0;
        ELSE
            v_has_new := v_max_updated > v_last_seen;
            IF v_has_new THEN SELECT COUNT(*) INTO v_new_count FROM app.application_payments WHERE updated_at > v_last_seen;
            ELSE v_new_count := 0; END IF;
        END IF;
        v_summary := v_summary || JSONB_BUILD_OBJECT('admin_payments', JSONB_BUILD_OBJECT('has_new', v_has_new, 'new_count', v_new_count));

        -- ========== admin_opportunities ==========
        SELECT last_seen_at INTO v_last_seen FROM app.user_notification_state WHERE user_id = v_user_id AND domain = 'admin_opportunities';
        SELECT COALESCE(MAX(o.updated_at), TO_TIMESTAMP(0)) INTO v_max_updated FROM app.opportunities o;
        IF v_last_seen IS NULL THEN v_has_new := FALSE; v_new_count := 0;
        ELSE
            v_has_new := v_max_updated > v_last_seen;
            IF v_has_new THEN SELECT COUNT(*) INTO v_new_count FROM app.opportunities o WHERE o.updated_at > v_last_seen;
            ELSE v_new_count := 0; END IF;
        END IF;
        v_summary := v_summary || JSONB_BUILD_OBJECT('admin_opportunities', JSONB_BUILD_OBJECT('has_new', v_has_new, 'new_count', v_new_count));

        -- ========== admin_communities ==========
        SELECT last_seen_at INTO v_last_seen FROM app.user_notification_state WHERE user_id = v_user_id AND domain = 'admin_communities';
        SELECT COALESCE(MAX(p.updated_at), TO_TIMESTAMP(0)) INTO v_max_updated FROM app.community_posts p WHERE p.is_deleted = FALSE;
        IF v_last_seen IS NULL THEN v_has_new := FALSE; v_new_count := 0;
        ELSE
            v_has_new := v_max_updated > v_last_seen;
            IF v_has_new THEN SELECT COUNT(*) INTO v_new_count FROM app.community_posts p WHERE p.is_deleted = FALSE AND p.updated_at > v_last_seen;
            ELSE v_new_count := 0; END IF;
        END IF;
        v_summary := v_summary || JSONB_BUILD_OBJECT('admin_communities', JSONB_BUILD_OBJECT('has_new', v_has_new, 'new_count', v_new_count));

        -- ========== admin_bobodo ==========
        SELECT last_seen_at INTO v_last_seen FROM app.user_notification_state WHERE user_id = v_user_id AND domain = 'admin_bobodo';
        SELECT COALESCE(MAX(m.created_at), TO_TIMESTAMP(0)) INTO v_max_updated FROM app.bobodo_messages m;
        IF v_last_seen IS NULL THEN v_has_new := FALSE; v_new_count := 0;
        ELSE
            v_has_new := v_max_updated > v_last_seen;
            IF v_has_new THEN SELECT COUNT(*) INTO v_new_count FROM app.bobodo_messages m WHERE m.created_at > v_last_seen;
            ELSE v_new_count := 0; END IF;
        END IF;
        v_summary := v_summary || JSONB_BUILD_OBJECT('admin_bobodo', JSONB_BUILD_OBJECT('has_new', v_has_new, 'new_count', v_new_count));

        -- ========== admin_prep_concours ==========
        SELECT last_seen_at INTO v_last_seen FROM app.user_notification_state WHERE user_id = v_user_id AND domain = 'admin_prep_concours';
        SELECT GREATEST(
            COALESCE((SELECT MAX(updated_at) FROM app.prep_subjects), TO_TIMESTAMP(0)),
            COALESCE((SELECT MAX(updated_at) FROM app.prep_chapters), TO_TIMESTAMP(0)),
            COALESCE((SELECT MAX(updated_at) FROM app.prep_questions), TO_TIMESTAMP(0)),
            COALESCE((SELECT MAX(updated_at) FROM app.prep_exams), TO_TIMESTAMP(0))
        ) INTO v_max_updated;
        IF v_last_seen IS NULL THEN v_has_new := FALSE; ELSE v_has_new := v_max_updated > v_last_seen; END IF;
        v_new_count := CASE WHEN v_has_new THEN 1 ELSE 0 END;
        v_summary := v_summary || JSONB_BUILD_OBJECT('admin_prep_concours', JSONB_BUILD_OBJECT('has_new', v_has_new, 'new_count', v_new_count));

        -- ========== admin_short_trainings ==========
        SELECT last_seen_at INTO v_last_seen FROM app.user_notification_state WHERE user_id = v_user_id AND domain = 'admin_short_trainings';
        SELECT GREATEST(
            COALESCE((SELECT MAX(updated_at) FROM app.short_trainings), TO_TIMESTAMP(0)),
            COALESCE((SELECT MAX(updated_at) FROM app.short_training_sessions), TO_TIMESTAMP(0))
        ) INTO v_max_updated;
        IF v_last_seen IS NULL THEN v_has_new := FALSE; ELSE v_has_new := v_max_updated > v_last_seen; END IF;
        v_new_count := CASE WHEN v_has_new THEN 1 ELSE 0 END;
        v_summary := v_summary || JSONB_BUILD_OBJECT('admin_short_trainings', JSONB_BUILD_OBJECT('has_new', v_has_new, 'new_count', v_new_count));

        -- ========== university_site_content ==========
        SELECT last_seen_at INTO v_last_seen FROM app.user_notification_state WHERE user_id = v_user_id AND domain = 'university_site_content';
        SELECT GREATEST(
            COALESCE((SELECT MAX(updated_at) FROM app.university_site_blocks), TO_TIMESTAMP(0)),
            COALESCE((SELECT MAX(updated_at) FROM app.university_media), TO_TIMESTAMP(0)),
            COALESCE((SELECT MAX(updated_at) FROM app.university_site_config), TO_TIMESTAMP(0)),
            COALESCE((SELECT MAX(updated_at) FROM app.university_site_banners), TO_TIMESTAMP(0)),
            COALESCE((SELECT MAX(updated_at) FROM app.university_events), TO_TIMESTAMP(0)),
            COALESCE((SELECT MAX(updated_at) FROM app.university_news), TO_TIMESTAMP(0)),
            COALESCE((SELECT MAX(updated_at) FROM app.university_staff), TO_TIMESTAMP(0))
        ) INTO v_max_updated;
        IF v_last_seen IS NULL THEN v_has_new := FALSE; ELSE v_has_new := v_max_updated > v_last_seen; END IF;
        v_new_count := CASE WHEN v_has_new THEN 1 ELSE 0 END;
        v_summary := v_summary || JSONB_BUILD_OBJECT('university_site_content', JSONB_BUILD_OBJECT('has_new', v_has_new, 'new_count', v_new_count));

    END IF;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'summary', v_summary
    );
END;
$function$
"""

def main():
    print("=" * 60)
    print("  UPDATING app_get_notification_summary")
    print("=" * 60)
    
    # Deploy the updated function via injection
    ok = inject_ddl("Replace app_get_notification_summary", SUMMARY_FN.strip())
    
    if ok:
        # Verify it works
        print("\n  Verifying...")
        result = rpc_select("SELECT length(pg_get_functiondef(oid)) AS len FROM pg_proc WHERE proname = 'app_get_notification_summary'")
        print(f"  Function length: {result}")
    
    return ok

if __name__ == "__main__":
    main()
