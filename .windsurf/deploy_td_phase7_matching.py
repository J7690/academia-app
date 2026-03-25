#!/usr/bin/env python3
"""Phase 7 TD: Deploy matching algorithm RPCs."""
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
print("PHASE 7 TD -- Matching algorithm RPCs")
print("=" * 60)

# RPC 1: Suggest groups for a student based on their profile
sql("""
CREATE OR REPLACE FUNCTION public.app_td_suggest_groups_for_student()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $fn$
DECLARE
    v_profile RECORD;
    v_result JSONB;
BEGIN
    SELECT * INTO v_profile FROM app.td_student_profiles WHERE student_id = auth.uid();
    IF v_profile IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'no_profile');
    END IF;

    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.match_score DESC), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT g.id, g.subject, g.level, g.city, g.neighborhood, g.status,
               g.max_members, g.current_members, g.session_date, g.price_per_student,
               s.full_name AS teacher_name,
               -- Match score: higher = better match
               (CASE WHEN g.subject = ANY(v_profile.subjects_needed) THEN 40 ELSE 0 END
                + CASE WHEN g.neighborhood = v_profile.neighborhood THEN 30 ELSE 0 END
                + CASE WHEN g.current_members < g.max_members THEN 20 ELSE 0 END
                + CASE WHEN g.assigned_teacher_id IS NOT NULL THEN 10 ELSE 0 END
               ) AS match_score
        FROM app.td_local_groups g
        LEFT JOIN app.students s ON s.id = g.assigned_teacher_id
        WHERE g.status IN ('forming', 'confirmed')
          AND g.current_members < g.max_members
          AND NOT EXISTS (SELECT 1 FROM app.td_local_group_members m WHERE m.group_id = g.id AND m.student_id = auth.uid())
        ORDER BY match_score DESC
        LIMIT 10
    ) t;

    RETURN jsonb_build_object('success', true, 'suggestions', v_result);
END; $fn$;
""", "RPC app_td_suggest_groups_for_student")

# RPC 2: Auto-match — create groups from seeking students (admin/system)
sql("""
CREATE OR REPLACE FUNCTION public.app_td_auto_match_groups(
    p_min_group_size INTEGER DEFAULT 3,
    p_max_group_size INTEGER DEFAULT 8
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $fn$
DECLARE
    v_subject TEXT;
    v_neighborhood TEXT;
    v_students UUID[];
    v_group_id UUID;
    v_groups_created INTEGER := 0;
    v_students_matched INTEGER := 0;
    rec RECORD;
BEGIN
    -- Find clusters: same subject_needed + same neighborhood + seeking
    FOR rec IN
        SELECT unnest(p.subjects_needed) AS subject, p.neighborhood, array_agg(p.student_id) AS student_ids
        FROM app.td_student_profiles p
        WHERE p.is_seeking_group = true
          AND p.neighborhood IS NOT NULL
          AND array_length(p.subjects_needed, 1) > 0
        GROUP BY unnest(p.subjects_needed), p.neighborhood
        HAVING COUNT(*) >= p_min_group_size
        ORDER BY COUNT(*) DESC
    LOOP
        v_subject := rec.subject;
        v_neighborhood := rec.neighborhood;
        v_students := rec.student_ids;

        -- Limit to max group size
        IF array_length(v_students, 1) > p_max_group_size THEN
            v_students := v_students[1:p_max_group_size];
        END IF;

        -- Check no existing forming group for this subject+neighborhood
        IF NOT EXISTS (
            SELECT 1 FROM app.td_local_groups
            WHERE subject = v_subject AND neighborhood = v_neighborhood AND status IN ('forming', 'confirmed', 'active')
        ) THEN
            -- Create group
            INSERT INTO app.td_local_groups (subject, neighborhood, city, max_members, current_members, status, created_by)
            VALUES (v_subject, v_neighborhood, 'Ouagadougou', p_max_group_size, array_length(v_students, 1), 'forming', v_students[1])
            RETURNING id INTO v_group_id;

            -- Add members
            FOR i IN 1..array_length(v_students, 1) LOOP
                INSERT INTO app.td_local_group_members (group_id, student_id)
                VALUES (v_group_id, v_students[i])
                ON CONFLICT DO NOTHING;
            END LOOP;

            -- Mark students as no longer seeking for this subject
            -- (they can still seek for other subjects)

            v_groups_created := v_groups_created + 1;
            v_students_matched := v_students_matched + array_length(v_students, 1);
        END IF;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'groups_created', v_groups_created, 'students_matched', v_students_matched);
END; $fn$;
""", "RPC app_td_auto_match_groups")

# RPC 3: Auto-assign teacher to unassigned groups based on specialty + neighborhood
sql("""
CREATE OR REPLACE FUNCTION public.app_td_auto_assign_teacher(
    p_group_id UUID DEFAULT NULL
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $fn$
DECLARE
    v_assigned INTEGER := 0;
    rec RECORD;
    v_teacher_id UUID;
BEGIN
    FOR rec IN
        SELECT g.id AS group_id, g.subject, g.neighborhood
        FROM app.td_local_groups g
        WHERE g.assigned_teacher_id IS NULL
          AND g.status IN ('forming', 'confirmed')
          AND (p_group_id IS NULL OR g.id = p_group_id)
    LOOP
        -- Find best matching teacher
        SELECT tp.teacher_id INTO v_teacher_id
        FROM app.td_teacher_profiles tp
        WHERE tp.is_available = true
          AND rec.subject = ANY(tp.specialties)
          AND (rec.neighborhood = ANY(tp.neighborhoods) OR array_length(tp.neighborhoods, 1) IS NULL)
        ORDER BY
            CASE WHEN rec.neighborhood = ANY(tp.neighborhoods) THEN 0 ELSE 1 END,
            tp.rating DESC,
            tp.total_sessions DESC
        LIMIT 1;

        IF v_teacher_id IS NOT NULL THEN
            UPDATE app.td_local_groups SET assigned_teacher_id = v_teacher_id, status = 'confirmed', updated_at = now()
            WHERE id = rec.group_id;
            v_assigned := v_assigned + 1;
        END IF;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'assigned', v_assigned);
END; $fn$;
""", "RPC app_td_auto_assign_teacher")

# Verification
print("\n--- VERIFICATION ---")
sql("SELECT routine_name FROM information_schema.routines WHERE routine_name IN ('app_td_suggest_groups_for_student', 'app_td_auto_match_groups', 'app_td_auto_assign_teacher') ORDER BY routine_name", "Matching RPCs")
print("\nPhase 7 SQL complete!")
