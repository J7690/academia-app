#!/usr/bin/env python3
"""Phase 7 TD: Deploy matching RPCs one by one with proper escaping."""
import requests

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SK, "Authorization": f"Bearer {SK}", "Content-Type": "application/json"}

def sql_raw(q, label=""):
    """Send SQL without collapsing whitespace — preserve $fn$ blocks."""
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                       json={"p_sql": q}, timeout=60)
    body = r.json() if r.status_code == 200 else {"ok": False, "error": r.text[:500]}
    ok = isinstance(body, dict) and body.get("ok", False)
    err = body.get("error", "") if not ok else ""
    print(f"  {'OK' if ok else 'ERR'} {label} {('-- ' + err[:200]) if err else ''}")
    return ok

print("=" * 60)
print("PHASE 7 TD -- Matching RPCs v2")
print("=" * 60)

# RPC 1: Suggest groups for student
rpc1 = """CREATE OR REPLACE FUNCTION public.app_td_suggest_groups_for_student()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $$
DECLARE v_profile RECORD; v_result JSONB;
BEGIN
  SELECT * INTO v_profile FROM app.td_student_profiles WHERE student_id = auth.uid();
  IF v_profile IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'no_profile'); END IF;
  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.match_score DESC), '[]'::jsonb) INTO v_result
  FROM (
    SELECT g.id, g.subject, g.level, g.city, g.neighborhood, g.status, g.max_members, g.current_members,
           g.session_date, g.price_per_student, s.full_name AS teacher_name,
           (CASE WHEN g.subject = ANY(v_profile.subjects_needed) THEN 40 ELSE 0 END
            + CASE WHEN g.neighborhood = v_profile.neighborhood THEN 30 ELSE 0 END
            + CASE WHEN g.current_members < g.max_members THEN 20 ELSE 0 END
            + CASE WHEN g.assigned_teacher_id IS NOT NULL THEN 10 ELSE 0 END) AS match_score
    FROM app.td_local_groups g LEFT JOIN app.students s ON s.id = g.assigned_teacher_id
    WHERE g.status IN ('forming','confirmed') AND g.current_members < g.max_members
      AND NOT EXISTS (SELECT 1 FROM app.td_local_group_members m WHERE m.group_id = g.id AND m.student_id = auth.uid())
    LIMIT 10
  ) t;
  RETURN jsonb_build_object('success', true, 'suggestions', v_result);
END; $$;"""
sql_raw(rpc1, "RPC app_td_suggest_groups_for_student")

# RPC 2: Auto-match groups from seeking students
rpc2 = """CREATE OR REPLACE FUNCTION public.app_td_auto_match_groups(p_min_group_size INTEGER DEFAULT 3, p_max_group_size INTEGER DEFAULT 8)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $$
DECLARE rec RECORD; v_group_id UUID; v_groups_created INTEGER := 0; v_students_matched INTEGER := 0; v_student UUID;
BEGIN
  FOR rec IN
    SELECT unnest(p.subjects_needed) AS subject, p.neighborhood, array_agg(p.student_id) AS sids
    FROM app.td_student_profiles p
    WHERE p.is_seeking_group = true AND p.neighborhood IS NOT NULL AND array_length(p.subjects_needed,1) > 0
    GROUP BY unnest(p.subjects_needed), p.neighborhood HAVING COUNT(*) >= p_min_group_size
  LOOP
    IF NOT EXISTS (SELECT 1 FROM app.td_local_groups WHERE subject = rec.subject AND neighborhood = rec.neighborhood AND status IN ('forming','confirmed','active')) THEN
      INSERT INTO app.td_local_groups (subject, neighborhood, city, max_members, current_members, status, created_by)
      VALUES (rec.subject, rec.neighborhood, 'Ouagadougou', p_max_group_size, LEAST(array_length(rec.sids,1), p_max_group_size), 'forming', rec.sids[1])
      RETURNING id INTO v_group_id;
      FOREACH v_student IN ARRAY rec.sids[1:LEAST(array_length(rec.sids,1), p_max_group_size)] LOOP
        INSERT INTO app.td_local_group_members (group_id, student_id) VALUES (v_group_id, v_student) ON CONFLICT DO NOTHING;
      END LOOP;
      v_groups_created := v_groups_created + 1;
      v_students_matched := v_students_matched + LEAST(array_length(rec.sids,1), p_max_group_size);
    END IF;
  END LOOP;
  RETURN jsonb_build_object('success', true, 'groups_created', v_groups_created, 'students_matched', v_students_matched);
END; $$;"""
sql_raw(rpc2, "RPC app_td_auto_match_groups")

# RPC 3: Auto-assign teacher
rpc3 = """CREATE OR REPLACE FUNCTION public.app_td_auto_assign_teacher(p_group_id UUID DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $$
DECLARE rec RECORD; v_teacher_id UUID; v_assigned INTEGER := 0;
BEGIN
  FOR rec IN SELECT g.id AS gid, g.subject, g.neighborhood FROM app.td_local_groups g
    WHERE g.assigned_teacher_id IS NULL AND g.status IN ('forming','confirmed') AND (p_group_id IS NULL OR g.id = p_group_id)
  LOOP
    SELECT tp.teacher_id INTO v_teacher_id FROM app.td_teacher_profiles tp
    WHERE tp.is_available = true AND rec.subject = ANY(tp.specialties)
    ORDER BY CASE WHEN rec.neighborhood = ANY(tp.neighborhoods) THEN 0 ELSE 1 END, tp.rating DESC LIMIT 1;
    IF v_teacher_id IS NOT NULL THEN
      UPDATE app.td_local_groups SET assigned_teacher_id = v_teacher_id, status = 'confirmed', updated_at = now() WHERE id = rec.gid;
      v_assigned := v_assigned + 1;
    END IF;
  END LOOP;
  RETURN jsonb_build_object('success', true, 'assigned', v_assigned);
END; $$;"""
sql_raw(rpc3, "RPC app_td_auto_assign_teacher")

# Verify
print("\n--- VERIFICATION ---")
sql_raw("SELECT routine_name FROM information_schema.routines WHERE routine_name IN ('app_td_suggest_groups_for_student','app_td_auto_match_groups','app_td_auto_assign_teacher') ORDER BY routine_name", "Matching RPCs")
