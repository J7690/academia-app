#!/usr/bin/env python3
"""Vérifie quelles RPCs référencent encore les colonnes legacy supprimées."""
import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": KEY, "Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q.rstrip().rstrip(';')}, timeout=30)
    d = r.json()
    return d.get('rows', []) if isinstance(d, dict) and d.get('ok') else []

# Get all challenge/video RPC source code and check for legacy columns
legacy_cols = ['video_url', 'video_renditions', 'thumbnail_url', 'submission_url']

rows = sql("""
    SELECT routine_name, routine_definition
    FROM information_schema.routines
    WHERE routine_type = 'FUNCTION'
      AND routine_schema = 'public'
      AND (
        routine_name LIKE '%challenge%'
        OR routine_name LIKE '%free_video%'
        OR routine_name LIKE '%video_feed%'
        OR routine_name LIKE '%videoasset%'
        OR routine_name LIKE '%video_like%'
        OR routine_name LIKE '%video_comment%'
        OR routine_name LIKE '%video_report%'
      )
    ORDER BY routine_name
""")

print(f"Analysé {len(rows)} RPCs\n")

broken = []
for row in rows:
    if not isinstance(row, dict):
        continue
    name = row.get('routine_name', '?')
    body = row.get('routine_definition', '') or ''
    
    found_legacy = []
    for col in legacy_cols:
        # Check for column references like cp.video_url, fv.video_url, etc.
        # but not in comments or as parameter names
        if f'.{col}' in body or f'"{col}"' in body:
            found_legacy.append(col)
    
    if found_legacy:
        broken.append((name, found_legacy))
        print(f"  ❌ {name}: référence {', '.join(found_legacy)}")
    else:
        print(f"  ✅ {name}")

print(f"\n{'='*60}")
print(f"RÉSUMÉ: {len(broken)} RPCs avec colonnes legacy sur {len(rows)} analysées")
for name, cols in broken:
    print(f"  ❌ {name}: {', '.join(cols)}")
