import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/bucket"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

print("Création des buckets Smart Whiteboard...")

# Bucket whiteboard-renders
print("\n1. Création bucket whiteboard-renders...")
bucket_data = {
    "name": "whiteboard-renders",
    "public": True,
    "file_size_limit": 104857600,  # 100MB
    "allowed_mime_types": ["video/mp4"]
}

resp = requests.post(url, headers=headers, json=bucket_data, timeout=30)
print(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    print("✅ Bucket whiteboard-renders créé")
elif resp.status_code == 409:
    print("⚠️ Bucket whiteboard-renders existe déjà")
else:
    print(f"❌ Error: {resp.text}")

# Bucket whiteboard-narrations
print("\n2. Création bucket whiteboard-narrations...")
bucket_data = {
    "name": "whiteboard-narrations",
    "public": True,
    "file_size_limit": 52428800,  # 50MB
    "allowed_mime_types": ["audio/mpeg", "audio/wav", "audio/mp3"]
}

resp = requests.post(url, headers=headers, json=bucket_data, timeout=30)
print(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    print("✅ Bucket whiteboard-narrations créé")
elif resp.status_code == 409:
    print("⚠️ Bucket whiteboard-narrations existe déjà")
else:
    print(f"❌ Error: {resp.text}")

print("\nTerminé.")
