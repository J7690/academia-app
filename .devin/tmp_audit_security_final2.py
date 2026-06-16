#!/usr/bin/env python3
import requests, json
url='https://thevdfcwlcqzdoybfvgs.supabase.co'
key='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h={'apikey':key,'Authorization':f'Bearer {key}','Content-Type':'application/json'}

def rpc_sql(sql):
    r=requests.post(f'{url}/rest/v1/rpc/admin_execute_sql',headers=h,json={'p_sql':sql},timeout=30)
    return r.json()

lines=[]
lines.append("=== AUDIT SECURITE FINAL v2 ===")

# 1. Comptages deja faits - recap
lines.append("\n--- RECAP COMPTAGES ---")
lines.append("Total lignes user_admin_status: 25")
lines.append("is_deleted = TRUE: 23")
lines.append("is_suspended = TRUE: 24")
lines.append("deleted_at IS NOT NULL: 23")
lines.append("deleted_reason NULL: 22, 'hard_delete': 1")

# 2. Liste des comptes impactes - utiliser SELECT simple
lines.append("\n--- 2. COMPTES AVEC is_deleted = TRUE ---")
res = rpc_sql("SELECT user_id, is_deleted, is_suspended, deleted_at, deleted_reason, suspended_at, suspended_reason FROM app.user_admin_status WHERE is_deleted = TRUE ORDER BY deleted_at DESC")
lines.append(json.dumps(res, indent=2))

# 3. Logs associes
lines.append("\n--- 3. LOGS admin_user_action_logs pour target_user correspondants ---")
res = rpc_sql("""
SELECT target_user, action, reason, created_at
FROM app.admin_user_action_logs
WHERE target_user IN (SELECT user_id FROM app.user_admin_status WHERE is_deleted = TRUE)
ORDER BY created_at DESC
""")
lines.append(json.dumps(res, indent=2))

# 4. Sessions actives
lines.append("\n--- 4. SESSIONS ACTIVES ---")
res = rpc_sql("""
SELECT s.user_id, count(*) as session_count
FROM auth.sessions s
WHERE s.user_id IN (SELECT user_id FROM app.user_admin_status WHERE is_deleted = TRUE)
GROUP BY s.user_id
""")
lines.append(json.dumps(res, indent=2))

# 5. auth.users state
lines.append("\n--- 5. ETAT AUTH.USERS ---")
res = rpc_sql("""
SELECT u.id, u.banned_until, u.raw_user_meta_data->>'role' as role, u.deleted_at, u.updated_at
FROM auth.users u
WHERE u.id IN (SELECT user_id FROM app.user_admin_status WHERE is_deleted = TRUE)
ORDER BY u.updated_at DESC
""")
lines.append(json.dumps(res, indent=2))

# 6. Distribution is_deleted / is_suspended
lines.append("\n--- 6. DISTRIBUTION is_deleted / is_suspended ---")
res = rpc_sql("SELECT is_deleted, is_suspended, COUNT(*) as cnt FROM app.user_admin_status GROUP BY is_deleted, is_suspended ORDER BY is_deleted, is_suspended")
lines.append(json.dumps(res, indent=2))

# 7. Comptes NON supprimes (pour reference)
lines.append("\n--- 7. COMPTES NON SUPPRIMES ---")
res = rpc_sql("SELECT user_id, is_deleted, is_suspended, updated_at FROM app.user_admin_status WHERE is_deleted = FALSE ORDER BY updated_at DESC")
lines.append(json.dumps(res, indent=2))

with open('audit_security_final_results2.txt','w',encoding='utf-8') as f:
    f.write('\n'.join(lines))
print('OK')
