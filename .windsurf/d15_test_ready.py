"""
MISSION D.15.1 - Test de bout en bout du flux Smart Whiteboard

Utilise un JWT passé en variable d'environnement TEST_JWT.
Si TEST_JWT n'est pas défini, le script demande un JWT interactif.

Pipeline testé:
1. whiteboard_create_project
2. whiteboard-generate-storyboard
3. Parsing du storyboard
"""

import os
import sys
import requests
import json

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMwNTY1NjAsImV4cCI6MjA3ODYzMjU2MH0.9r5x1E0h2B6g4y7z8A1b2C3d4e5F6g7H8i9J0k1L2m3"


def get_jwt():
    jwt = os.environ.get("TEST_JWT", "")
    if not jwt:
        jwt = input("Collez le JWT utilisateur de test: ").strip()
    return jwt


def call_rpc(jwt, rpc_name, params):
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
    print("MISSION D.15.1 - TEST BOUT EN BOUT SMART WHITEBOARD")
    print("=" * 80)

    jwt = get_jwt()
    if not jwt:
        print("❌ Aucun JWT fourni.")
        sys.exit(1)

    print("\n1. Appel de whiteboard_create_project...")
    params = {
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
        print("\n❌ POINT DE RUPTURE: whiteboard_create_project")
        print("=" * 80)
        return

    project_id = result.get("project_id")
    print(f"\n✅ Projet créé: {project_id}")

    print("\n2. Appel de l'Edge Function whiteboard-generate-storyboard...")
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
        print("\n❌ POINT DE RUPTURE: whiteboard-generate-storyboard")
        print("=" * 80)
        return

    print("\n✅ Edge Function retournée avec succès")

    if isinstance(ef_result, dict) and "storyboard_json" in ef_result:
        storyboard = ef_result["storyboard_json"]
        print("\n3. Vérification du storyboard...")
        print(f"  version: {storyboard.get('version')}")
        print(f"  nombre de scènes: {len(storyboard.get('scenes', []))}")
        print(f"  narration_mode: {storyboard.get('narration_mode')}")
        print("\n✅ Test réussi jusqu'au parsing storyboard.")
    else:
        print("\n⚠️ storyboard_json absent de la réponse")

    print("=" * 80)


if __name__ == "__main__":
    main()
