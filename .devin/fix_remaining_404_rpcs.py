#!/usr/bin/env python3
"""Fix the 2 remaining 404 RPCs by examining exact signatures and recreating with defaults."""
import requests
import time
from supabase_auto_manager import SupabaseAutoManager

def q(m, sql):
    r = requests.post(f"{m.url}/rest/v1/rpc/execute_sql",
        headers=m.headers, json={"sql_query": sql}, timeout=30)
    try:
        data = r.json()
        return data if isinstance(data, list) else []
    except:
        return []

def deploy(m, name, sql):
    print(f"📦 {name}...")
    try:
        r = requests.post(f"{m.url}/rest/v1/rpc/execute_ddl",
            headers=m.headers, json={"ddl_query": sql}, timeout=30)
        if r.status_code == 200:
            print(f"   ✅ OK")
            return True
        else:
            print(f"   ❌ {r.text[:250]}")
            return False
    except Exception as e:
        print(f"   ❌ {str(e)[:100]}")
        return False

def main():
    m = SupabaseAutoManager()
    print("\n🔧 FIX — 2 RPCs restantes 404\n")

    # 1. Get exact body of app_admin_upsert_short_training
    print("═══ Corps de app_admin_upsert_short_training ═══")
    body1 = q(m,
        "SELECT pg_get_function_arguments(p.oid) AS args, prosrc "
        "FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
        "WHERE n.nspname='public' AND p.proname='app_admin_upsert_short_training'")
    if body1:
        print(f"  Args: {body1[0].get('args','')[:200]}")
        print(f"  Body (first 500 chars): {body1[0].get('prosrc','')[:500]}")

    # 2. Get exact body of app_register_short_training_full
    print("\n═══ Corps de app_register_short_training_full ═══")
    body2 = q(m,
        "SELECT pg_get_function_arguments(p.oid) AS args, prosrc "
        "FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
        "WHERE n.nspname='public' AND p.proname='app_register_short_training_full'")
    if body2:
        print(f"  Args: {body2[0].get('args','')[:200]}")
        print(f"  Body (first 500 chars): {body2[0].get('prosrc','')[:500]}")

    # 3. The 404 issue is that PostgREST can't match the overload when params are sent
    # as JSON with some params missing. We need to DROP and recreate with DEFAULT NULL.
    
    # Fix app_admin_upsert_short_training - add DEFAULT NULL to all optional params
    if body1:
        src = body1[0].get('prosrc','')
        print("\n═══ Recréer app_admin_upsert_short_training avec defaults ═══")
        deploy(m, "DROP old", "DROP FUNCTION IF EXISTS public.app_admin_upsert_short_training(uuid, text, text, text, text, text, integer, numeric, boolean)")
        time.sleep(0.3)
        deploy(m, "Recreate app_admin_upsert_short_training", f"""
CREATE OR REPLACE FUNCTION public.app_admin_upsert_short_training(
    p_training_id uuid DEFAULT NULL,
    p_title text DEFAULT NULL,
    p_short_description text DEFAULT NULL,
    p_full_description text DEFAULT NULL,
    p_category text DEFAULT NULL,
    p_modality text DEFAULT NULL,
    p_duration_days integer DEFAULT NULL,
    p_price numeric DEFAULT NULL,
    p_is_active boolean DEFAULT true
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $fn$
{src}
$fn$
        """)

    # Fix app_register_short_training_full - add DEFAULT NULL to optional params
    if body2:
        src2 = body2[0].get('prosrc','')
        print("\n═══ Recréer app_register_short_training_full avec defaults ═══")
        deploy(m, "DROP old", "DROP FUNCTION IF EXISTS public.app_register_short_training_full(uuid, text, text, text, boolean, text, text)")
        time.sleep(0.3)
        deploy(m, "Recreate app_register_short_training_full", f"""
CREATE OR REPLACE FUNCTION public.app_register_short_training_full(
    p_session_id uuid DEFAULT NULL,
    p_contact_phone text DEFAULT NULL,
    p_preferred_channel text DEFAULT NULL,
    p_payment_method text DEFAULT NULL,
    p_wants_invoice boolean DEFAULT false,
    p_company_name text DEFAULT NULL,
    p_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $fn$
{src2}
$fn$
        """)

    # Also fix app_admin_upsert_short_training_session
    print("\n═══ Fix app_admin_upsert_short_training_session ═══")
    body3 = q(m,
        "SELECT pg_get_function_arguments(p.oid) AS args, prosrc "
        "FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
        "WHERE n.nspname='public' AND p.proname='app_admin_upsert_short_training_session'")
    if body3:
        src3 = body3[0].get('prosrc','')
        deploy(m, "DROP old session", "DROP FUNCTION IF EXISTS public.app_admin_upsert_short_training_session(uuid, uuid, timestamptz, timestamptz, text, integer, text, boolean)")
        time.sleep(0.3)
        deploy(m, "Recreate app_admin_upsert_short_training_session", f"""
CREATE OR REPLACE FUNCTION public.app_admin_upsert_short_training_session(
    p_session_id uuid DEFAULT NULL,
    p_training_id uuid DEFAULT NULL,
    p_start_at timestamptz DEFAULT NULL,
    p_end_at timestamptz DEFAULT NULL,
    p_location text DEFAULT NULL,
    p_capacity integer DEFAULT NULL,
    p_status text DEFAULT 'open',
    p_is_active boolean DEFAULT true
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $fn$
{src3}
$fn$
        """)

    # Grant permissions
    for rpc in ['app_admin_upsert_short_training', 'app_register_short_training_full', 'app_admin_upsert_short_training_session']:
        deploy(m, f"GRANT {rpc}", f"GRANT EXECUTE ON FUNCTION public.{rpc} TO authenticated")
        time.sleep(0.1)

    # NOTIFY
    deploy(m, "NOTIFY pgrst", "NOTIFY pgrst, 'reload schema'")
    time.sleep(2)

    # Test
    print("\n═══ TEST FINAL ═══\n")
    final_tests = [
        ('app_admin_list_short_trainings', {}),
        ('app_admin_upsert_short_training', {'p_title': 'test'}),
        ('app_admin_upsert_short_training_session', {'p_training_id': '00000000-0000-0000-0000-000000000000'}),
        ('app_admin_list_short_training_registrations', {'p_session_id': '00000000-0000-0000-0000-000000000000'}),
        ('app_list_public_short_training_sessions', {}),
        ('app_list_my_short_trainings', {}),
        ('app_register_short_training', {'p_session_id': '00000000-0000-0000-0000-000000000000'}),
        ('app_register_short_training_full', {'p_session_id': '00000000-0000-0000-0000-000000000000'}),
        ('app_list_short_training_messages_for_admin', {'p_registration_id': '00000000-0000-0000-0000-000000000000'}),
        ('app_add_short_training_message_from_student', {'p_registration_id': '00000000-0000-0000-0000-000000000000', 'p_content': 'test'}),
    ]
    
    ok_count = 0
    for rpc, params in final_tests:
        try:
            resp = requests.post(f"{m.url}/rest/v1/rpc/{rpc}",
                headers=m.headers, json=params, timeout=10)
            code = resp.status_code
            icon = "✅" if code in [200, 400] else "❌"
            print(f"  {icon} {rpc} → {code}")
            if code in [200, 400]:
                ok_count += 1
        except:
            print(f"  ❌ {rpc} → ERREUR")

    print(f"\n✅ {ok_count}/{len(final_tests)} RPCs accessibles.\n")

if __name__ == "__main__":
    main()
