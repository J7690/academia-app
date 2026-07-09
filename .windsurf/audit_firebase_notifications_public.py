import requests
import json
from datetime import datetime

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

print("=" * 80)
print("AUDIT SCHÉMA PUBLIC - TABLES NOTIFICATIONS")
print("=" * 80)

# Chercher toutes les tables contenant "token" ou "notification" dans le schéma public
sql_search = """
SELECT 
    table_name,
    table_type
FROM information_schema.tables
WHERE table_schema = 'public'
AND (table_name LIKE '%token%' OR table_name LIKE '%notification%' OR table_name LIKE '%device%')
ORDER BY table_name;
"""

resp = requests.post(admin_url, headers=headers, json={"p_sql": sql_search}, timeout=30)
if resp.status_code == 200:
    tables = resp.json().get('data', [])
    print(f"\nTables trouvées dans public: {len(tables)}")
    for table in tables:
        print(f"  - {table[0]} ({table[1]})")
else:
    print(f"Erreur: {resp.text}")

# Lister toutes les tables du schéma public (premières 50)
print("\n" + "=" * 80)
print("PREMIÈRES 50 TABLES DU SCHÉMA PUBLIC")
print("=" * 80)

sql_public_tables = """
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name
LIMIT 50;
"""

resp_public = requests.post(admin_url, headers=headers, json={"p_sql": sql_public_tables}, timeout=30)
if resp_public.status_code == 200:
    public_tables = resp_public.json().get('data', [])
    print(f"\nNombre de tables dans public (limit 50): {len(public_tables)}")
    for i, table in enumerate(public_tables, 1):
        print(f"  {i}. {table[0]}")
else:
    print(f"Erreur: {resp_public.text}")

# Compter le total de tables dans public
sql_count = """
SELECT COUNT(*) FROM information_schema.tables 
WHERE table_schema = 'public';
"""

resp_count = requests.post(admin_url, headers=headers, json={"p_sql": sql_count}, timeout=30)
if resp_count.status_code == 200:
    total = resp_count.json().get('data', [[0]])[0][0]
    print(f"\nTotal tables dans public: {total}")
