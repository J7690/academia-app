#!/usr/bin/env python3
"""Test final des capacités d'injection directe"""

import requests
import json
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    
    print("🔍 TEST FINAL D'INJECTION DIRECTE\n")
    
    # 1. Test injection JSON Concours
    print("1. Injection JSON Concours (app_admin_prep_import_questions_json):")
    try:
        url = f'{m.url}/rest/v1/rpc/app_admin_prep_import_questions_json'
        payload = {
            'p_questions': [
                {
                    'question': 'Test injection - Quelle est la capitale du Burkina Faso?',
                    'options': ['Bobo-Dioulasso', 'Ouagadougou', 'Koudougou', 'Banfora'],
                    'correct_index': 1,
                    'explanation': 'Ouagadougou est la capitale depuis l\'indépendance',
                    'difficulty': 2
                }
            ],
            'p_concours_type': 'TEST_INJECTION',
            'p_subject_name': 'Test Subject'
        }
        
        resp = requests.post(url, headers=m.headers, json=payload, timeout=10)
        print(f'   Status: {resp.status_code}')
        if resp.status_code == 200:
            result = resp.json()
            print(f'   ✅ Success: {result}')
        else:
            print(f'   ❌ Error: {resp.text[:200]}')
    except Exception as e:
        print(f'   💥 Exception: {e}')
    
    print()
    
    # 2. Test injection Texte Concours
    print("2. Injection Texte Concours (app_admin_prep_import_text_bulk):")
    try:
        url = f'{m.url}/rest/v1/rpc/app_admin_prep_import_text_bulk'
        payload = {
            'p_text': '''SUJET TEST INJECTION DIRECTE

CONCOURS TEST 2024 — Épreuve de Test

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
            'p_concours_type': 'TEST_INJECTION',
            'p_subject_name': 'Test Subject',
            'p_doc_type': 'sujet'
        }
        
        resp = requests.post(url, headers=m.headers, json=payload, timeout=10)
        print(f'   Status: {resp.status_code}')
        if resp.status_code == 200:
            result = resp.json()
            print(f'   ✅ Success: {result}')
        else:
            print(f'   ❌ Error: {resp.text[:200]}')
    except Exception as e:
        print(f'   💥 Exception: {e}')
    
    print()
    
    # 3. Vérifier que les données ont été injectées
    print("3. Vérification des données injectées:")
    
    # Vérifier les questions
    try:
        sql_check = """
SELECT COUNT(*) as count, subject, concours_type, source
FROM app.prep_questions 
WHERE concours_type = 'TEST_INJECTION' 
GROUP BY subject, concours_type, source;
"""
        
        url = f'{m.url}/rest/v1/rpc/admin_execute_sql'
        resp = requests.post(url, headers=m.headers, json={'p_sql': sql_check}, timeout=10)
        
        if resp.status_code == 200:
            data = resp.json()
            if data.get('ok') and data.get('rows'):
                print("   📊 Questions injectées:")
                for row in data['rows']:
                    print(f"      - {row['subject']} ({row['concours_type']}): {row['count']} questions (source: {row['source']})")
            else:
                print("   ⚠️  Aucune question trouvée")
        else:
            print(f"   ❌ Erreur vérification: {resp.text[:100]}")
    except Exception as e:
        print(f"   💥 Exception vérification: {e}")
    
    print()
    
    # Vérifier les documents
    try:
        sql_check_docs = """
SELECT COUNT(*) as count, doc_type, concours_type, status
FROM app.prep_source_documents 
WHERE concours_type = 'TEST_INJECTION' 
GROUP BY doc_type, concours_type, status;
"""
        
        resp = requests.post(url, headers=m.headers, json={'p_sql': sql_check_docs}, timeout=10)
        
        if resp.status_code == 200:
            data = resp.json()
            if data.get('ok') and data.get('rows'):
                print("   📄 Documents injectés:")
                for row in data['rows']:
                    print(f"      - {row['doc_type']} ({row['concours_type']}): {row['count']} documents (status: {row['status']})")
            else:
                print("   ⚠️  Aucun document trouvé")
        else:
            print(f"   ❌ Erreur vérification docs: {resp.text[:100]}")
    except Exception as e:
        print(f"   💥 Exception vérification docs: {e}")
    
    print()
    
    # 4. Test si les questions sont utilisables
    print("4. Test d'utilisation des questions injectées:")
    try:
        url = f'{m.url}/rest/v1/rpc/app_prep_get_quiz_questions'
        payload = {
            'p_concours_type': 'TEST_INJECTION',
            'p_subject': 'Test Subject',
            'p_count': 5
        }
        
        resp = requests.post(url, headers=m.headers, json=payload, timeout=10)
        print(f'   Status: {resp.status_code}')
        if resp.status_code == 200:
            result = resp.json()
            if isinstance(result, list) and len(result) > 0:
                print(f'   ✅ Questions récupérées: {len(result)}')
                for i, q in enumerate(result[:2]):  # Afficher les 2 premières
                    print(f'      Q{i+1}: {q.get("question", "")[:50]}...')
            else:
                print('   ⚠️  Aucune question récupérée (liste vide)')
        else:
            print(f'   ❌ Error: {resp.text[:200]}')
    except Exception as e:
        print(f'   💥 Exception: {e}')
    
    print("\n✅ TEST TERMINÉ")

if __name__ == '__main__':
    main()
