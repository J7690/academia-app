import requests
import json

url = 'https://thevdfcwlcqzdoybfvgs.supabase.co'
sk = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h = {'Authorization': f'Bearer {sk}', 'apikey': sk, 'Content-Type': 'application/json'}

# Get all RPCs related to search/embedding/RAG
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT routine_name, routine_type FROM information_schema.routines WHERE routine_schema='public' AND (routine_name LIKE '%search%' OR routine_name LIKE '%embedding%' OR routine_name LIKE '%vector%' OR routine_name LIKE '%rag%' OR routine_name LIKE '%knowledge%') ORDER BY routine_name"}, timeout=30)
print("=== RPCs related to search/embedding/vector/RAG/knowledge ===")
print(json.dumps(r.json(), indent=2))

# Get source of app_search_bobodo_knowledge_vector
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT pg_get_functiondef(oid) as source FROM pg_proc WHERE proname='app_search_bobodo_knowledge_vector'"}, timeout=30)
print("\n=== Source of app_search_bobodo_knowledge_vector ===")
print(r.json()[0]['source'] if r.json() else "Not found")

# Get source of app_search_bobodo_knowledge
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT pg_get_functiondef(oid) as source FROM pg_proc WHERE proname='app_search_bobodo_knowledge'"}, timeout=30)
print("\n=== Source of app_search_bobodo_knowledge ===")
print(r.json()[0]['source'] if r.json() else "Not found")
