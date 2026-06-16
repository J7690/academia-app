#!/usr/bin/env python3
"""Récupère le source complet de app_confirm_ligdicash_payment depuis Supabase."""

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

def execute_sql(sql):
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/execute_sql",
        headers=HEADERS,
        json={"sql_query": sql},
        timeout=15,
    )
    if r.status_code == 200:
        return r.json()
    return {"error": r.status_code, "text": r.text[:500]}

result = execute_sql("""
    SELECT pg_get_functiondef(oid) AS full_def
    FROM pg_proc 
    WHERE proname = 'app_confirm_ligdicash_payment'
    LIMIT 1
""")

if isinstance(result, list) and len(result) > 0:
    src = result[0].get("full_def", "")
    with open("logs/current_confirm_rpc_source.sql", "w", encoding="utf-8") as f:
        f.write(src)
    print(f"Source sauvé dans logs/current_confirm_rpc_source.sql ({len(src)} chars)")
else:
    print(f"Erreur: {result}")
