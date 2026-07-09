"""
MISSION D.15.1 - Test fonctionnel du flux Smart Whiteboard

1. Crée un utilisateur de test (ou réutilise un existant)
2. Authentifie l'utilisateur
3. Appelle whiteboard_create_project
4. Appelle l'Edge Function whiteboard-generate-storyboard
5. Affiche le résultat et le prochain point de rupture
"""

import requests
import json
import uuid
import time

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMwNTY1NjAsImV4cCI6MjA3ODYzMjU2MH0.9r5x1E0h2B6g4y7z8A1b2C3d4e5F6g7H8i9J0k1L2m3"

HEADERS_SERVICE = {
    "apikey": ANON_KEY,
    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
    "Content-Type": "application/json",
}


def create_test_user(email, password):
    """Crée un utilisateur de test via l'API admin."""
    url = f"{SUPABASE_URL}/auth/v1/admin/users"
    payload = {
        "email": email,
        "password": password,
        "email_confirm": True,
    }
    resp = requests.post(url, headers=HEADERS_SERVICE, json=payload, timeout=30)
    try:
        return resp.json()
    except Exception:
        return {"status": resp.status_code, "text": resp.text}


def sign_in(email, password):
    """Authentifie l'utilisateur et retourne le JWT."""
    url = f"{SUPABASE_URL}/auth/v1/token?grant_type=password"
    headers = {
        "apikey": ANON_KEY,
        "Content-Type": "application/json",
    }
    payload = {
        "email": email,
        "password": password,
    }
    resp = requests.post(url, headers=headers, json=payload, timeout=30)
    try:
        data = resp.json()
        return data.get("access_token"), data
    except Exception:
        return None, {"status": resp.status_code, "text": resp.text}


def call_rpc(jwt, rpc_name, params):
    """Appelle une RPC Supabase."""
    url = f"{SUPABASE_URL}/rest/v1/rpc/{rpc_name}"
    headers = {
        "apikey": ANON_KEY,
        "Authorization": f"Bearer {jwt}",
        "Content-Type": "application/json",
    }
    resp = requests.post(url, headers=headers, json=params, timeout=30)
    try:
        return resp.json(), resp.status_code
    except Exception:
        return resp.text, resp.status_code


def call_edge_function(jwt, body):
    """Appelle l'Edge Function whiteboard-generate-storyboard."""
    url = f"{SUPABASE_URL}/functions/v1/whiteboard-generate-storyboard"
    headers = {
        "apikey": ANON_KEY,
        "Authorization": f"Bearer {jwt}",
        "Content-Type": "application/json",
    }
    resp = requests.post(url, headers=headers, json=body, timeout=120)
    try:
        return resp.json(), resp.status_code
    except Exception:
        return resp.text, resp.status_code


def main():
    print("=" * 80)
    print("MISSION D.15.1 - TEST FONCTIONNEL DU FLUX SMART WHITEBOARD")
    print("=" * 80)

    email = f"test_whiteboard_{uuid.uuid4().hex[:8]}@example.com"
    password = "TestPassword123!"

    print(f"\n1. Création de l'utilisateur de test: {email}")
    user = create_test_user(email, password)
    print(json.dumps(user, indent=2, ensure_ascii=False)[:500])

    print("\n2. Authentification de l'utilisateur...")
    jwt, auth_data = sign_in(email, password)
    if not jwt:
        print("❌ Échec de l'authentification:")
        print(json.dumps(auth_data, indent=2, ensure_ascii=False))
        print("=" * 80)
        return
    print(f"✅ Authentifié (JWT: {jwt[:30]}...)")

    print("\n3. Appel de whiteboard_create_project...")
    params = {
        "p_student_id": auth_data.get("user", {}).get("id"),
        "p_subject": "Dérivée d'une fonction",
        "p_renderer_id": "scientific",
        "p_theme_id": "scientific",
        "p_narration_mode": "none",
        "p_storyboard_json": {},
    }
    result, status = call_rpc(jwt, "whiteboard_create_project", params)
    print(f"Status: {status}")
    print(json.dumps(result, indent=2, ensure_ascii=False)[:1000])

    if status != 200 or not isinstance(result, dict) or not result.get("success"):
        print("\n❌ POINT DE RUPTURE 1: whiteboard_create_project")
        print("=" * 80)
        return

    project_id = result.get("project_id")
    print(f"\n✅ Projet créé: {project_id}")

    print("\n4. Appel de l'Edge Function whiteboard-generate-storyboard...")
    body = {
        "mode": "simple_subject",
        "subject": "Dérivée d'une fonction",
        "content": "",
        "renderer": "scientific",
        "theme": "scientific",
        "narration_mode": "none",
    }
    ef_result, ef_status = call_edge_function(jwt, body)
    print(f"Status: {ef_status}")
    print(json.dumps(ef_result, indent=2, ensure_ascii=False)[:2000])

    if ef_status != 200:
        print("\n❌ POINT DE RUPTURE 2: whiteboard-generate-storyboard")
        print("=" * 80)
        return

    print("\n✅ Edge Function retournée avec succès")

    # Vérifier la présence de storyboard_json
    if isinstance(ef_result, dict) and "storyboard_json" in ef_result:
        storyboard = ef_result["storyboard_json"]
        print("\n5. Vérification du storyboard retourné...")
        print(f"  version: {storyboard.get('version')}")
        print(f"  nombre de scènes: {len(storyboard.get('scenes', []))}")
        print(f"  narration_mode: {storyboard.get('narration_mode')}")
    else:
        print("\n⚠️ storyboard_json absent de la réponse Edge Function")

    print("=" * 80)


if __name__ == "__main__":
    main()
