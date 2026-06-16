#!/usr/bin/env python3
"""Vérifie quelles RPCs référencent encore les colonnes legacy via pg_proc."""
import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": KEY, "Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q.rstrip().rstrip(';')}, timeout=30)
    d = r.json()
    return d.get('rows', []) if isinstance(d, dict) and d.get('ok') else []

legacy_cols = ['video_url', 'video_renditions', 'thumbnail_url', 'submission_url']

rows = sql("""
    SELECT p.proname as name, pg_get_functiondef(p.oid) as src
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND (
        p.proname LIKE '%challenge%'
        OR p.proname LIKE '%free_video%'
        OR p.proname LIKE '%video_feed%'
        OR p.proname LIKE '%videoasset%'
      )
    ORDER BY p.proname
""")

print(f"Analysé {len(rows)} RPCs\n")

broken = []
ok_list = []
for row in rows:
    if not isinstance(row, dict): continue
    name = row.get('name', '?')
    src = row.get('src', '') or ''
    
    found = []
    for col in legacy_cols:
        # Match table.column references like cp.video_url, fv.video_url
        if f'.{col}' in src:
            found.append(col)
    
    if found:
        broken.append((name, found))
        print(f"  ❌ {name}: {', '.join(found)}")
    else:
        ok_list.append(name)
        print(f"  ✅ {name}")

print(f"\n{'='*60}")
print(f"RÉSUMÉ: {len(broken)} RPCs CASSÉES / {len(rows)} analysées")
for name, cols in broken:
    print(f"  ❌ {name}: {', '.join(cols)}")
print(f"\n{len(ok_list)} RPCs OK")
