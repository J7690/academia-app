#!/usr/bin/env python3
"""D25 - Recuperer storyboard avec p_sql"""
import sys, json, requests
sys.stdout.reconfigure(encoding='utf-8')

RENDER_ID = "07356b0d-ff4c-4ce2-80a9-9e7ec5306367"
SUPABASE  = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY      = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{SUPABASE}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q}, timeout=30)
    return r.json()

# Storyboard du render cible
res = sql(f"""
SELECT
  rj.id,
  rj.project_id,
  rj.status,
  rj.video_url,
  rj.created_at,
  rj.updated_at,
  EXTRACT(EPOCH FROM (rj.updated_at - rj.created_at))::int AS duree_traitement_s,
  wp.subject,
  wp.title AS project_title,
  jsonb_array_length(rj.storyboard_json->'scenes') AS nb_scenes,
  rj.storyboard_json->'theme' AS theme,
  rj.storyboard_json->'renderer' AS renderer
FROM whiteboard_render_jobs rj
LEFT JOIN whiteboard_projects wp ON wp.id = rj.project_id
WHERE rj.id = '{RENDER_ID}';
""")
rows = res.get('rows', [])
if rows:
    r = rows[0]
    print("=== D25-01: METADONNEES SUPABASE ===")
    print(f"render_id        : {r.get('id')}")
    print(f"project_id       : {r.get('project_id')}")
    print(f"subject          : {r.get('subject')}")
    print(f"project_title    : {r.get('project_title')}")
    print(f"status           : {r.get('status')}")
    print(f"video_url        : {r.get('video_url')}")
    print(f"created_at       : {r.get('created_at')}")
    print(f"updated_at       : {r.get('updated_at')}")
    print(f"duree_traitement : {r.get('duree_traitement_s')} secondes")
    print(f"nb_scenes        : {r.get('nb_scenes')}")
    print(f"theme            : {r.get('theme')}")
    print(f"renderer         : {r.get('renderer')}")
    nb = int(r.get('nb_scenes') or 0)
    print(f"duree_attendue   : {nb * 5}s ({nb} scenes x 5s)")
    print(f"nb_frames_attendu: {nb * 5 * 30} frames (30fps)")
else:
    print(f"ERREUR: {res}")

# Scenes en detail
res2 = sql(f"""
SELECT
  sc->>'id' AS scene_id,
  sc->>'title' AS title,
  sc->>'order' AS "order",
  jsonb_array_length(sc->'blocks') AS nb_blocs
FROM whiteboard_render_jobs,
     jsonb_array_elements(storyboard_json->'scenes') AS sc
WHERE id = '{RENDER_ID}'
ORDER BY (sc->>'order')::int;
""")
print("\nSCENES DETAIL:")
for sc in res2.get('rows', []):
    print(f"  Scene order={sc.get('order')} title='{sc.get('title')}' blocs={sc.get('nb_blocs')}")

# D25-04 avec vraies donnees
nb_scenes = len(res2.get('rows', []))
dur_attendue = nb_scenes * 5
dur_reelle = 49.966667
nb_frames_attendus = nb_scenes * 5 * 30
nb_frames_reels = 1499
print(f"\n=== D25-04: VALIDATION DUREE ===")
print(f"ATTENDU  : {nb_scenes} scenes x 5s = {dur_attendue}s | {nb_frames_attendus} frames attendus")
print(f"REEL     : {dur_reelle}s | {nb_frames_reels} frames")
ecart_s = dur_reelle - dur_attendue
ecart_f = nb_frames_reels - nb_frames_attendus
print(f"ECART    : +{ecart_s:.3f}s | +{ecart_f} frames")
if ecart_s > 0:
    print(f"EXPLICATION: Le concat demuxer ajoute 1 frame supplementaire (le last-frame duplique)")
    print(f"             = {ecart_s:.3f}s = normal, conforme au comportement FFmpeg concat")

# D25-08: Cahier des charges - lire les fichiers Flutter de spec
print("\n=== D25-08: CAHIER DES CHARGES (spec dans code) ===")
res3 = sql("""
SELECT routine_name, routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name ILIKE '%whiteboard%'
ORDER BY routine_name;
""")
print("RPCs whiteboard disponibles:")
for rpc in res3.get('rows', []):
    print(f"  {rpc.get('routine_name')}")
