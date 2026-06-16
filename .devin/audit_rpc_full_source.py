#!/usr/bin/env python3
"""Extraire le code source complet des RPCs critiques sans troncature."""

import requests
import json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {"apikey": KEY, "Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}

def q(sql):
    r = requests.post(f"{URL}/rest/v1/rpc/execute_sql", headers=HEADERS, json={"sql_query": sql}, timeout=30)
    if r.status_code == 200:
        return r.json()
    return f"ERR {r.status_code}: {r.text[:500]}"

rpcs = [
    'app_student_create_free_video',
    'app_student_set_free_video_main_renditions',
    'app_videoasset_get_playback_for_direct_url',
    'app_student_upload_free_video',
]

for name in rpcs:
    print(f"\n{'='*70}")
    print(f"  RPC: {name}")
    print(f"{'='*70}")
    rows = q(f"""
        SELECT p.prosrc
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE p.proname = '{name}'
          AND n.nspname = 'public'
    """)
    if isinstance(rows, list) and rows:
        for r in rows:
            src = r.get('prosrc', '(no source)')
            print(src)
    else:
        print(f"  NOT FOUND or error: {rows}")
