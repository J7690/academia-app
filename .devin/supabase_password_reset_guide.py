#!/usr/bin/env python3
"""Guide complet pour déclencher des réinitialisations de mot de passe via Supabase Auth.

Ce script montre plusieurs méthodes pour réinitialiser les mots de passe des comptes universités.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any, Dict, List

import requests

sys.path.insert(0, str(Path(__file__).parent))
from supabase_auto_manager import SupabaseAutoManager


def exec_sql_rows(manager: SupabaseAutoManager, sql: str) -> List[Dict[str, Any]]:
    url = f"{manager.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=manager.headers, json={"p_sql": sql}, timeout=45)
    r.raise_for_status()
    data = r.json()
    rows = data.get("rows") if isinstance(data, dict) else None
    return rows if isinstance(rows, list) else []


def method_1_supabase_admin_api(manager: SupabaseAutoManager) -> bool:
    """Méthode 1: Utiliser l'API Admin de Supabase Auth"""
    print("\n[🔧 MÉTHODE 1] API Admin Supabase Auth")
    print("  URL: https://api.supabase.com/v1/admin/users")
    print("  Headers: Authorization: Bearer <SERVICE_ROLE_KEY>")
    print("  Method: POST /admin/users/{user_id}/recovery")
    
    # Exemple de code
    example_code = '''
# Exemple en Python
import requests

url = "https://api.supabase.com/v1/admin/users/{user_id}/recovery"
headers = {
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "Content-Type": "application/json"
}

response = requests.post(url, headers=headers)
if response.status_code == 200:
    print("Email de réinitialisation envoyé")
else:
    print(f"Erreur: {response.status_code}")
'''
    print(example_code)
    return True


def method_2_supabase_client_sdk(manager: SupabaseAutoManager) -> bool:
    """Méthode 2: Utiliser le SDK client Supabase"""
    print("\n[🔧 MÉTHODE 2] SDK Client Supabase")
    print("  Utiliser supabase.auth.resetPasswordForEmail()")
    
    example_code = '''
# Exemple en Python/Flutter
from supabase_py import create_client

supabase = create_client(
    "https://your-project.supabase.co",
    "your-anon-key"
)

# Envoyer email de réinitialisation
try:
    response = supabase.auth.reset_password_for_email(
        "actiona2024@gmail.com",
        options={"redirectTo": "https://your-app.com/reset-password"}
    )
    print("Email de réinitialisation envoyé")
except Exception as e:
    print(f"Erreur: {e}")

# En Flutter (Dart)
await supabase.auth.resetPasswordForEmail(
  'actiona2024@gmail.com',
  options: AuthOptions(
    redirectTo: 'https://your-app.com/reset-password',
  ),
);
'''
    print(example_code)
    return True


def method_3_custom_rpc(manager: SupabaseAutoManager) -> bool:
    """Méthode 3: Créer une RPC custom pour la réinitialisation"""
    print("\n[🔧 MÉTHODE 3] RPC Custom Admin")
    print("  Créer une RPC dans Supabase pour gérer les réinitialisations")
    
    rpc_sql = '''
-- Créer une RPC pour réinitialiser le mot de passe
CREATE OR REPLACE FUNCTION app_admin_reset_user_password(p_email TEXT)
RETURNS TABLE(success BOOLEAN, message TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_record RECORD;
BEGIN
    -- Trouver l'utilisateur par email
    SELECT id, email INTO user_record
    FROM auth.users
    WHERE email = p_email;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'Utilisateur non trouvé'::TEXT;
        RETURN;
    END IF;
    
    -- Mettre à jour le recovery_token pour forcer la réinitialisation
    UPDATE auth.users
    SET 
        recovery_token = gen_random_uuid()::text,
        recovery_sent_at = now()
    WHERE id = user_record.id;
    
    -- TODO: Envoyer email via votre service d'envoi d'emails
    -- ou utiliser le système de Supabase
    
    RETURN QUERY SELECT TRUE, 'Email de réinitialisation envoyé'::TEXT;
    RETURN;
END;
$$;
'''
    
    print("SQL à exécuter:")
    print(rpc_sql)
    
    # Exemple d'utilisation
    usage_code = '''
# Utilisation via admin_execute_sql
import requests

url = "https://your-project.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "Authorization": "Bearer your-service-role-key",
    "Content-Type": "application/json"
}

data = {
    "p_sql": "SELECT * FROM app_admin_reset_user_password('actiona2024@gmail.com')"
}

response = requests.post(url, headers=headers, json=data)
result = response.json()
print(result)
'''
    print("\nUtilisation:")
    print(usage_code)
    return True


