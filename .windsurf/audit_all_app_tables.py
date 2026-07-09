"""
Lister toutes les tables du schéma app
"""

import requests
import json
import time

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== TOUTES LES TABLES DU SCHÉMA app ===\n")

sql = """
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'app'
ORDER BY table_name;
"""

try:
    resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
    print(f"Status: {resp.status_code}")
    if resp.status_code == 200:
        data = resp.json()
        if data.get("ok") and data.get("rows"):
            print(f"Total tables: {len(data['rows'])}\n")
            for i, row in enumerate(data["rows"], 1):
                print(f"{i:3}. {row['table_name']}")
        else:
            print("Aucune table trouvée")
    else:
        print(f"Erreur: {resp.text}")
except Exception as e:
    print(f"Exception: {e}")

print("\n=== RECHERCHE TERMINÉE ===")
