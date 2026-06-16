#!/usr/bin/env python3
"""
Audit forensique complementaire - suppression de compte Academia
"""
import requests, json
url='https://thevdfcwlcqzdoybfvgs.supabase.co'
key='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h={'apikey':key,'Authorization':f'Bearer {key}','Content-Type':'application/json'}

def rpc_sql(sql):
    r=requests.post(f'{url}/rest/v1/rpc/admin_execute_sql',headers=h,json={'p_sql':sql},timeout=30)
    return r.json()

lines=[]

# A. INVENTAIRE RPCs - Toutes variantes
lines.append("=== A. INVENTAIRE RPCs (toutes variantes) ===")
variants = [
    'app_student_request_account_deletion',
    'delete_account', 'account_deletion', 'account_delete',
    'user_delete', 'user_deletion', 'remove_user',
    'purge_user', 'purge_account', 'close_account',
    'self_delete', 'request_deletion', 'delete_user',
    'purge_deleted', 'admin_purge', 'app_admin_purge_deleted_accounts',
    'app_check_account_status', 'check_account_status'
]
for v in variants:
    res = rpc_sql(f"SELECT n.nspname, p.proname, pg_get_function_arguments(p.oid) AS args, pg_get_function_result(p.oid) AS returns FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE p.proname LIKE '%{v}%' ORDER BY n.nspname, p.proname")
    if res.get('rows'):
        lines.append(f"\n--- MATCH: {v} ---")
        lines.append(json.dumps(res, indent=2))

# Also broad search
lines.append("\n--- BROAD SEARCH: all RPCs containing 'delete' or 'purge' or 'account' ---")
res = rpc_sql("SELECT n.nspname, p.proname, pg_get_function_arguments(p.oid) AS args FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE p.proname SIMILAR TO '%(delete|purge|account|deletion)%' ORDER BY n.nspname, p.proname")
lines.append(json.dumps(res, indent=2))

# B. INVENTAIRE TABLES - Colonnes deletion/purge/is_deleted/banned_until
lines.append("\n=== B. INVENTAIRE TABLES (colonnes deletion/purge/is_deleted/banned_until) ===")
res = rpc_sql("SELECT table_schema, table_name, column_name, data_type FROM information_schema.columns WHERE column_name IN ('deletion_requested_at','purge_due_at','deleted_at','is_deleted','is_suspended','account_status','banned_until','purge_status','deletion_method') AND table_schema NOT IN ('pg_catalog','information_schema') ORDER BY table_schema, table_name, column_name")
lines.append(json.dumps(res, indent=2))

# Also check for any column containing 'delete' or 'purge'
lines.append("\n--- Any column containing 'delete' or 'purge' ---")
res = rpc_sql("SELECT table_schema, table_name, column_name, data_type FROM information_schema.columns WHERE (column_name LIKE '%delete%' OR column_name LIKE '%purge%') AND table_schema NOT IN ('pg_catalog','information_schema') ORDER BY table_schema, table_name, column_name")
lines.append(json.dumps(res, indent=2))

# C. INVENTAIRE CRONS
lines.append("\n=== C. INVENTAIRE CRONS ===")
res = rpc_sql("SELECT jobname, schedule, command, active FROM cron.job WHERE jobname SIMILAR TO '%(purge|delete|account|user)%' OR command SIMILAR TO '%(purge|delete|account|user)%'")
lines.append(json.dumps(res, indent=2))

# Also list ALL crons
lines.append("\n--- ALL CRONS ---")
res = rpc_sql("SELECT jobname, schedule, active FROM cron.job ORDER BY jobname")
lines.append(json.dumps(res, indent=2))

# D. FONCTIONS DE PURGE / ANONYMISATION
lines.append("\n=== D. FONCTIONS PURGE / ANONYMISATION ===")
res = rpc_sql("SELECT n.nspname, p.proname, pg_get_functiondef(p.oid) AS definition FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE p.proname SIMILAR TO '%(purge|anonym|clean|wipe|scrub)%' OR pg_get_functiondef(p.oid) LIKE '%anonym%' OR pg_get_functiondef(p.oid) LIKE '%purge%' ORDER BY n.nspname, p.proname")
lines.append(json.dumps(res, indent=2))

# E. VÉRIFICATION SUPABASE RÉELLE - RPC app_student_request_account_deletion
lines.append("\n=== E. VÉRIFICATION RPC app_student_request_account_deletion ===")
res = rpc_sql("SELECT n.nspname, p.proname, p.prosecdef, p.proacl, pg_get_function_arguments(p.oid) AS args, pg_get_function_result(p.oid) AS returns FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE p.proname = 'app_student_request_account_deletion'")
lines.append(json.dumps(res, indent=2))

# Also check if it exists in app schema specifically
lines.append("\n--- Check in app schema ---")
res = rpc_sql("SELECT proname, prosrc FROM pg_proc WHERE proname = 'app_student_request_account_deletion'")
lines.append(json.dumps(res, indent=2))

# Check all schemas for any deletion-related RPC
lines.append("\n--- All schemas deletion RPCs ---")
res = rpc_sql("SELECT n.nspname, p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE p.proname SIMILAR TO '%(delete|purge|deletion)%' ORDER BY n.nspname, p.proname")
lines.append(json.dumps(res, indent=2))

# F. COHÉRENCE - user_admin_status colonnes réelles
lines.append("\n=== F. COHÉRENCE user_admin_status ===")
res = rpc_sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='user_admin_status' ORDER BY ordinal_position")
lines.append(json.dumps(res, indent=2))

# Check if deletion columns exist
lines.append("\n--- Check deletion columns in user_admin_status ---")
res = rpc_sql("SELECT column_name FROM information_schema.columns WHERE table_schema='app' AND table_name='user_admin_status' AND column_name IN ('deletion_requested_at','purge_due_at','deletion_method')")
lines.append(json.dumps(res, indent=2))

# Check if app_admin_purge_deleted_accounts exists
lines.append("\n--- Check app_admin_purge_deleted_accounts ---")
res = rpc_sql("SELECT n.nspname, p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE p.proname='app_admin_purge_deleted_accounts'")
lines.append(json.dumps(res, indent=2))

# Check Edge Functions
lines.append("\n=== G. EDGE FUNCTIONS (hard delete) ===")
r = requests.get(f'{url}/rest/v1/edge_functions', headers=h, timeout=15)
lines.append(f"Edge Functions HTTP: {r.status_code}")
if r.status_code == 200:
    ef = r.json()
    for f in ef if isinstance(ef, list) else []:
        if 'delete' in f.get('name','').lower() or 'account' in f.get('name','').lower() or 'purge' in f.get('name','').lower() or 'user' in f.get('name','').lower():
            lines.append(f"Edge Function: {f}")

# Check if app_check_account_status exists in public schema (from previous work)
lines.append("\n=== H. app_check_account_status in public (from previous fix) ===")
res = rpc_sql("SELECT n.nspname, p.proname, pg_get_function_arguments(p.oid) AS args FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE p.proname='app_check_account_status'")
lines.append(json.dumps(res, indent=2))

with open('audit_comprehensive_results.txt','w',encoding='utf-8') as f:
    f.write('\n'.join(lines))
print('OK')
