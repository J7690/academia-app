"""
Phase C.3B.1 – Check Table Name
Vérifie le nom exact de la table whiteboard_renders
"""

import requests

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== VÉRIFICATION NOM TABLE ===\n")

job_id = "4082281a-b8a2-4ed2-88fe-98df8c5d7301"

# Tester l'URL REST avec différents formats
print("Test URLs REST :")
test_urls = [
    f"https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/whiteboard_renders?id=eq.{job_id}",
    f"https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/app.whiteboard_renders?id=eq.{job_id}",
]

for url in test_urls:
    resp = requests.get(url, headers=headers, timeout=10)
    print(f"  {url}")
    print(f"    Status : {resp.status_code}")
    if resp.status_code == 200:
        print(f"    ✅ SUCCÈS")
        data = resp.json()
        if data and len(data) > 0:
            print(f"    Statut job : {data[0].get('status')}")
    else:
        print(f"    ❌ ÉCHEC")
    print()
