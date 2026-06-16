import requests
import json

url = 'https://thevdfcwlcqzdoybfvgs.supabase.co'
sk = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h = {'Authorization': f'Bearer {sk}', 'apikey': sk, 'Content-Type': 'application/json'}

# Check prep_doc_chunks columns
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': 'SELECT column_name, data_type FROM information_schema.columns WHERE table_schema=\'app\' AND table_name=\'prep_doc_chunks\' ORDER BY ordinal_position'}, timeout=30)
print("=== prep_doc_chunks columns ===")
print(json.dumps(r.json(), indent=2))

# Check td_doc_chunks columns
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': 'SELECT column_name, data_type FROM information_schema.columns WHERE table_schema=\'app\' AND table_name=\'td_doc_chunks\' ORDER BY ordinal_position'}, timeout=30)
print("\n=== td_doc_chunks columns ===")
print(json.dumps(r.json(), indent=2))

# Check if prep_doc_chunks has embedding
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': 'SELECT COUNT(*) AS nb FROM app.prep_doc_chunks WHERE embedding IS NOT NULL'}, timeout=30)
print("\n=== prep_doc_chunks with embedding ===")
print(r.json())

# Check if td_doc_chunks has embedding
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': 'SELECT COUNT(*) AS nb FROM app.td_doc_chunks WHERE embedding IS NOT NULL'}, timeout=30)
print("\n=== td_doc_chunks with embedding ===")
print(r.json())
