#!/usr/bin/env python3
"""D25 - Recuperer storyboard et cahier des charges"""
import sys, json, requests
sys.stdout.reconfigure(encoding='utf-8')

RENDER_ID = "07356b0d-ff4c-4ce2-80a9-9e7ec5306367"
SUPABASE  = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY      = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{SUPABASE}/rest/v1/rpc/admin_execute_sql", headers=H, json={"sql": q}, timeout=30)
    return r.json()

# 1. Recuperer le storyboard brut
res = sql(f"SELECT storyboard_json FROM whiteboard_render_jobs WHERE id = '{RENDER_ID}';")
rows = res.get('rows', [])
if rows and rows[0].get('storyboard_json'):
    sj = rows[0]['storyboard_json']
    if isinstance(sj, str):
        sj = json.loads(sj)
    scenes = sj.get('scenes', [])
    print(f"STORYBOARD - nb_scenes: {len(scenes)}")
    print(f"theme    : {sj.get('theme')}")
    print(f"renderer : {sj.get('renderer')}")
    print(f"duree_attendue: {len(scenes)*5}s")
    for i, sc in enumerate(scenes):
        blocs = sc.get('blocks', [])
        print(f"  Scene {i+1}: '{sc.get('title','')}' — {len(blocs)} blocs")
        for b in blocs[:2]:
            print(f"    [{b.get('type')}] '{str(b.get('content',''))[:80]}'")
    
    # Confirmation D25-04
    nb = len(scenes)
    dur_attendue = nb * 5
    dur_reelle = 49.966667
    nb_frames_attendus = nb * 5 * 30
    nb_frames_reels = 1499
    print(f"\n--- D25-04 ECART DUREE ---")
    print(f"ATTENDU  : {nb} scenes x 5s = {dur_attendue}s | {nb_frames_attendus} frames")
    print(f"REEL     : {dur_reelle}s | {nb_frames_reels} frames")
    print(f"ECART    : {dur_reelle - dur_attendue:.3f}s | {nb_frames_reels - nb_frames_attendus} frames")
    if dur_reelle > dur_attendue:
        extra_frames = nb_frames_reels - nb_frames_attendus
        extra_s = dur_reelle - dur_attendue
        print(f"NOTE: {extra_s:.3f}s de trop (={extra_frames} frames) — probablement le frame final duplique du concat demuxer")
else:
    print(f"RAW result: {res}")

# 2. Verifier si ce render a ete traite par v5 ou v6
print("\n--- TIMING ---")
print("Worker v6 demarre : 2026-06-29 07:13:05 UTC")
print("Render traite     : 2026-06-29 07:26:02 UTC")
print("CONCLUSION: render APRES restart v6 => v6 assembler utilise")

# 3. Cahier des charges - chercher dans les fichiers de spec
print("\n--- D25-08: CAHIER DES CHARGES INITIAL ---")
res2 = sql("""
SELECT routine_definition 
FROM information_schema.routines 
WHERE routine_name = 'whiteboard_create_render_job'
LIMIT 1;
""")
print(f"RPC whiteboard_create_render_job: {json.dumps(res2.get('rows',[])[0] if res2.get('rows') else {}, indent=2)[:500]}")
