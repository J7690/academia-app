"""
Nettoyage complet de toutes les vidéos — Supabase DB + Storage
Étape 1: Audit (comptage avant suppression)
Étape 2: Suppression DB (tables dépendantes d'abord, puis parents)
Étape 3: Suppression Storage (fichiers dans les buckets vidéo)
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

def exec_sql(sql):
    """Execute SQL via admin_execute_sql RPC"""
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/admin_execute_sql",
        headers=HEADERS,
        json={"sql_query": sql},
    )
    if r.status_code == 200:
        return r.json()
    else:
        print(f"  SQL ERROR ({r.status_code}): {r.text[:200]}")
        return None

def list_storage_files(bucket):
    """List files in a storage bucket"""
    r = requests.post(
        f"{SUPABASE_URL}/storage/v1/object/list/{bucket}",
        headers=HEADERS,
        json={"prefix": "", "limit": 1000, "offset": 0},
    )
    if r.status_code == 200:
        return r.json()
    else:
        print(f"  Storage list ERROR ({r.status_code}) for {bucket}: {r.text[:200]}")
        return []

def delete_storage_files(bucket, paths):
    """Delete files from a storage bucket"""
    if not paths:
        return
    r = requests.delete(
        f"{SUPABASE_URL}/storage/v1/object/{bucket}",
        headers=HEADERS,
        json={"prefixes": paths},
    )
    if r.status_code in (200, 204):
        print(f"  ✅ Deleted {len(paths)} files from bucket '{bucket}'")
    else:
        print(f"  ❌ Storage delete ERROR ({r.status_code}) for {bucket}: {r.text[:200]}")

def list_storage_recursive(bucket, prefix=""):
    """Recursively list all files in a bucket"""
    all_files = []
    r = requests.post(
        f"{SUPABASE_URL}/storage/v1/object/list/{bucket}",
        headers=HEADERS,
        json={"prefix": prefix, "limit": 1000, "offset": 0},
    )
    if r.status_code != 200:
        return all_files
    items = r.json()
    for item in items:
        name = item.get("name", "")
        full_path = f"{prefix}/{name}" if prefix else name
        if item.get("id") is None:
            # It's a folder, recurse
            all_files.extend(list_storage_recursive(bucket, full_path))
        else:
            all_files.append(full_path)
    return all_files


# ═══════════════════════════════════════════════════════════════
# STEP 1: AUDIT — Count everything before deletion
# ═══════════════════════════════════════════════════════════════
print("=" * 60)
print("ÉTAPE 1: AUDIT — Comptage avant suppression")
print("=" * 60)

tables_to_check = [
    ("app.challenge_video_overlays", "Overlays vidéo challenges"),
    ("app.challenge_video_assets", "Assets vidéo challenges"),
    ("app.free_video_overlays", "Overlays vidéo libres"),
    ("app.free_videos", "Vidéos libres"),
    ("app.video_renditions", "Renditions vidéo"),
    ("app.video_sources", "Sources vidéo"),
    ("app.video_assets", "Assets vidéo"),
    ("app.challenge_participations", "Participations challenges"),
]

counts = {}
for table, label in tables_to_check:
    result = exec_sql(f"SELECT count(*) as cnt FROM {table}")
    cnt = 0
    if result and isinstance(result, list) and len(result) > 0:
        cnt = result[0].get("cnt", 0)
    elif result and isinstance(result, dict):
        cnt = result.get("cnt", 0)
    counts[table] = cnt
    print(f"  {label} ({table}): {cnt} enregistrements")

# Check storage buckets
print("\n--- Storage buckets ---")
buckets_to_check = ["video-sources", "video-renders", "thumbnails", "videos", "challenge-videos"]
storage_files = {}
for bucket in buckets_to_check:
    files = list_storage_recursive(bucket)
    storage_files[bucket] = files
    print(f"  Bucket '{bucket}': {len(files)} fichiers")

total_db = sum(counts.values())
total_storage = sum(len(f) for f in storage_files.values())
print(f"\n  TOTAL DB: {total_db} enregistrements")
print(f"  TOTAL Storage: {total_storage} fichiers")

# ═══════════════════════════════════════════════════════════════
# STEP 2: DELETE DB — Order matters (children first, parents last)
# ═══════════════════════════════════════════════════════════════
print("\n" + "=" * 60)
print("ÉTAPE 2: SUPPRESSION DB — Tables dépendantes d'abord")
print("=" * 60)

delete_order = [
    "app.challenge_video_overlays",
    "app.challenge_video_assets",
    "app.free_video_overlays",
    "app.free_videos",
    "app.video_renditions",
    "app.video_sources",
    "app.video_assets",
    "app.challenge_participations",
]

for table in delete_order:
    if counts.get(table, 0) == 0:
        print(f"  ⏭️  {table}: déjà vide, skip")
        continue
    result = exec_sql(f"DELETE FROM {table}")
    # Verify
    verify = exec_sql(f"SELECT count(*) as cnt FROM {table}")
    remaining = 0
    if verify and isinstance(verify, list) and len(verify) > 0:
        remaining = verify[0].get("cnt", 0)
    elif verify and isinstance(verify, dict):
        remaining = verify.get("cnt", 0)
    if remaining == 0:
        print(f"  ✅ {table}: {counts[table]} supprimés → 0 restants")
    else:
        print(f"  ⚠️  {table}: {remaining} restants (certains protégés par FK?)")

# ═══════════════════════════════════════════════════════════════
# STEP 3: DELETE STORAGE — Remove files from all video buckets
# ═══════════════════════════════════════════════════════════════
print("\n" + "=" * 60)
print("ÉTAPE 3: SUPPRESSION STORAGE — Fichiers dans les buckets")
print("=" * 60)

for bucket, files in storage_files.items():
    if not files:
        print(f"  ⏭️  Bucket '{bucket}': vide, skip")
        continue
    # Delete in batches of 100
    for i in range(0, len(files), 100):
        batch = files[i:i+100]
        delete_storage_files(bucket, batch)

# ═══════════════════════════════════════════════════════════════
# STEP 4: VERIFY — Final count
# ═══════════════════════════════════════════════════════════════
print("\n" + "=" * 60)
print("ÉTAPE 4: VÉRIFICATION FINALE")
print("=" * 60)

for table, label in tables_to_check:
    result = exec_sql(f"SELECT count(*) as cnt FROM {table}")
    cnt = 0
    if result and isinstance(result, list) and len(result) > 0:
        cnt = result[0].get("cnt", 0)
    elif result and isinstance(result, dict):
        cnt = result.get("cnt", 0)
    status = "✅" if cnt == 0 else "⚠️"
    print(f"  {status} {label}: {cnt}")

for bucket in buckets_to_check:
    files = list_storage_recursive(bucket)
    status = "✅" if len(files) == 0 else "⚠️"
    print(f"  {status} Bucket '{bucket}': {len(files)} fichiers")

print("\n🏁 Nettoyage terminé.")
