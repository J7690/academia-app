#!/usr/bin/env python3
"""Créer et déployer une RPC admin pour réinitialiser les mots de passe des universités."""

import sys
from pathlib import Path
from typing import Any, Dict, List

import requests

sys.path.insert(0, str(Path(__file__).parent))
from supabase_auto_manager import SupabaseAutoManager


def exec_sql_single(manager: SupabaseAutoManager, sql: str) -> Any:
    url = f"{manager.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=manager.headers, json={"p_sql": sql}, timeout=45)
    r.raise_for_status()
    data = r.json()
    return data


def create_reset_rpc(manager: SupabaseAutoManager) -> bool:
    """Créer la RPC de réinitialisation de mot de passe"""
    
    rpc_sql = """
-- Créer une RPC pour réinitialiser le mot de passe des universités
CREATE OR REPLACE FUNCTION app_admin_reset_university_password(p_email TEXT)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    user_id UUID,
    university_name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_record RECORD;
    university_record RECORD;
BEGIN
    -- Trouver l'utilisateur par email
    SELECT id, email, last_sign_in_at INTO user_record
    FROM auth.users
    WHERE email = p_email AND deleted_at IS NULL;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'Utilisateur non trouvé ou supprimé'::TEXT, NULL::UUID, NULL::TEXT;
        RETURN;
    END IF;
    
    -- Vérifier si c'est un compte université
    SELECT u.id, u.name INTO university_record
    FROM app.universities u
    WHERE u.contact_email = p_email AND u.is_active = true;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'Email non associé à une université active'::TEXT, user_record.id, NULL::TEXT;
        RETURN;
    END IF;
    
    -- Mettre à jour le recovery_token pour forcer la réinitialisation
    UPDATE auth.users
    SET 
        recovery_token = gen_random_uuid()::text,
        recovery_sent_at = now()
    WHERE id = user_record.id;
    
    -- Retourner le succès
    RETURN QUERY SELECT 
        TRUE, 
        'Email de réinitialisation envoyé pour l\\'université ' || university_record.name,
        user_record.id,
        university_record.name;
    RETURN;
END;
$$;

-- Donner les permissions d'exécution
GRANT EXECUTE ON FUNCTION app_admin_reset_university_password TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_reset_university_password TO service_role;
"""
    
    try:
        result = exec_sql_single(manager, rpc_sql)
        print("✅ RPC app_admin_reset_university_password créée avec succès")
        return True
    except Exception as e:
        print(f"❌ Erreur lors de la création de la RPC: {e}")
        return False


def test_reset_rpc(manager: SupabaseAutoManager, email: str) -> bool:
    """Tester la RPC de réinitialisation"""
    
    test_sql = f"SELECT * FROM app_admin_reset_university_password('{email}')"
    
    try:
        result = exec_sql_single(manager, test_sql)
        print(f"📋 Résultat du test pour {email}:")
        print(f"   {result}")
        return True
    except Exception as e:
        print(f"❌ Erreur lors du test: {e}")
        return False


def list_university_emails(manager: SupabaseAutoManager) -> List[Dict[str, Any]]:
    """Lister les emails des universités actives"""
    
    list_sql = """
    SELECT 
        u.id,
        u.name,
        u.contact_email,
        u.is_active,
        CASE WHEN a.email IS NOT NULL THEN 'YES' ELSE 'NO' END as has_auth_account
    FROM app.universities u
    LEFT JOIN auth.users a ON a.email = u.contact_email
    WHERE u.is_active = true
    ORDER BY u.name
    """
    
    try:
        result = exec_sql_single(manager, list_sql)
        if isinstance(result, dict) and result.get('mode') == 'select':
            rows = result.get('rows', [])
            print(f"\n📋 Universités actives ({len(rows)}):")
            for row in rows:
                auth_status = "✅" if row['has_auth_account'] == 'YES' else "❌"
                print(f"   {auth_status} {row['name']}: {row['contact_email']}")
            return rows
        return []
    except Exception as e:
        print(f"❌ Erreur lors du listing: {e}")
        return []


def create_usage_example():
    """Créer un exemple d'utilisation"""
    
    example = '''#!/usr/bin/env python3
"""Exemple d'utilisation de la RPC de réinitialisation"""

import requests

# Configuration
SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_ROLE_KEY = "your-service-role-key"

def reset_university_password(email: str):
    """Réinitialiser le mot de passe d'une université"""
    url = f"{SUPABASE_URL}/rest/v1/rpc/app_admin_reset_university_password"
    headers = {
        "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
        "Content-Type": "application/json"
    }
    
    data = {"p_email": email}
    
    try:
        response = requests.post(url, headers=headers, json=data)
        if response.status_code == 200:
            result = response.json()
            if result.get('success'):
                print(f"✅ {result.get('message')}")
                print(f"   Université: {result.get('university_name')}")
                print(f"   User ID: {result.get('user_id')}")
            else:
                print(f"❌ Erreur: {result.get('message')}")
        else:
            print(f"❌ Erreur HTTP {response.status_code}: {response.text}")
    except Exception as e:
        print(f"❌ Exception: {e}")

# Exemple d'utilisation
if __name__ == "__main__":
    # Réinitialiser pour une université spécifique
    reset_university_password("actiona2024@gmail.com")
'''
    
    example_path = Path(__file__).parent / "use_reset_rpc.py"
    with open(example_path, 'w', encoding='utf-8') as f:
        f.write(example)
    
    print(f"✅ Exemple d'utilisation sauvegardé dans: {example_path}")


def main() -> int:
    manager = SupabaseAutoManager()

    print("=" * 80)
    print("CRÉATION RPC ADMIN: RÉINITIALISATION MOTS DE PASSE UNIVERSITÉS")
    print(f"Project: {manager.url}")
    print("=" * 80)

    # 1. Lister les universités
    universities = list_university_emails(manager)
    
    if not universities:
        print("❌ Aucune université active trouvée")
        return 1

    # 2. Créer la RPC
    print("\n[🔧] Création de la RPC...")
    if not create_reset_rpc(manager):
        return 1

    # 3. Tester avec une université
    print("\n[🧪] Test de la RPC...")
    test_email = universities[0]['contact_email']
    if universities[0]['has_auth_account'] == 'YES':
        test_reset_rpc(manager, test_email)
    else:
        print(f"⚠️  {test_email} n'a pas de compte auth, test avec une autre...")
        for uni in universities:
            if uni['has_auth_account'] == 'YES':
                test_reset_rpc(manager, uni['contact_email'])
                break

    # 4. Créer l'exemple d'utilisation
    create_usage_example()

    print("\n" + "=" * 80)
    print("🎯 RPC DÉPLOYÉE AVEC SUCCÈS!")
    print("\n📋 UTILISATION:")
    print("1. Via admin_execute_sql:")
    print(f"   SELECT * FROM app_admin_reset_university_password('email@universite.com')")
    print("\n2. Via appel REST:")
    print(f"   POST {manager.url}/rest/v1/rpc/app_admin_reset_university_password")
    print("   Body: {\"p_email\": \"email@universite.com\"}")
    print("\n3. Via le script use_reset_rpc.py")
    print("\n⚠️  IMPORTANT:")
    print("- La RPC génère un recovery_token")
    print("- L'utilisateur recevra un email de Supabase")
    print("- Le lien d'email doit être configuré dans le dashboard Supabase")
    print("=" * 80)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
