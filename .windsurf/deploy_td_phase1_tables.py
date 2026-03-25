#!/usr/bin/env python3
"""Phase 1 TD: Deploy new tables for local groups, physical sessions, extended profiles."""
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
print("PHASE 1 TD -- Tables + RPCs + RLS")
print("=" * 60)

# ═══════════════════════════════════════════════════════════════
# A: TABLES
# ═══════════════════════════════════════════════════════════════
print("\n--- A: Tables ---")

sql("CREATE TABLE IF NOT EXISTS app.td_student_profiles (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), student_id UUID NOT NULL REFERENCES auth.users(id) UNIQUE, university TEXT, faculty TEXT, study_year TEXT, subjects_needed TEXT[] DEFAULT '{}', neighborhood TEXT, availability_days TEXT[] DEFAULT '{}', availability_times TEXT[] DEFAULT '{}', max_group_size INTEGER DEFAULT 6, is_seeking_group BOOLEAN DEFAULT false, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now())", "CREATE td_student_profiles")

sql("CREATE TABLE IF NOT EXISTS app.td_teacher_profiles (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), teacher_id UUID NOT NULL REFERENCES auth.users(id) UNIQUE, specialties TEXT[] DEFAULT '{}', universities TEXT[] DEFAULT '{}', neighborhoods TEXT[] DEFAULT '{}', max_distance_km INTEGER DEFAULT 10, hourly_rate INTEGER, availability_days TEXT[] DEFAULT '{}', availability_times TEXT[] DEFAULT '{}', rating NUMERIC(3,2) DEFAULT 0, total_sessions INTEGER DEFAULT 0, total_reviews INTEGER DEFAULT 0, is_available BOOLEAN DEFAULT true, bio TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now())", "CREATE td_teacher_profiles")

sql("CREATE TABLE IF NOT EXISTS app.td_local_groups (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), subject TEXT NOT NULL, level TEXT, city TEXT DEFAULT 'Ouagadougou', neighborhood TEXT, lat NUMERIC(10,7), lng NUMERIC(10,7), max_members INTEGER DEFAULT 8, current_members INTEGER DEFAULT 0, status TEXT NOT NULL DEFAULT 'forming', assigned_teacher_id UUID REFERENCES auth.users(id), session_date DATE, session_time TEXT, location_type TEXT DEFAULT 'to_define', location_address TEXT, price_per_student INTEGER, created_by UUID REFERENCES auth.users(id), created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now())", "CREATE td_local_groups")

sql("CREATE TABLE IF NOT EXISTS app.td_local_group_members (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), group_id UUID NOT NULL REFERENCES app.td_local_groups(id) ON DELETE CASCADE, student_id UUID NOT NULL REFERENCES auth.users(id), joined_at TIMESTAMPTZ DEFAULT now(), status TEXT DEFAULT 'active', UNIQUE(group_id, student_id))", "CREATE td_local_group_members")

sql("CREATE TABLE IF NOT EXISTS app.td_physical_sessions (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), group_id UUID NOT NULL REFERENCES app.td_local_groups(id) ON DELETE CASCADE, teacher_id UUID REFERENCES auth.users(id), session_date DATE NOT NULL, start_time TEXT, end_time TEXT, location TEXT, status TEXT DEFAULT 'planned', notes TEXT, attendance JSONB DEFAULT '[]'::jsonb, teacher_rating NUMERIC(3,2), created_at TIMESTAMPTZ NOT NULL DEFAULT now())", "CREATE td_physical_sessions")

# ═══════════════════════════════════════════════════════════════
# B: RLS
# ═══════════════════════════════════════════════════════════════
print("\n--- B: RLS ---")

tables = ["td_student_profiles", "td_teacher_profiles", "td_local_groups", "td_local_group_members", "td_physical_sessions"]
for t in tables:
    sql(f"ALTER TABLE app.{t} ENABLE ROW LEVEL SECURITY", f"ENABLE RLS {t}")
    time.sleep(0.1)

