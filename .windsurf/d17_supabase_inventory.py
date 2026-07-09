"""
MISSION D.17 - PHASE 2: Inventaire Supabase réel

Interroge Supabase directement via PostgREST (pas admin_execute_sql).
"""

import requests
import json

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}


def query_sql(query):
    """Exécute une requête SQL via admin_execute_sql. SELECT uniquement."""
    url = f"{SUPABASE_URL}/rest/v1/rpc/admin_execute_sql"
    return requests.post(url, headers=HEADERS, json={"p_sql": query}, timeout=30)


def query_get(table, select, params=None):
    url = f"{SUPABASE_URL}/rest/v1/{table}"
    headers = HEADERS.copy()
    headers["Prefer"] = "count=exact"
    p = {"select": select}
    if params:
        p.update(params)
    return requests.get(url, headers=headers, params=p, timeout=30)


def main():
    print("=" * 80)
    print("MISSION D.17 - INVENTAIRE SUPABASE RÉEL")
    print("=" * 80)

    # RPCs
    print("\n### RPCS WHITEBOARD ###")
    rpc_query = """
    SELECT json_agg(t) FROM (
      SELECT
        n.nspname as schema,
        p.proname as name,
        pg_get_function_identity_arguments(p.oid) as args,
        pg_get_function_result(p.oid) as result
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE p.proname ILIKE '%whiteboard%'
      ORDER BY n.nspname, p.proname
    ) t;
    """
    resp = query_sql(rpc_query)
    print(f"Status: {resp.status_code}")
    try:
        data = resp.json()
        print(json.dumps(data, indent=2, ensure_ascii=False))
    except Exception as e:
        print(f"Erreur: {e}")
        print(resp.text)

    # Tables
    print("\n### TABLES WHITEBOARD ###")
    tables_query = """
    SELECT json_agg(t) FROM (
      SELECT schemaname, tablename
      FROM pg_tables
      WHERE tablename ILIKE '%whiteboard%'
      ORDER BY schemaname, tablename
    ) t;
    """
    resp = query_sql(tables_query)
    print(f"Status: {resp.status_code}")
    try:
        data = resp.json()
        print(json.dumps(data, indent=2, ensure_ascii=False))
    except Exception as e:
        print(f"Erreur: {e}")
        print(resp.text)

    # Buckets
    print("\n### BUCKETS ###")
    buckets_query = """
    SELECT json_agg(t) FROM (
      SELECT id, name, public
      FROM storage.buckets
      ORDER BY name
    ) t;
    """
    resp = query_sql(buckets_query)
    print(f"Status: {resp.status_code}")
    try:
        data = resp.json()
        print(json.dumps(data, indent=2, ensure_ascii=False))
    except Exception as e:
        print(f"Erreur: {e}")
        print(resp.text)

    print("\n" + "=" * 80)


if __name__ == "__main__":
    main()
