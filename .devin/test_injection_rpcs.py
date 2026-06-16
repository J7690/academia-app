#!/usr/bin/env python3
"""Test RPCs for direct content injection"""

import requests
import json
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    
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

Durée : 3 heures — Coefficient : 3

PARTIE I — Questions à choix multiples (40 points)

1. Le Produit Intérieur Brut (PIB) du Burkina Faso en 2022 était d'environ :
A) 10 milliards de dollars
B) 18 milliards de dollars  
C) 25 milliards de dollars
D) 35 milliards de dollars

Réponse : B

2. La monnaie utilisée au Burkina Faso est :
A) Le Naira
B) Le Cedi
C) Le Franc CFA
D) Le Shilling

Réponse : C''',
            'p_concours_type': 'ENAREF',
            'p_subject_name': 'Culture Générale'
        }),
        ('app_td_admin_import_questions_json', {
            'p_questions': [
                {
                    'question': 'Calculer la dérivée de f(x) = x² + 3x - 5',
                    'options': ['2x + 3', 'x² + 3', '2x - 5', '3x + 2'],
                    'correct_index': 0,
                    'explanation': 'f\'(x) = 2x + 3 (dérivée terme à terme)',
                    'difficulty': 2,
                    'subject': 'Mathématiques'
                }
            ],
            'p_subject': 'Mathématiques',
            'p_study_year': 'Licence 2'
        }),
        ('app_td_admin_import_text_bulk', {
            'p_text': '''UNIVERSITÉ JOSEPH KI-ZERBO — Licence 2 Mathématiques
TD n°3 — Analyse : Suites numériques

Exercice 1 :
Soit la suite (u_n) définie par u_0 = 1 et u_{n+1} = (2u_n + 3) / (u_n + 2)
a) Montrer que la suite est bornée
b) Étudier la monotonie
c) En déduire que la suite converge et déterminer sa limite

Corrigé :
Exercice 1 :
a) Par récurrence : si 0 < u_n < 3, alors...
b) La suite est croissante car...
c) La limite est √3''',
            'p_subject': 'Mathématiques',
            'p_study_year': 'Licence 2',
            'p_doc_type': 'exercice'
        })
    ]
    
    print("🔍 Test des RPCs d'injection directe de contenu\n")
    
    for rpc_name, params in rpcs_to_test:
        try:
            url = f'{m.url}/rest/v1/rpc/{rpc_name}'
            resp = requests.post(url, headers=m.headers, json=params, timeout=10)
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
