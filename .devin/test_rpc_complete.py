
#!/usr/bin/env python3
"""
Test des fonctions RPC après configuration
"""

import requests
import json

# Configuration
url = "https://thevdfcwlcqzdoybfvgs.supabase.co"
service_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

headers = {
    "apikey": service_key,
    "Authorization": f"Bearer {service_key}",
    "Content-Type": "application/json",
    "Accept": "application/json"
}

def test_rpc_functions():
    """Test toutes les fonctions RPC"""
    
    print("🧪 Test des fonctions RPC Supabase...")
    
    # Test 1: Lister les tables détaillées
    print("\n1. Test list_tables_detailed()...")
    response = requests.post(f"{url}/rest/v1/rpc/list_tables_detailed", headers=headers)
    
    if response.status_code == 200:
        tables = response.json()
        print(f"✅ Tables trouvées: {len(tables)}")
        for table in tables:
            print(f"   - {table['table_name']} ({table['row_count']} lignes, {table['size_bytes']} bytes)")
    else:
        print(f"❌ Erreur list_tables_detailed: {response.status_code}")
        print(f"Response: {response.text}")
    
    # Test 2: Exécuter du SQL personnalisé
    print("\n2. Test execute_sql()...")
    sql_query = "SELECT table_name, column_name, data_type FROM information_schema.columns WHERE table_schema = 'public' ORDER BY table_name, ordinal_position LIMIT 10"
    
    response = requests.post(f"{url}/rest/v1/rpc/execute_sql", 
                             headers=headers, 
                             json={"sql_query": sql_query})
    
    if response.status_code == 200:
        result = response.json()
        if result and len(result) > 0 and 'result' in result[0]:
            columns = json.loads(result[0]['result'])
            print(f"✅ SQL exécuté: {len(columns)} colonnes trouvées")
            for col in columns[:5]:
                print(f"   - {col['table_name']}.{col['column_name']} ({col['data_type']})")
    else:
        print(f"❌ Erreur execute_sql: {response.status_code}")
        print(f"Response: {response.text}")
    
    # Test 3: Décrire une table
    print("\n3. Test describe_table_detailed()...")
    response = requests.post(f"{url}/rest/v1/rpc/describe_table_detailed", 
                             headers=headers, 
                             json={"table_name": "rpc_test_table"})
    
    if response.status_code == 200:
        columns = response.json()
        print(f"✅ Description table: {len(columns)} colonnes")
        for col in columns:
            print(f"   - {col['column_name']}: {col['data_type']} ({col['is_nullable']})")
    else:
        print(f"❌ Erreur describe_table_detailed: {response.status_code}")
    
    # Test 4: Créer une table via RPC
    print("\n4. Test create_table_safe()...")
    table_definition = [
        {"name": "id", "type": "SERIAL PRIMARY KEY"},
        {"name": "name", "type": "TEXT NOT NULL"},
        {"name": "value", "type": "INTEGER", "nullable": True},
        {"name": "created_at", "type": "TIMESTAMPTZ DEFAULT NOW()"}
    ]
    
    response = requests.post(f"{url}/rest/v1/rpc/create_table_safe", 
                             headers=headers, 
                             json={"table_name": "rpc_created_table", "table_definition": table_definition})
    
    if response.status_code == 200:
        result = response.json()
        print(f"✅ Table créée: {result}")
    else:
        print(f"❌ Erreur create_table_safe: {response.status_code}")
        print(f"Response: {response.text}")
    
    # Test 5: Insérer des données via RPC
    print("\n5. Test insert_data()...")
    test_data = {
        "test_data": "Données insérées via RPC",
        "extra_field": "Test supplémentaire"
    }
    
    response = requests.post(f"{url}/rest/v1/rpc/insert_data", 
                             headers=headers, 
                             json={"table_name": "rpc_test_table", "data": test_data})
    
    if response.status_code == 200:
        inserted_id = response.json()
        print(f"✅ Données insérées, ID: {inserted_id}")
    else:
        print(f"❌ Erreur insert_data: {response.status_code}")
    
    print("\n🎯 Test RPC terminé!")

if __name__ == "__main__":
    test_rpc_functions()
