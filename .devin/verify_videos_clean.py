"""
Vérification directe via PostgREST API — pas besoin de RPC
"""
import requests

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "count=exact",
}

tables = [
    "video_assets",
    "video_sources",
    "video_renditions",
    "free_videos",
    "free_video_overlays",
    "challenge_participations",
    "challenge_video_overlays",
]

print("=" * 50)
print("VÉRIFICATION — Tables vidéo via PostgREST")
print("=" * 50)

for table in tables:
    r = requests.get(
        f"{SUPABASE_URL}/rest/v1/{table}?select=id&limit=0",
        headers=HEADERS,
    )
    # Count is in the Content-Range header
    count_header = r.headers.get("Content-Range", "")
    if r.status_code == 200:
        # Parse "0-0/N" or "*/N"
        if "/" in count_header:
            total = count_header.split("/")[-1]
        else:
            total = "?"
        status = "✅" if total in ("0", "*") else "⚠️"
        print(f"  {status} {table}: {total} enregistrements")
    elif r.status_code == 404:
        print(f"  ⏭️  {table}: table non exposée via PostgREST")
    else:
        print(f"  ❌ {table}: HTTP {r.status_code} — {r.text[:100]}")

# Storage buckets
print("\n" + "=" * 50)
print("VÉRIFICATION — Buckets Storage")
print("=" * 50)

# First list all buckets
r = requests.get(
    f"{SUPABASE_URL}/storage/v1/bucket",
    headers={"apikey": SERVICE_KEY, "Authorization": f"Bearer {SERVICE_KEY}"},
)
if r.status_code == 200:
    buckets = r.json()
    print(f"  Buckets trouvés: {len(buckets)}")
    for b in buckets:
        name = b.get("name", "?")
        # List files
        r2 = requests.post(
            f"{SUPABASE_URL}/storage/v1/object/list/{name}",
            headers={"apikey": SERVICE_KEY, "Authorization": f"Bearer {SERVICE_KEY}", "Content-Type": "application/json"},
            json={"prefix": "", "limit": 1000},
        )
        files = r2.json() if r2.status_code == 200 else []
        file_count = len(files) if isinstance(files, list) else 0
        status = "✅" if file_count == 0 else f"⚠️ ({file_count} fichiers)"
        print(f"  {status} Bucket '{name}': {file_count} fichiers")
        # If there are files, list them
        if file_count > 0:
            for f in files[:10]:
                meta = f.get('metadata') or {}
                print(f"      → {f.get('name', '?')} ({meta.get('size', '?')} bytes)")
            if file_count > 10:
                print(f"      ... et {file_count - 10} de plus")
else:
    print(f"  ❌ Impossible de lister les buckets: {r.status_code}")

print("\n🏁 Vérification terminée.")