policies = [
    # service_role ALL
    ("sr_all_td_student_profiles", "td_student_profiles", "FOR ALL TO service_role USING (true) WITH CHECK (true)"),
    ("sr_all_td_teacher_profiles", "td_teacher_profiles", "FOR ALL TO service_role USING (true) WITH CHECK (true)"),
    ("sr_all_td_local_groups", "td_local_groups", "FOR ALL TO service_role USING (true) WITH CHECK (true)"),
    ("sr_all_td_local_group_members", "td_local_group_members", "FOR ALL TO service_role USING (true) WITH CHECK (true)"),
    ("sr_all_td_physical_sessions", "td_physical_sessions", "FOR ALL TO service_role USING (true) WITH CHECK (true)"),
    # Student own profile
    ("student_own_td_profile", "td_student_profiles", "FOR ALL TO public USING (student_id = auth.uid()) WITH CHECK (student_id = auth.uid())"),
    # Student see active groups
    ("student_select_td_groups", "td_local_groups", "FOR SELECT TO public USING (status IN (''forming'',''confirmed'',''active''))"),
    # Student own group membership
    ("student_own_group_member", "td_local_group_members", "FOR SELECT TO public USING (student_id = auth.uid())"),
    ("student_join_group", "td_local_group_members", "FOR INSERT TO public WITH CHECK (student_id = auth.uid())"),
    # Student see sessions for own groups
    ("student_see_sessions", "td_physical_sessions", "FOR SELECT TO public USING (EXISTS (SELECT 1 FROM app.td_local_group_members m WHERE m.group_id = td_physical_sessions.group_id AND m.student_id = auth.uid()))"),
    # Teacher own profile
    ("teacher_own_td_profile", "td_teacher_profiles", "FOR ALL TO public USING (teacher_id = auth.uid()) WITH CHECK (teacher_id = auth.uid())"),
    # Teacher see assigned groups
    ("teacher_see_assigned_groups", "td_local_groups", "FOR SELECT TO public USING (assigned_teacher_id = auth.uid())"),
    # Teacher manage assigned sessions
    ("teacher_manage_sessions", "td_physical_sessions", "FOR ALL TO public USING (teacher_id = auth.uid()) WITH CHECK (teacher_id = auth.uid())"),
    # Admin ALL
    ("admin_all_td_student_profiles", "td_student_profiles", "FOR ALL TO public USING (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>''role'' = ''admin'')) WITH CHECK (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>''role'' = ''admin''))"),
    ("admin_all_td_teacher_profiles", "td_teacher_profiles", "FOR ALL TO public USING (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>''role'' = ''admin'')) WITH CHECK (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>''role'' = ''admin''))"),
    ("admin_all_td_local_groups", "td_local_groups", "FOR ALL TO public USING (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>''role'' = ''admin'')) WITH CHECK (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>''role'' = ''admin''))"),
    ("admin_all_td_group_members", "td_local_group_members", "FOR ALL TO public USING (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>''role'' = ''admin'')) WITH CHECK (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>''role'' = ''admin''))"),
    ("admin_all_td_physical_sessions", "td_physical_sessions", "FOR ALL TO public USING (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>''role'' = ''admin'')) WITH CHECK (EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.raw_user_meta_data->>''role'' = ''admin''))"),
]

for pname, tname, clause in policies:
    sql(f"DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='{pname}' AND tablename='{tname}') THEN EXECUTE 'CREATE POLICY {pname} ON app.{tname} {clause}'; END IF; END $$;", f"policy {pname}")
    time.sleep(0.1)

# ═══════════════════════════════════════════════════════════════
# C: RPCs
# ═══════════════════════════════════════════════════════════════
print("\n--- C: RPCs ---")

# C1: Student upsert TD profile
sql("""
CREATE OR REPLACE FUNCTION public.app_td_student_upsert_profile(
    p_university TEXT DEFAULT NULL, p_faculty TEXT DEFAULT NULL, p_study_year TEXT DEFAULT NULL,
    p_subjects_needed TEXT[] DEFAULT '{}', p_neighborhood TEXT DEFAULT NULL,
    p_availability_days TEXT[] DEFAULT '{}', p_availability_times TEXT[] DEFAULT '{}',
    p_max_group_size INTEGER DEFAULT 6, p_is_seeking_group BOOLEAN DEFAULT false
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $fn$
BEGIN
    INSERT INTO app.td_student_profiles (student_id, university, faculty, study_year, subjects_needed, neighborhood, availability_days, availability_times, max_group_size, is_seeking_group)
    VALUES (auth.uid(), p_university, p_faculty, p_study_year, p_subjects_needed, p_neighborhood, p_availability_days, p_availability_times, p_max_group_size, p_is_seeking_group)
    ON CONFLICT (student_id) DO UPDATE SET
        university = COALESCE(EXCLUDED.university, app.td_student_profiles.university),
        faculty = COALESCE(EXCLUDED.faculty, app.td_student_profiles.faculty),
        study_year = COALESCE(EXCLUDED.study_year, app.td_student_profiles.study_year),
        subjects_needed = EXCLUDED.subjects_needed,
        neighborhood = COALESCE(EXCLUDED.neighborhood, app.td_student_profiles.neighborhood),
        availability_days = EXCLUDED.availability_days,
        availability_times = EXCLUDED.availability_times,
        max_group_size = EXCLUDED.max_group_size,
        is_seeking_group = EXCLUDED.is_seeking_group,
        updated_at = now();
    RETURN jsonb_build_object('success', true);
END; $fn$;
""", "RPC app_td_student_upsert_profile")

