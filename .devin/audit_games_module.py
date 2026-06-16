#!/usr/bin/env python3
"""Audit Supabase pour le module Jeux/Kellenge.
Vérifie les tables, RPCs et données liées aux jeux économiques.
"""
import requests
import json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
    "Accept": "application/json"
}

def exec_sql(sql):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql",
                      headers=HEADERS, json={"sql_query": sql}, timeout=30)
    if r.status_code == 200:
        return r.json()
    # fallback to execute_sql
    r2 = requests.post(f"{URL}/rest/v1/rpc/execute_sql",
                       headers=HEADERS, json={"sql_query": sql}, timeout=30)
    if r2.status_code == 200:
        return r2.json()
    return {"error": r.status_code, "body": r.text[:500], "fallback_error": r2.status_code, "fallback_body": r2.text[:500]}

print("=" * 60)
print("1. TABLES liées aux jeux (tournament*, league*, game*, economic*, adaptive*)")
print("=" * 60)
result = exec_sql("""
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema IN ('app', 'public')
  AND (table_name ILIKE '%tournament%'
    OR table_name ILIKE '%league%'
    OR table_name ILIKE '%game%'
    OR table_name ILIKE '%economic%'
    OR table_name ILIKE '%adaptive%'
    OR table_name ILIKE '%african_market%'
    OR table_name ILIKE '%kelleng%')
ORDER BY table_schema, table_name;
""")
print(json.dumps(result, indent=2, default=str))

print("\n" + "=" * 60)
print("2. RPCs liées aux jeux (tournament*, league*, game*, kelleng*)")
print("=" * 60)
result = exec_sql("""
SELECT routine_name, routine_schema
FROM information_schema.routines
WHERE routine_schema IN ('app', 'public')
  AND (routine_name ILIKE '%tournament%'
    OR routine_name ILIKE '%league%'
    OR routine_name ILIKE '%game%'
    OR routine_name ILIKE '%kelleng%')
ORDER BY routine_name;
""")
print(json.dumps(result, indent=2, default=str))

print("\n" + "=" * 60)
print("3. Colonnes des tables tournament*")
print("=" * 60)
result = exec_sql("""
SELECT table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'app'
  AND (table_name ILIKE '%tournament%' OR table_name ILIKE '%league%')
ORDER BY table_name, ordinal_position;
""")
print(json.dumps(result, indent=2, default=str))

print("\n" + "=" * 60)
print("4. Données dans les tables jeux (counts)")
print("=" * 60)
for tbl in ['tournaments', 'tournament_participants', 'tournament_matches', 'tournament_rewards',
            'leagues', 'league_participations', 'league_matches',
            'economic_indicators', 'african_market_scenarios', 'adaptive_learning_profiles']:
    result = exec_sql(f"SELECT count(*) as cnt FROM app.{tbl};")
    print(f"  app.{tbl}: {json.dumps(result, default=str)}")

print("\n" + "=" * 60)
print("5. RLS policies sur les tables jeux")
print("=" * 60)
result = exec_sql("""
SELECT schemaname, tablename, policyname, permissive, roles, cmd
FROM pg_policies
WHERE schemaname = 'app'
  AND (tablename ILIKE '%tournament%'
    OR tablename ILIKE '%league%'
    OR tablename ILIKE '%game%')
ORDER BY tablename, policyname;
""")
print(json.dumps(result, indent=2, default=str))

print("\n" + "=" * 60)
print("6. Source code des RPCs tournament (première)")
print("=" * 60)
result = exec_sql("""
SELECT routine_name, routine_definition
FROM information_schema.routines
WHERE routine_schema IN ('app', 'public')
  AND routine_name = 'tournament_list_available'
LIMIT 1;
""")
print(json.dumps(result, indent=2, default=str))

print("\nAudit terminé.")
