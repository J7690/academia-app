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

print("=" * 80)
print("CORRECTION CONTRAINTE narration_mode")
print("=" * 80)

# Supprimer l'ancienne contrainte
print("\n1. Suppression de l'ancienne contrainte...")
ddl1 = "ALTER TABLE app.whiteboard_projects DROP CONSTRAINT IF EXISTS whiteboard_projects_narration_mode_check"
result1 = execute_ddl(ddl1)
print(f"  Résultat : {result1}")

# Créer la nouvelle contrainte avec les valeurs Flutter correctes
print("\n2. Création de la nouvelle contrainte avec valeurs Flutter...")
ddl2 = """
ALTER TABLE app.whiteboard_projects 
ADD CONSTRAINT whiteboard_projects_narration_mode_check 
CHECK (narration_mode IN ('none', 'tts', 'userRecording'))
"""
result2 = execute_ddl(ddl2)
print(f"  Résultat : {result2}")

print("\n" + "=" * 80)
print("CORRECTION TERMINÉE")
print("=" * 80)
