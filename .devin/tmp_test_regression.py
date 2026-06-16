#!/usr/bin/env python3
"""Test de régression programmatique: vérifier que les autres RPCs forum répondent toujours"""
import requests, json, sys

url='https://thevdfcwlcqzdoybfvgs.supabase.co'
key='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h={'apikey':key,'Authorization':f'Bearer {key}','Content-Type':'application/json'}

rpcs_to_test=[
    ('app_student_list_online_course_forum_threads',{'p_course_id':'00000000-0000-0000-0000-000000000000'}),
    ('app_student_list_online_course_forum_messages',{'p_thread_id':'00000000-0000-0000-0000-000000000000'}),
    ('app_student_create_online_course_forum_thread',{'p_course_id':'00000000-0000-0000-0000-000000000000','p_title':'test','p_content':'test'}),
    ('app_student_add_online_course_forum_message',{'p_thread_id':'00000000-0000-0000-0000-000000000000','p_content':'test'}),
]

all_ok=True
for name,payload in rpcs_to_test:
    r=requests.post(f'{url}/rest/v1/rpc/{name}',headers=h,json=payload,timeout=30)
    is_pgrst202=(r.status_code==404 and ('PGRST202' in r.text or 'not found' in r.text.lower()))
    if is_pgrst202:
        print(f"❌ {name}: PGRST202 détecté!")
        all_ok=False
    else:
        print(f"✅ {name}: HTTP {r.status_code} (pas de PGRST202)")

if all_ok:
    print("\n✅ Aucune régression détectée sur les RPCs forum.")
    sys.exit(0)
else:
    print("\n❌ Régression détectée.")
    sys.exit(1)
