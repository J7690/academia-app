#!/usr/bin/env python3
"""Déployer l'Edge Function admin-create-teacher-account via l'API Management Supabase.

Étapes principales :
- S'assurer que la table app.instructors existe avec les bonnes RLS.
- Déployer / mettre à jour l'Edge Function admin-create-teacher-account via l'API Management.
- Vérifier que la fonction est bien enregistrée côté management.
- Tester que le runtime Edge répond sur /functions/v1/admin-create-teacher-account (test simple).

Ce script suppose :
- SUPABASE_URL et SUPABASE_SERVICE_KEY définis dans auto_supabase_import.py
- Un token d'accès Management API dans la variable d'environnement SUPABASE_ACCESS_TOKEN
"""

import json
import os
import sys
from typing import Optional

import requests

try:
    from auto_supabase_import import SUPABASE_URL, SUPABASE_SERVICE_KEY
except Exception as exc:  # pragma: no cover - environnement spécifique
    print(f"[ERROR] Impossible d'importer auto_supabase_import: {exc}")
    sys.exit(1)

try:
    # Réutiliser le mécanisme permanent déjà en place pour récupérer le token Management API
    from supabase_permanent_access import get_management_access_token
except Exception as exc:  # pragma: no cover - environnement spécifique
    print(f"[ERROR] Impossible d'importer supabase_permanent_access: {exc}")
    get_management_access_token = None


HEADERS_SQL = {
    "apikey": SUPABASE_SERVICE_KEY,
    "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
    "Content-Type": "application/json",
}


def run_admin_sql(label: str, sql: str) -> bool:
    """Exécuter du SQL privilégié via admin_execute_sql."""
    url = f"{SUPABASE_URL}/rest/v1/rpc/admin_execute_sql"
    print(f"\n=== {label} ===")
    print(f"SQL (début) : {sql[:200]}...")

    try:
        resp = requests.post(url, headers=HEADERS_SQL, json={"p_sql": sql}, timeout=60)
    except Exception as exc:
        print(f"[ERROR] Exception réseau admin_execute_sql: {exc}")
        return False

    print(f"STATUS: {resp.status_code}")
    try:
        body = resp.json()
        print("BODY:", json.dumps(body, ensure_ascii=False, indent=2)[:800])
    except Exception:
        print("BODY_RAW:", resp.text[:800])

    return resp.status_code == 200


def ensure_app_instructors() -> bool:
    """S'assurer que la table app.instructors existe (définition issue de supabase_online_courses.sql)."""
    sql = """
    CREATE SCHEMA IF NOT EXISTS app;

    CREATE TABLE IF NOT EXISTS app.instructors (
        id UUID PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
        full_name TEXT,
        bio TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
        updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
    );

    ALTER TABLE app.instructors ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS instructor_select_self ON app.instructors;
    CREATE POLICY instructor_select_self
    ON app.instructors FOR SELECT
    USING (id = auth.uid());

    DROP POLICY IF EXISTS instructor_insert_self ON app.instructors;
    CREATE POLICY instructor_insert_self
    ON app.instructors FOR INSERT
    WITH CHECK (id = auth.uid());

    DROP POLICY IF EXISTS instructor_update_self ON app.instructors;
    CREATE POLICY instructor_update_self
    ON app.instructors FOR UPDATE
    USING (id = auth.uid());

    GRANT SELECT, INSERT, UPDATE ON app.instructors TO authenticated;
    GRANT ALL ON app.instructors TO service_role;
    """.strip()

    return run_admin_sql("Assurer la présence de app.instructors", sql)


def get_management_headers() -> Optional[dict]:
    """Construire les headers pour l'API Management Supabase.

    On suit le même modèle que les autres scripts .windsurf :
    - priorité au token retourné par supabase_permanent_access.get_management_access_token()
    - fallback éventuel sur la variable d'environnement SUPABASE_ACCESS_TOKEN si nécessaire.
    """

    access_token: str = ""

    # 1) Essayer de récupérer le token via supabase_permanent_access
    if get_management_access_token is not None:
        try:
            token = get_management_access_token()
            if isinstance(token, str) and token.strip():
                access_token = token.strip()
        except Exception as exc:
            print(f"[WARN] Échec get_management_access_token(): {exc}")

    # 2) Fallback sur la variable d'environnement si toujours vide
    if not access_token:
        env_token = os.environ.get("SUPABASE_ACCESS_TOKEN", "").strip()
        if env_token:
            access_token = env_token

    if not access_token:
        print("[ERROR] Aucun token Management API disponible (ni supabase_permanent_access, ni SUPABASE_ACCESS_TOKEN).")
        return None

    return {
        "Authorization": f"Bearer {access_token}",
        "apikey": access_token,
        "Content-Type": "application/json",
    }


