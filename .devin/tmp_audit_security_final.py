#!/usr/bin/env python3
"""
Audit de securite final avant execution correction suppression de compte
Aucune modification - lecture seule
"""
import requests, json
url='https://thevdfcwlcqzdoybfvgs.supabase.co'
key='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h={'apikey':key,'Authorization':f'Bearer {key}','Content-Type':'application/json'}

def rpc_sql(sql):
    r=requests.post(f'{url}/rest/v1/rpc/admin_execute_sql',headers=h,json={'p_sql':sql},timeout=30)
    return r.json()

lines=[]
lines.append("=== AUDIT SECURITE FINAL — user_admin_status ===")

# 1. Counts
lines.append("\n--- 1. COMPTAGES ---")
res = rpc_sql("SELECT COUNT(*) as total FROM app.user_admin_status")
lines.append(f"Total lignes: {json.dumps(res)}")

res = rpc_sql("SELECT COUNT(*) as cnt FROM app.user_admin_status WHERE is_deleted = TRUE")
lines.append(f"is_deleted = TRUE: {json.dumps(res)}")

res = rpc_sql("SELECT COUNT(*) as cnt FROM app.user_admin_status WHERE is_suspended = TRUE")
lines.append(f"is_suspended = TRUE: {json.dumps(res)}")

res = rpc_sql("SELECT COUNT(*) as cnt FROM app.user_admin_status WHERE deleted_at IS NOT NULL")
lines.append(f"deleted_at IS NOT NULL: {json.dumps(res)}")

res = rpc_sql("SELECT COUNT(*) as cnt FROM app.user_admin_status WHERE deleted_at IS NOT NULL AND is_deleted = FALSE")
lines.append(f"deleted_at NOT NULL mais is_deleted = FALSE (incoherence): {json.dumps(res)}")

res = rpc_sql("SELECT COUNT(*) as cnt FROM app.user_admin_status WHERE is_deleted = TRUE AND deleted_at IS NULL")
lines.append(f"is_deleted = TRUE mais deleted_at NULL (incoherence): {json.dumps(res)}")

# 2. Liste des comptes impactes (sans PII)
lines.append("\n--- 2. LISTE DES COMPTES IMPACTES (sans PII) ---")
res = rpc_sql("""
SELECT 
  u.user_id,
  u.is_deleted,
  u.is_suspended,
  u.deleted_at,
  u.deleted_reason,
  u.suspended_at,
  u.suspended_reason,
  u.updated_at,
  au.raw_user_meta_data->>'role' as role
FROM app.user_admin_status u
LEFT JOIN auth.users au ON au.id = u.user_id
WHERE u.is_deleted = TRUE OR u.deleted_at IS NOT NULL
ORDER BY u.deleted_at DESC NULLS LAST
""")
lines.append(json.dumps(res, indent=2))

# 3. Origine via admin_user_action_logs
lines.append("\n--- 3. ORIGINE VIA admin_user_action_logs ---")
res = rpc_sql("""
SELECT 
  target_user,
  action,
  reason,
  meta,
  created_at
FROM app.admin_user_action_logs
WHERE action IN ('delete', 'self_delete_request', 'account_purged', 'suspend')
ORDER BY created_at DESC
""")
lines.append(json.dumps(res, indent=2))

# 4. Verifier si certains de ces user_id ont encore des sessions actives
lines.append("\n--- 4. SESSIONS ACTIVES DES COMPTES IMPACTES ---")
res = rpc_sql("""
SELECT 
  s.user_id,
  COUNT(*) as session_count
FROM auth.sessions s
WHERE s.user_id IN (
  SELECT user_id FROM app.user_admin_status WHERE is_deleted = TRUE OR deleted_at IS NOT NULL
)
GROUP BY s.user_id
""")
lines.append(json.dumps(res, indent=2))

# 5. Verifier auth.users pour les comptes supprimes (role, banned_until)
lines.append("\n--- 5. ETAT AUTH.USERS POUR COMPTES IMPACTES ---")
res = rpc_sql("""
SELECT 
  u.id as user_id,
  u.banned_until,
  u.raw_user_meta_data->>'role' as role,
  u.deleted_at as auth_deleted_at,
  u.updated_at
FROM auth.users u
WHERE u.id IN (
  SELECT user_id FROM app.user_admin_status WHERE is_deleted = TRUE OR deleted_at IS NOT NULL
)
ORDER BY u.updated_at DESC
""")
lines.append(json.dumps(res, indent=2))

# 6. Compter combien de comptes avec is_deleted=TRUE ont aussi is_suspended=TRUE
lines.append("\n--- 6. CO-OCCURRENCE is_deleted + is_suspended ---")
res = rpc_sql("""
SELECT 
  is_deleted,
  is_suspended,
  COUNT(*) as cnt
FROM app.user_admin_status
GROUP BY is_deleted, is_suspended
ORDER BY is_deleted, is_suspended
""")
lines.append(json.dumps(res, indent=2))

# 7. Analyser les deleted_reason distincts
lines.append("\n--- 7. DELETED_REASON DISTINCTS ---")
res = rpc_sql("SELECT DISTINCT deleted_reason, COUNT(*) as cnt FROM app.user_admin_status WHERE deleted_at IS NOT NULL OR is_deleted = TRUE GROUP BY deleted_reason ORDER BY cnt DESC")
lines.append(json.dumps(res, indent=2))

with open('audit_security_final_results.txt','w',encoding='utf-8') as f:
    f.write('\n'.join(lines))
print('OK')
