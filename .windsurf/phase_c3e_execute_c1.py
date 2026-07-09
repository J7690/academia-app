"""
Phase C.3E – Lot 1 – Exécution C1
Corriger CHECK status
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

print("=== CORRECTION C1 : CHECK STATUS ===\n")

# Étape 1 : Supprimer l'ancienne contrainte
print("Étape 1 : Supprimer l'ancienne contrainte")
ddl1 = "ALTER TABLE app.whiteboard_renders DROP CONSTRAINT IF EXISTS whiteboard_renders_status_check"
result1 = execute_ddl(ddl1)
print(f"  Résultat : {result1}")
print()

# Étape 2 : Créer la nouvelle contrainte
print("Étape 2 : Créer la nouvelle contrainte")
ddl2 = """
ALTER TABLE app.whiteboard_renders 
ADD CONSTRAINT whiteboard_renders_status_check 
CHECK (status IN ('queued', 'processing', 'done', 'failed'))
"""
result2 = execute_ddl(ddl2)
print(f"  Résultat : {result2}")
print()

print("=== CORRECTION C1 TERMINÉE ===\n")
