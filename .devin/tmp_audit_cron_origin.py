#!/usr/bin/env python3
"""
Audit origine exacte du cron purge_deleted_accounts
"""
import requests, json
url='https://thevdfcwlcqzdoybfvgs.supabase.co'
key='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h={'apikey':key,'Authorization':f'Bearer {key}','Content-Type':'application/json'}

def rpc_sql(sql):
    r=requests.post(f'{url}/rest/v1/rpc/admin_execute_sql',headers=h,json={'p_sql':sql},timeout=30)
    return r.json()

lines=[]
lines.append("=== AUDIT ORIGINE CRON purge_deleted_accounts ===")

# 1. Détails du cron dans cron.job
lines.append("\n--- 1. Détails complets dans cron.job ---")
res = rpc_sql("SELECT jobid, jobname, schedule, command, nodename, nodeport, database, username, active, jobtype FROM cron.job WHERE jobname = 'purge_deleted_accounts'")
lines.append(json.dumps(res, indent=2))

# 2. Historique d'exécution du cron (cron.job_run_details)
lines.append("\n--- 2. Historique d'exécution (cron.job_run_details) ---")
res = rpc_sql("SELECT jobid, runid, job_pid, database, username, command, status, return_message, start_time, end_time FROM cron.job_run_details WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'purge_deleted_accounts') ORDER BY start_time DESC LIMIT 20")
lines.append(json.dumps(res, indent=2))

# 3. Date de création approximative du cron (via pg_stat_user_tables ou autre)
lines.append("\n--- 3. Vérifier si la fonction app_admin_purge_deleted_accounts a existé ---")
res = rpc_sql("SELECT proname, prosrc FROM pg_proc WHERE proname = 'app_admin_purge_deleted_accounts'")
lines.append(json.dumps(res, indent=2))

# 4. Vérifier s'il y a d'autres jobs cron avec des noms similaires
lines.append("\n--- 4. Tous les jobs cron liés à suppression/compte ---")
res = rpc_sql("SELECT jobname, schedule, command, active FROM cron.job WHERE jobname LIKE '%delete%' OR jobname LIKE '%purge%' OR jobname LIKE '%account%' OR command LIKE '%delete%' OR command LIKE '%purge%' OR command LIKE '%account%'")
lines.append(json.dumps(res, indent=2))

# 5. Vérifier pg_stat_user_tables pour user_admin_status (date de dernière modif)
lines.append("\n--- 5. Date de dernière modification de user_admin_status ---")
res = rpc_sql("SELECT relname, last_vacuum, last_autovacuum, last_analyze, last_autoanalyze FROM pg_stat_user_tables WHERE relname = 'user_admin_status'")
lines.append(json.dumps(res, indent=2))

# 6. Vérifier si des colonnes deletion_* ont existé puis été supprimées
lines.append("\n--- 6. Colonnes actuelles de user_admin_status ---")
res = rpc_sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='user_admin_status' ORDER BY ordinal_position")
lines.append(json.dumps(res, indent=2))

# 7. Vérifier pg_attribute pour voir si des colonnes ont été supprimées (attisdropped)
lines.append("\n--- 7. Attributs supprimés de user_admin_status ---")
res = rpc_sql("SELECT attname, attisdropped FROM pg_attribute WHERE attrelid = 'app.user_admin_status'::regclass AND attnum > 0 ORDER BY attnum")
lines.append(json.dumps(res, indent=2))

# 8. Vérifier les dépendances du cron (si la fonction a existé)
lines.append("\n--- 8. Dépendances du job cron ---")
res = rpc_sql("SELECT * FROM pg_depend WHERE objid = (SELECT oid FROM cron.job WHERE jobname = 'purge_deleted_accounts')::regclass LIMIT 10")
lines.append(json.dumps(res, indent=2))

with open('audit_cron_origin_results.txt','w',encoding='utf-8') as f:
    f.write('\n'.join(lines))
print('OK')
