#!/usr/bin/env python3
"""Audit complémentaire — RPCs + renditions malformées + cleanup candidates"""
import json, requests, os

CFG = json.load(open(r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\supabase_permanent_config.json"))
H = {
    "apikey": CFG["service_role_key"],
    "Authorization": f"Bearer {CFG['service_role_key']}",
    "Content-Type": "application/json",
}

def sql(q):
    r = requests.post(f"{CFG['url']}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q})
    d = r.json()
    if isinstance(d, str): d = json.loads(d)
    return d.get("rows", []) if d.get("ok") else []

def pr(t):
    print(f"\n{'='*70}\n  {t}\n{'='*70}")

ALL = {}

# =========================================================================
pr("A. RPCs vidéo — recherche par proname directe")
# =========================================================================
# Essayons une approche différente pour les RPCs
rpc_names = [
    'app_videoasset_create_upload_intent',
    'app_videoasset_register_uploaded_source',
    'app_student_unified_video_feed',
    'app_student_create_free_video',
    'app_student_update_free_video',
    'app_student_list_my_free_videos',
    'app_student_get_free_video',
    'app_student_delete_free_video',
    'app_student_update_free_video_overlays',
    'app_student_get_free_video_overlays',
    'app_student_submit_challenge_video',
    'app_student_list_my_challenge_videos',
    'app_admin_list_free_videos',
    'app_admin_moderate_free_video',
    'app_student_remix_video',
]

found_rpcs = []
for name in rpc_names:
    result = sql(f"SELECT 1 as found FROM pg_proc WHERE proname = '{name}'")
    exists = len(result) > 0
    found_rpcs.append({"name": name, "exists": exists})
    status = "✅" if exists else "❌"
    print(f"  {status} {name}")

ALL["rpcs_checked"] = found_rpcs

# Also search broadly
broad_rpcs = sql("""
SELECT proname FROM pg_proc 
WHERE proname LIKE 'app_%video%' OR proname LIKE 'app_%challenge%' 
   OR proname LIKE 'app_%overlay%' OR proname LIKE 'app_%feed%'
ORDER BY proname
""")
ALL["rpcs_broad"] = broad_rpcs
print(f"\n  Recherche large (app_*video*, app_*challenge*, etc.):")
for r in broad_rpcs:
    print(f"    {r['proname']}")

# =========================================================================
pr("B. RENDITIONS MALFORMÉES (rendition_key = chemin storage)")
# =========================================================================
bad_rend = sql("""
SELECT id, video_asset_id, rendition_key, public_url_hint, status
FROM app.video_renditions
WHERE rendition_key LIKE '%/%'
""")
ALL["bad_rendition_keys"] = bad_rend
print(f"  Renditions avec rendition_key contenant '/': {len(bad_rend)}")
for r in bad_rend:
    print(f"    id={r['id'][:12]}... key={r['rendition_key'][:60]}")
    print(f"      url={str(r.get('public_url_hint',''))[:80]}")

# =========================================================================
pr("C. VIDEO_ASSETS en statut anormal (draft/processing)")
# =========================================================================
stuck = sql("""
SELECT id, origin, status, created_at::text, owner_user_id
FROM app.video_assets
WHERE status IN ('draft', 'processing')
ORDER BY created_at DESC
""")
ALL["stuck_assets"] = stuck
print(f"  Assets en draft/processing: {len(stuck)}")
for s in stuck:
    print(f"    {s['id'][:12]}... status={s['status']} origin={s.get('origin')} created={s.get('created_at','?')[:10]}")

# =========================================================================
pr("D. VIDEO_ASSETS 'uploaded' jamais passés à 'ready'")
# =========================================================================
uploaded_old = sql("""
SELECT id, origin, status, created_at::text
FROM app.video_assets
WHERE status = 'uploaded'
ORDER BY created_at ASC
LIMIT 10
""")
ALL["uploaded_not_ready"] = uploaded_old
print(f"  Les 10 plus anciens en 'uploaded':")
for u in uploaded_old:
    print(f"    {u['id'][:12]}... origin={u.get('origin')} created={u.get('created_at','?')[:10]}")

# =========================================================================
pr("E. FREE_VIDEO sans video_asset_id — détail")
# =========================================================================
orphan_fv = sql("""
SELECT id, user_id, title, description, created_at::text, moderation_status
FROM app.free_videos WHERE video_asset_id IS NULL
""")
ALL["orphan_free_videos"] = orphan_fv
print(f"  free_videos sans asset: {len(orphan_fv)}")
for o in orphan_fv:
    print(f"    id={o['id'][:12]}... title={o.get('title')} status={o.get('moderation_status')} created={o.get('created_at','?')[:10]}")

# =========================================================================
pr("F. challenge_video_assets (table vide?)")
# =========================================================================
cva = sql("SELECT * FROM app.challenge_video_assets LIMIT 5")
ALL["challenge_video_assets_sample"] = cva
print(f"  challenge_video_assets: {len(cva)} rows")

# Check if table has any purpose
cva_cols = sql("""
SELECT key as col FROM (SELECT row_to_json(t.*) as j FROM app.challenge_video_assets t LIMIT 1) sub, json_each(sub.j)
""")
if not cva_cols:
    # Try via regclass
    cva_cols = sql("SELECT attname as col FROM pg_attribute WHERE attrelid = 'app.challenge_video_assets'::regclass AND attnum > 0 AND NOT attisdropped ORDER BY attnum")
ALL["cva_columns"] = cva_cols
if cva_cols:
    print(f"  Colonnes: {', '.join(c['col'] for c in cva_cols)}")
else:
    print(f"  Colonnes: non détectables")

# =========================================================================
pr("G. EDGE FUNCTIONS — vérifier les fonctions de transcodage/merge")
# =========================================================================
# Check for transcode/merge related functions
ef_funcs = sql("""
SELECT proname FROM pg_proc 
WHERE proname LIKE '%transcode%' OR proname LIKE '%merge%' OR proname LIKE '%watermark%'
ORDER BY proname
""")
ALL["edge_related_funcs"] = ef_funcs
print(f"  Fonctions transcode/merge/watermark: {len(ef_funcs)}")
for f in ef_funcs:
    print(f"    {f['proname']}")

# =========================================================================
pr("H. RÉSUMÉ DES PROBLÈMES À NETTOYER")
# =========================================================================
problems = []

if bad_rend:
    problems.append(f"🔴 {len(bad_rend)} renditions avec rendition_key malformée (contient des chemins storage)")

if orphan_fv:
    problems.append(f"🟡 {len(orphan_fv)} free_videos sans video_asset_id")

stuck_draft = [s for s in stuck if s['status'] == 'draft']
stuck_proc = [s for s in stuck if s['status'] == 'processing']
if stuck_draft:
    problems.append(f"🟡 {len(stuck_draft)} video_assets en 'draft' (possiblement abandonnés)")
if stuck_proc:
    problems.append(f"🔴 {len(stuck_proc)} video_assets en 'processing' (possiblement bloqués)")

uploaded_cnt = len(uploaded_old)
if uploaded_cnt:
    problems.append(f"🟡 62 video_assets en 'uploaded' — transcodage jamais déclenché?")

problems.append("⚠️ AUCUN INDEX sur video_assets, video_sources, video_renditions, free_videos, free_video_overlays")
problems.append("ℹ️ challenge_video_assets: table VIDE (0 rows) — résidu?")

print(f"  {len(problems)} problèmes détectés:")
for p in problems:
    print(f"    {p}")

ALL["problems"] = problems

# Save
out = r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\logs\audit_video_complement.json"
os.makedirs(os.path.dirname(out), exist_ok=True)
with open(out, "w", encoding="utf-8") as f:
    json.dump({"date": __import__('datetime').datetime.now().isoformat(), "results": ALL}, f, indent=2, ensure_ascii=False, default=str)
print(f"\n  → {out}")
