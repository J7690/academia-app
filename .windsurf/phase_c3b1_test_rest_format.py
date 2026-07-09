"""
Phase C.3B.1 – Test REST Format
Teste différents formats d'URL pour accéder aux tables du schema app
"""

import requests

headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
}

print("=== TEST FORMAT REST ===\n")

# Tester avec une table connue du schema app (student_credits)
print("1. Test avec table student_credits (schema app) :")
test_urls = [
    "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/student_credits?limit=1",
    "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/app.student_credits?limit=1",
]

for url in test_urls:
    resp = requests.get(url, headers=headers, timeout=10)
    print(f"  {url}")
    print(f"    Status : {resp.status_code}")
    if resp.status_code == 200:
        print(f"    ✅ SUCCÈS")
    else:
        print(f"    ❌ ÉCHEC")
print()

# Tester avec whiteboard_renders
print("2. Test avec table whiteboard_renders :")
test_urls = [
    "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/whiteboard_renders?limit=1",
    "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/app.whiteboard_renders?limit=1",
]

for url in test_urls:
    resp = requests.get(url, headers=headers, timeout=10)
    print(f"  {url}")
    print(f"    Status : {resp.status_code}")
    if resp.status_code == 200:
        print(f"    ✅ SUCCÈS")
    else:
        print(f"    ❌ ÉCHEC")
print()
