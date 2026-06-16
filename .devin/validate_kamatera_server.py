#!/usr/bin/env python3
"""
Validation du serveur Kamatera via API
Utilise les identifiants fournis
"""

import requests
import json
import time

# Nouveaux identifiants fournis
API_URL = "https://console.kamatera.com/service"
API2 = "https://cloudcli.cloudwm.com"
CLIENT_ID = "a91330958142da0f32fdc6b9f7e16476"
SECRET = "354e008099f0dbb3e667f550965d8e95"
SERVER_ID = "f6d2656b-0f80-4df1-ac62-53b26d6d921b"

HEADERS = {"AuthClientId": CLIENT_ID, "AuthSecret": SECRET}
HEADERS2 = {"AuthClientId": CLIENT_ID, "AuthSecret": SECRET, "Content-Type": "application/json"}

def validate_server():
    """Valider le serveur via API Kamatera"""
    print("=== VALIDATION SERVEUR KAMATERA ===")
    print(f"Server ID: {SERVER_ID}")
    print(f"Client ID: {CLIENT_ID}")
    print(f"Secret: {SECRET[:8]}...")
    print()
    
    # Test 1: Connexion API cloudcli
    print("[1] Test connexion API cloudcli...")
    try:
        response = requests.post(f"{API2}/service/server/info", headers=HEADERS2, json={"name": "academia-livekit"}, timeout=30)
        print(f"  Status: {response.status_code}")
        if response.status_code == 200:
            print("  ✅ Connexion API cloudcli réussie")
            data = response.json()
            print(f"  Détails: {json.dumps(data, indent=2, ensure_ascii=False)[:1000]}")
        else:
            print(f"  ❌ Erreur: {response.text[:200]}")
    except requests.exceptions.Timeout:
        print("  ❌ Timeout")
    except Exception as e:
        print(f"  ❌ Erreur: {e}")
    
    # Test 2: Connexion API console
    print("\n[2] Test connexion API console...")
    try:
        response = requests.get(f"{API_URL}/server/info", headers=HEADERS, timeout=30)
        print(f"  Status: {response.status_code}")
        if response.status_code == 200:
            print("  ✅ Connexion API console réussie")
        else:
            print(f"  ❌ Erreur: {response.text[:200]}")
    except requests.exceptions.Timeout:
        print("  ❌ Timeout")
    except Exception as e:
        print(f"  ❌ Erreur: {e}")
    
    # Test 3: Récupérer les détails du serveur via cloudcli
    print("\n[3] Récupération détails serveur via cloudcli...")
    try:
        response = requests.post(f"{API2}/service/server/info", headers=HEADERS2, json={"id": SERVER_ID}, timeout=30)
        print(f"  Status: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print("  ✅ Serveur trouvé")
            print(f"  Détails: {json.dumps(data, indent=2, ensure_ascii=False)[:1000]}")
        else:
            print(f"  ❌ Erreur: {response.text[:200]}")
    except requests.exceptions.Timeout:
        print("  ❌ Timeout")
    except Exception as e:
        print(f"  ❌ Erreur: {e}")
    
    # Test 4: Lister tous les serveurs via console
    print("\n[4] Liste tous les serveurs via console...")
    try:
        response = requests.get(f"{API_URL}/server/info", headers=HEADERS, timeout=30)
        print(f"  Status: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            if isinstance(data, list):
                print(f"  ✅ {len(data)} serveurs trouvés")
                for server in data:
                    if server.get('id') == SERVER_ID:
                        print(f"  ✅ Serveur trouvé dans la liste")
                        print(f"  Détails: {json.dumps(server, indent=2, ensure_ascii=False)[:1000]}")
            else:
                print(f"  ⚠️ Format inattendu: {type(data)}")
                print(f"  Données: {str(data)[:500]}")
        else:
            print(f"  ❌ Erreur: {response.text[:200]}")
    except requests.exceptions.Timeout:
        print("  ❌ Timeout")
    except Exception as e:
        print(f"  ❌ Erreur: {e}")
    
    print("\n=== VALIDATION TERMINÉE ===")


if __name__ == "__main__":
    validate_server()
