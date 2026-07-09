#!/usr/bin/env python3
"""MISSION D.27B — Inventaire réel des fonctions whiteboard (lecture seule)."""
import httpx
import json
import time

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {
    "apikey": KEY,
    "Authorization": "Bearer " + KEY,
    "Content-Type": "application/json",
}


def execute_sql(sql):
    sql = sql.strip().rstrip(';')
    for attempt in range(3):
        try:
            with httpx.Client(timeout=60) as client:
                resp = client.post(URL, headers=HEADERS, json={"p_sql": sql})
                resp.raise_for_status()
                return resp.json()
        except Exception as e:
            if attempt == 2:
                raise
            time.sleep(2)


queries = {
    "all_whiteboard_functions": """
SELECT
    p.proname,
    n.nspname,
    pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname ILIKE '%whiteboard%'
ORDER BY n.nspname, p.proname
""",
    "variants_get_project": """
SELECT p.proname, n.nspname
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname ILIKE '%get%project%' OR p.proname ILIKE '%project%by%id%' OR p.proname ILIKE '%project%get%'
ORDER BY n.nspname, p.proname
""",
    "variants_update_project": """
SELECT p.proname, n.nspname
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname ILIKE '%update%project%' OR p.proname ILIKE '%project%update%'
ORDER BY n.nspname, p.proname
""",
    "variants_delete_project": """
SELECT p.proname, n.nspname
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname ILIKE '%delete%project%' OR p.proname ILIKE '%project%delete%'
ORDER BY n.nspname, p.proname
""",
    "all_app_public_functions": """
SELECT p.proname, n.nspname
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('app', 'public') AND p.proname ILIKE '%whiteboard%'
ORDER BY n.nspname, p.proname
""",
}

results = {}
for name, sql in queries.items():
    try:
        results[name] = execute_sql(sql)
    except Exception as e:
        results[name] = {"error": str(e)}

outfile = r"C:\Users\fasop\AndroidStudioProjects\academia\.windsurf\MISSION_D27B_rpc_inventory_output.json"
with open(outfile, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False)

print(f"Saved {outfile}")
print(json.dumps(results, indent=2, ensure_ascii=False))
