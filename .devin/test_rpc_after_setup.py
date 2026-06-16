
#!/usr/bin/env python3
"""
Test après configuration SQL RPC
"""

import requests

# Configuration
url = "https://thevdfcwlcqzdoybfvgs.supabase.co"
service_key = "VOTRE_SERVICE_KEY"

headers = {
    "apikey": service_key,
    "Authorization": f"Bearer {service_key}",
    "Content-Type": "application/json"
}

# Test 1: Lister les tables
print("1. Test list_tables()...")
response = requests.post(f"{url}/rest/v1/rpc/list_tables", headers=headers)
if response.status_code == 200:
    tables = response.json()
    print(f"✅ Tables trouvées: {len(tables)}")
    for table in tables:
        print(f"   - {table['table_name']}")
else:
    print(f"❌ Erreur: {response.status_code}")

# Test 2: Exécuter du SQL
print("\n2. Test execute_sql()...")
sql_query = "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' LIMIT 5"
response = requests.post(f"{url}/rest/v1/rpc/execute_sql", 
                         headers=headers, 
                         json={"sql_query": sql_query})
if response.status_code == 200:
    result = response.json()
    print(f"✅ SQL exécuté: {result}")
else:
    print(f"❌ Erreur SQL: {response.status_code}")

# Test 3: Créer une table
print("\n3. Test create_table_ddl()...")
create_sql = """
CREATE TABLE test_rpc_table (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
)
"""
response = requests.post(f"{url}/rest/v1/rpc/create_table_ddl", 
                         headers=headers, 
                         json={"table_definition": create_sql})
if response.status_code == 200:
    result = response.json()
    print(f"✅ Table créée: {result}")
else:
    print(f"❌ Erreur création: {response.status_code}")
