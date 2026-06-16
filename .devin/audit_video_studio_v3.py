#!/usr/bin/env python3
"""Audit Supabase v3 — Utilise des requêtes directes qui fonctionnent avec admin_execute_sql"""
import json, requests, os
from datetime import datetime

CFG = json.load(open(r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\supabase_permanent_config.json"))
H = {
    "apikey": CFG["service_role_key"],
    "Authorization": f"Bearer {CFG['service_role_key']}",
    "Content-Type": "application/json",
}

def sql(q):
    r = requests.post(f"{CFG['url']}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q})
    if r.status_code != 200:
        return []
    d = r.json()
    if isinstance(d, str):
        d = json.loads(d)
    return d.get("rows", []) if d.get("ok") else []

def pr(t):
    print(f"\n{'='*70}\n  {t}\n{'='*70}")

ALL = {}

# =========================================================================
pr("1. TABLES VIDÉO — colonnes via SELECT * LIMIT 0 + trick")
# =========================================================================
tables_to_audit = [
    'video_assets', 'video_sources', 'video_renditions',
    'challenge_participations', 'free_videos',
    'free_video_overlays', 'challenge_video_overlays',
    'challenges', 'challenge_video_assets',
]

for tbl in tables_to_audit:
    # Get column names using json_object_keys on a row
    cols = sql(f"""
    SELECT key as col_name 
    FROM (SELECT row_to_json(t.*) as j FROM app.{tbl} t LIMIT 1) sub, 
         json_each(sub.j)
    """)
    cnt_r = sql(f"SELECT count(*) as cnt FROM app.{tbl}")
    cnt = cnt_r[0]['cnt'] if cnt_r else '?'
    ALL[f"table_{tbl}"] = {"count": cnt, "columns": [c['col_name'] for c in cols]}
    
    if cols:
        col_names = [c['col_name'] for c in cols]
        print(f"\n  {tbl} ({cnt} rows, {len(col_names)} cols):")
        print(f"    {', '.join(col_names)}")
    else:
        # Table might be empty, try another approach
        cols2 = sql(f"""
        SELECT column_name as col_name
        FROM information_schema.columns 
        WHERE table_schema = 'app' AND table_name = '{tbl}'
        ORDER BY ordinal_position
        """)
        if not cols2:
            # Last resort: SET search_path
            cols2 = sql(f"""
            SELECT a.attname as col_name
            FROM pg_attribute a
            WHERE a.attrelid = 'app.{tbl}'::regclass
            AND a.attnum > 0 AND NOT a.attisdropped
            ORDER BY a.attnum
            """)
        col_names = [c['col_name'] for c in cols2] if cols2 else []
        ALL[f"table_{tbl}"]["columns"] = col_names
        print(f"\n  {tbl} ({cnt} rows, {len(col_names)} cols):")
        if col_names:
            print(f"    {', '.join(col_names)}")
        else:
            print(f"    (colonnes non détectables, mais table existe avec {cnt} rows)")

# =========================================================================
pr("2. RPCs vidéo/studio (via pg_proc + regclass trick)")
# =========================================================================

rpcs = sql("""
SELECT p.proname as name, n.nspname as schema,
       pg_catalog.pg_get_function_identity_arguments(p.oid) as args
FROM pg_catalog.pg_proc p
JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('public', 'app')
AND (p.proname LIKE '%video%' OR p.proname LIKE '%challenge%' OR p.proname LIKE '%overlay%'
     OR p.proname LIKE '%rendition%' OR p.proname LIKE '%transcode%' OR p.proname LIKE '%upload%'
     OR p.proname LIKE '%playback%' OR p.proname LIKE '%segment%' OR p.proname LIKE '%free_video%'
     OR p.proname LIKE 'app_%video%' OR p.proname LIKE 'app_student%' OR p.proname LIKE 'app_admin%challenge%')
ORDER BY n.nspname, p.proname
""")
ALL["rpcs"] = rpcs
print(f"  {len(rpcs)} fonctions:")
for r in rpcs:
    a = r.get('args', '')[:50]
    print(f"  [{r['schema']}] {r['name']}({a})")

# =========================================================================
pr("3. COMPTAGES DÉTAILLÉS")
# =========================================================================

# video_assets par statut
statuses = sql("SELECT COALESCE(status, 'NULL') as status, count(*) as cnt FROM app.video_assets GROUP BY status ORDER BY cnt DESC")
ALL["asset_statuses"] = statuses
print("  video_assets par statut:")
for s in statuses:
    print(f"    {str(s['status']):25s} → {s['cnt']}")

# video_assets par origin
origins = sql("SELECT COALESCE(origin, 'NULL') as origin, count(*) as cnt FROM app.video_assets GROUP BY origin ORDER BY cnt DESC")
ALL["asset_origins"] = origins
print("\n  video_assets par origin:")
for o in origins:
    print(f"    {str(o['origin']):30s} → {o['cnt']}")

# rendition_keys
rend_keys = sql("SELECT rendition_key, count(*) as cnt FROM app.video_renditions GROUP BY rendition_key ORDER BY cnt DESC")
ALL["rendition_keys"] = rend_keys
print("\n  video_renditions par rendition_key:")
for k in rend_keys:
    print(f"    {str(k['rendition_key']):30s} → {k['cnt']}")

# =========================================================================
pr("4. ORPHELINS & DOUBLONS")
# =========================================================================

# 4a. video_assets sans AUCUNE rendition
orphan_a = sql("""
SELECT va.id, va.origin, va.status
FROM app.video_assets va
WHERE NOT EXISTS (SELECT 1 FROM app.video_renditions vr WHERE vr.video_asset_id = va.id)
LIMIT 30
""")
ALL["orphan_no_rendition"] = orphan_a
print(f"  4a. video_assets SANS rendition: {len(orphan_a)}")
for o in orphan_a[:5]:
    print(f"      {o['id'][:12]}... origin={o.get('origin')} status={o.get('status')}")

# 4b. video_assets sans source
orphan_b = sql("""
SELECT va.id, va.origin, va.status
FROM app.video_assets va
WHERE NOT EXISTS (SELECT 1 FROM app.video_sources vs WHERE vs.video_asset_id = va.id)
LIMIT 30
""")
ALL["orphan_no_source"] = orphan_b
print(f"  4b. video_assets SANS source: {len(orphan_b)}")

# 4c. renditions sans URL
rend_no_url = sql("""
SELECT vr.id, vr.video_asset_id, vr.rendition_key
FROM app.video_renditions vr
WHERE vr.public_url_hint IS NULL OR vr.public_url_hint = ''
LIMIT 20
""")
ALL["renditions_no_url"] = rend_no_url
print(f"  4c. renditions SANS public_url_hint: {len(rend_no_url)}")

# 4d. Doublons renditions
dup_rend = sql("""
SELECT video_asset_id, rendition_key, count(*) as cnt
FROM app.video_renditions
GROUP BY video_asset_id, rendition_key
HAVING count(*) > 1
""")
ALL["dup_renditions"] = dup_rend
print(f"  4d. Doublons renditions (asset+key): {len(dup_rend)}")
for d in dup_rend[:5]:
    print(f"      asset={d['video_asset_id'][:12]}... key={d['rendition_key']} x{d['cnt']}")

# 4e. free_videos sans video_asset_id
orphan_fv = sql("SELECT id, user_id FROM app.free_videos WHERE video_asset_id IS NULL")
ALL["orphan_fv_no_asset"] = orphan_fv
print(f"  4e. free_videos SANS video_asset_id: {len(orphan_fv)}")
for o in orphan_fv[:3]:
    print(f"      id={o['id'][:12]}... user={o.get('user_id','?')[:12]}...")

# 4f. Overlays sans free_video existant
orphan_ov = sql("""
SELECT fvo.id, fvo.free_video_id
FROM app.free_video_overlays fvo
WHERE NOT EXISTS (SELECT 1 FROM app.free_videos fv WHERE fv.id = fvo.free_video_id)
""")
ALL["orphan_overlays"] = orphan_ov
print(f"  4f. free_video_overlays ORPHELINS (fv inexistant): {len(orphan_ov)}")

# 4g. video_assets sans AUCUN rattachement (ni free_video, ni challenge_participation)
orphan_unattached = sql("""
SELECT va.id, va.origin, va.status, va.created_at::text
FROM app.video_assets va
WHERE NOT EXISTS (SELECT 1 FROM app.free_videos fv WHERE fv.video_asset_id = va.id)
AND NOT EXISTS (SELECT 1 FROM app.challenge_participations cp WHERE cp.video_asset_id = va.id)
LIMIT 30
""")
ALL["orphan_unattached_assets"] = orphan_unattached
print(f"  4g. video_assets SANS rattachement (ni fv ni cp): {len(orphan_unattached)}")
for o in orphan_unattached[:5]:
    print(f"      {o['id'][:12]}... origin={o.get('origin')} status={o.get('status')} created={o.get('created_at','?')[:10]}")

# =========================================================================
pr("5. STORAGE BUCKETS")
# =========================================================================
buckets = sql("SELECT id, name, public FROM storage.buckets ORDER BY name")
ALL["buckets"] = buckets
for b in buckets:
    p = "PUBLIC" if b['public'] else "PRIVATE"
    print(f"  {b['name']:35s} {p}")

# Fichiers dans le bucket video-assets
va_files = sql("""
SELECT count(*) as cnt, 
       COALESCE(sum(metadata->>'size')::bigint, 0) as total_bytes
FROM storage.objects 
WHERE bucket_id = 'video-assets'
""")
ALL["video_assets_storage"] = va_files
if va_files:
    cnt = va_files[0]['cnt']
    sz = va_files[0]['total_bytes']
    sz_mb = sz / 1048576 if sz else 0
    print(f"\n  Bucket 'video-assets': {cnt} fichiers, {sz_mb:.1f} MB total")

# Fichiers dans challenge-media
cm_files = sql("""
SELECT count(*) as cnt
FROM storage.objects 
WHERE bucket_id = 'challenge-media'
""")
if cm_files:
    print(f"  Bucket 'challenge-media': {cm_files[0]['cnt']} fichiers")

# =========================================================================
pr("6. ÉCHANTILLONS DE DONNÉES")
# =========================================================================

# Sample video_asset
sample_va = sql("SELECT * FROM app.video_assets ORDER BY created_at DESC LIMIT 2")
ALL["sample_video_asset"] = sample_va
if sample_va:
    print("  Dernier video_asset:")
    for k, v in sample_va[0].items():
        v_str = str(v)[:80]
        print(f"    {k:25s} = {v_str}")

# Sample rendition
sample_vr = sql("SELECT * FROM app.video_renditions ORDER BY created_at DESC LIMIT 2")
ALL["sample_rendition"] = sample_vr
if sample_vr:
    print("\n  Dernière rendition:")
    for k, v in sample_vr[0].items():
        v_str = str(v)[:80]
        print(f"    {k:25s} = {v_str}")

# Sample free_video
sample_fv = sql("SELECT * FROM app.free_videos ORDER BY created_at DESC LIMIT 2")
ALL["sample_free_video"] = sample_fv
if sample_fv:
    print("\n  Dernière free_video:")
    for k, v in sample_fv[0].items():
        v_str = str(v)[:80]
        print(f"    {k:25s} = {v_str}")

# Sample overlay
sample_ov = sql("SELECT id, free_video_id, overlays::text as overlays_text FROM app.free_video_overlays ORDER BY created_at DESC LIMIT 1")
ALL["sample_overlay"] = sample_ov
if sample_ov:
    print(f"\n  Dernier overlay: fv={sample_ov[0].get('free_video_id','?')[:15]}...")
    ov_text = sample_ov[0].get('overlays_text', '')[:200]
    print(f"    overlays={ov_text}")

# =========================================================================
pr("7. INDEXES + RLS + TRIGGERS + FK (via regclass)")
# =========================================================================

# Indexes via regclass trick
for tbl in ['video_assets', 'video_sources', 'video_renditions', 'free_videos', 'free_video_overlays']:
    idxs = sql(f"""
    SELECT indexrelid::regclass::text as idx
    FROM pg_index WHERE indrelid = 'app.{tbl}'::regclass
    """)
    if idxs:
        print(f"  [{tbl}] indexes: {', '.join(i['idx'] for i in idxs)}")
    else:
        print(f"  [{tbl}] aucun index")
    ALL[f"idx_{tbl}"] = idxs

# RLS enabled?
for tbl in ['video_assets', 'video_sources', 'video_renditions', 'free_videos', 'free_video_overlays', 'challenge_participations']:
    rls = sql(f"SELECT relrowsecurity FROM pg_class WHERE oid = 'app.{tbl}'::regclass")
    enabled = rls[0]['relrowsecurity'] if rls else '?'
    print(f"  [{tbl}] RLS enabled: {enabled}")
    ALL[f"rls_{tbl}"] = enabled

# FK 
for tbl in ['video_sources', 'video_renditions', 'free_videos', 'free_video_overlays', 'challenge_participations']:
    fks = sql(f"""
    SELECT conname, pg_get_constraintdef(oid) as def
    FROM pg_constraint
    WHERE conrelid = 'app.{tbl}'::regclass AND contype = 'f'
    """)
    ALL[f"fk_{tbl}"] = fks
    for f in fks:
        print(f"  [{tbl}] FK: {f['conname']} → {f['def'][:60]}")

# Triggers
for tbl in ['video_assets', 'free_videos', 'challenge_participations', 'free_video_overlays']:
    trigs = sql(f"""
    SELECT tgname FROM pg_trigger
    WHERE tgrelid = 'app.{tbl}'::regclass AND NOT tgisinternal
    """)
    ALL[f"trig_{tbl}"] = trigs
    if trigs:
        print(f"  [{tbl}] triggers: {', '.join(t['tgname'] for t in trigs)}")

# =========================================================================
pr("SAUVEGARDE")
# =========================================================================
out = r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\logs\audit_video_studio_supabase_v3.json"
os.makedirs(os.path.dirname(out), exist_ok=True)
with open(out, "w", encoding="utf-8") as f:
    json.dump({"date": datetime.now().isoformat(), "results": ALL}, f, indent=2, ensure_ascii=False, default=str)
print(f"  → {out}")
print(f"\n{'='*70}\n  AUDIT v3 COMPLET\n{'='*70}")
