"""
Phase C.3E – Lot 1 – Exécution C2
Ajouter colonne export_settings
"""

import requests

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/execute_ddl"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

def execute_ddl(ddl):
    resp = requests.post(admin_url, headers=headers, json={"ddl_query": ddl}, timeout=30)
    return resp.json()

print("=== CORRECTION C2 : EXPORT_SETTINGS ===\n")

ddl = "ALTER TABLE app.whiteboard_renders ADD COLUMN IF NOT EXISTS export_settings JSONB"
result = execute_ddl(ddl)
print(f"Résultat : {result}")
print()

print("=== CORRECTION C2 TERMINÉE ===\n")
