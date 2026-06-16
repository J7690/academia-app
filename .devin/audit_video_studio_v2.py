#!/usr/bin/env python3
"""Audit Supabase v2 — Système vidéo + Studio (utilise pg_catalog au lieu de information_schema)"""
import json, requests, os
from datetime import datetime

CONFIG = json.load(open(r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\supabase_permanent_config.json"))
HEADERS = {
    "apikey": CONFIG["service_role_key"],
    "Authorization": f"Bearer {CONFIG['service_role_key']}",
    "Content-Type": "application/json",
}

def sql(query):
    r = requests.post(f"{CONFIG['url']}/rest/v1/rpc/admin_execute_sql", headers=HEADERS, json={"p_sql": query})
    if r.status_code != 200:
        return {"ok": False, "error": f"HTTP {r.status_code}"}
    d = r.json()
    return json.loads(d) if isinstance(d, str) else d

def rows(query):
    r = sql(query)
    return r.get("rows", []) if r.get("ok") else []

def pr(title):
    print(f"\n{'='*70}\n  {title}\n{'='*70}")

ALL = {}

# =========================================================================
# 1. TOUTES les tables du schema app (via pg_catalog)
# =========================================================================
pr("1. TABLES schema app liées vidéo/studio")

video_tables = rows("""
SELECT c.relname as table_name,
       (SELECT count(*) FROM pg_attribute a WHERE a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped) as col_count,
       pg_total_relation_size(c.oid) as size_bytes
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'app' AND c.relkind = 'r'
AND (c.relname LIKE '%video%' OR c.relname LIKE '%challenge%' OR c.relname LIKE '%overlay%'
     OR c.relname LIKE '%rendition%' OR c.relname LIKE '%audio%' OR c.relname LIKE '%studio%'
     OR c.relname LIKE '%draft%' OR c.relname LIKE '%render%' OR c.relname LIKE '%segment%'
     OR c.relname LIKE '%sticker%' OR c.relname LIKE '%transcode%' OR c.relname LIKE '%free_video%')
ORDER BY c.relname
""")
ALL["video_tables"] = video_tables
for t in video_tables:
    sz = t['size_bytes']
    sz_str = f"{sz/1024:.0f} KB" if sz < 1048576 else f"{sz/1048576:.1f} MB"
    print(f"  {t['table_name']:45s} {t['col_count']:3d} cols  {sz_str}")

# =========================================================================
# 2. Colonnes détaillées de chaque table vidéo
# =========================================================================
pr("2. COLONNES DÉTAILLÉES")

key_tables = ['video_assets', 'video_sources', 'video_renditions',
              'challenge_participations', 'free_videos',
              'free_video_overlays', 'challenge_video_overlays']
ALL["columns"] = {}

for tbl in key_tables:
    cols = rows(f"""
    SELECT a.attname as col, pg_catalog.format_type(a.atttypid, a.atttypmod) as dtype,
           NOT a.attnotnull as nullable,
           pg_get_expr(d.adbin, d.adrelid) as dflt
    FROM pg_attribute a
    JOIN pg_class c ON c.oid = a.attrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
    WHERE n.nspname = 'app' AND c.relname = '{tbl}' AND a.attnum > 0 AND NOT a.attisdropped
    ORDER BY a.attnum
    """)
    ALL["columns"][tbl] = cols
    print(f"\n  {tbl} ({len(cols)} cols):")
    for c in cols:
        null = "NULL" if c['nullable'] else "NOT NULL"
        dflt = f" = {c['dflt'][:40]}" if c.get('dflt') else ""
        print(f"    {c['col']:35s} {c['dtype']:25s} {null}{dflt}")

# =========================================================================
# 3. RPCs (fonctions) liées vidéo/studio
# =========================================================================
pr("3. RPCs (fonctions)")

rpcs = rows("""
SELECT p.proname as name, n.nspname as schema,
       pg_get_function_arguments(p.oid) as args,
       pg_get_function_result(p.oid) as returns
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('public', 'app')
AND (p.proname LIKE '%video%' OR p.proname LIKE '%challenge%' OR p.proname LIKE '%overlay%'
     OR p.proname LIKE '%rendition%' OR p.proname LIKE '%transcode%' OR p.proname LIKE '%upload%'
     OR p.proname LIKE '%playback%' OR p.proname LIKE '%segment%' OR p.proname LIKE '%audio%'
     OR p.proname LIKE '%studio%' OR p.proname LIKE '%render%' OR p.proname LIKE '%draft%'
     OR p.proname LIKE '%sticker%' OR p.proname LIKE '%free_video%' OR p.proname LIKE 'app_%video%'
     OR p.proname LIKE 'app_student%video%' OR p.proname LIKE 'app_student%challenge%')
ORDER BY n.nspname, p.proname
""")
ALL["rpcs"] = rpcs
print(f"  {len(rpcs)} fonctions trouvées:")
for r in rpcs:
    args_short = r['args'][:60] if r['args'] else ''
    print(f"  [{r['schema']}] {r['name']}({args_short}) → {r['returns']}")

# =========================================================================
# 4. Comptages + échantillons
# =========================================================================
pr("4. COMPTAGES")

counts = {}
for tbl in ['video_assets', 'video_sources', 'video_renditions',
            'challenge_participations', 'free_videos',
            'free_video_overlays', 'challenge_video_overlays']:
    r = rows(f"SELECT count(*) as cnt FROM app.{tbl}")
    cnt = r[0]['cnt'] if r else '?'
    counts[tbl] = cnt
    print(f"  {tbl:45s} → {cnt}")
ALL["counts"] = counts

# =========================================================================
# 5. Orphelins & doublons
# =========================================================================
pr("5. ORPHELINS & DOUBLONS")

# 5a. video_assets sans rendition
orphan_no_rend = rows("""
SELECT va.id, va.origin, va.status, va.created_at::text
FROM app.video_assets va
LEFT JOIN app.video_renditions vr ON vr.video_asset_id = va.id
WHERE vr.id IS NULL
LIMIT 20
""")
ALL["orphan_no_rendition"] = orphan_no_rend
print(f"\n  5a. video_assets SANS rendition: {len(orphan_no_rend)}")
for o in orphan_no_rend[:5]:
    print(f"      {o['id'][:12]}... origin={o.get('origin')} status={o.get('status')}")

# 5b. video_assets sans source
orphan_no_src = rows("""
SELECT va.id, va.origin, va.status
FROM app.video_assets va
LEFT JOIN app.video_sources vs ON vs.video_asset_id = va.id
WHERE vs.id IS NULL
LIMIT 20
""")
ALL["orphan_no_source"] = orphan_no_src
print(f"  5b. video_assets SANS source: {len(orphan_no_src)}")

# 5c. Renditions sans URL
rend_no_url = rows("""
SELECT id, video_asset_id, rendition_key, status
FROM app.video_renditions
WHERE (public_url_hint IS NULL OR public_url_hint = '')
LIMIT 20
""")
ALL["renditions_no_url"] = rend_no_url
print(f"  5c. renditions SANS public_url_hint: {len(rend_no_url)}")

# 5d. Doublons renditions
dup_rend = rows("""
SELECT video_asset_id, rendition_key, count(*) as cnt
FROM app.video_renditions
GROUP BY video_asset_id, rendition_key
HAVING count(*) > 1
""")
ALL["dup_renditions"] = dup_rend
print(f"  5d. Doublons renditions (asset+key): {len(dup_rend)}")
for d in dup_rend[:5]:
    print(f"      asset={d['video_asset_id'][:12]}... key={d['rendition_key']} x{d['cnt']}")

# 5e. free_videos sans video_asset
orphan_fv = rows("SELECT id, user_id FROM app.free_videos WHERE video_asset_id IS NULL")
ALL["orphan_fv_no_asset"] = orphan_fv
print(f"  5e. free_videos SANS video_asset_id: {len(orphan_fv)}")

# 5f. challenge_participations soumises sans video_asset
orphan_cp = rows("""
SELECT id, user_id, challenge_id FROM app.challenge_participations
WHERE video_asset_id IS NULL AND submitted_at IS NOT NULL
""")
ALL["orphan_cp_submitted_no_asset"] = orphan_cp
print(f"  5f. challenge_participations soumises SANS video_asset: {len(orphan_cp)}")

# 5g. video_assets avec status anormal
bad_status = rows("""
SELECT status, count(*) as cnt
FROM app.video_assets
GROUP BY status ORDER BY cnt DESC
""")
ALL["asset_statuses"] = bad_status
print(f"\n  5g. Distribution statuts video_assets:")
for s in bad_status:
    print(f"      {s['status']:25s} → {s['cnt']}")

# =========================================================================
# 6. Storage buckets
# =========================================================================
pr("6. STORAGE BUCKETS (tous)")

buckets = rows("SELECT id, name, public FROM storage.buckets ORDER BY name")
ALL["buckets"] = buckets
for b in buckets:
    pub = "PUBLIC" if b['public'] else "PRIVATE"
    print(f"  {b['name']:35s} {pub}")

# =========================================================================
# 7. Indexes
# =========================================================================
pr("7. INDEXES tables vidéo")

idxs = rows("""
SELECT indexrelid::regclass as idx_name, indrelid::regclass as table_name,
       pg_get_indexdef(indexrelid) as def
FROM pg_index
JOIN pg_class c ON c.oid = indrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'app'
AND (c.relname LIKE '%video%' OR c.relname LIKE '%rendition%' OR c.relname LIKE '%overlay%')
ORDER BY c.relname
""")
ALL["indexes"] = idxs
print(f"  {len(idxs)} indexes:")
for i in idxs:
    print(f"    {i['idx_name']}")

# =========================================================================
# 8. RLS policies
# =========================================================================
pr("8. RLS POLICIES tables vidéo")

rls = rows("""
SELECT pol.polname as policy, c.relname as table_name,
       CASE pol.polcmd WHEN 'r' THEN 'SELECT' WHEN 'a' THEN 'INSERT'
            WHEN 'w' THEN 'UPDATE' WHEN 'd' THEN 'DELETE' ELSE '*' END as cmd,
       pol.polpermissive as permissive
FROM pg_policy pol
JOIN pg_class c ON c.oid = pol.polrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'app'
AND (c.relname LIKE '%video%' OR c.relname LIKE '%rendition%' OR c.relname LIKE '%overlay%'
     OR c.relname LIKE '%free_video%')
ORDER BY c.relname, pol.polname
""")
ALL["rls"] = rls
print(f"  {len(rls)} policies:")
for p in rls:
    print(f"    [{p['table_name']}] {p['policy']} ({p['cmd']})")

# =========================================================================
# 9. Triggers
# =========================================================================
pr("9. TRIGGERS tables vidéo/challenge")

trigs = rows("""
SELECT tgname as trigger_name, c.relname as table_name,
       CASE WHEN tgtype & 2 = 2 THEN 'BEFORE' ELSE 'AFTER' END as timing,
       CASE WHEN tgtype & 4 = 4 THEN 'INSERT'
            WHEN tgtype & 8 = 8 THEN 'DELETE'
            WHEN tgtype & 16 = 16 THEN 'UPDATE'
            ELSE 'MIXED' END as event
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'app' AND NOT t.tgisinternal
AND (c.relname LIKE '%video%' OR c.relname LIKE '%challenge%' OR c.relname LIKE '%overlay%')
ORDER BY c.relname, tgname
""")
ALL["triggers"] = trigs
print(f"  {len(trigs)} triggers:")
for t in trigs:
    print(f"    [{t['table_name']}] {t['trigger_name']} ({t['timing']} {t['event']})")

# =========================================================================
# 10. FK constraints
# =========================================================================
pr("10. FOREIGN KEYS tables vidéo")

fks = rows("""
SELECT conname, conrelid::regclass as from_table,
       confrelid::regclass as to_table,
       pg_get_constraintdef(oid) as def
FROM pg_constraint
WHERE contype = 'f'
AND conrelid IN (
    SELECT c.oid FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'app'
    AND (c.relname LIKE '%video%' OR c.relname LIKE '%rendition%' OR c.relname LIKE '%overlay%'
         OR c.relname LIKE '%free_video%')
)
ORDER BY conrelid::regclass::text, conname
""")
ALL["foreign_keys"] = fks
print(f"  {len(fks)} FK:")
for f in fks:
    print(f"    {f['from_table']} → {f['to_table']}: {f['conname']}")

# =========================================================================
# 11. Échantillons de données
# =========================================================================
pr("11. ÉCHANTILLONS")

# Rendition keys utilisées
rend_keys = rows("""
SELECT rendition_key, count(*) as cnt
FROM app.video_renditions
GROUP BY rendition_key ORDER BY cnt DESC
""")
ALL["rendition_keys"] = rend_keys
print("  Rendition keys:")
for k in rend_keys:
    print(f"    {k['rendition_key']:30s} → {k['cnt']}")

# Origines video_assets
origins = rows("""
SELECT origin, count(*) as cnt
FROM app.video_assets
GROUP BY origin ORDER BY cnt DESC
""")
ALL["asset_origins"] = origins
print("\n  video_assets origins:")
for o in origins:
    print(f"    {o['origin']:30s} → {o['cnt']}")

# Free video overlays sample
ov_sample = rows("SELECT id, free_video_id, overlays::text FROM app.free_video_overlays LIMIT 3")
ALL["overlay_sample"] = ov_sample
print(f"\n  free_video_overlays sample: {len(ov_sample)} rows")
for o in ov_sample:
    ov_text = str(o.get('overlays', ''))[:100]
    print(f"    fv={o.get('free_video_id','?')[:12]}... overlays={ov_text}")

# =========================================================================
# SAVE
# =========================================================================
pr("SAUVEGARDE")
out = r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\logs\audit_video_studio_supabase_v2.json"
os.makedirs(os.path.dirname(out), exist_ok=True)
with open(out, "w", encoding="utf-8") as f:
    json.dump({"date": datetime.now().isoformat(), "results": ALL}, f, indent=2, ensure_ascii=False, default=str)
print(f"  → {out}")
print(f"\n{'='*70}\n  AUDIT COMPLET\n{'='*70}")
