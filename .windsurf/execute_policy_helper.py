#!/usr/bin/env python3
"""Exécute la fonction helper pour créer les policies via SQL direct."""

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
    """Exécute du SQL via execute_sql RPC."""
    resp = requests.post(
        f"{URL}/rest/v1/rpc/execute_sql",
        headers=HEADERS,
        json={"sql_query": sql},
        timeout=60,
    )
    print(f"  HTTP {resp.status_code}")
    try:
        return resp.json()
    except:
        return {"raw": resp.text}


def main():
    print("=" * 60)
    print("EXÉCUTION DE LA FONCTION HELPER VIA SQL")
    print("=" * 60)

    # Appeler la fonction via SELECT
    print("\n[1] Appel de admin_create_storage_policies_for_community_media()")
    print("-" * 40)
    result = execute_sql("SELECT admin_create_storage_policies_for_community_media()")
    print(f"  Résultat: {json.dumps(result, indent=2, ensure_ascii=False)}")

    # Vérification
    print("\n[2] Vérification des policies créées")
    print("-" * 40)
    result = execute_sql("""
        SELECT polname, polcmd 
        FROM pg_policy 
        WHERE polrelid = 'storage.objects'::regclass
          AND polname LIKE '%community%'
    """)
    print(f"  Policies: {json.dumps(result, indent=2, ensure_ascii=False)}")

    print("\n" + "=" * 60)
    print("FIN")
    print("=" * 60)


if __name__ == "__main__":
    main()
