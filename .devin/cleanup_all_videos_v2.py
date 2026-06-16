"""
Nettoyage complet vidéos v2 — Deep recursive scan + SQL via migration
"""
import requests
import json

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
}

def list_recursive(bucket, prefix="", depth=0):
    """Recursively list all items in a storage bucket"""
    all_files = []
    r = requests.post(
        f"{SUPABASE_URL}/storage/v1/object/list/{bucket}",
        headers=HEADERS,
        json={"prefix": prefix, "limit": 1000, "offset": 0},
    )
    if r.status_code != 200:
        return all_files
    items = r.json()
    if not isinstance(items, list):
        return all_files
    for item in items:
        name = item.get("name", "")
        full_path = f"{prefix}/{name}" if prefix else name
        item_id = item.get("id")
        meta = item.get("metadata") or {}
        size = meta.get("size", "?")
        indent = "  " * (depth + 1)
        if item_id is None:
            # Folder
            print(f"{indent}📁 {name}/")
            sub = list_recursive(bucket, full_path, depth + 1)
            all_files.extend(sub)
        else:
            # File
            print(f"{indent}📄 {name} ({size} bytes)")
            all_files.append(full_path)
    return all_files

def delete_files(bucket, paths):
    """Delete files from storage"""
    if not paths:
        return 0
    r = requests.delete(
        f"{SUPABASE_URL}/storage/v1/object/{bucket}",
        headers=HEADERS,
        json={"prefixes": paths},
    )
    if r.status_code in (200, 204):
        print(f"  ✅ Supprimé {len(paths)} fichiers de '{bucket}'")
        return len(paths)
    else:
        print(f"  ❌ Erreur suppression ({r.status_code}): {r.text[:200]}")
        return 0

# ═══════════════════════════════════════════════════════════════
# STEP 1: DEEP SCAN des buckets vidéo
# ═══════════════════════════════════════════════════════════════
print("=" * 60)
print("ÉTAPE 1: Scan récursif profond des buckets vidéo")
print("=" * 60)

video_buckets = ["video-assets", "challenge-media", "community-media", "hero_videos"]
all_to_delete = {}

for bucket in video_buckets:
    print(f"\n📦 Bucket: {bucket}")
    files = list_recursive(bucket)
    all_to_delete[bucket] = files
    print(f"  → Total: {len(files)} fichiers")

# ═══════════════════════════════════════════════════════════════
# STEP 2: SUPPRESSION des fichiers Storage
# ═══════════════════════════════════════════════════════════════
print("\n" + "=" * 60)
print("ÉTAPE 2: Suppression des fichiers Storage")
print("=" * 60)

total_deleted = 0
for bucket, files in all_to_delete.items():
    if not files:
        print(f"  ⏭️  '{bucket}': vide")
        continue
    # Delete in batches of 50
    for i in range(0, len(files), 50):
        batch = files[i:i+50]
        total_deleted += delete_files(bucket, batch)

print(f"\n  TOTAL fichiers supprimés: {total_deleted}")

# ═══════════════════════════════════════════════════════════════
# STEP 3: SUPPRESSION DB via execute_sql (essai schéma app)
# ═══════════════════════════════════════════════════════════════
print("\n" + "=" * 60)
print("ÉTAPE 3: Suppression DB via execute_sql")
print("=" * 60)

# Try the RPC in the app schema
def try_exec_sql(sql, schema="public"):
    """Try executing SQL via RPC in given schema"""
    h = dict(HEADERS)
    if schema != "public":
        h["Accept-Profile"] = schema
        h["Content-Profile"] = schema
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/execute_sql",
        headers=h,
        json={"sql_query": sql},
    )
    if r.status_code == 200:
        return r.json()
    # Try admin variant
    r2 = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/admin_execute_sql",
        headers=h,
        json={"sql_query": sql},
    )
    if r2.status_code == 200:
        return r2.json()
    return None

# Delete order: children → parents
delete_sql = [
    ("challenge_video_overlays", "DELETE FROM app.challenge_video_overlays"),
    ("free_video_overlays", "DELETE FROM app.free_video_overlays"),
    ("video_renditions", "DELETE FROM app.video_renditions"),
    ("video_sources", "DELETE FROM app.video_sources"),
    ("free_videos", "DELETE FROM app.free_videos"),
    ("challenge_participations", "DELETE FROM app.challenge_participations"),
    ("video_assets", "DELETE FROM app.video_assets"),
]

rpc_works = False
for label, sql in delete_sql:
    for schema in ["public", "app"]:
        result = try_exec_sql(sql, schema)
        if result is not None:
            rpc_works = True
            print(f"  ✅ {label}: supprimé (via {schema} schema)")
            break
    else:
        print(f"  ⚠️  {label}: RPC non accessible")

if not rpc_works:
    print("\n  ⚠️  Les RPCs SQL ne sont pas accessibles.")
    print("  → Utilisation de l'API PostgREST directe comme fallback...")
    
    # Try direct PostgREST with app schema
    for label, _ in delete_sql:
        h = dict(HEADERS)
        h["Prefer"] = "return=minimal"
        # Try with Accept-Profile: app
        h["Accept-Profile"] = "app"
        h["Content-Profile"] = "app"
        r = requests.delete(
            f"{SUPABASE_URL}/rest/v1/{label}?id=not.is.null",
            headers=h,
        )
        if r.status_code in (200, 204):
            print(f"  ✅ {label}: supprimé via PostgREST (app schema)")
        elif r.status_code == 404:
            # Not exposed
            print(f"  ⏭️  {label}: pas exposé via PostgREST")
        else:
            print(f"  ❌ {label}: HTTP {r.status_code} — {r.text[:100]}")

# ═══════════════════════════════════════════════════════════════
# STEP 4: VÉRIFICATION
# ═══════════════════════════════════════════════════════════════
print("\n" + "=" * 60)
print("ÉTAPE 4: Vérification finale Storage")
print("=" * 60)

for bucket in video_buckets:
    files = list_recursive(bucket)
    status = "✅" if len(files) == 0 else f"⚠️ {len(files)} restants"
    print(f"  {status} Bucket '{bucket}'")

print("\n🏁 Nettoyage v2 terminé.")
