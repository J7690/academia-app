#!/usr/bin/env python3
"""Check if injection RPCs exist in database"""

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

    # Vérifier si les RPCs existent
    sql_check = """
SELECT proname, pronargs, proargtypes 
FROM pg_proc p 
JOIN pg_namespace n ON n.oid = p.pronamespace 
WHERE n.nspname = 'public' 
AND proname IN ('app_admin_prep_import_questions_json', 'app_admin_prep_import_text_bulk', 'app_td_admin_import_questions_json', 'app_td_admin_import_text_bulk')
ORDER BY proname;
"""

    params = {'p_sql': sql_check}
    url = f'{m_url}/rest/v1/rpc/admin_execute_sql'
    resp = requests.post(url, headers=headers, json=params, timeout=10)
    print(f'Check RPCs: {resp.status_code}')
    
    if resp.status_code == 200:
        data = resp.json()
        if data.get('ok'):
            print('RPCs trouvées:')
            for row in data.get('rows', []):
                print(f'  - {row["proname"]} (args: {row["pronargs"]})')
        else:
            print('Erreur:', data.get('error'))
    else:
        print('Erreur HTTP:', resp.text[:200])
    
    print()
    
    # Vérifier les tables cibles
    tables_check = """
SELECT table_name, column_names 
FROM information_schema.columns 
WHERE table_schema = 'app' 
AND table_name IN ('prep_questions', 'td_questions', 'prep_source_documents', 'td_source_documents')
ORDER BY table_name;
"""
    
    params = {'p_sql': tables_check}
    resp = requests.post(url, headers=headers, json=params, timeout=10)
    print(f'Check tables: {resp.status_code}')
    
    if resp.status_code == 200:
        data = resp.json()
        if data.get('ok'):
            tables = {}
            for row in data.get('rows', []):
                table = row['table_name']
                col = row['column_names']
                if table not in tables:
                    tables[table] = []
                tables[table].append(col)
            
            for table, cols in tables.items():
                print(f'Table {table}:')
                for col in cols[:5]:  # Limiter à 5 colonnes
                    print(f'  - {col}')
                if len(cols) > 5:
                    print(f'  ... et {len(cols) - 5} autres colonnes')
        else:
            print('Erreur:', data.get('error'))
    else:
        print('Erreur HTTP:', resp.text[:200])

if __name__ == '__main__':
    main()
