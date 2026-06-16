#!/usr/bin/env python3
"""Audit direct du Storage Supabase via API REST."""

import requests
import json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
}


def execute_sql(sql: str) -> dict:
    """Exécute du SQL via la RPC execute_sql."""
    resp = requests.post(
        f"{URL}/rest/v1/rpc/execute_sql",
        headers=HEADERS,
        json={"sql_query": sql},
        timeout=30,
    )
    print(f"  HTTP {resp.status_code}")
    return resp.json()


def main():
    print("=" * 60)
    print("AUDIT STORAGE SUPABASE - DIRECT")
    print("=" * 60)

    # 1. Lister les buckets
    print("\n[1] BUCKETS EXISTANTS")
    print("-" * 40)
    result = execute_sql("SELECT id, name, public FROM storage.buckets ORDER BY name")
    print(f"  Résultat: {json.dumps(result, indent=2, ensure_ascii=False)}")

    # 2. Vérifier community-media
    print("\n[2] BUCKET community-media")
    print("-" * 40)
    result = execute_sql("SELECT id, name, public FROM storage.buckets WHERE id = 'community-media'")
    print(f"  Résultat: {json.dumps(result, indent=2, ensure_ascii=False)}")

    # 3. Policies sur storage.objects (version simplifiée)
    print("\n[3] POLICIES SUR storage.objects")
    print("-" * 40)
    result = execute_sql("""
        SELECT polname, polcmd 
        FROM pg_policy 
        WHERE polrelid = 'storage.objects'::regclass
    """)
    print(f"  Résultat: {json.dumps(result, indent=2, ensure_ascii=False)}")

    # 4. Tester l'API Storage directement - lister les buckets via l'API Storage
    print("\n[4] API STORAGE - Liste des buckets")
    print("-" * 40)
    resp = requests.get(f"{URL}/storage/v1/bucket", headers=HEADERS, timeout=30)
    print(f"  HTTP {resp.status_code}")
    print(f"  Résultat: {json.dumps(resp.json(), indent=2, ensure_ascii=False)}")

    # 5. Vérifier si le bucket community-media existe via l'API Storage
    print("\n[5] API STORAGE - Bucket community-media")
    print("-" * 40)
    resp = requests.get(f"{URL}/storage/v1/bucket/community-media", headers=HEADERS, timeout=30)
    print(f"  HTTP {resp.status_code}")
    print(f"  Résultat: {json.dumps(resp.json(), indent=2, ensure_ascii=False)}")

    print("\n" + "=" * 60)
    print("FIN DE L'AUDIT")
    print("=" * 60)


if __name__ == "__main__":
    main()
