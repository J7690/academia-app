#!/usr/bin/env python3
import requests, json
url='https://thevdfcwlcqzdoybfvgs.supabase.co'
key='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h={'apikey':key,'Authorization':f'Bearer {key}','Content-Type':'application/json'}

def rpc_sql(sql):
    r=requests.post(f'{url}/rest/v1/rpc/admin_execute_sql',headers=h,json={'p_sql':sql},timeout=30)
    return r.json()

# Check constraint on admin_user_action_logs.action
res=rpc_sql("""
SELECT conname, pg_get_constraintdef(oid) as def
FROM pg_constraint
WHERE conrelid = 'app.admin_user_action_logs'::regclass
  AND contype = 'c'
""")
print(json.dumps(res, indent=2))

# Also check if there are any enum types
res2=rpc_sql("""
SELECT typname FROM pg_type WHERE typname LIKE '%action%' AND typtype = 'e'
""")
print(json.dumps(res2, indent=2))
