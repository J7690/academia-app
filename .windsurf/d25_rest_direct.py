#!/usr/bin/env python3
"""D25 - Acces Supabase REST direct (pas de RPC SQL)"""
import sys, json, requests
sys.stdout.reconfigure(encoding='utf-8')

RENDER_ID = "07356b0d-ff4c-4ce2-80a9-9e7ec5306367"
SUPABASE  = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY      = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}

# 1. Via RPC whiteboard_get_render_status (deja connu)
print("=== D25-01: VIA RPC whiteboard_get_render_status ===")
r = requests.post(f"{SUPABASE}/rest/v1/rpc/whiteboard_get_render_status", headers=H,
    json={"p_render_id": RENDER_ID}, timeout=20)
print(f"HTTP: {r.status_code}")
data = r.json()
print(json.dumps(data, indent=2, ensure_ascii=False)[:3000])

# Extraire les infos
if isinstance(data, dict):
    render = data.get('render', {})
    if render:
        sb = render.get('storyboard_json', {})
        if isinstance(sb, str): sb = json.loads(sb)
        scenes = sb.get('scenes', []) if sb else []
        nb_scenes = len(scenes)
        print(f"\nnb_scenes        : {nb_scenes}")
        print(f"duree_attendue   : {nb_scenes * 5}s")
        print(f"nb_frames_attend : {nb_scenes * 5 * 30}")

        # D25-04
        dur_reelle = 49.966667
        nb_frames_reels = 1499
        dur_attendue = nb_scenes * 5
        print(f"\n=== D25-04: VALIDATION DUREE ===")
        print(f"ATTENDU  : {nb_scenes} scenes x 5s = {dur_attendue}s | {nb_scenes*5*30} frames")
        print(f"REEL     : {dur_reelle}s | {nb_frames_reels} frames")
        print(f"ECART    : +{dur_reelle - dur_attendue:.3f}s | +{nb_frames_reels - nb_scenes*5*30} frames")
        
        for i, sc in enumerate(scenes):
            blocs = sc.get('blocks', [])
            print(f"  Scene {i+1}: '{sc.get('title','')}' — {len(blocs)} blocs")

# 2. Verifier via whiteboard_fetch_queued_jobs si les jobs sont accessibles
print("\n=== TEST RPC whiteboard_mark_done (pour verifier le schema) ===")
r2 = requests.post(f"{SUPABASE}/rest/v1/rpc/whiteboard_create_render_job", headers=H,
    json={"p_project_id": "test-readonly"}, timeout=10)
print(f"HTTP: {r2.status_code} - {r2.text[:200]}")
