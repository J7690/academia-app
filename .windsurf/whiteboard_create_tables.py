"""
Script RPC administrateur pour créer les tables whiteboard
Phase B.2 – Tables Execution
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

# Lire le fichier SQL
with open("supabase/migrations/20260623000001_create_whiteboard_tables.sql", "r", encoding="utf-8") as f:
    sql = f.read()

# Exécuter la migration
payload = {"p_sql": sql}
resp = requests.post(url, headers=headers, json=payload, timeout=60)

# Afficher le résultat
print("Status Code:", resp.status_code)
print("Response:", resp.text)

if resp.status_code == 200:
    result = resp.json()
    print("Migration réussie!")
    print("Résultat:", result)
else:
    print("Erreur lors de la migration!")
    print("Erreur:", resp.text)
