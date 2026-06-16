#!/usr/bin/env python3
"""Phase 8 TD: Deploy notification triggers + workflow RPCs."""
import requests

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SK, "Authorization": f"Bearer {SK}", "Content-Type": "application/json"}

def sql_raw(q, label=""):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                       json={"p_sql": q}, timeout=60)
    body = r.json() if r.status_code == 200 else {"ok": False, "error": r.text[:500]}
    ok = isinstance(body, dict) and body.get("ok", False)
    err = body.get("error", "") if not ok else ""
    print(f"  {'OK' if ok else 'ERR'} {label} {('-- ' + err[:200]) if err else ''}")
    return ok

print("=" * 60)
print("PHASE 8 TD -- Notifications + Workflow RPCs")
print("=" * 60)

# ═══════════════════════════════════════════════════════════════
# A: Notification functions (insert into notification_events)
# ═══════════════════════════════════════════════════════════════
print("\n--- A: Notification functions ---")

# Notify when teacher is assigned to a group
sql_raw("""CREATE OR REPLACE FUNCTION app.app_notify_td_group_teacher_assigned()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.assigned_teacher_id IS NOT NULL AND (OLD.assigned_teacher_id IS NULL OR OLD.assigned_teacher_id != NEW.assigned_teacher_id) THEN
    INSERT INTO app.notification_events (user_id, domain, event_type, payload)
    VALUES (NEW.assigned_teacher_id, 'td_local_groups', 'teacher_assigned',
      jsonb_build_object('group_id', NEW.id, 'subject', NEW.subject, 'neighborhood', NEW.neighborhood, 'members', NEW.current_members));
  END IF;
  RETURN NEW;
END; $$;""", "FUNC notify_td_group_teacher_assigned")

# Notify group members when status changes (confirmed, active)
sql_raw("""CREATE OR REPLACE FUNCTION app.app_notify_td_group_status_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_member RECORD;
BEGIN
  IF NEW.status != OLD.status AND NEW.status IN ('confirmed', 'active') THEN
    FOR v_member IN SELECT student_id FROM app.td_local_group_members WHERE group_id = NEW.id LOOP
      INSERT INTO app.notification_events (user_id, domain, event_type, payload)
      VALUES (v_member.student_id, 'td_local_groups', 'group_' || NEW.status,
        jsonb_build_object('group_id', NEW.id, 'subject', NEW.subject, 'neighborhood', NEW.neighborhood, 'status', NEW.status));
    END LOOP;
  END IF;
  RETURN NEW;
END; $$;""", "FUNC notify_td_group_status_change")

# Notify when new member joins
sql_raw("""CREATE OR REPLACE FUNCTION app.app_notify_td_group_member_joined()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_group RECORD; v_member RECORD; v_name TEXT;
BEGIN
  SELECT * INTO v_group FROM app.td_local_groups WHERE id = NEW.group_id;
  SELECT full_name INTO v_name FROM app.students WHERE id = NEW.student_id;
  FOR v_member IN SELECT student_id FROM app.td_local_group_members WHERE group_id = NEW.group_id AND student_id != NEW.student_id LOOP
    INSERT INTO app.notification_events (user_id, domain, event_type, payload)
    VALUES (v_member.student_id, 'td_local_groups', 'member_joined',
      jsonb_build_object('group_id', NEW.group_id, 'subject', v_group.subject, 'member_name', v_name));
  END LOOP;
  RETURN NEW;
END; $$;""", "FUNC notify_td_group_member_joined")

# ═══════════════════════════════════════════════════════════════
# B: Triggers
# ═══════════════════════════════════════════════════════════════
print("\n--- B: Triggers ---")

sql_raw("""DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.triggers WHERE trigger_name = 'trg_td_group_teacher_assigned' AND event_object_table = 'td_local_groups') THEN
    CREATE TRIGGER trg_td_group_teacher_assigned AFTER UPDATE ON app.td_local_groups
    FOR EACH ROW EXECUTE FUNCTION app.app_notify_td_group_teacher_assigned();
  END IF;
END $$;""", "TRIGGER trg_td_group_teacher_assigned")

sql_raw("""DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.triggers WHERE trigger_name = 'trg_td_group_status_change' AND event_object_table = 'td_local_groups') THEN
    CREATE TRIGGER trg_td_group_status_change AFTER UPDATE ON app.td_local_groups
    FOR EACH ROW EXECUTE FUNCTION app.app_notify_td_group_status_change();
  END IF;
END $$;""", "TRIGGER trg_td_group_status_change")

