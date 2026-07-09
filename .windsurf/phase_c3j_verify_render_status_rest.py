"""
Phase C.3J – Verify Render Status REST
Vérifie les données du render job via REST API
"""

import requests

service_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/app.whiteboard_renders"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== PHASE C.3J – VÉRIFICATION RENDER STATUS REST ===\n")

# Vérifier le statut du job traité
render_id = "5ab36d99-05df-40d6-8a7b-dfe6dc89de6c"
resp = requests.get(f"{service_url}?id=eq.{render_id}&select=id,status,video_url,duration_ms,error_message,created_at,completed_at", headers=headers, timeout=30)
print(f"Statut render job 5ab36d99-05df-40d6-8a7b-dfe6dc89de6c :")
print(f"   Status : {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    print(f"   Data : {data}")
print()

# Vérifier le statut du nouveau job
render_id_new = "fd9e3969-be64-45a9-8e95-00606ac51446"
resp = requests.get(f"{service_url}?id=eq.{render_id_new}&select=id,status,video_url,duration_ms,error_message,created_at,completed_at", headers=headers, timeout=30)
print(f"Statut nouveau render job fd9e3969-be64-45a9-8e95-00606ac51446 :")
print(f"   Status : {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    print(f"   Data : {data}")
print()

print("=== VÉRIFICATION TERMINÉ ===\n")
