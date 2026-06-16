#!/usr/bin/env python3
"""Test embeddings avec la clé de production via Edge Function"""

import requests
from pathlib import Path

# Charger la clé API depuis le fichier .env
root = Path(__file__).resolve().parents[1]
env_path = root / "academia_bobodo_backend" / ".env"

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = None

if env_path.exists():
    try:
        content = env_path.read_text(encoding="utf-8")
        for line in content.splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            key = key.strip()
            value = value.strip().strip('"').strip("'")
            
            if key == "SUPABASE_SERVICE_KEY":
                SERVICE_KEY = value
                break
    except Exception as e:
        print(f"Erreur lecture fichier .env: {e}")

if not SERVICE_KEY:
    print("❌ SUPABASE_SERVICE_KEY non trouvée")
    exit(1)

print("=" * 80)
print("TEST EMBEDDINGS AVEC CLÉ DE PRODUCTION")
print("=" * 80)

headers = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
    "Accept": "application/json"
}

payload = {
    "text": "Test embedding generation with production key"
}

try:
    response = requests.post(
        f"{SUPABASE_URL}/functions/v1/test-embeddings-production",
        headers=headers,
        json=payload,
        timeout=30
    )
    
    print(f"\nHTTP Status: {response.status_code}")
    
    if response.status_code == 200:
        data = response.json()
        print("\n" + "=" * 80)
        print("RÉSULTAT TEST EMBEDDINGS")
        print("=" * 80)
        
        print(f"\nSuccès: {data.get('success')}")
        print(f"Modèle utilisé: {data.get('model')}")
        print(f"Modèle retourné par OpenRouter: {data.get('model_used')}")
        print(f"Longueur clé API: {data.get('api_key_length')}")
        print(f"Dimension embedding: {data.get('embedding_dimension')}")
        
        if data.get('success'):
            print("\n✅ Les embeddings fonctionnent avec la clé de production")
        else:
            print(f"\n❌ Erreur: {data.get('error')}")
    else:
        print(f"❌ Erreur HTTP {response.status_code}")
        print(f"   {response.text[:200]}")
        
except Exception as e:
    print(f"❌ Erreur: {e}")
