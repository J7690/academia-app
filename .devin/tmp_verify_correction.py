#!/usr/bin/env python3
"""Verification post-execution du script de correction"""
import requests, json
url='https://thevdfcwlcqzdoybfvgs.supabase.co'
key='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h={'apikey':key,'Authorization':f'Bearer {key}','Content-Type':'application/json'}

def rpc_sql(sql):
    r=requests.post(f'{url}/rest/v1/rpc/admin_execute_sql',headers=h,json={'p_sql':sql},timeout=30)
    return r.json()

lines=[]
lines.append("=== VERIFICATION POST-EXECUTION ===\n")

# 1. Colonnes
lines.append("--- 1. COLONNES user_admin_status ---")
res=rpc_sql("""
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema='app' AND table_name='user_admin_status'
  AND column_name IN ('deletion_requested_at','purge_due_at','deletion_method')
ORDER BY ordinal_position
""")
lines.append(json.dumps(res, indent=2))

# 2. Fonctions
lines.append("\n--- 2. FONCTIONS PUBLIC ---")
res=rpc_sql("""
SELECT routine_name, routine_type, data_type
FROM information_schema.routines
WHERE routine_schema='public'
  AND routine_name IN ('app_student_request_account_deletion','app_admin_purge_deleted_accounts')
ORDER BY routine_name
""")
lines.append(json.dumps(res, indent=2))

# 3. Permissions
lines.append("\n--- 3. PERMISSIONS GRANT ---")
res=rpc_sql("""
SELECT grantee, privilege_type
FROM information_schema.role_routine_grants
WHERE routine_schema='public'
  AND routine_name='app_student_request_account_deletion'
""")
lines.append(json.dumps(res, indent=2))

# 4. Cron
lines.append("\n--- 4. CRON JOB ---")
res=rpc_sql("SELECT jobid, jobname, schedule, command, active FROM cron.job WHERE jobname='purge_deleted_accounts'")
lines.append(json.dumps(res, indent=2))

# 5. Eligibilite purge (doit etre 0)
lines.append("\n--- 5. COMPTES ELIGIBLES AU CRON (DOIT ETRE 0) ---")
res=rpc_sql("""
SELECT COUNT(*) as eligible
FROM app.user_admin_status
WHERE is_deleted=TRUE
  AND purge_due_at IS NOT NULL
  AND purge_due_at <= NOW()
  AND deletion_method = 'self_service'
""")
lines.append(json.dumps(res, indent=2))

# 6. Comptes historiques (23) intactes
lines.append("\n--- 6. COMPTES HISTORIQUES deletion_method ---")
res=rpc_sql("""
SELECT deletion_method, COUNT(*) as cnt
FROM app.user_admin_status
WHERE is_deleted = TRUE
GROUP BY deletion_method
ORDER BY cnt DESC
""")
lines.append(json.dumps(res, indent=2))

# 7. Total lignes (doit rester 25)
lines.append("\n--- 7. TOTAL LIGNES user_admin_status ---")
res=rpc_sql("SELECT COUNT(*) as total FROM app.user_admin_status")
lines.append(json.dumps(res, indent=2))

# 8. Verification signature fonction
lines.append("\n--- 8. SIGNATURE FONCTIONS ---")
res=rpc_sql("""
SELECT p.proname, pg_get_function_identity_arguments(p.oid) as args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('app_student_request_account_deletion','app_admin_purge_deleted_accounts')
""")
lines.append(json.dumps(res, indent=2))

with open('verify_correction_results.txt','w',encoding='utf-8') as f:
    f.write('\n'.join(lines))
print('OK')
