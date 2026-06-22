import requests

# Vérifier l'existence des fichiers dans Supabase Storage
# On ne peut pas lister le bucket directement via REST API sans auth admin
# Mais on peut vérifier l'existence de fichiers spécifiques

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/video-assets"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
}

video_asset_id = "10f674b9-d337-47b5-ae77-6cbbabc5b97b"

print("=== PHASE E: AUDIT STORAGE SUPABASE ===\n")

# Vérifier l'existence de chaque rendition
renditions = [
    f"renditions/{video_asset_id}/mp4_main.mp4",
    f"renditions/{video_asset_id}/mp4_480p.mp4",
    f"renditions/{video_asset_id}/mp4_360p.mp4",
    f"renditions/{video_asset_id}/mp4_240p.mp4",
    f"raw/{video_asset_id}/6c2dbe61-1002-455e-8639-6c8557d86fe2"
]

for rendition_path in renditions:
    check_url = f"{url}/{rendition_path}"
    try:
        resp = requests.head(check_url, headers=headers, timeout=10)
        print(f"{rendition_path}:")
        print(f"  Status: {resp.status_code}")
        if resp.status_code == 200:
            print(f"  Content-Length: {resp.headers.get('Content-Length', 'N/A')}")
            print(f"  Content-Type: {resp.headers.get('Content-Type', 'N/A')}")
            print(f"  Last-Modified: {resp.headers.get('Last-Modified', 'N/A')}")
        print()
    except Exception as e:
        print(f"{rendition_path}:")
        print(f"  Error: {e}")
        print()
