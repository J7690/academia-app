#!/usr/bin/env python3
"""Script pratique pour réinitialiser les mots de passe des universités"""

import requests
import sys

# Configuration
SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_ROLE_KEY = "your-service-role-key"  # À remplacer

def reset_password_via_auth_api(email: str) -> bool:
    """Méthode recommandée: API Auth Supabase"""
    url = f"{SUPABASE_URL}/auth/v1/recover"
    headers = {
        "apikey": SERVICE_ROLE_KEY,
        "Content-Type": "application/json"
    }
    
    data = {"email": email}
    
    try:
        response = requests.post(url, headers=headers, json=data)
        if response.status_code == 200:
            print(f"✅ Email de réinitialisation envoyé à {email}")
            return True
        else:
            print(f"❌ Erreur {response.status_code}: {response.text}")
            return False
    except Exception as e:
        print(f"❌ Exception: {e}")
        return False

def reset_password_via_admin_rpc(email: str) -> bool:
    """Alternative: RPC admin custom"""
    url = f"{SUPABASE_URL}/rest/v1/rpc/admin_execute_sql"
    headers = {
        "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
        "Content-Type": "application/json"
    }
    
    sql = f"SELECT * FROM app_admin_reset_user_password('{email}')"
    data = {"p_sql": sql}
    
    try:
        response = requests.post(url, headers=headers, json=data)
        result = response.json()
        print(f"Résultat: {result}")
        return True
    except Exception as e:
        print(f"❌ Exception: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python reset_password.py <email>")
        print("Exemple: python reset_password.py actiona2024@gmail.com")
        sys.exit(1)
    
    email = sys.argv[1]
    print(f"Tentative de réinitialisation pour: {email}")
    
    # Méthode 1: API Auth (recommandée)
    if reset_password_via_auth_api(email):
        print("✅ Réinitialisation réussie via API Auth")
    else:
        print("⚠️  Tentative via RPC admin...")
        reset_password_via_admin_rpc(email)