# C2: Student get own TD profile
sql("""
CREATE OR REPLACE FUNCTION public.app_td_student_get_profile()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $fn$
DECLARE v_result JSONB;
BEGIN
    SELECT row_to_json(t)::jsonb INTO v_result
    FROM (SELECT p.*, s.full_name, s.city, s.geo_latitude, s.geo_longitude
          FROM app.td_student_profiles p
          JOIN app.students s ON s.id = p.student_id
          WHERE p.student_id = auth.uid()) t;
    RETURN COALESCE(v_result, '{}'::jsonb);
END; $fn$;
""", "RPC app_td_student_get_profile")

# C3: Student list available groups
sql("""
CREATE OR REPLACE FUNCTION public.app_td_student_list_local_groups(
    p_subject TEXT DEFAULT NULL, p_neighborhood TEXT DEFAULT NULL, p_city TEXT DEFAULT NULL
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $fn$
DECLARE v_result JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at DESC), '[]'::jsonb) INTO v_result
    FROM (
        SELECT g.*, (SELECT COUNT(*) FROM app.td_local_group_members m WHERE m.group_id = g.id) AS member_count,
               (SELECT jsonb_build_object('joined', true) FROM app.td_local_group_members m WHERE m.group_id = g.id AND m.student_id = auth.uid() LIMIT 1) AS my_membership,
               tp.rating AS teacher_rating, s.full_name AS teacher_name
        FROM app.td_local_groups g
        LEFT JOIN app.td_teacher_profiles tp ON tp.teacher_id = g.assigned_teacher_id
        LEFT JOIN app.students s ON s.id = g.assigned_teacher_id
        WHERE g.status IN ('forming', 'confirmed', 'active')
          AND (p_subject IS NULL OR g.subject ILIKE '%' || p_subject || '%')
          AND (p_neighborhood IS NULL OR g.neighborhood ILIKE '%' || p_neighborhood || '%')
          AND (p_city IS NULL OR g.city ILIKE '%' || p_city || '%')
    ) t;
    RETURN v_result;
END; $fn$;
""", "RPC app_td_student_list_local_groups")

# C4: Student join group
sql("""
CREATE OR REPLACE FUNCTION public.app_td_student_join_group(p_group_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $fn$
DECLARE v_current INTEGER; v_max INTEGER;
BEGIN
    SELECT current_members, max_members INTO v_current, v_max FROM app.td_local_groups WHERE id = p_group_id;
    IF v_current >= v_max THEN RETURN jsonb_build_object('success', false, 'error', 'group_full'); END IF;
    INSERT INTO app.td_local_group_members (group_id, student_id) VALUES (p_group_id, auth.uid())
    ON CONFLICT (group_id, student_id) DO NOTHING;
    UPDATE app.td_local_groups SET current_members = (SELECT COUNT(*) FROM app.td_local_group_members WHERE group_id = p_group_id), updated_at = now() WHERE id = p_group_id;
    RETURN jsonb_build_object('success', true);
END; $fn$;
""", "RPC app_td_student_join_group")

# C5: Student create group
sql("""
CREATE OR REPLACE FUNCTION public.app_td_student_create_group(
    p_subject TEXT, p_level TEXT DEFAULT NULL, p_city TEXT DEFAULT 'Ouagadougou',
    p_neighborhood TEXT DEFAULT NULL, p_max_members INTEGER DEFAULT 8
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $fn$
DECLARE v_id UUID; v_lat NUMERIC; v_lng NUMERIC;
BEGIN
    SELECT geo_latitude, geo_longitude INTO v_lat, v_lng FROM app.students WHERE id = auth.uid();
    INSERT INTO app.td_local_groups (subject, level, city, neighborhood, lat, lng, max_members, current_members, created_by)
    VALUES (p_subject, p_level, p_city, p_neighborhood, v_lat, v_lng, p_max_members, 1, auth.uid())
    RETURNING id INTO v_id;
    INSERT INTO app.td_local_group_members (group_id, student_id) VALUES (v_id, auth.uid());
    RETURN jsonb_build_object('success', true, 'id', v_id);
END; $fn$;
""", "RPC app_td_student_create_group")

