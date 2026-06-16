#!/usr/bin/env python3
"""Test programmatique: vérifier que le proxy public est résolu par PostgREST (pas de PGRST202)"""
import requests, json, sys

url='https://thevdfcwlcqzdoybfvgs.supabase.co'
key='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h={'apikey':key,'Authorization':f'Bearer {key}','Content-Type':'application/json','Prefer':'params=single-object'}

payload={"p_message_id":"00000000-0000-0000-0000-000000000000"}

print("=== TEST RÉSOLUTION POSTGREST ===")
print(f"POST {url}/rest/v1/rpc/app_student_delete_forum_message")
print(f"Payload: {payload}")
print()

r=requests.post(f'{url}/rest/v1/rpc/app_student_delete_forum_message',headers=h,json=payload,timeout=30)

print(f"Status code: {r.status_code}")
print(f"Headers: {dict(r.headers)}")
try:
    body=r.json()
    print(f"Body: {json.dumps(body,indent=2,ensure_ascii=False)}")
except Exception as e:
    print(f"Body (text): {r.text}")

# Analyse
if r.status_code==404:
    if 'PGRST202' in r.text or 'not found' in r.text.lower():
        print("\n❌ PGRST202 détecté. Le proxy n'est pas encore visible de PostgREST (peut nécessiter un reload).")
        sys.exit(1)
    else:
        print("\n❌ 404 non PGRST202.")
        sys.exit(2)
elif r.status_code in (200,201):
    print("\n✅ Proxy résolu par PostgREST (HTTP 200). La fonction est accessible.")
    # Note: avec service_role sans auth utilisateur, la fonction source retournera probablement une erreur métier JSON
    if isinstance(body,dict) and body.get('success')==False:
        print(f"   Réponse métier: {body.get('error','N/A')} — attendu car pas d'utilisateur authentifié.")
    sys.exit(0)
elif r.status_code==401:
    print("\n⚠️  401 Unauthorized — possible si le proxy n'est pas encore visible ou si le grant manque.")
    sys.exit(3)
else:
    print(f"\n⚠️  Statut inattendu {r.status_code}.")
    sys.exit(4)
