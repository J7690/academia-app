#!/usr/bin/env python3
"""Creer les RPCs manquantes pour l'interface admin de tarification."""

import requests

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {"apikey": SERVICE_ROLE_KEY, "Authorization": f"Bearer {SERVICE_ROLE_KEY}", "Content-Type": "application/json"}

def ddl(q):
    r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/execute_ddl", headers=HEADERS, json={"ddl_query": q}, timeout=20)
    ok = r.status_code == 200
    msg = r.json() if ok else r.text[:200]
    return ok, msg

def deploy(name, sql):
    ok, msg = ddl(sql)
    print(f"  {'OK' if ok else 'ERR'} {name}: {msg if not ok else ''}")
    return ok

print("=== Deploying missing pricing RPCs ===\n")

# 1. app_admin_list_credit_packs
deploy("app_admin_list_credit_packs", """
CREATE OR REPLACE FUNCTION app_admin_list_credit_packs()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_role TEXT;
BEGIN
  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = auth.uid();
  IF v_role <> 'admin' THEN RETURN JSONB_BUILD_OBJECT('success',FALSE,'error','not_admin'); END IF;
  RETURN JSONB_BUILD_OBJECT('success',TRUE,'packs',(
    SELECT JSONB_AGG(ROW_TO_JSON(p) ORDER BY p.sort_order)
    FROM app.credit_packs p
  ));
END;$$;
GRANT EXECUTE ON FUNCTION app_admin_list_credit_packs() TO authenticated;
""")

# 2. app_admin_list_subscription_plans
deploy("app_admin_list_subscription_plans", """
CREATE OR REPLACE FUNCTION app_admin_list_subscription_plans()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_role TEXT;
BEGIN
  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = auth.uid();
  IF v_role <> 'admin' THEN RETURN JSONB_BUILD_OBJECT('success',FALSE,'error','not_admin'); END IF;
  RETURN JSONB_BUILD_OBJECT('success',TRUE,'plans',(
    SELECT JSONB_AGG(ROW_TO_JSON(p) ORDER BY p.price)
    FROM app.subscription_plans p
  ));
END;$$;
GRANT EXECUTE ON FUNCTION app_admin_list_subscription_plans() TO authenticated;
""")

# 3. app_admin_list_ai_action_prices
deploy("app_admin_list_ai_action_prices", """
CREATE OR REPLACE FUNCTION app_admin_list_ai_action_prices()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_role TEXT;
BEGIN
  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = auth.uid();
  IF v_role <> 'admin' THEN RETURN JSONB_BUILD_OBJECT('success',FALSE,'error','not_admin'); END IF;
  RETURN JSONB_BUILD_OBJECT('success',TRUE,'prices',(
    SELECT JSONB_AGG(ROW_TO_JSON(p) ORDER BY p.action_code)
    FROM app.ai_action_prices p
  ));
END;$$;
GRANT EXECUTE ON FUNCTION app_admin_list_ai_action_prices() TO authenticated;
""")

# 4. app_admin_list_short_trainings_pricing
deploy("app_admin_list_short_trainings_pricing", """
CREATE OR REPLACE FUNCTION app_admin_list_short_trainings_pricing()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_role TEXT;
BEGIN
  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = auth.uid();
  IF v_role <> 'admin' THEN RETURN JSONB_BUILD_OBJECT('success',FALSE,'error','not_admin'); END IF;
  RETURN JSONB_BUILD_OBJECT('success',TRUE,'trainings',(
    SELECT JSONB_AGG(JSONB_BUILD_OBJECT(
      'id', t.id, 'title', t.title, 'category', t.category,
      'modality', t.modality, 'duration_days', t.duration_days,
      'price', t.price, 'is_active', t.is_active
    ) ORDER BY t.title)
    FROM app.short_trainings t
  ));
END;$$;
GRANT EXECUTE ON FUNCTION app_admin_list_short_trainings_pricing() TO authenticated;
""")

