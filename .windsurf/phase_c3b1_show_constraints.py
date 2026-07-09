"""
Phase C.3B.1 – Show Constraints
Affiche les contraintes de check sur whiteboard_renders
"""

import requests

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== SHOW CONSTRAINTS ===\n")

sql = """
SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'app.whiteboard_renders'::regclass
AND contype = 'c';
"""

resp = requests.post(admin_url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"Status : {resp.status_code}")
result = resp.json()
print(f"Contraintes : {result}")

# Si la RPC ne retourne pas les données, essayer une autre approche
if isinstance(result, dict) and result.get('ok'):
    print("\nLa RPC ne retourne pas les données. Essai avec une table temporaire...")
    sql2 = """
    CREATE TEMP TABLE temp_constraints AS
    SELECT conname, pg_get_constraintdef(oid) as constraint_def
    FROM pg_constraint
    WHERE conrelid = 'app.whiteboard_renders'::regclass
    AND contype = 'c';
    
    SELECT * FROM temp_constraints;
    """
    resp2 = requests.post(admin_url, headers=headers, json={"p_sql": sql2}, timeout=30)
    print(f"Status : {resp2.status_code}")
    print(f"Résultat : {resp2.json()}")
