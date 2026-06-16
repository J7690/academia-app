#!/usr/bin/env python3
"""Audit complete injection capabilities"""

import requests
import json

def main():
    m_url = 'https://thevdfcwlcqzdoybfvgs.supabase.co'
    m_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'

    headers = {
        'apikey': m_key,
        'Authorization': f'Bearer {m_key}',
        'Content-Type': 'application/json'
    }

    print("🔍 AUDIT COMPLET DES CAPACITÉS D'INJECTION\n")

    # 1. Vérifier les RPCs d'injection
    print("1. RPCs d'injection disponibles:")
    sql_rpcs = """
SELECT proname, pronargs, proargtypes::text 
FROM pg_proc p 
JOIN pg_namespace n ON n.oid = p.pronamespace 
WHERE n.nspname = 'public' 
AND proname LIKE '%import%'
ORDER BY proname;
"""
    
    params = {'p_sql': sql_rpcs}
    url = f'{m_url}/rest/v1/rpc/admin_execute_sql'
    resp = requests.post(url, headers=headers, json=params, timeout=10)
    
    if resp.status_code == 200:
        data = resp.json()
        if data.get('ok'):
            for row in data.get('rows', []):
                print(f"  ✅ {row['proname']} ({row['pronargs']} args)")
    else:
        print("  ❌ Erreur:", resp.text[:100])
    
    print()

    # 2. Vérifier les tables cibles
    print("2. Tables cibles pour l'injection:")
    sql_tables = """
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'app' 
AND table_name IN ('prep_questions', 'td_questions', 'prep_source_documents', 'td_source_documents', 'prep_doc_chunks', 'td_doc_chunks')
ORDER BY table_name;
"""
    
    params = {'p_sql': sql_tables}
    resp = requests.post(url, headers=headers, json=params, timeout=10)
    
    if resp.status_code == 200:
        data = resp.json()
        if data.get('ok'):
            for row in data.get('rows', []):
                print(f"  ✅ app.{row['table_name']}")
    else:
        print("  ❌ Erreur:", resp.text[:100])
    
    print()

    # 3. Vérifier les définitions exactes des RPCs
    print("3. Définitions exactes des RPCs d'injection:")
    target_rpcs = [
        'app_admin_prep_import_questions_json',
        'app_admin_prep_import_text_bulk',
        'app_td_admin_import_questions_json',
        'app_td_admin_import_text_bulk'
    ]
    
    for rpc in target_rpcs:
        sql_def = f"""
SELECT pg_get_functiondef(p.oid) AS ddl
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = '{rpc}';
"""
        
        params = {'p_sql': sql_def}
        resp = requests.post(url, headers=headers, json=params, timeout=10)
        
        if resp.status_code == 200:
            data = resp.json()
            if data.get('ok') and data.get('rows'):
                ddl = data['rows'][0]['ddl']
                # Extraire la signature
                if 'CREATE OR REPLACE FUNCTION' in ddl:
                    sig_start = ddl.find('(') + 1
                    sig_end = ddl.find(')', sig_start)
                    signature = ddl[sig_start:sig_end]
                    print(f"  📝 {rpc}({signature})")
                else:
                    print(f"  ❌ {rpc}: Définition non trouvée")
            else:
                print(f"  ❌ {rpc}: Non trouvée")
        else:
            print(f"  ❌ {rpc}: Erreur HTTP {resp.status_code}")
    
    print()

    # 4. Vérifier les permissions
    print("4. Permissions sur les RPCs:")
    sql_perms = """
SELECT routine_name, privilege_type, grantee
FROM information_schema.role_routine_grants 
WHERE routine_schema = 'public'
AND routine_name LIKE '%import%'
ORDER BY routine_name, privilege_type;
"""
    
    params = {'p_sql': sql_perms}
    resp = requests.post(url, headers=headers, json=params, timeout=10)
    
    if resp.status_code == 200:
        data = resp.json()
        if data.get('ok') and data.get('rows'):
            for row in data.get('rows', []):
                print(f"  🔐 {row['routine_name']} - {row['privilege_type']} → {row['grantee']}")
        else:
            print("  ⚠️  Aucune permission trouvée ou erreur")
    else:
        print("  ❌ Erreur:", resp.text[:100])
    
    print("\n✅ AUDIT TERMINÉ")

if __name__ == '__main__':
    main()
