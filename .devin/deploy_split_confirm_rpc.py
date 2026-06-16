#!/usr/bin/env python3
"""Déploie la RPC app_confirm_ligdicash_payment mise à jour avec le split actor_balances."""

import requests
import json

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

HEADERS = {
    "apikey": SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}

def execute_ddl(sql):
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/execute_ddl",
        headers=HEADERS,
        json={"ddl_query": sql},
        timeout=30,
    )
    return r.status_code, r.text[:500]

def main():
    # Read the SQL migration file
    with open("sql_changes/change_20260407_add_split_to_confirm_rpc.sql", "r", encoding="utf-8") as f:
        sql = f.read()

    print("Deploying updated app_confirm_ligdicash_payment with revenue split...")
    print(f"SQL length: {len(sql)} chars")

    status, text = execute_ddl(sql)
    print(f"Status: {status}")
    print(f"Response: {text}")

    if status == 200:
        print("\n✅ RPC déployée avec succès!")
        
        # Verify the split is now in the function
        r = requests.post(
            f"{SUPABASE_URL}/rest/v1/rpc/execute_sql",
            headers=HEADERS,
            json={"sql_query": """
                SELECT prosrc FROM pg_proc 
                WHERE proname = 'app_confirm_ligdicash_payment' LIMIT 1
            """},
            timeout=15,
        )
        if r.status_code == 200:
            data = r.json()
            if isinstance(data, list) and len(data) > 0:
                src = str(data[0].get("prosrc", ""))
                has_actor = "actor_balances" in src
                has_split = "revenue_split" in src
                print(f"\nVérification post-déploiement:")
                print(f"  Contient 'actor_balances': {'✅ OUI' if has_actor else '❌ NON'}")
                print(f"  Contient 'revenue_split': {'✅ OUI' if has_split else '❌ NON'}")
    else:
        print(f"\n❌ Erreur de déploiement!")

if __name__ == "__main__":
    main()
