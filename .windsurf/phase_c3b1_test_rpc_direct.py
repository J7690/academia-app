"""
Phase C.3B.1 – Test RPC Direct
Teste l'appel direct aux RPCs whiteboard
"""

import requests

headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
}

print("=== TEST RPC DIRECT ===\n")

# Tester avec POST et GET
test_cases = [
    ("GET", "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/whiteboard_fetch_queued_jobs?p_limit=1", None),
    ("POST", "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/whiteboard_fetch_queued_jobs", {"p_limit": 1}),
]

for method, url, data in test_cases:
    if method == "GET":
        resp = requests.get(url, headers=headers, timeout=10)
    else:
        resp = requests.post(url, headers=headers, json=data, timeout=10)
    print(f"  {method} {url}")
    print(f"    Status : {resp.status_code}")
    if resp.status_code == 200:
        print(f"    ✅ SUCCÈS")
        print(f"    Response : {resp.json()}")
    else:
        print(f"    ❌ ÉCHEC")
        print(f"    Response : {resp.text[:500]}")
    print()

# Vérifier s'il y a des projects avec des storyboards
print("=== VÉRIFICATION PROJECTS ===\n")
admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
sql = """
SELECT id, subject, status
FROM app.whiteboard_projects
LIMIT 5;
"""
resp = requests.post(admin_url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"Status : {resp.status_code}")
print(f"Projects : {resp.json()}")
