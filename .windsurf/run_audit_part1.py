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

q("TABLES_COMMUNAUTES", "SELECT table_name FROM information_schema.tables WHERE table_schema='app' AND table_name ILIKE '%communit%' ORDER BY table_name")
q("TOUTES_TABLES_APP", "SELECT table_name FROM information_schema.tables WHERE table_schema='app' ORDER BY table_name")
q("COL_COMMUNITIES", "SELECT column_name, data_type, column_default FROM information_schema.columns WHERE table_schema='app' AND table_name='communities' ORDER BY ordinal_position")
q("COL_MEMBERSHIPS", "SELECT column_name, data_type, column_default FROM information_schema.columns WHERE table_schema='app' AND table_name='community_memberships' ORDER BY ordinal_position")
q("COL_POSTS", "SELECT column_name, data_type, column_default FROM information_schema.columns WHERE table_schema='app' AND table_name='community_posts' ORDER BY ordinal_position")
