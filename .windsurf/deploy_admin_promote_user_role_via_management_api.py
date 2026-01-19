#!/usr/bin/env python3
"""Déployer l'Edge Function admin-promote-user-role via l'API Management Supabase.

Inspiré de deploy_bobodo_chat_via_management_api.py, mais ciblé sur la fonction
admin-promote-user-role.
"""

import json
import requests
from auto_supabase_import import SUPABASE_URL, SUPABASE_SERVICE_KEY


def deploy_edge_function() -> bool:
    """Déployer l'Edge Function via l'API Management Supabase."""

    # Lire le code de l'Edge Function
    edge_function_path = "../supabase/functions/admin-promote-user-role/index.ts"
    try:
        with open(edge_function_path, "r", encoding="utf-8") as f:
            edge_function_code = f.read()
    except Exception as exc:
        print(f"[ERROR] Impossible de lire le fichier Edge Function: {exc}")
        return False

    # Préparer le payload pour l'API Management
    payload = {
        "name": "admin-promote-user-role",
        "body": edge_function_code,
        "verify_jwt": True,
        "import_map": "{}",
    }

    # Headers pour l'API Management
    headers = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Content-Type": "application/json",
    }

    # URL pour l'API Management (différente de l'API REST)
    project_ref = SUPABASE_URL.split("//")[1].split(".")[0]
    management_url = f"https://api.supabase.com/v1/projects/{project_ref}/edge-functions"

    print("=== Déploiement de l'Edge Function admin-promote-user-role ===")
    print(f"Project ref: {project_ref}")
    print(f"Management URL: {management_url}")
    print(f"Taille du code: {len(edge_function_code)} caractères")

    try:
        # Essayer de créer la fonction
        response = requests.post(management_url, headers=headers, json=payload, timeout=30)
        print(f"POST STATUS: {response.status_code}")

        if response.status_code == 200:
            print("✅ Edge Function créée avec succès")
            return True
        elif response.status_code == 409:
            print("⚠️  La fonction existe déjà, tentative de mise à jour...")
            # Mettre à jour la fonction existante
            update_url = f"{management_url}/admin-promote-user-role"
            response = requests.put(update_url, headers=headers, json=payload, timeout=30)
            print(f"PUT STATUS: {response.status_code}")

            if response.status_code == 200:
                print("✅ Edge Function mise à jour avec succès")
                return True
            else:
                print(f"❌ Échec de la mise à jour: {response.text}")
                return False
        else:
            print(f"❌ Échec de la création: {response.text}")
            return False

    except Exception as exc:
        print(f"[ERROR] Exception lors du déploiement: {exc}")
        return False


def verify_edge_function() -> bool:
    """Vérifier que l'Edge Function est bien déployée."""

    project_ref = SUPABASE_URL.split("//")[1].split(".")[0]
    management_url = f"https://api.supabase.com/v1/projects/{project_ref}/edge-functions"

    headers = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Content-Type": "application/json",
    }

    print("\n=== Vérification de l'Edge Function admin-promote-user-role ===")

    try:
        response = requests.get(f"{management_url}/admin-promote-user-role", headers=headers, timeout=30)
        print(f"GET STATUS: {response.status_code}")

        if response.status_code == 200:
            data = response.json()
            print("✅ Edge Function trouvée:")
            print(f"  - Nom: {data.get('name')}")
            print(f"  - Status: {data.get('status')}")
            print(f"  - Créée le: {data.get('created_at')}")
            print(f"  - Modifiée le: {data.get('updated_at')}")
            return True
        else:
            print(f"❌ Edge Function non trouvée: {response.text}")
            return False

    except Exception as exc:
        print(f"[ERROR] Exception lors de la vérification: {exc}")
        return False


def main() -> int:
    print("Déploiement de l'Edge Function admin-promote-user-role via API Management Supabase")
    print("=" * 80)

    # Déployer la fonction
    if not deploy_edge_function():
        return 1

    # Vérifier le déploiement
    if not verify_edge_function():
        return 1

    print("\n✅ Déploiement terminé avec succès!")
    print("L'Edge Function admin-promote-user-role est maintenant active (côté Supabase).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
