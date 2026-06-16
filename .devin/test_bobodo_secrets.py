#!/usr/bin/env python3
"""Test Edge Function test-bobodo-secrets pour voir les secrets effectifs"""

import requests
import json
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
print("AUDIT SECRETS BOBODO-CHAT - EDGE FUNCTION TEST")
print("=" * 80)
print(f"\nSupabase URL: {SUPABASE_URL}")
print(f"Service Key (tronquée): {SERVICE_KEY[:20]}...{SERVICE_KEY[-10:]}")

headers = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
    "Accept": "application/json"
}

try:
    response = requests.get(
        f"{SUPABASE_URL}/functions/v1/test-bobodo-secrets",
        headers=headers,
        timeout=30
    )
    
    print(f"\nHTTP Status: {response.status_code}")
    
    if response.status_code == 200:
        data = response.json()
        print("\n" + "=" * 80)
        print("SECRETS EFFECTIFS DANS BOBODO-CHAT (PRODUCTION)")
        print("=" * 80)
        
        print("\nOPENROUTER_API_KEY:")
        api_key = data['OPENROUTER_API_KEY']
        print(f"  Présent: {api_key['present']}")
        print(f"  Longueur: {api_key['length']}")
        print(f"  Préfixe: {api_key['prefix']}")
        print(f"  Suffixe: {api_key['suffix']}")
        
        print("\nOPENROUTER_MODEL:")
        model = data['OPENROUTER_MODEL']
        print(f"  Présent: {model['present']}")
        print(f"  Valeur: {model['value']}")
        
        print("\nOPENROUTER_FALLBACK_MODEL:")
        fallback = data['OPENROUTER_FALLBACK_MODEL']
        print(f"  Présent: {fallback['present']}")
        print(f"  Valeur: {fallback['value']}")
        
        print("\nOPENROUTER_EMBEDDING_MODEL:")
        embedding = data['OPENROUTER_EMBEDDING_MODEL']
        print(f"  Présent: {embedding['present']}")
        print(f"  Valeur: {embedding['value']}")
        
        print("\n" + "=" * 80)
        print("ANALYSE")
        print("=" * 80)
        
        if not embedding['present']:
            print("❌ OPENROUTER_EMBEDDING_MODEL NON DÉFINI dans les secrets Supabase")
            print("→ Les embeddings échoueront car le modèle n'est pas configuré")
        else:
            print(f"✅ OPENROUTER_EMBEDDING_MODEL défini: {embedding['value']}")
            
        if not api_key['present']:
            print("❌ OPENROUTER_API_KEY NON DÉFINI dans les secrets Supabase")
            print("→ Bobodo ne fonctionnera pas du tout")
        else:
            print(f"✅ OPENROUTER_API_KEY défini (longueur: {api_key['length']})")
            
    else:
        print(f"❌ Erreur: {response.text[:200]}")
        
except Exception as e:
    print(f"❌ Erreur: {e}")