sql_raw("""DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.triggers WHERE trigger_name = 'trg_td_group_member_joined' AND event_object_table = 'td_local_group_members') THEN
    CREATE TRIGGER trg_td_group_member_joined AFTER INSERT ON app.td_local_group_members
    FOR EACH ROW EXECUTE FUNCTION app.app_notify_td_group_member_joined();
  END IF;
END $$;""", "TRIGGER trg_td_group_member_joined")

# ═══════════════════════════════════════════════════════════════
# C: Workflow RPCs (complete session + rate teacher)
# ═══════════════════════════════════════════════════════════════
print("\n--- C: Workflow RPCs ---")

sql_raw("""CREATE OR REPLACE FUNCTION public.app_td_teacher_complete_session(
  p_session_id UUID, p_notes TEXT DEFAULT NULL, p_attendance JSONB DEFAULT '[]'::jsonb
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $$
BEGIN
  UPDATE app.td_physical_sessions SET status = 'completed', notes = COALESCE(p_notes, notes), attendance = COALESCE(p_attendance, attendance)
  WHERE id = p_session_id AND teacher_id = auth.uid();
  UPDATE app.td_teacher_profiles SET total_sessions = total_sessions + 1, updated_at = now()
  WHERE teacher_id = auth.uid();
  RETURN jsonb_build_object('success', true);
END; $$;""", "RPC app_td_teacher_complete_session")

sql_raw("""CREATE OR REPLACE FUNCTION public.app_td_student_rate_session(
  p_session_id UUID, p_rating NUMERIC(3,2)
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $$
DECLARE v_teacher_id UUID; v_avg NUMERIC;
BEGIN
  SELECT teacher_id INTO v_teacher_id FROM app.td_physical_sessions WHERE id = p_session_id;
  IF v_teacher_id IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'session_not_found'); END IF;
  UPDATE app.td_physical_sessions SET teacher_rating = p_rating WHERE id = p_session_id;
  SELECT AVG(teacher_rating) INTO v_avg FROM app.td_physical_sessions WHERE teacher_id = v_teacher_id AND teacher_rating IS NOT NULL;
  UPDATE app.td_teacher_profiles SET rating = COALESCE(v_avg, 0), total_reviews = total_reviews + 1, updated_at = now()
  WHERE teacher_id = v_teacher_id;
  RETURN jsonb_build_object('success', true, 'new_avg_rating', v_avg);
END; $$;""", "RPC app_td_student_rate_session")

# RPC to create a physical session from a group
sql_raw("""CREATE OR REPLACE FUNCTION public.app_td_teacher_create_physical_session(
  p_group_id UUID, p_session_date DATE, p_start_time TEXT DEFAULT NULL,
  p_end_time TEXT DEFAULT NULL, p_location TEXT DEFAULT NULL
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $$
DECLARE v_id UUID;
BEGIN
  INSERT INTO app.td_physical_sessions (group_id, teacher_id, session_date, start_time, end_time, location, status)
  VALUES (p_group_id, auth.uid(), p_session_date, p_start_time, p_end_time, p_location, 'planned')
  RETURNING id INTO v_id;
  UPDATE app.td_local_groups SET status = 'active', session_date = p_session_date, updated_at = now() WHERE id = p_group_id;
  RETURN jsonb_build_object('success', true, 'id', v_id);
END; $$;""", "RPC app_td_teacher_create_physical_session")

# ═══════════════════════════════════════════════════════════════
# VERIFICATION
# ═══════════════════════════════════════════════════════════════
print("\n--- VERIFICATION ---")
sql_raw("SELECT trigger_name, event_object_table FROM information_schema.triggers WHERE trigger_schema='app' AND event_object_table IN ('td_local_groups','td_local_group_members') ORDER BY trigger_name", "New triggers")
sql_raw("SELECT routine_name FROM information_schema.routines WHERE routine_name IN ('app_td_teacher_complete_session','app_td_student_rate_session','app_td_teacher_create_physical_session','app_notify_td_group_teacher_assigned','app_notify_td_group_status_change','app_notify_td_group_member_joined') ORDER BY routine_name", "New RPCs + notify funcs")
print("\nPhase 8 SQL complete!")
