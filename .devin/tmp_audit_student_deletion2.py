#!/usr/bin/env python3
import requests, json
url='https://thevdfcwlcqzdoybfvgs.supabase.co'
key='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h={'apikey':key,'Authorization':f'Bearer {key}','Content-Type':'application/json'}

def rpc_sql(sql):
    r=requests.post(f'{url}/rest/v1/rpc/admin_execute_sql',headers=h,json={'p_sql':sql},timeout=30)
    return r.json()

lines=[]

# PHASE 3: Existence du RPC
lines.append("=== PHASE 3: Existence de app_student_request_account_deletion ===")
res=rpc_sql("SELECT n.nspname AS schema, p.proname AS name, pg_get_function_arguments(p.oid) AS args, pg_get_function_result(p.oid) AS returns FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE p.proname='app_student_request_account_deletion'")
lines.append(json.dumps(res, indent=2))

# PHASE 4: RPCs équivalents
lines.append("\n=== PHASE 4: RPCs équivalents ===")
res=rpc_sql("SELECT n.nspname AS schema, p.proname AS name, pg_get_function_arguments(p.oid) AS args, pg_get_function_result(p.oid) AS returns FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE p.proname SIMILAR TO '(.*delete.*|.*deletion.*|.*remove.*|.*erase.*|.*close_account.*|.*account_closure.*|.*user_deletion.*)' ORDER BY n.nspname, p.proname")
lines.append(json.dumps(res, indent=2))

# PHASE 6: Tables avec user_id
lines.append("\n=== PHASE 6: Tables avec user_id ===")
res=rpc_sql("SELECT table_schema, table_name, column_name, data_type FROM information_schema.columns WHERE column_name='user_id' AND table_schema NOT IN ('pg_catalog','information_schema') ORDER BY table_schema, table_name")
lines.append(json.dumps(res, indent=2))

# PHASE 6b: FK vers auth.users
lines.append("\n=== PHASE 6b: FK vers auth.users ===")
res=rpc_sql("SELECT tc.table_schema, tc.table_name, kcu.column_name, ccu.table_name AS foreign_table_name FROM information_schema.table_constraints tc JOIN information_schema.key_column_usage kcu ON tc.constraint_name=kcu.constraint_name AND tc.table_schema=kcu.table_schema JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_name=tc.constraint_name AND ccu.table_schema=tc.table_schema WHERE tc.constraint_type='FOREIGN KEY' AND ccu.table_name='users' AND ccu.table_schema='auth' ORDER BY tc.table_schema, tc.table_name")
lines.append(json.dumps(res, indent=2))

# PHASE 7: Définition RPC
lines.append("\n=== PHASE 7: Définition app_student_request_account_deletion ===")
res=rpc_sql("SELECT p.proname, n.nspname, pg_get_functiondef(p.oid) AS definition FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE p.proname='app_student_request_account_deletion'")
lines.append(json.dumps(res, indent=2))

with open('audit_student_deletion_results2.txt','w',encoding='utf-8') as f:
    f.write('\n'.join(lines))
print('OK')