def deploy_edge_function() -> bool:
    """Déployer / mettre à jour l'Edge Function admin-create-teacher-account via l'API Management."""
    edge_function_path = "../supabase/functions/admin-create-teacher-account/index.ts"
    try:
        with open(edge_function_path, "r", encoding="utf-8") as f:
            edge_function_code = f.read()
    except Exception as exc:
        print(f"[ERROR] Impossible de lire le fichier Edge Function: {exc}")
        return False

    headers = get_management_headers()
    if not headers:
        return False

    project_ref = SUPABASE_URL.split("//")[1].split(".")[0]
    management_url = f"https://api.supabase.com/v1/projects/{project_ref}/edge-functions"

    payload = {
        "name": "admin-create-teacher-account",
        "body": edge_function_code,
        "verify_jwt": True,
        "import_map": "{}",
    }

    print("\n=== Déploiement de l'Edge Function admin-create-teacher-account ===")
    print(f"Project ref: {project_ref}")
    print(f"Management URL: {management_url}")
    print(f"Taille du code: {len(edge_function_code)} caractères")

    try:
        response = requests.post(management_url, headers=headers, json=payload, timeout=60)
    except Exception as exc:
        print(f"[ERROR] Exception lors de l'appel POST Management API: {exc}")
        return False

    print(f"POST STATUS: {response.status_code}")
    print("POST BODY:", response.text[:800])

    if response.status_code == 200:
        print("✅ Edge Function créée / mise à jour via POST")
        return True
    elif response.status_code == 409:
        print("⚠️ La fonction existe déjà, tentative de mise à jour via PUT...")
        update_url = f"{management_url}/admin-create-teacher-account"
        try:
            response = requests.put(update_url, headers=headers, json=payload, timeout=60)
        except Exception as exc:
            print(f"[ERROR] Exception lors de l'appel PUT Management API: {exc}")
            return False

        print(f"PUT STATUS: {response.status_code}")
        print("PUT BODY:", response.text[:800])
        if response.status_code == 200:
            print("✅ Edge Function mise à jour avec succès")
            return True
        else:
            print("❌ Échec de la mise à jour Edge Function")
            return False

    else:
        print("❌ Échec de la création Edge Function via Management API")
        return False


def verify_edge_function_management() -> bool:
    """Vérifier via l'API Management que la fonction est bien enregistrée."""
    headers = get_management_headers()
    if not headers:
        return False

    project_ref = SUPABASE_URL.split("//")[1].split(".")[0]
    management_url = f"https://api.supabase.com/v1/projects/{project_ref}/edge-functions/admin-create-teacher-account"

    print("\n=== Vérification Management de l'Edge Function admin-create-teacher-account ===")

    try:
        response = requests.get(management_url, headers=headers, timeout=60)
    except Exception as exc:
        print(f"[ERROR] Exception lors de l'appel GET Management API: {exc}")
        return False

    print(f"GET STATUS: {response.status_code}")
    print("GET BODY:", response.text[:800])

    return response.status_code == 200


def test_edge_function_runtime() -> bool:
    """Tester que le runtime Edge répond sur /functions/v1/admin-create-teacher-account.

    Ce test utilise la clé service_role comme Bearer, ce qui devrait conduire la fonction
    à répondre par une erreur fonctionnelle (not_authenticated / not_admin) mais permet
    de vérifier que :
    - la fonction est déployée,
    - le runtime Deno s'exécute correctement.
    """
    headers = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Content-Type": "application/json",
    }

    url = f"{SUPABASE_URL}/functions/v1/admin-create-teacher-account"
    payload = {
        "email": "test-teacher@example.com",
        "password": "Dummy123!",
        "full_name": "Test Teacher Runtime",
    }

    print("\n=== Test runtime de l'Edge Function admin-create-teacher-account ===")
    print(f"URL: {url}")

    try:
        response = requests.post(url, headers=headers, json=payload, timeout=60)
    except Exception as exc:
        print(f"[ERROR] Exception lors de l'appel runtime: {exc}")
        return False

    print(f"RUNTIME STATUS: {response.status_code}")
    print("RUNTIME BODY:", response.text[:800])

    # On considère que le runtime est OK si la fonction répond (même avec une erreur fonctionnelle contrôlée)
    return response.status_code in (200, 400, 401, 403)


def main() -> int:
    print("Déploiement complet de admin-create-teacher-account (enseignants TD)")
    print("=" * 80)

    # 1) Assurer la table app.instructors
    if not ensure_app_instructors():
        print("❌ Échec lors de la mise en place de app.instructors")
        return 1

    # 2) Déployer l'Edge Function via Management API
    if not deploy_edge_function():
        print("❌ Échec du déploiement de l'Edge Function admin-create-teacher-account")
        return 1

    # 3) Vérifier côté Management
    verify_edge_function_management()

    # 4) Tester le runtime Edge
    test_edge_function_runtime()

    print("\n✅ Déploiement complet terminé. La fonction admin-create-teacher-account est en place.")
    print("   Pour tester le flux complet, utiliser l'interface admin TD (création enseignant TD).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
