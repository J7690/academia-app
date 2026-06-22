import requests

url_base = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Accept": "application/json",
    "Accept-Profile": "app",
    "Content-Profile": "app"
}

print("=== VÉRIFICATION DÉTAILLÉE RENDITIONS ===\n")

# 1. Renditions pour un asset spécifique (10f674b9-d337-47b5-ae77-6cbbabc5b97b)
asset_id = "10f674b9-d337-47b5-ae77-6cbbabc5b97b"
url = f"{url_base}/video_renditions"
params = {
    "video_asset_id": f"eq.{asset_id}",
    "select": "*",
    "order": "rendition_key"
}
resp = requests.get(url, headers=headers, params=params, timeout=30)
print(f'Renditions pour asset {asset_id}:')
print(f'Status: {resp.status_code}')
if resp.status_code == 200:
    data = resp.json()
    print(f'Nombre de renditions: {len(data)}')
    for row in data:
        print(f"  Key: {row['rendition_key']}, Status: {row['status']}, Width: {row.get('width')}, Height: {row.get('height')}")
        print(f"    Storage: {row['storage_bucket']}/{row['storage_path']}")
        print(f"    URL: {row['public_url_hint']}")
print()

# 2. Statistiques globales des renditions
url2 = f"{url_base}/video_renditions"
params2 = {
    "select": "rendition_key,status",
    "order": "rendition_key,status"
}
resp2 = requests.get(url2, headers=headers, params=params2, timeout=30)
print('Statistiques globales renditions:')
if resp2.status_code == 200:
    data = resp2.json()
    stats = {}
    for row in data:
        key = f"{row['rendition_key']}:{row['status']}"
        stats[key] = stats.get(key, 0) + 1
    for key, count in sorted(stats.items()):
        print(f"  {key}: {count}")
print()

# 3. Renditions récentes
url3 = f"{url_base}/video_renditions"
params3 = {
    "select": "*",
    "order": "created_at.desc",
    "limit": "5"
}
resp3 = requests.get(url3, headers=headers, params=params3, timeout=30)
print('Renditions récentes (5 dernières):')
if resp3.status_code == 200:
    data = resp3.json()
    for row in data:
        print(f"  Asset: {row['video_asset_id'][:8]}..., Key: {row['rendition_key']}, Status: {row['status']}, Created: {row['created_at']}")
print()
