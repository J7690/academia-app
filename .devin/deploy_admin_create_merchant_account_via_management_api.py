#!/usr/bin/env python3
"""Déployer l'Edge Function admin-create-merchant-account via l'API Management Supabase.

Ce script suit le pattern "via_management_api" déjà utilisé dans .windsurf.
Pré-requis : un token Management API Supabase disponible via :
- variable d'environnement SUPABASE_ACCESS_TOKEN (prioritaire)
- ou supabase_permanent_access.get_management_access_token() si présent
"""

import os
import requests

from auto_supabase_import import SUPABASE_URL

try:
    from supabase_permanent_access import get_management_access_token
except Exception:
    get_management_access_token = None


def get_access_token() -> str:
    token = os.environ.get("SUPABASE_ACCESS_TOKEN", "").strip()
    if token:
        return token

    if get_management_access_token is not None:
        try:
            fallback = get_management_access_token()
            if isinstance(fallback, str) and fallback.strip():
                return fallback.strip()
        except Exception:
            pass

    return ""


def deploy_edge_function() -> bool:
    edge_function_path = "supabase/functions/admin-create-merchant-account/index.ts"
    try:
        with open(edge_function_path, "r", encoding="utf-8") as f:
            edge_function_code = f.read()
    except Exception as exc:
        print(f"[ERROR] Impossible de lire le fichier Edge Function: {exc}")
        return False

    access_token = get_access_token()
    if not access_token:
        print("[ERROR] Aucun token Management API disponible (SUPABASE_ACCESS_TOKEN non défini).")
        return False

    payload = {
        "name": "admin-create-merchant-account",
        "body": edge_function_code,
        "verify_jwt": True,
        "import_map": "{}",
    }

    headers = {
        "apikey": access_token,
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json",
    }

    project_ref = SUPABASE_URL.split("//")[1].split(".")[0]
    management_url = f"https://api.supabase.com/v1/projects/{project_ref}/edge-functions"

    print("=== Déploiement de l'Edge Function admin-create-merchant-account ===")
    print(f"Project ref: {project_ref}")
    print(f"Management URL: {management_url}")
    print(f"Taille du code: {len(edge_function_code)} caractères")

    try:
        response = requests.post(management_url, headers=headers, json=payload, timeout=60)
        print(f"POST STATUS: {response.status_code}")

        if response.status_code == 200:
            print("✅ Edge Function créée avec succès")
            return True
        elif response.status_code == 409:
            print("⚠️  La fonction existe déjà, tentative de mise à jour...")
            update_url = f"{management_url}/admin-create-merchant-account"
            response = requests.put(update_url, headers=headers, json=payload, timeout=60)
            print(f"PUT STATUS: {response.status_code}")

            if response.status_code == 200:
                print("✅ Edge Function mise à jour avec succès")
                return True

            print(f"❌ Échec de la mise à jour: {response.text[:800]}")
            return False

        print(f"❌ Échec de la création: {response.text[:800]}")
        return False

    except Exception as exc:
        print(f"[ERROR] Exception lors du déploiement: {exc}")
        return False


def verify_edge_function() -> bool:
    access_token = get_access_token()
    if not access_token:
        print("[ERROR] Aucun token Management API disponible (SUPABASE_ACCESS_TOKEN non défini).")
        return False

    headers = {
        "apikey": access_token,
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json",
    }

    project_ref = SUPABASE_URL.split("//")[1].split(".")[0]
    management_url = f"https://api.supabase.com/v1/projects/{project_ref}/edge-functions"

    print("\n=== Vérification de l'Edge Function admin-create-merchant-account ===")

    try:
        response = requests.get(
            f"{management_url}/admin-create-merchant-account",
            headers=headers,
            timeout=60,
        )
        print(f"GET STATUS: {response.status_code}")
        if response.status_code == 200:
            print("✅ Edge Function trouvée")
            return True

        print(f"❌ Edge Function non trouvée: {response.text[:800]}")
        return False

    except Exception as exc:
        print(f"[ERROR] Exception lors de la vérification: {exc}")
        return False


def main() -> int:
    print("Déploiement de l'Edge Function admin-create-merchant-account via API Management Supabase")
    print("=" * 80)

    if not deploy_edge_function():
        return 1

    if not verify_edge_function():
        return 1

    print("\n✅ Déploiement terminé avec succès!")
    print("L'Edge Function admin-create-merchant-account est maintenant active.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
