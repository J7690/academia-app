"""
Script RPC administrateur pour vérifier la structure de la table students
"""

import requests
import json

# Configuration
url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

def execute_sql(sql):
    resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
    return resp.json()

print("=== STRUCTURE TABLE students ===\n")

sql = """
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_schema = 'app' AND table_name = 'students'
ORDER BY ordinal_position
"""
result = execute_sql(sql)
print("Colonnes:")
if result.get("ok") and result.get("rows"):
    for row in result["rows"]:
        print(f"  {row['column_name']}: {row['data_type']} (nullable: {row['is_nullable']})")
else:
    print("❌ Colonnes non trouvées")

print("\n=== ÉTUDIANTS EXISTANTS ===\n")

sql = "SELECT id FROM app.students LIMIT 1"
result = execute_sql(sql)
print(f"SELECT: {result}")
if result.get("ok") and result.get("rows"):
    print(f"✅ Étudiant existant: {result['rows'][0]['id']}")
    student_id = result['rows'][0]['id']
else:
    print("❌ Aucun étudiant existant")
    student_id = None
