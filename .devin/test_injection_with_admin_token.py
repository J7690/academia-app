#!/usr/bin/env python3
"""Test injection avec token admin"""

import requests
import json

def main():
    m_url = 'https://thevdfcwlcqzdoybfvgs.supabase.co'
    m_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
    
    print("🔧 TEST INJECTION AVEC TOKEN ADMIN\n")
    
    # 1. Obtenir le token admin
    print("1. Authentification admin:")
    try:
        auth_url = f'{m_url}/auth/v1/token?grant_type=password'
        auth_headers = {
            'apikey': m_key,
            'Content-Type': 'application/json'
        }
        auth_data = {
            'email': 'admin@academia.app',
            'password': 'admin123'
        }
        
        resp = requests.post(auth_url, headers=auth_headers, json=auth_data, timeout=10)
        print(f'   Status: {resp.status_code}')
        
        if resp.status_code == 200:
            token = resp.json()['access_token']
            print(f'   ✅ Token obtenu: {token[:50]}...')
            
            # Headers avec token admin
            headers = {
                'apikey': m_key,
                'Authorization': f'Bearer {token}',
                'Content-Type': 'application/json'
            }
        else:
            print(f'   ❌ Erreur auth: {resp.text[:200]}')
            return
    
    except Exception as e:
        print(f'   💥 Exception auth: {e}')
        return
    
    print()
    
    # 2. Test injection JSON
    print("2. Injection JSON (app_admin_prep_import_questions_json):")
    try:
        url = f'{m_url}/rest/v1/rpc/app_admin_prep_import_questions_json'
        payload = {
            'p_questions': [
                {
                    'question': 'Test final - Quelle est la capitale du Burkina Faso?',
                    'options': ['Bobo-Dioulasso', 'Ouagadougou', 'Koudougou', 'Banfora'],
                    'correct_index': 1,
                    'explanation': 'Ouagadougou est la capitale depuis l\'indépendance',
                    'difficulty': 2
                }
            ],
            'p_concours_type': 'TEST_FINAL',
            'p_subject_name': 'Test Final Subject'
        }
        
        resp = requests.post(url, headers=headers, json=payload, timeout=10)
        print(f'   Status: {resp.status_code}')
        if resp.status_code == 200:
            result = resp.json()
            print(f'   ✅ Success: {result}')
        else:
            print(f'   ❌ Error: {resp.text[:200]}')
    
    except Exception as e:
        print(f'   💥 Exception: {e}')
    
    print()
    
    # 3. Test injection texte
    print("3. Injection Texte (app_admin_prep_import_text_bulk):")
    try:
        url = f'{m_url}/rest/v1/rpc/app_admin_prep_import_text_bulk'
        payload = {
            'p_text': '''SUJET TEST FINAL INJECTION

CONCOURS TEST FINAL 2024 — Épreuve Test

1. Quelle est la capitale du Burkina Faso?
A) Bobo-Dioulasso
B) Ouagadougou  
C) Koudougou
D) Banfora

Réponse : B

2. La monnaie utilisée est :
A) Naira
B) Cedi
C) Franc CFA
D) Shilling

Réponse : C''',
            'p_concours_type': 'TEST_FINAL',
            'p_subject_name': 'Test Final Subject',
            'p_doc_type': 'sujet'
        }
        
        resp = requests.post(url, headers=headers, json=payload, timeout=10)
        print(f'   Status: {resp.status_code}')
        if resp.status_code == 200:
            result = resp.json()
            print(f'   ✅ Success: {result}')
        else:
            print(f'   ❌ Error: {resp.text[:200]}')
    
    except Exception as e:
        print(f'   💥 Exception: {e}')
    
    print()
    
    # 4. Vérification
    print("4. Vérification des injections:")
    try:
        sql_check = """
SELECT 'prep_questions' as table_name, COUNT(*) as count
FROM app.prep_questions 
WHERE concours_type = 'TEST_FINAL'
UNION ALL
SELECT 'prep_source_documents' as table_name, COUNT(*) as count
FROM app.prep_source_documents 
WHERE concours_type = 'TEST_FINAL';
"""
        
        url = f'{m_url}/rest/v1/rpc/admin_execute_sql'
        resp = requests.post(url, headers=headers, json={'p_sql': sql_check}, timeout=10)
        
        if resp.status_code == 200:
            data = resp.json()
            if data.get('ok') and data.get('rows'):
                print("   📊 Données injectées:")
                for row in data['rows']:
                    print(f"      - {row['table_name']}: {row['count']} enregistrements")
            else:
                print("   ⚠️  Aucune donnée trouvée")
        else:
            print(f"   ❌ Erreur vérification: {resp.text[:100]}")
    
    except Exception as e:
        print(f'   💥 Exception vérification: {e}')
    
    print()
    
    # 5. Test utilisation
    print("5. Test utilisation des questions:")
    try:
        url = f'{m_url}/rest/v1/rpc/app_prep_get_quiz_questions'
        payload = {
            'p_concours_type': 'TEST_FINAL',
            'p_subject': 'Test Final Subject',
            'p_count': 5
        }
        
        resp = requests.post(url, headers=headers, json=payload, timeout=10)
        print(f'   Status: {resp.status_code}')
        if resp.status_code == 200:
            result = resp.json()
            if isinstance(result, list) and len(result) > 0:
                print(f'   ✅ Questions récupérées: {len(result)}')
                for i, q in enumerate(result[:2]):
                    print(f'      Q{i+1}: {q.get("question", "")[:50]}...')
            else:
                print('   ⚠️  Aucune question récupérée')
        else:
            print(f'   ❌ Error: {resp.text[:200]}')
    
    except Exception as e:
        print(f'   💥 Exception: {e}')
    
    print("\n✅ TEST TERMINÉ")

if __name__ == '__main__':
    main()
