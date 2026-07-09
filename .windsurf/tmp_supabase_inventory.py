#!/usr/bin/env python3
"""Inventory Supabase whiteboard objects via admin_execute_sql."""
import requests
import json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {
    "apikey": KEY,
    "Authorization": "Bearer " + KEY,
    "Content-Type": "application/json",
}

results = []


def run(label, sql):
    print(f"\n=== {label} ===")
    r = requests.post(URL, headers=HEADERS, json={"p_sql": sql}, timeout=30)
    print(f"status: {r.status_code}")
    try:
        body = r.json()
        print(json.dumps(body, indent=2, ensure_ascii=False)[:2000])
        results.append({"label": label, "body": body})
        return body
    except Exception as e:
        print(f"raw: {r.text[:500]}")
        print(f"parse error: {e}")
        results.append({"label": label, "error": str(e), "raw": r.text[:500]})
        return None


run("tables", """SELECT n.nspname AS schema, c.relname AS name, c.relkind
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE c.relname ILIKE '%whiteboard%'
ORDER BY n.nspname, c.relname""")

run("rpcs", """SELECT n.nspname AS schema, p.proname AS name,
pg_get_function_identity_arguments(p.oid) AS signature
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE p.proname ILIKE '%whiteboard%'
ORDER BY n.nspname, p.proname""")

run("policies", """SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies WHERE tablename ILIKE '%whiteboard%'
ORDER BY schemaname, tablename, policyname""")

run("triggers", """SELECT event_object_schema, event_object_table, trigger_name, event_manipulation
FROM information_schema.triggers
WHERE event_object_table ILIKE '%whiteboard%'
ORDER BY event_object_schema, event_object_table, trigger_name""")

run("indexes", """SELECT schemaname, tablename, indexname
FROM pg_indexes WHERE tablename ILIKE '%whiteboard%'
ORDER BY schemaname, tablename, indexname""")

run("columns whiteboard_renders", """SELECT table_schema, column_name, data_type
FROM information_schema.columns
WHERE table_name='whiteboard_renders'
ORDER BY ordinal_position""")

outfile = r"C:\Users\fasop\AndroidStudioProjects\academia\.windsurf\tmp_supabase_inventory_output.json"
with open(outfile, "w", encoding="utf-8") as f:
    f.write(json.dumps(results, indent=2, ensure_ascii=False))
print(f"\nSaved full results to {outfile}")
