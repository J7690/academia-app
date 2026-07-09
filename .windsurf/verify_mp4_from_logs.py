import requests

print("=" * 80)
print("VÉRIFICATION MP4 À PARTIR DES LOGS WORKER")
print("=" * 80)

# MP4 URL from worker logs
mp4_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/whiteboard-renders/renders/fd9e3969-be64-45a9-8e95-00606ac51446/99f1c7ef242a4961afc6dc27edc4d77b.mp4"

headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
}

print(f"\nURL: {mp4_url}")

try:
    resp = requests.head(mp4_url, headers=headers, timeout=10)
    print(f"\nSTATUS: {resp.status_code}")
    print(f"Content-Type: {resp.headers.get('Content-Type', 'N/A')}")
    print(f"Content-Length: {resp.headers.get('Content-Length', 'N/A')} bytes")
    
    if resp.status_code == 200:
        print("\n✅ MP4 accessible via Storage")
        
        # Try to download a small portion to verify it's a valid MP4
        resp_get = requests.get(mp4_url, headers=headers, timeout=10, stream=True)
        first_bytes = resp_get.content[:12]
        
        # MP4 files start with bytes indicating it's an ftyp box
        if first_bytes[:4] == b'\x00\x00\x00\x18' or first_bytes[:4] == b'\x00\x00\x00\x20':
            print("✅ Valid MP4 header detected")
        else:
            print(f"⚠️ Unexpected header: {first_bytes.hex()}")
    else:
        print(f"\n❌ Erreur HTTP {resp.status_code}")
        print(f"Response: {resp.text[:200]}")
        
except Exception as e:
    print(f"\n❌ Erreur: {e}")

print("\n" + "=" * 80)
