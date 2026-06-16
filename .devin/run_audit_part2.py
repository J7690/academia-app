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

# Check if app_student_list_my_chats exists
q("CHECK_LIST_MY_CHATS", "SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE p.proname = 'app_student_list_my_chats'")

# Check if app_student_create_group exists
q("CHECK_CREATE_GROUP", "SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE p.proname = 'app_student_create_group'")

# Check if app_student_edit_community_post exists
q("CHECK_EDIT_POST", "SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE p.proname = 'app_student_edit_community_post'")

# Check if app_student_pin_community_post exists
q("CHECK_PIN_POST", "SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE p.proname = 'app_student_pin_community_post'")

# Check if app_student_list_community_members exists
q("CHECK_LIST_MEMBERS", "SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE p.proname = 'app_student_list_community_members'")

# Check community_posts columns for edited_at
q("CHECK_EDITED_AT_COL", "SELECT column_name FROM information_schema.columns WHERE table_schema='app' AND table_name='community_posts' AND column_name='edited_at'")

# Check if direct_messages table exists
q("CHECK_DM_TABLE", "SELECT table_name FROM information_schema.tables WHERE table_schema='app' AND table_name ILIKE '%direct%' OR table_name ILIKE '%dm_%' OR table_name ILIKE '%private_message%'")
