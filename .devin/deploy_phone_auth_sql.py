#!/usr/bin/env python3
"""Deployer le trigger handle_new_user et la RPC ensure_student_profile."""

import requests

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {"apikey": SERVICE_ROLE_KEY, "Authorization": f"Bearer {SERVICE_ROLE_KEY}", "Content-Type": "application/json"}

def ddl(q, label=""):
    r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/execute_ddl", headers=HEADERS, json={"ddl_query": q}, timeout=20)
    ok = r.status_code == 200
    msg = r.json() if ok else r.text[:200]
    status = "OK" if (ok and (not isinstance(msg, dict) or msg.get("success"))) else "ERR"
    print(f"  {status} {label}: {'' if status=='OK' else msg}")
    return ok

print("=== DEPLOYING PHONE AUTH SQL ===\n")

# 1. Fonction trigger handle_new_user
ddl("""
CREATE OR REPLACE FUNCTION app_handle_new_auth_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, app AS $$
DECLARE
  v_full_name TEXT;
  v_phone     TEXT;
BEGIN
  v_phone := NEW.phone;
  v_full_name := COALESCE(
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'name',
    CASE
      WHEN NEW.phone IS NOT NULL
      THEN 'Etudiant ' || right(NEW.phone, 4)
      ELSE split_part(NEW.email, '@', 1)
    END
  );

  -- Creer le profil etudiant si absent
  INSERT INTO app.students (id, full_name, phone)
  VALUES (NEW.id, v_full_name, v_phone)
  ON CONFLICT (id) DO UPDATE SET
    phone = COALESCE(EXCLUDED.phone, app.students.phone),
    updated_at = NOW()
  WHERE app.students.phone IS NULL AND EXCLUDED.phone IS NOT NULL;

  -- Forcer role=student si absent des metadonnees
  IF (NEW.raw_user_meta_data->>'role') IS NULL THEN
    UPDATE auth.users
    SET raw_user_meta_data =
      COALESCE(raw_user_meta_data, '{}'::jsonb) || '{"role":"student"}'::jsonb
    WHERE id = NEW.id;
  END IF;

  RETURN NEW;
END;
$$;
""", "create function app_handle_new_auth_user")

# 2. Trigger sur auth.users
ddl("""
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION app_handle_new_auth_user();
""", "create trigger on_auth_user_created")

# 3. RPC app_ensure_student_profile (idempotent, appele par AuthWrapper)
ddl("""
CREATE OR REPLACE FUNCTION app_ensure_student_profile()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, app AS $$
DECLARE
  v_uid   UUID := auth.uid();
  v_phone TEXT;
  v_name  TEXT;
BEGIN
  IF v_uid IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT phone INTO v_phone FROM auth.users WHERE id = v_uid;

  SELECT COALESCE(
    (SELECT raw_user_meta_data->>'full_name' FROM auth.users WHERE id = v_uid),
    CASE WHEN v_phone IS NOT NULL THEN 'Etudiant ' || right(v_phone, 4) ELSE 'Etudiant' END
  ) INTO v_name;

  INSERT INTO app.students (id, full_name, phone)
  VALUES (v_uid, v_name, v_phone)
  ON CONFLICT (id) DO UPDATE SET
    phone = COALESCE(EXCLUDED.phone, app.students.phone),
    updated_at = NOW()
  WHERE app.students.phone IS NULL AND EXCLUDED.phone IS NOT NULL;

  -- Assurer role=student
  UPDATE auth.users
  SET raw_user_meta_data =
    COALESCE(raw_user_meta_data, '{}'::jsonb) || '{"role":"student"}'::jsonb
  WHERE id = v_uid AND (raw_user_meta_data->>'role') IS NULL;

  RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;
GRANT EXECUTE ON FUNCTION app_ensure_student_profile() TO authenticated;
""", "create RPC app_ensure_student_profile")

print("\n=== Done ===")
