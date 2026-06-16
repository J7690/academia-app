#!/usr/bin/env python3
"""ÉTAPE 3 — Validation Supabase post-déploiement"""
import requests, json, sys

url='https://thevdfcwlcqzdoybfvgs.supabase.co'
key='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h={'apikey':key,'Authorization':f'Bearer {key}','Content-Type':'application/json'}

def rpc_sql(sql):
    r=requests.post(f'{url}/rest/v1/rpc/admin_execute_sql',headers=h,json={'p_sql':sql},timeout=30)
    return r.json()

# Validation 1: existence du proxy dans public
q1="SELECT routine_name, routine_schema, data_type as return_type FROM information_schema.routines WHERE routine_schema='public' AND routine_name='app_student_delete_forum_message' AND routine_type='FUNCTION'"
print("=== VALIDATION 1: Existence du proxy dans public ===")
r1=rpc_sql(q1)
print(json.dumps(r1,indent=2,ensure_ascii=False))

if not (r1.get('ok') and r1.get('mode')=='select' and len(r1.get('rows',[]))>=1):
    print("\n❌ PROXY NON TROUVÉ dans public. Arrêt.")
    sys.exit(1)
row=r1['rows'][0]
if row.get('return_type','').lower()!='jsonb':
    print(f"\n❌ RETURN TYPE incorrect: {row.get('return_type')}. Arrêt.")
    sys.exit(2)
print("\n✅ Proxy public trouvé avec return_type=jsonb.")

# Validation 2: présence du GRANT
q2="SELECT grantee, privilege_type FROM information_schema.role_routine_grants WHERE routine_schema='public' AND routine_name='app_student_delete_forum_message' AND privilege_type='EXECUTE'"
print("\n=== VALIDATION 2: Présence du GRANT ===")
r2=rpc_sql(q2)
print(json.dumps(r2,indent=2,ensure_ascii=False))

if not (r2.get('ok') and r2.get('mode')=='select'):
    print("\n❌ ERREUR lors de la vérification du GRANT. Arrêt.")
    sys.exit(3)

grantees=[g['grantee'] for g in r2.get('rows',[])]
print(f"\nGrantees trouvés: {grantees}")

if 'authenticated' not in grantees:
    print("\n❌ GRANT 'authenticated' manquant. Arrêt.")
    sys.exit(4)
print("\n✅ GRANT EXECUTE pour 'authenticated' présent.")

print("\n=== ÉTAPE 3 TERMINÉE ===")
sys.exit(0)
