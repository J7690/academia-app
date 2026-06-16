#!/usr/bin/env python3
import requests, json
url='https://thevdfcwlcqzdoybfvgs.supabase.co'
key='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h={'apikey':key,'Authorization':f'Bearer {key}','Content-Type':'application/json'}

def rpc_sql(sql):
    r=requests.post(f'{url}/rest/v1/rpc/admin_execute_sql',headers=h,json={'p_sql':sql},timeout=30)
    return r.json()

lines=[]

# Method 1: information_schema
res=rpc_sql("""
SELECT constraint_name, check_clause
FROM information_schema.check_constraints
WHERE constraint_name LIKE 'admin_user_action_logs%'
""")
lines.append("information_schema:")
lines.append(json.dumps(res, indent=2))

# Method 2: pg_constraint with explicit select
res2=rpc_sql("""
SELECT conname, pg_get_constraintdef(oid) as def
FROM pg_constraint
WHERE conrelid = 'app.admin_user_action_logs'::regclass
  AND contype = 'c'
""")
lines.append("\npg_constraint:")
lines.append(json.dumps(res2, indent=2))

# Method 3: get distinct actions already in table
res3=rpc_sql("SELECT DISTINCT action FROM app.admin_user_action_logs LIMIT 50")
lines.append("\nExisting actions:")
lines.append(json.dumps(res3, indent=2))

with open('check_constraint_results3.txt','w',encoding='utf-8') as f:
    f.write('\n'.join(lines))
print('OK')
