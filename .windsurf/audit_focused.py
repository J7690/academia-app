#!/usr/bin/env python3
"""Audit focalisé: colonnes free_videos et challenge_participations."""

import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": KEY, "Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q.rstrip().rstrip(';')}, timeout=30)
    d = r.json()
    if isinstance(d, dict) and d.get('ok') == False:
        return None, d.get('error')
    rows = d.get('rows', d) if isinstance(d, dict) else d
    return rows, None

def show_cols(table):
    s, t = table.split('.')
    rows, err = sql(f"SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='{s}' AND table_name='{t}' ORDER BY ordinal_position")
    print(f"\n{'='*60}\n{table} COLONNES\n{'='*60}")
    if err: print(f"  ERR: {err}"); return
    if not rows: print("  INEXISTANTE"); return
    for r in rows:
        if isinstance(r, dict):
            print(f"  {r['column_name']:35s} {r['data_type']}")
        else:
            print(f"  {r}")

# 1. Colonnes
for t in ['app.free_videos', 'app.challenge_participations']:
    show_cols(t)

# 2. Vérifier si video_url existe dans free_videos
print(f"\n{'='*60}\nCHECK: video_url dans free_videos?\n{'='*60}")
rows, err = sql("SELECT column_name FROM information_schema.columns WHERE table_schema='app' AND table_name='free_videos' AND column_name='video_url'")
if err: print(f"  ERR: {err}")
elif rows: print(f"  OUI — video_url EXISTE")
else: print(f"  NON — video_url N'EXISTE PAS <<<")

# 3. Vérifier si video_url existe dans challenge_participations
print(f"\n{'='*60}\nCHECK: video_url dans challenge_participations?\n{'='*60}")
rows, err = sql("SELECT column_name FROM information_schema.columns WHERE table_schema='app' AND table_name='challenge_participations' AND column_name='video_url'")
if err: print(f"  ERR: {err}")
elif rows: print(f"  OUI — video_url EXISTE")
else: print(f"  NON — video_url N'EXISTE PAS <<<")

# 4. Vérifier colonnes legacy vs new
for col in ['video_url', 'video_renditions', 'thumbnail_url', 'video_asset_id', 'submission_url', 'submission_text']:
    for t in ['free_videos', 'challenge_participations']:
        rows, err = sql(f"SELECT column_name FROM information_schema.columns WHERE table_schema='app' AND table_name='{t}' AND column_name='{col}'")
        exists = "OUI" if (rows and not err) else "NON"
        print(f"  {t:30s} . {col:25s} = {exists}")

# 5. Comptes
print(f"\n{'='*60}\nCOMPTES\n{'='*60}")
for t in ['app.free_videos', 'app.challenge_participations', 'app.video_renditions']:
    rows, err = sql(f"SELECT COUNT(*) as cnt FROM {t}")
    if err: print(f"  {t:40s} ERR: {err}")
    elif rows and isinstance(rows[0], dict): print(f"  {t:40s} {rows[0]['cnt']}")
    else: print(f"  {t:40s} {rows}")
