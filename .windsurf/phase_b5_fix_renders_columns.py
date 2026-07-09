"""
Script pour Phase B.5 – Fix table whiteboard_renders (ajouter colonnes manquantes)
"""

import requests

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

print("=== FIX TABLE whiteboard_renders (colonnes manquantes) ===\n")

# Ajouter video_storage_path
sql = "ALTER TABLE app.whiteboard_renders ADD COLUMN IF NOT EXISTS video_storage_path TEXT"
result = execute_sql(sql)
print(f"Ajout video_storage_path: {result}")

# Ajouter video_storage_bucket
sql = "ALTER TABLE app.whiteboard_renders ADD COLUMN IF NOT EXISTS video_storage_bucket TEXT"
result = execute_sql(sql)
print(f"Ajout video_storage_bucket: {result}")

# Ajouter error_message
sql = "ALTER TABLE app.whiteboard_renders ADD COLUMN IF NOT EXISTS error_message TEXT"
result = execute_sql(sql)
print(f"Ajout error_message: {result}")

print("\n=== FIX TERMINÉ ===\n")
