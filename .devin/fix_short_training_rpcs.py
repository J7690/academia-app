#!/usr/bin/env python3
"""Diagnostiquer et fixer les RPCs formations courtes qui renvoient 404."""
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
            print(f"   ❌ {r.text[:200]}")
            return False
    except Exception as e:
        print(f"   ❌ {str(e)[:100]}")
        return False

def main():
    m = SupabaseAutoManager()
    print("\n🔧 FIX — RPCs formations courtes\n")

    # 1. Diagnostiquer: vérifier les signatures des RPCs qui 404
    print("═══ DIAGNOSTIC: Signatures des RPCs existantes ═══\n")
    rpcs_404 = [
        'app_admin_upsert_short_training',
        'app_admin_upsert_short_training_session',
        'app_admin_list_short_training_registrations',
        'app_register_short_training',
        'app_register_short_training_full',
        'app_list_short_training_messages_for_admin',
        'app_list_short_training_messages_for_student',
        'app_add_short_training_message_from_admin_to_student',
        'app_add_short_training_message_from_student',
    ]
    
    for rpc in rpcs_404:
        info = q(m,
            f"SELECT n.nspname, pg_get_function_arguments(p.oid) AS args, "
            f"pg_get_function_result(p.oid) AS returns "
            f"FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
            f"WHERE p.proname='{rpc}'")
        if info:
            for i in info:
                args = i.get('args','')
                # Check if all params have defaults
                has_all_defaults = True
                if args:
                    params = [p.strip() for p in args.split(',')]
                    for param in params:
                        if 'DEFAULT' not in param.upper() and param.strip():
                            has_all_defaults = False
                            break
                status = "✅ all defaults" if has_all_defaults else "⚠️  REQUIRED params"
                print(f"  [{i.get('nspname','')}] {rpc}")
                print(f"    Args: {args[:120]}")
                print(f"    {status}")
        else:
            print(f"  ❌ {rpc} NOT FOUND in pg_proc!")

    # 2. The 404 issue: PostgREST returns 404 when calling with {} 
    # but the function has required params without defaults.
    # This is expected behavior. Let's test with proper params.
    print("\n═══ TEST avec paramètres corrects ═══\n")
    
    tests = [
        ('app_admin_upsert_short_training', {'p_title': 'test'}),
        ('app_admin_list_short_training_registrations', {'p_session_id': '00000000-0000-0000-0000-000000000000'}),
        ('app_register_short_training', {'p_session_id': '00000000-0000-0000-0000-000000000000'}),
        ('app_register_short_training_full', {'p_session_id': '00000000-0000-0000-0000-000000000000'}),
        ('app_list_short_training_messages_for_admin', {'p_registration_id': '00000000-0000-0000-0000-000000000000'}),
        ('app_list_short_training_messages_for_student', {'p_registration_id': '00000000-0000-0000-0000-000000000000'}),
        ('app_add_short_training_message_from_admin_to_student', {'p_registration_id': '00000000-0000-0000-0000-000000000000', 'p_content': 'test'}),
        ('app_add_short_training_message_from_student', {'p_registration_id': '00000000-0000-0000-0000-000000000000', 'p_content': 'test'}),
    ]
    
    for rpc, params in tests:
        try:
            resp = requests.post(f"{m.url}/rest/v1/rpc/{rpc}",
                headers=m.headers, json=params, timeout=10)
            code = resp.status_code
            icon = "✅" if code in [200, 400] else "❌"
            label = "OK" if code == 200 else "AUTH/ERR" if code == 400 else f"{code}"
            snippet = resp.text[:80] if code not in [200] else ""
            print(f"  {icon} {rpc} → {code} ({label}) {snippet}")
        except Exception as e:
            print(f"  ❌ {rpc} → {str(e)[:60]}")

    # 3. Create missing table short_training_messages
    print("\n═══ CRÉATION TABLE short_training_messages ═══\n")
    deploy(m, "Table short_training_messages", """
CREATE TABLE IF NOT EXISTS app.short_training_messages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    registration_id uuid NOT NULL REFERENCES app.short_training_registrations(id) ON DELETE CASCADE,
    sender_role text NOT NULL CHECK (sender_role IN ('student', 'admin')),
    sender_id uuid NOT NULL REFERENCES auth.users(id),
    content text NOT NULL,
    created_at timestamptz DEFAULT now()
)
    """)
    
    deploy(m, "Index short_training_messages",
        "CREATE INDEX IF NOT EXISTS idx_short_training_messages_reg "
        "ON app.short_training_messages(registration_id, created_at)")
    
    deploy(m, "RLS short_training_messages",
        "ALTER TABLE app.short_training_messages ENABLE ROW LEVEL SECURITY")

    # 4. NOTIFY PostgREST
    deploy(m, "NOTIFY pgrst", "NOTIFY pgrst, 'reload schema'")
    time.sleep(2)

    # 5. Re-test
    print("\n═══ RE-TEST après fix ═══\n")
    for rpc, params in tests:
        try:
            resp = requests.post(f"{m.url}/rest/v1/rpc/{rpc}",
                headers=m.headers, json=params, timeout=10)
            code = resp.status_code
            icon = "✅" if code in [200, 400] else "❌"
            print(f"  {icon} {rpc} → {code}")
        except:
            print(f"  ❌ {rpc} → ERREUR")

    print("\n✅ Terminé.\n")

if __name__ == "__main__":
    main()
