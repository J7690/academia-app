#!/usr/bin/env python3
import requests, json, sys
url='https://thevdfcwlcqzdoybfvgs.supabase.co'
key='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h={'apikey':key,'Authorization':f'Bearer {key}','Content-Type':'application/json'}

def rpc_sql(sql):
    r=requests.post(f'{url}/rest/v1/rpc/admin_execute_sql',headers=h,json={'p_sql':sql},timeout=30)
    return r.json()

# Test 1: simple select one line
q1="SELECT routine_name, data_type as return_type FROM information_schema.routines WHERE routine_schema='app' AND routine_name='app_student_delete_forum_message' AND routine_type='FUNCTION'"
print("=== Q1 ===")
print(q1)
r1=rpc_sql(q1)
print(json.dumps(r1,indent=2,ensure_ascii=False))

# Test 2: pg_proc one line
q2="SELECT p.proname as function_name, pg_get_function_arguments(p.oid) as arguments, pg_get_function_result(p.oid) as return_type FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='app' AND p.proname='app_student_delete_forum_message'"
print("\n=== Q2 ===")
print(q2)
r2=rpc_sql(q2)
print(json.dumps(r2,indent=2,ensure_ascii=False))
