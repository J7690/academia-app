#!/usr/bin/env python3
"""Test RPCs for direct content injection with proper auth"""

import requests
import json
from supabase_auto_manager import SupabaseAutoManager

def get_admin_token(m):
    """Get admin auth token"""
    try:
        # Login as admin
        login_url = f'{m.url}/auth/v1/token?grant_type=password'
        login_data = {
            'email': 'admin@academia.app',
            'password': 'admin123'
        }
        resp = requests.post(login_url, json=login_data, timeout=10)
        if resp.status_code == 200:
            token = resp.json()['access_token']
            return token
    except Exception as e:
        print(f'Login failed: {e}')
    return None

def main():
    m = SupabaseAutoManager()
    
    # Get admin token
    admin_token = get_admin_token(m)
    if not admin_token:
        print('❌ Impossible de récupérer le token admin')
        return
    
    headers = {
        **m.headers,
        'Authorization': f'Bearer {admin_token}'
    }
    
    # Test des RPCs d'injection directe
    rpcs_to_test = [
        ('app_admin_prep_import_questions_json', {
            'p_questions': [
                {
                    'question': 'Quelle est la capitale du Burkina Faso?',
                    'options': ['Bobo-Dioulasso', 'Ouagadougou', 'Koudougou', 'Banfora'],
                    'correct_index': 1,
                    'explanation': 'Ouagadougou est la capitale depuis l\'indépendance.',
                    'difficulty': 2
                }
            ],
            'p_concours_type': 'ENAREF',
            'p_subject_name': 'Culture Générale'
        }),
        ('app_admin_prep_import_text_bulk', {
            'p_text': '''CONCOURS ENAREF 2023 — Épreuve de Culture Générale

PARTIE I — Questions à choix multiples

1. Le Produit Intérieur Brut (PIB) du Burkina Faso en 2022 était d'environ :
A) 10 milliards de dollars
B) 18 milliards de dollars  
C) 25 milliards de dollars
D) 35 milliards de dollars

Réponse : B''',
            'p_concours_type': 'ENAREF',
            'p_subject_name': 'Culture Générale'
        }),
        ('app_td_admin_import_text_bulk', {
            'p_text': '''UNIVERSITÉ JOSEPH KI-ZERBO — Licence 2 Mathématiques
TD n°3 — Analyse : Suites numériques

Exercice 1 :
Soit la suite (u_n) définie par u_0 = 1 et u_{n+1} = (2u_n + 3) / (u_n + 2)
a) Montrer que la suite est bornée
b) Étudier la monotonie''',
            'p_subject': 'Mathématiques',
            'p_study_year': 'Licence 2',
            'p_doc_type': 'exercice'
        })
    ]
    
    print("🔍 Test des RPCs d'injection directe de contenu (avec auth)\n")
    
    for rpc_name, params in rpcs_to_test:
        try:
            url = f'{m.url}/rest/v1/rpc/{rpc_name}'
            resp = requests.post(url, headers=headers, json=params, timeout=10)
            print(f'📡 {rpc_name}: {resp.status_code}')
            
            if resp.status_code == 200:
                try:
                    result = resp.json()
                    success = result.get('success', False)
                    print(f'  ✅ Success: {success}')
                    if 'questions_inserted' in result:
                        print(f'  📊 Questions insérées: {result["questions_inserted"]}')
                    if 'document_id' in result:
                        print(f'  📄 Document ID: {result["document_id"]}')
                    if 'chunks_created' in result:
                        print(f'  🧩 Chunks créés: {result["chunks_created"]}')
                except json.JSONDecodeError:
                    print(f'  ✅ Success (non-JSON): {resp.text[:100]}')
            else:
                print(f'  ❌ Error: {resp.text[:200]}')
                
        except Exception as e:
            print(f'💥 {rpc_name}: Exception - {e}')
        print()
    
    print("✅ Tests terminés")

if __name__ == '__main__':
    main()
