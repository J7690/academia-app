"""
Script pour Phase B.5 – Fix table whiteboard_renders (ajouter started_at)
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

print("=== FIX TABLE whiteboard_renders ===\n")

# Vérifier la structure actuelle
sql = """
SELECT 
    column_name, 
    data_type, 
    is_nullable, 
    column_default
FROM information_schema.columns 
WHERE table_schema = 'app' 
  AND table_name = 'whiteboard_renders' 
ORDER BY ordinal_position
"""
result = execute_sql(sql)
print("Structure actuelle whiteboard_renders:")
if result.get("ok") and result.get("rows"):
    for row in result["rows"]:
        print(f"  {row['column_name']}: {row['data_type']} (nullable: {row['is_nullable']})")
else:
    print("❌ Erreur récupération structure")

# Ajouter started_at si manquant
sql = "ALTER TABLE app.whiteboard_renders ADD COLUMN IF NOT EXISTS started_at TIMESTAMPTZ"
result = execute_sql(sql)
print(f"\nAjout started_at: {result}")

# Ajouter completed_at si manquant
sql = "ALTER TABLE app.whiteboard_renders ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ"
result = execute_sql(sql)
print(f"Ajout completed_at: {result}")

print("\n=== FIX TERMINÉ ===\n")
