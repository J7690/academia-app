#!/usr/bin/env python3
"""Vérifie les fonctions storage disponibles pour créer des signed URLs."""

import requests
import json

PROJECT_REF = "thevdfcwlcqzdoybfvgs"
URL = f"https://{PROJECT_REF}.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
}


def execute_sql(sql: str) -> dict:
    resp = requests.post(
        f"{URL}/rest/v1/rpc/execute_sql",
        headers=HEADERS,
        json={"sql_query": sql},
        timeout=60,
    )
    return resp.json()


def main():
    print("=" * 60)
    print("VÉRIFICATION FONCTIONS STORAGE SUPABASE")
    print("=" * 60)

    # 1. Lister toutes les fonctions dans le schéma storage
    print("\n[1] Fonctions dans le schéma storage")
    print("-" * 40)
    result = execute_sql("""
        SELECT p.proname as function_name,
               pg_get_function_arguments(p.oid) as arguments,
               pg_get_function_result(p.oid) as return_type
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'storage'
        ORDER BY p.proname
    """)
    print(f"  Fonctions: {json.dumps(result, indent=2, ensure_ascii=False)}")

    # 2. Chercher des fonctions pour signed URLs
    print("\n[2] Fonctions pour signed URLs")
    print("-" * 40)
    result = execute_sql("""
        SELECT p.proname, n.nspname
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE p.proname LIKE '%sign%' OR p.proname LIKE '%url%' OR p.proname LIKE '%upload%'
        ORDER BY n.nspname, p.proname
    """)
    print(f"  Fonctions: {json.dumps(result, indent=2, ensure_ascii=False)}")

    # 3. Tester l'API Storage pour créer une signed URL
    print("\n[3] Test API Storage - Create Signed Upload URL")
    print("-" * 40)
    
    resp = requests.post(
        f"{URL}/storage/v1/object/upload/sign/community-media/test/signed_upload.txt",
        headers=HEADERS,
        json={},
        timeout=30,
    )
    print(f"  HTTP {resp.status_code}")
    print(f"  Réponse: {resp.text}")

    # 4. Tester avec un autre endpoint
    print("\n[4] Test API Storage - Signed URL endpoint")
    print("-" * 40)
    
    resp = requests.post(
        f"{URL}/storage/v1/object/sign/community-media/test/file.txt",
        headers=HEADERS,
        json={"expiresIn": 3600},
        timeout=30,
    )
    print(f"  HTTP {resp.status_code}")
    print(f"  Réponse: {resp.text}")

    print("\n" + "=" * 60)


if __name__ == "__main__":
    main()
