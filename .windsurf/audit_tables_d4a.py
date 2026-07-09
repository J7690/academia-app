import requests
import json

url = "https://thevdfcwlcqzdoybfvgs.supabase.co"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

print("=" * 80)
print("AUDIT TABLES - PHASE D.4A")
print("=" * 80)

results = {}

# 1. Vérifier app.whiteboard_projects
print("\n1. Vérification table app.whiteboard_projects...")
sql = """
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'app'
AND table_name = 'whiteboard_projects'
ORDER BY ordinal_position;
"""

rpc_url = f"{url}/rest/v1/rpc/admin_execute_sql"
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"STATUS: {resp.status_code}")

if resp.status_code == 200:
    data = resp.json()
    columns = data.get('data', [])
    if columns:
        results['whiteboard_projects'] = {'exists': True, 'columns': columns}
        print(f"  ✅ Table app.whiteboard_projects existe ({len(columns)} colonnes)")
        for col in columns:
            print(f"    - {col[0]}: {col[1]} (nullable: {col[2]}, default: {col[3]})")
    else:
        results['whiteboard_projects'] = {'exists': False}
        print("  ❌ Table app.whiteboard_projects n'existe pas")
else:
    results['whiteboard_projects'] = {'exists': False, 'error': resp.text}
    print(f"  ❌ Error: {resp.text}")

# 2. Vérifier app.whiteboard_renders
print("\n2. Vérification table app.whiteboard_renders...")
sql = """
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'app'
AND table_name = 'whiteboard_renders'
ORDER BY ordinal_position;
"""

resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"STATUS: {resp.status_code}")

if resp.status_code == 200:
    data = resp.json()
    columns = data.get('data', [])
    if columns:
        results['whiteboard_renders'] = {'exists': True, 'columns': columns}
        print(f"  ✅ Table app.whiteboard_renders existe ({len(columns)} colonnes)")
        for col in columns:
            print(f"    - {col[0]}: {col[1]} (nullable: {col[2]}, default: {col[3]})")
    else:
        results['whiteboard_renders'] = {'exists': False}
        print("  ❌ Table app.whiteboard_renders n'existe pas")
else:
    results['whiteboard_renders'] = {'exists': False, 'error': resp.text}
    print(f"  ❌ Error: {resp.text}")

# 3. Compter les lignes dans app.whiteboard_projects
if results.get('whiteboard_projects', {}).get('exists'):
    print("\n3. Comptage des lignes dans app.whiteboard_projects...")
    sql = "SELECT COUNT(*) FROM app.whiteboard_projects;"
    resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
    print(f"STATUS: {resp.status_code}")
    if resp.status_code == 200:
        data = resp.json()
        count = data.get('data', [[0]])[0][0]
        results['whiteboard_projects']['row_count'] = count
        print(f"  Nombre de lignes: {count}")
    else:
        print(f"  ❌ Error: {resp.text}")

# 4. Compter les lignes dans app.whiteboard_renders
if results.get('whiteboard_renders', {}).get('exists'):
    print("\n4. Comptage des lignes dans app.whiteboard_renders...")
    sql = "SELECT COUNT(*) FROM app.whiteboard_renders;"
    resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
    print(f"STATUS: {resp.status_code}")
    if resp.status_code == 200:
        data = resp.json()
        count = data.get('data', [[0]])[0][0]
        results['whiteboard_renders']['row_count'] = count
        print(f"  Nombre de lignes: {count}")
    else:
        print(f"  ❌ Error: {resp.text}")

# 5. Vérifier les contraintes
if results.get('whiteboard_projects', {}).get('exists'):
    print("\n5. Contraintes de app.whiteboard_projects...")
    sql = """
    SELECT 
      constraint_name,
      constraint_type
    FROM information_schema.table_constraints
    WHERE table_schema = 'app'
    AND table_name = 'whiteboard_projects';
    """
    resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
    print(f"STATUS: {resp.status_code}")
    if resp.status_code == 200:
        data = resp.json()
        constraints = data.get('data', [])
        results['whiteboard_projects']['constraints'] = constraints
        print(f"  Contraintes: {len(constraints)}")
        for constraint in constraints:
            print(f"    - {constraint[0]}: {constraint[1]}")
    else:
        print(f"  ❌ Error: {resp.text}")

if results.get('whiteboard_renders', {}).get('exists'):
    print("\n6. Contraintes de app.whiteboard_renders...")
    sql = """
    SELECT 
      constraint_name,
      constraint_type
    FROM information_schema.table_constraints
    WHERE table_schema = 'app'
    AND table_name = 'whiteboard_renders';
    """
    resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
    print(f"STATUS: {resp.status_code}")
    if resp.status_code == 200:
        data = resp.json()
        constraints = data.get('data', [])
        results['whiteboard_renders']['constraints'] = constraints
        print(f"  Contraintes: {len(constraints)}")
        for constraint in constraints:
            print(f"    - {constraint[0]}: {constraint[1]}")
    else:
        print(f"  ❌ Error: {resp.text}")

# Sauvegarder les résultats
with open('audit_tables_d4a_results.json', 'w') as f:
    json.dump(results, f, indent=2)

print("\n" + "=" * 80)
print("RÉSULTATS SAUVEGARDÉS DANS audit_tables_d4a_results.json")
print("=" * 80)
