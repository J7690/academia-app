"""
Script pour Phase B.4B – Storage Creation via API REST Storage
"""

import requests
import json

# Configuration
storage_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/bucket"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

def create_bucket(bucket_id, bucket_name, public=False, file_size_limit=None, allowed_mime_types=None):
    """Crée un bucket via API REST Storage"""
    payload = {
        "id": bucket_id,
        "name": bucket_name,
        "public": public
    }
    if file_size_limit:
        payload["file_size_limit"] = file_size_limit
    if allowed_mime_types:
        payload["allowed_mime_types"] = allowed_mime_types
    
    resp = requests.post(storage_url, headers=headers, json=payload, timeout=30)
    return resp

print("=== CRÉATION DES BUCKETS STORAGE VIA API REST ===\n")

# Création bucket whiteboard-narrations
print("CRÉATION whiteboard-narrations")
payload = {
    "id": "whiteboard-narrations",
    "name": "whiteboard-narrations",
    "public": False,
    "file_size_limit": 104857600,  # 100 MB
    "allowed_mime_types": ["audio/mpeg", "audio/wav", "audio/mp3"]
}
resp = requests.post(storage_url, headers=headers, json=payload, timeout=30)
print(f"Status: {resp.status_code}")
print(f"Response: {resp.text}")
if resp.status_code in [200, 201]:
    print("✅ whiteboard-narrations créé")
else:
    print(f"❌ Erreur création whiteboard-narrations: {resp.text}")

print("\nCRÉATION whiteboard-renders")
payload = {
    "id": "whiteboard-renders",
    "name": "whiteboard-renders",
    "public": False,
    "file_size_limit": 524288000,  # 500 MB
    "allowed_mime_types": ["video/mp4"]
}
resp = requests.post(storage_url, headers=headers, json=payload, timeout=30)
print(f"Status: {resp.status_code}")
print(f"Response: {resp.text}")
if resp.status_code in [200, 201]:
    print("✅ whiteboard-renders créé")
else:
    print(f"❌ Erreur création whiteboard-renders: {resp.text}")

print("\n=== CRÉATION TERMINÉE ===\n")
