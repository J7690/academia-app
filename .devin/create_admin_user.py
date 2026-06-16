#!/usr/bin/env python3
"""Créer un utilisateur admin pour les tests d'injection"""

import requests
import json
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    
    print("🔧 CRÉATION UTILISATEUR ADMIN POUR TESTS\n")
    
    # 1. Créer l'utilisateur dans auth.users
    try:
        url = f'{m.url}/auth/v1/admin/users'
        headers = {
            'apikey': m.headers['apikey'],
            'Authorization': f'Bearer {m.headers["apikey"]}',
            'Content-Type': 'application/json'
        }
        
        user_data = {
            'email': 'admin@academia.app',
            'password': 'admin123',
            'email_confirm': True,
            'user_metadata': {
                'role': 'admin',
                'full_name': 'Admin Test'
            }
        }
        
        resp = requests.post(url, headers=headers, json=user_data, timeout=10)
        print(f'Création user auth: {resp.status_code}')
        if resp.status_code in [200, 201]:
            user_id = resp.json().get('id')
            print(f'   ✅ User ID: {user_id}')
        elif 'already registered' in resp.text:
            print('   ⚠️  Utilisateur existe déjà')
            # Récupérer l'ID existant
            get_url = f'{m.url}/auth/v1/admin/users?email=admin@academia.app'
            get_resp = requests.get(get_url, headers=headers, timeout=10)
            if get_resp.status_code == 200:
                users = get_resp.json()
                if users and len(users) > 0:
                    user_id = users[0]['id']
                    print(f'   📝 User ID existant: {user_id}')
        else:
            print(f'   ❌ Erreur: {resp.text[:200]}')
            return
    
    except Exception as e:
        print(f'💥 Exception création user: {e}')
        return
    
    print()
    
    # 2. Créer le profil dans app.user_admin_status
    try:
        sql_create_admin = f"""
INSERT INTO app.user_admin_status (user_id, is_active, granted_at, granted_by)
VALUES ('{user_id}', true, now(), 'system')
ON CONFLICT (user_id) DO UPDATE SET 
    is_active = true,
    granted_at = now(),
    granted_by = 'system';
"""
        
        url = f'{m.url}/rest/v1/rpc/execute_ddl'
        resp = requests.post(url, headers=m.headers, json={'ddl_query': sql_create_admin}, timeout=10)
        
        print(f'Création profil admin: {resp.status_code}')
        if resp.status_code == 200:
            print('   ✅ Profil admin créé')
        else:
            print(f'   ❌ Erreur: {resp.text[:200]}')
    
    except Exception as e:
        print(f'💥 Exception création profil: {e}')
    
    print()
    
    # 3. Tester l'authentification
    try:
        auth_url = f'{m.url}/auth/v1/token?grant_type=password'
        auth_data = {
            'email': 'admin@academia.app',
            'password': 'admin123'
        }
        
        resp = requests.post(auth_url, json=auth_data, timeout=10)
        print(f'Test auth: {resp.status_code}')
        if resp.status_code == 200:
            token = resp.json()['access_token']
            print('   ✅ Authentification réussie')
            print(f'   🎫 Token: {token[:50]}...')
            
            # Sauvegarder le token pour les tests suivants
            with open('.admin_token.txt', 'w') as f:
                f.write(token)
            print('   💾 Token sauvegardé dans .admin_token.txt')
        else:
            print(f'   ❌ Erreur auth: {resp.text[:200]}')
    
    except Exception as e:
        print(f'💥 Exception auth: {e}')
    
    print("\n✅ CRÉATION ADMIN TERMINÉE")

if __name__ == '__main__':
    main()
