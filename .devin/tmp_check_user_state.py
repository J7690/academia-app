#!/usr/bin/env python3
import requests, json, sys
url='https://thevdfcwlcqzdoybfvgs.supabase.co'
key='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h={'apikey':key,'Authorization':f'Bearer {key}','Content-Type':'application/json'}

def rpc_sql(sql):
    r=requests.post(f'{url}/rest/v1/rpc/admin_execute_sql',headers=h,json={'p_sql':sql},timeout=30)
    return r.json()

user_email = sys.argv[1] if len(sys.argv) > 1 else 'test@example.com'
lines=[]
lines.append(f"=== User state check for: {user_email} ===")

res = rpc_sql(f"SELECT id, email, banned_until, deleted_at, raw_user_meta_data FROM auth.users WHERE email = '{user_email}'")
lines.append(json.dumps(res, indent=2))

if res.get('rows') and res['rows']:
    user_id = res['rows'][0].get('id')
    lines.append(f"\n=== user_admin_status for {user_id} ===")
    res2 = rpc_sql(f"SELECT * FROM app.user_admin_status WHERE user_id = '{user_id}'")
    lines.append(json.dumps(res2, indent=2))
    
    lines.append(f"\n=== sessions for {user_id} ===")
    res3 = rpc_sql(f"SELECT id, created_at FROM auth.sessions WHERE user_id = '{user_id}'")
    lines.append(json.dumps(res3, indent=2))

with open('user_state_check.txt','w',encoding='utf-8') as f:
    f.write('\n'.join(lines))
print('OK')
