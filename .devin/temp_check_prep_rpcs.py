import requests
import json

url = 'https://thevdfcwlcqzdoybfvgs.supabase.co'
sk = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h = {'Authorization': f'Bearer {sk}', 'apikey': sk, 'Content-Type': 'application/json'}

# Get source of app_prep_get_rag_chunks
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT pg_get_functiondef(oid) as source FROM pg_proc WHERE proname='app_prep_get_rag_chunks'"}, timeout=30)
print("=== Source of app_prep_get_rag_chunks ===")
print(r.json()[0]['source'] if r.json() else "Not found")

# Get source of app_prep_semantic_search
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT pg_get_functiondef(oid) as source FROM pg_proc WHERE proname='app_prep_semantic_search'"}, timeout=30)
print("\n=== Source of app_prep_semantic_search ===")
print(r.json()[0]['source'] if r.json() else "Not found")

# Get source of app_td_semantic_search
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT pg_get_functiondef(oid) as source FROM pg_proc WHERE proname='app_td_semantic_search'"}, timeout=30)
print("\n=== Source of app_td_semantic_search ===")
print(r.json()[0]['source'] if r.json() else "Not found")

# Check bobodo_knowledge content
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT category, title, LEFT(content, 100) as content_preview FROM app.bobodo_knowledge WHERE is_active=TRUE ORDER BY category, title"}, timeout=30)
print("\n=== bobodo_knowledge content ===")
print(json.dumps(r.json(), indent=2))