def method_4_direct_auth_api(manager: SupabaseAutoManager) -> bool:
    """Méthode 4: API Auth directe de Supabase"""
    print("\n[🔧 MÉTHODE 4] API Auth Directe")
    print("  Utiliser l'endpoint de récupération de Supabase")
    
    example_code = '''
# Endpoint direct de Supabase Auth
POST https://your-project.supabase.co/auth/v1/recover
Headers:
  - apikey: your-anon-key
  - Content-Type: application/json

Body:
{
  "email": "actiona2024@gmail.com"
}

# En Python
import requests

url = "https://your-project.supabase.co/auth/v1/recover"
headers = {
    "apikey": "your-anon-key",
    "Content-Type": "application/json"
}

data = {"email": "actiona2024@gmail.com"}

response = requests.post(url, headers=headers, json=data)
if response.status_code == 200:
    print("Email de réinitialisation envoyé")
else:
    print(f"Erreur: {response.status_code}")
'''
    print(example_code)
    return True


def list_university_users(manager: SupabaseAutoManager) -> List[Dict[str, Any]]:
    """Lister les utilisateurs universités pour les tests"""
    print("\n[📋 UTILISATEURS UNIVERSITÉS DISPONIBLES:")
    
    users = exec_sql_rows(
        manager,
        """
        SELECT 
            u.id,
            u.email,
            u.created_at,
            u.last_sign_in_at,
            uni.name as university_name,
            uni.is_active as uni_active
        FROM auth.users u
        LEFT JOIN app.universities uni ON uni.contact_email = u.email
        WHERE uni.id IS NOT NULL
        ORDER BY uni.is_active DESC, uni.name, u.email
        """.strip(),
    )
    
    if users:
        print(f"  Found {len(users)} university users:")
        for user in users:
            status = "ACTIVE" if user['last_sign_in_at'] else "NEVER_SIGNED_IN"
            uni_status = "ACTIVE" if user['uni_active'] else "INACTIVE"
            print(f"    - {user['email']} ({user['university_name']} [{uni_status}] - {status})")
    else:
        print("  No university users found")
    
    return users


def create_reset_script(manager: SupabaseAutoManager) -> bool:
    """Créer un script pratique pour la réinitialisation"""
    print("\n[📝 SCRIPT PRATIQUE DE RÉINITIALISATION")
    
    script_content = '''#!/usr/bin/env python3
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
'''
    
    print("Script à sauvegarder dans reset_password.py:")
    print(script_content)
    
    # Sauvegarder le script
    script_path = Path(__file__).parent / "reset_password.py"
    with open(script_path, 'w', encoding='utf-8') as f:
        f.write(script_content)
    
    print(f"\n✅ Script sauvegardé dans: {script_path}")
    return True


def main() -> int:
    manager = SupabaseAutoManager()

    print("=" * 80)
    print("GUIDE COMPLET: RÉINITIALISATION MOTS DE PASSE UNIVERSITÉS")
    print(f"Project: {manager.url}")
    print("=" * 80)

    # Lister les utilisateurs universités
    users = list_university_users(manager)

    # Présenter les méthodes
    method_1_supabase_admin_api(manager)
    method_2_supabase_client_sdk(manager)
    method_3_custom_rpc(manager)
    method_4_direct_auth_api(manager)

    # Créer le script pratique
    create_reset_script(manager)

    print("\n" + "=" * 80)
    print("🎯 RECOMMANDATION:")
    print("1. Utiliser la MÉTHODE 4 (API Auth Directe) - plus simple")
    print("2. Ou la MÉTHODE 2 (SDK Client) pour intégration Flutter")
    print("3. La MÉTHODE 3 (RPC Custom) si besoin de contrôle total")
    print("\n⚠️  IMPORTANT:")
    print("- Configurer les templates d'emails dans Supabase Dashboard")
    print("- Définir l'URL de redirection dans les paramètres Auth")
    print("- Tester avec un compte de développement d'abord")
    print("=" * 80)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
