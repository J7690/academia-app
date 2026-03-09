#!/usr/bin/env python3
import json, sys
sys.stdout.reconfigure(encoding='utf-8')
from supabase_auto_manager import SupabaseAutoManager
m = SupabaseAutoManager()

def q(label, sql):
    print(f"\n### {label} ###")
    r = m.execute_sql_auto(sql)
    if r.get("success"):
        d = r.get("data", [])
        print(json.dumps(d, indent=2, ensure_ascii=False, default=str) if d else "  (vide)")
    else:
        print(f"  ERR: {r.get('error','?')}")

q("VERIFY_EDITED_AT", "SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='community_posts' AND column_name='edited_at'")
q("VERIFY_EDIT_RPC", "SELECT proname FROM pg_proc WHERE proname='app_student_edit_community_post'")
q("VERIFY_PIN_RPC", "SELECT proname FROM pg_proc WHERE proname='app_student_pin_community_post'")
q("VERIFY_MEMBERS_RPC", "SELECT proname FROM pg_proc WHERE proname='app_student_list_community_members'")
q("VERIFY_DM_TABLES", "SELECT table_name FROM information_schema.tables WHERE table_schema='app' AND table_name LIKE 'direct_%' ORDER BY table_name")
q("VERIFY_DM_RPCS", "SELECT proname FROM pg_proc WHERE proname LIKE 'app_student_%dm%' OR proname LIKE 'app_student_%direct%' ORDER BY proname")
