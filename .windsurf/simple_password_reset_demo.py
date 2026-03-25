#!/usr/bin/env python3
"""Démonstration simple de réinitialisation de mot de passe via API Supabase Auth.

Ce script montre la méthode la plus simple pour réinitialiser les mots de passe.
"""

import sys
import requests
from pathlib import Path

# Configuration
SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"

def reset_password_for_email(email: str, api_key: str) -> dict:
    """
    Réinitialiser le mot de passe pour un email donné.
    
    Args:
        email: L'email de l'université
        api_key: La clé API Supabase (anon ou service_role)
    
    Returns:
        dict: Résultat de l'opération
    """
    url = f"{SUPABASE_URL}/auth/v1/recover"
    headers = {
        "apikey": api_key,
        "Content-Type": "application/json"
    }
    
    data = {"email": email}
    
    try:
        response = requests.post(url, headers=headers, json=data)
        
        if response.status_code == 200:
            return {
                "success": True,
                "message": f"Email de réinitialisation envoyé à {email}",
                "status": response.status_code
            }
        else:
            return {
                "success": False,
                "message": f"Erreur {response.status_code}: {response.text}",
                "status": response.status_code
            }
    except Exception as e:
        return {
            "success": False,
            "message": f"Exception: {str(e)}",
            "status": 0
        }

def list_university_emails():
    """Lister les emails des universités actives"""
    emails = [
        "actiona2024@gmail.com",      # Action (active)
        "coserfaburkina@gmail.com",  # COSERFA (active)
        "jeremieayivor835@gmail.com", # IIM (active)
        "istapem@istapem.com",       # ISTAPEM (active)
        "supmgtburkina@supmanagement.bf", # Sup'Management (active)
        "info.service@umefburkina.com"    # UMET-BURKINA (active)
    ]
    
    print("📋 Emails des universités actives:")
    for i, email in enumerate(emails, 1):
        print(f"   {i}. {email}")
    
    return emails

def main():
    print("=" * 80)
    print("DÉMONSTRATION RÉINITIALISATION MOT DE PASSE UNIVERSITÉS")
    print(f"URL: {SUPABASE_URL}")
    print("=" * 80)
    
    # 1. Lister les emails disponibles
    emails = list_university_emails()
    
    # 2. Demander à l'utilisateur de choisir
    print("\n" + "=" * 40)
    print("CHOIX DE L'UNIVERSITÉ:")
    print("=" * 40)
    
    try:
        choice = input("Entrez le numéro de l'université (1-6): ").strip()
        
        if not choice.isdigit() or not (1 <= int(choice) <= len(emails)):
            print("❌ Choix invalide")
            return 1
        
        email = emails[int(choice) - 1]
        print(f"\n📧 Email sélectionné: {email}")
        
        # 3. Demander la clé API
        print("\n" + "=" * 40)
        print("CLÉ API SUPABASE:")
        print("=" * 40)
        print("Options:")
        print("1. Clé Anonyme (anon)")
        print("2. Clé Service Role (service_role)")
        
        key_choice = input("Choisissez (1 ou 2): ").strip()
        
        if key_choice == "1":
            print("\n⚠️  Utilisez votre clé ANONYME depuis Supabase Dashboard > Settings > API")
        else:
            print("\n⚠️  Utilisez votre clé SERVICE_ROLE depuis Supabase Dashboard > Settings > API")
        
        api_key = input("Collez la clé API: ").strip()
        
        if not api_key:
            print("❌ Clé API requise")
            return 1
        
        # 4. Exécuter la réinitialisation
        print(f"\n🔄 Envoi de l'email de réinitialisation à {email}...")
        result = reset_password_for_email(email, api_key)
        
        print("\n" + "=" * 40)
        print("RÉSULTAT:")
        print("=" * 40)
        
        if result["success"]:
            print(f"✅ {result['message']}")
            print("\n🎯 PROCHAINES ÉTAPES:")
            print("1. L'utilisateur recevra un email de Supabase")
            print("2. Il devra cliquer sur le lien dans l'email")
            print("3. Il pourra définir son nouveau mot de passe")
            print("4. Le mot de passe sera mis à jour immédiatement")
        else:
            print(f"❌ {result['message']}")
            print("\n🔍 DÉBOGAGE:")
            print("- Vérifiez que la clé API est correcte")
            print("- Vérifiez que l'email existe dans auth.users")
            print("- Vérifiez les templates d'emails dans Supabase Dashboard")
            print("- Vérifiez les paramètres de redirection dans Auth Settings")
        
    except KeyboardInterrupt:
        print("\n\n❌ Opération annulée")
        return 1
    except Exception as e:
        print(f"\n❌ Erreur: {e}")
        return 1
    
    print("\n" + "=" * 80)
    print("📚 DOCUMENTATION SUPABASE:")
    print("https://supabase.com/docs/guides/auth/auth-helpers#reset-password")
    print("=" * 80)
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