# 5. app_admin_list_td_programs_pricing
deploy("app_admin_list_td_programs_pricing", """
CREATE OR REPLACE FUNCTION app_admin_list_td_programs_pricing()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_role TEXT;
BEGIN
  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = auth.uid();
  IF v_role <> 'admin' THEN RETURN JSONB_BUILD_OBJECT('success',FALSE,'error','not_admin'); END IF;
  RETURN JSONB_BUILD_OBJECT('success',TRUE,'programs',(
    SELECT JSONB_AGG(JSONB_BUILD_OBJECT(
      'id', p.id, 'title', p.title, 'level', p.level,
      'modality', p.modality, 'price', p.price,
      'currency', p.currency, 'status', p.status
    ) ORDER BY p.title)
    FROM app.td_programs p
  ));
END;$$;
GRANT EXECUTE ON FUNCTION app_admin_list_td_programs_pricing() TO authenticated;
""")

# 6. app_admin_update_td_program_price
deploy("app_admin_update_td_program_price", """
CREATE OR REPLACE FUNCTION app_admin_update_td_program_price(
  p_program_id UUID,
  p_price NUMERIC,
  p_status TEXT DEFAULT NULL
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_role TEXT;
BEGIN
  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = auth.uid();
  IF v_role <> 'admin' THEN RETURN JSONB_BUILD_OBJECT('success',FALSE,'error','not_admin'); END IF;
  UPDATE app.td_programs SET
    price = COALESCE(p_price, price),
    status = COALESCE(p_status::app.td_program_status, status),
    updated_at = NOW()
  WHERE id = p_program_id;
  IF NOT FOUND THEN RETURN JSONB_BUILD_OBJECT('success',FALSE,'error','not_found'); END IF;
  RETURN JSONB_BUILD_OBJECT('success',TRUE);
END;$$;
GRANT EXECUTE ON FUNCTION app_admin_update_td_program_price(UUID,NUMERIC,TEXT) TO authenticated;
""")

# 7. app_admin_list_programs_pricing (university programs)
deploy("app_admin_list_programs_pricing", """
CREATE OR REPLACE FUNCTION app_admin_list_programs_pricing()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_role TEXT;
BEGIN
  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = auth.uid();
  IF v_role <> 'admin' THEN RETURN JSONB_BUILD_OBJECT('success',FALSE,'error','not_admin'); END IF;
  RETURN JSONB_BUILD_OBJECT('success',TRUE,'programs',(
    SELECT JSONB_AGG(JSONB_BUILD_OBJECT(
      'id', p.id, 'title', p.title, 'degree_level', p.degree_level,
      'tuition_fees', p.tuition_fees, 'is_active', p.is_active,
      'university_id', p.university_id
    ) ORDER BY p.title)
    FROM app.programs p
  ));
END;$$;
GRANT EXECUTE ON FUNCTION app_admin_list_programs_pricing() TO authenticated;
""")

# 8. app_admin_update_program_fees
deploy("app_admin_update_program_fees", """
CREATE OR REPLACE FUNCTION app_admin_update_program_fees(
  p_program_id UUID,
  p_tuition_fees NUMERIC DEFAULT NULL,
  p_is_active BOOLEAN DEFAULT NULL
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_role TEXT;
BEGIN
  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = auth.uid();
  IF v_role <> 'admin' THEN RETURN JSONB_BUILD_OBJECT('success',FALSE,'error','not_admin'); END IF;
  UPDATE app.programs SET
    tuition_fees = COALESCE(p_tuition_fees, tuition_fees),
    is_active = COALESCE(p_is_active, is_active),
    updated_at = NOW()
  WHERE id = p_program_id;
  IF NOT FOUND THEN RETURN JSONB_BUILD_OBJECT('success',FALSE,'error','not_found'); END IF;
  RETURN JSONB_BUILD_OBJECT('success',TRUE);
END;$$;
GRANT EXECUTE ON FUNCTION app_admin_update_program_fees(UUID,NUMERIC,BOOLEAN) TO authenticated;
""")

print("\n=== Done ===")
