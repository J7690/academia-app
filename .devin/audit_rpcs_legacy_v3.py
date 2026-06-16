#!/usr/bin/env python3
"""Vérifie quelles RPCs référencent les colonnes legacy via prosrc."""
import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": KEY, "Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q.rstrip().rstrip(';')}, timeout=30)
    d = r.json()
    if isinstance(d, dict) and d.get('ok'): return d.get('rows', [])
    print(f"  SQL ERR: {d}")
    return []

# Search for RPCs whose body contains legacy column names
# Using prosrc which contains the function body
for col in ['video_url', 'video_renditions', 'thumbnail_url', 'submission_url']:
    print(f"\n=== RPCs contenant '.{col}' dans leur corps ===")
    rows = sql(f"""
        SELECT p.proname
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.prosrc LIKE '%.{col}%'
        ORDER BY p.proname
    """)
    if rows:
        for r in rows:
            name = r.get('proname', r) if isinstance(r, dict) else r
            print(f"  ❌ {name}")
    else:
        print(f"  ✅ Aucune RPC")
