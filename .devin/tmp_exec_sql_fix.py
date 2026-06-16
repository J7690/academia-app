#!/usr/bin/env python3
"""ÉTAPE 2 — Exécution contrôlée du script SQL de correction"""
import requests, json, sys

url='https://thevdfcwlcqzdoybfvgs.supabase.co'
key='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h={'apikey':key,'Authorization':f'Bearer {key}','Content-Type':'application/json'}

def rpc_sql(sql):
    r=requests.post(f'{url}/rest/v1/rpc/admin_execute_sql',headers=h,json={'p_sql':sql},timeout=30)
    return r.json()

# Commande 1: CREATE OR REPLACE FUNCTION
sql_create = "CREATE OR REPLACE FUNCTION public.app_student_delete_forum_message(p_message_id UUID) RETURNS JSONB LANGUAGE sql SECURITY DEFINER SET search_path = public, app, auth AS $$ SELECT app.app_student_delete_forum_message(p_message_id); $$;"

print("=== COMMANDE 1: CREATE OR REPLACE FUNCTION ===")
print(sql_create)
print()
r1 = rpc_sql(sql_create)
print(json.dumps(r1, indent=2, ensure_ascii=False))

if not r1.get('ok'):
    print("\n❌ ÉCHEC CREATE FUNCTION. Arrêt.")
    sys.exit(1)
print("\n✅ CREATE FUNCTION réussi.")

# Commande 2: GRANT EXECUTE
sql_grant = "GRANT EXECUTE ON FUNCTION public.app_student_delete_forum_message(UUID) TO authenticated;"

print("\n=== COMMANDE 2: GRANT EXECUTE ===")
print(sql_grant)
print()
r2 = rpc_sql(sql_grant)
print(json.dumps(r2, indent=2, ensure_ascii=False))

if not r2.get('ok'):
    print("\n❌ ÉCHEC GRANT. Arrêt.")
    sys.exit(2)
print("\n✅ GRANT EXECUTE réussi.")

print("\n=== ÉTAPE 2 TERMINÉE ===")
sys.exit(0)