# C6: Teacher upsert profile
sql("""
CREATE OR REPLACE FUNCTION public.app_td_teacher_upsert_profile(
    p_specialties TEXT[] DEFAULT '{}', p_universities TEXT[] DEFAULT '{}',
    p_neighborhoods TEXT[] DEFAULT '{}', p_max_distance_km INTEGER DEFAULT 10,
    p_hourly_rate INTEGER DEFAULT NULL, p_availability_days TEXT[] DEFAULT '{}',
    p_availability_times TEXT[] DEFAULT '{}', p_is_available BOOLEAN DEFAULT true, p_bio TEXT DEFAULT NULL
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $fn$
BEGIN
    INSERT INTO app.td_teacher_profiles (teacher_id, specialties, universities, neighborhoods, max_distance_km, hourly_rate, availability_days, availability_times, is_available, bio)
    VALUES (auth.uid(), p_specialties, p_universities, p_neighborhoods, p_max_distance_km, p_hourly_rate, p_availability_days, p_availability_times, p_is_available, p_bio)
    ON CONFLICT (teacher_id) DO UPDATE SET
        specialties = EXCLUDED.specialties, universities = EXCLUDED.universities,
        neighborhoods = EXCLUDED.neighborhoods, max_distance_km = EXCLUDED.max_distance_km,
        hourly_rate = EXCLUDED.hourly_rate, availability_days = EXCLUDED.availability_days,
        availability_times = EXCLUDED.availability_times, is_available = EXCLUDED.is_available,
        bio = COALESCE(EXCLUDED.bio, app.td_teacher_profiles.bio), updated_at = now();
    RETURN jsonb_build_object('success', true);
END; $fn$;
""", "RPC app_td_teacher_upsert_profile")

# C7: Teacher list assigned groups
sql("""
CREATE OR REPLACE FUNCTION public.app_td_teacher_list_local_groups()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $fn$
DECLARE v_result JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.session_date ASC NULLS LAST), '[]'::jsonb) INTO v_result
    FROM (
        SELECT g.*, (SELECT COUNT(*) FROM app.td_local_group_members m WHERE m.group_id = g.id) AS member_count,
               (SELECT jsonb_agg(jsonb_build_object('student_id', m.student_id, 'name', s.full_name))
                FROM app.td_local_group_members m JOIN app.students s ON s.id = m.student_id
                WHERE m.group_id = g.id) AS members
        FROM app.td_local_groups g WHERE g.assigned_teacher_id = auth.uid()
    ) t;
    RETURN v_result;
END; $fn$;
""", "RPC app_td_teacher_list_local_groups")

# C8: Admin assign teacher to group
sql("""
CREATE OR REPLACE FUNCTION public.app_td_admin_assign_teacher_to_group(p_group_id UUID, p_teacher_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $fn$
BEGIN
    UPDATE app.td_local_groups SET assigned_teacher_id = p_teacher_id, status = 'confirmed', updated_at = now() WHERE id = p_group_id;
    RETURN jsonb_build_object('success', true);
END; $fn$;
""", "RPC app_td_admin_assign_teacher_to_group")

# C9: Admin list all groups
sql("""
CREATE OR REPLACE FUNCTION public.app_td_admin_list_local_groups(p_status TEXT DEFAULT NULL, p_city TEXT DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'app' AS $fn$
DECLARE v_result JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at DESC), '[]'::jsonb) INTO v_result
    FROM (
        SELECT g.*, (SELECT COUNT(*) FROM app.td_local_group_members m WHERE m.group_id = g.id) AS member_count,
               s.full_name AS teacher_name
        FROM app.td_local_groups g LEFT JOIN app.students s ON s.id = g.assigned_teacher_id
        WHERE (p_status IS NULL OR g.status = p_status)
          AND (p_city IS NULL OR g.city = p_city)
    ) t;
    RETURN v_result;
END; $fn$;
""", "RPC app_td_admin_list_local_groups")

# ═══════════════════════════════════════════════════════════════
# VERIFICATION
# ═══════════════════════════════════════════════════════════════
print("\n--- VERIFICATION ---")
for t in ["td_student_profiles", "td_teacher_profiles", "td_local_groups", "td_local_group_members", "td_physical_sessions"]:
    sql(f"SELECT COUNT(*) AS cnt FROM information_schema.tables WHERE table_schema='app' AND table_name='{t}'", f"Table {t}")

sql("SELECT COUNT(*) AS cnt FROM pg_policies WHERE schemaname='app' AND tablename IN ('td_student_profiles','td_teacher_profiles','td_local_groups','td_local_group_members','td_physical_sessions')", "RLS count")

sql("SELECT routine_name FROM information_schema.routines WHERE routine_name LIKE 'app_td_%local%' OR routine_name LIKE 'app_td_%profile' OR routine_name LIKE 'app_td_%_group%' ORDER BY routine_name", "New RPCs")

sql("SELECT COUNT(*) AS cnt FROM information_schema.tables WHERE table_schema='app' AND table_name LIKE 'td_%'", "Total td_* tables")

print("\nPhase 1 TD deployment complete!")
