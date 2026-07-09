"""
Script pour Phase B.4B – Storage Tests
"""

import requests
import base64

# Configuration
storage_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
}

print("=== TESTS STORAGE whiteboard-narrations ===\n")

# Test upload whiteboard-narrations
print("TEST UPLOAD whiteboard-narrations")
project_id = "c63e9c1e-92d9-43f3-ab41-066ec3dc788b"
test_content = base64.b64encode(b"test audio content").decode()
upload_url = f"{storage_url}/object/whiteboard-narrations/{project_id}/test.mp3"
headers_upload = headers.copy()
headers_upload["Content-Type"] = "audio/mpeg"
resp = requests.post(upload_url, headers=headers_upload, data=test_content, timeout=30)
print(f"Upload: {resp.status_code} - {resp.text}")

# Test lecture whiteboard-narrations
print("\nTEST LECTURE whiteboard-narrations")
read_url = f"{storage_url}/object/whiteboard-narrations/{project_id}/test.mp3"
resp = requests.get(read_url, headers=headers, timeout=30)
print(f"Lecture: {resp.status_code}")
if resp.status_code == 200:
    print("✅ Lecture réussie")
else:
    print(f"❌ Erreur lecture: {resp.text}")

# Test suppression whiteboard-narrations
print("\nTEST SUPPRESSION whiteboard-narrations")
delete_url = f"{storage_url}/object/whiteboard-narrations/{project_id}/test.mp3"
resp = requests.delete(delete_url, headers=headers, timeout=30)
print(f"Suppression: {resp.status_code} - {resp.text}")

print("\n=== TESTS STORAGE whiteboard-renders ===\n")

# Test upload whiteboard-renders
print("TEST UPLOAD whiteboard-renders")
test_content = base64.b64encode(b"test video content").decode()
upload_url = f"{storage_url}/object/whiteboard-renders/{project_id}/test.mp4"
headers_upload = headers.copy()
headers_upload["Content-Type"] = "video/mp4"
resp = requests.post(upload_url, headers=headers_upload, data=test_content, timeout=30)
print(f"Upload: {resp.status_code} - {resp.text}")

# Test lecture whiteboard-renders
print("\nTEST LECTURE whiteboard-renders")
read_url = f"{storage_url}/object/whiteboard-renders/{project_id}/test.mp4"
resp = requests.get(read_url, headers=headers, timeout=30)
print(f"Lecture: {resp.status_code}")
if resp.status_code == 200:
    print("✅ Lecture réussie")
else:
    print(f"❌ Erreur lecture: {resp.text}")

# Test suppression whiteboard-renders
print("\nTEST SUPPRESSION whiteboard-renders")
delete_url = f"{storage_url}/object/whiteboard-renders/{project_id}/test.mp4"
resp = requests.delete(delete_url, headers=headers, timeout=30)
print(f"Suppression: {resp.status_code} - {resp.text}")

print("\n=== TESTS TERMINÉS ===\n")
