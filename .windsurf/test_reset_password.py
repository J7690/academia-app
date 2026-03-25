#!/usr/bin/env python3
"""Test de réinitialisation de mot de passe pour université.

Script de démonstration pour tester la réinitialisation de mot de passe.
"""

import sys
import requests
from pathlib import Path

# Configuration
SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"

def reset_password_via_auth_api(email: str, api_key: str) -> bool:
    """Méthode recommandée: API Auth Supabase"""
    url = f"{SUPABASE_URL}/auth/v1/recover"
    headers = {
        "apikey": api_key,
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

def main():
    if len(sys.argv) != 3:
        print("Usage: python test_reset_password.py <email> <api_key>")
        print("Exemple: python test_reset_password.py actiona2024@gmail.com your-anon-key")
        sys.exit(1)
    
    email = sys.argv[1]
    api_key = sys.argv[2]
    
    print(f"Tentative de réinitialisation pour: {email}")
    print(f"URL: {SUPABASE_URL}")
    
    success = reset_password_via_auth_api(email, api_key)
    
    if success:
        print("\n🎯 ÉTAPES SUIVANTES:")
        print("1. L'utilisateur recevra un email de réinitialisation")
        print("2. Il devra cliquer sur le lien dans l'email")
        print("3. Il pourra définir son nouveau mot de passe")
        print("4. Le nouveau mot de passe sera valide immédiatement")
    else:
        print("\n⚠️  Vérifier:")
        print("- L'API key est valide")
        print("- L'email existe dans auth.users")
        print("- Les templates d'emails sont configurés dans Supabase")

if __name__ == "__main__":
    main()
