"""
Phase C.3B.1 – Check Table Columns
Vérifie les colonnes réelles de la table whiteboard_renders
"""

import requests

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== CHECK TABLE COLUMNS ===\n")

sql = """
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'whiteboard_renders'
ORDER BY ordinal_position;
"""

resp = requests.post(admin_url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"Status : {resp.status_code}")
print(f"Type de réponse : {type(resp.json())}")
print(f"Réponse brute : {resp.json()}")
print(f"Colonnes de app.whiteboard_renders :")
result = resp.json()
if isinstance(result, list):
    for row in result:
        if isinstance(row, dict):
            print(f"  {row.get('column_name')} : {row.get('data_type')}")
        else:
            print(f"  {row}")
else:
    print(f"  Format non attendu : {result}")
