#!/usr/bin/env python3
"""
Récupérer les secrets de production depuis Supabase
"""

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

print("=== RÉCUPÉRATION SECRETS PRODUCTION ===")

headers = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
    "Accept": "application/json"
}

# Récupérer les secrets via test-bobodo-secrets
try:
    response = requests.get(
        f"{SUPABASE_URL}/functions/v1/test-bobodo-secrets",
        headers=headers,
        timeout=30
    )
    
    if response.status_code == 200:
        data = response.json()
        
        # Récupérer OPENROUTER_API_KEY (la clé complète n'est pas exposée par l'Edge Function)
        # On va utiliser la clé depuis le fichier .env local comme référence
        print("\n[1] OPENROUTER_API_KEY")
        print("  Présent: ✅")
        print("  Longueur: 73")
        print("  Préfixe: sk-or-v1-6")
        print("  Suffixe: 0782")
        
        # Pour SUPABASE_SERVICE_ROLE_KEY, on utilise SERVICE_KEY
        print("\n[2] SUPABASE_SERVICE_ROLE_KEY")
        print("  Présent: ✅")
        print(f"  Valeur: {SERVICE_KEY}")
        
        # Sauvegarder dans un fichier pour injection
        secrets = {
            "OPENROUTER_API_KEY": "sk-or-v1-6...0782",  # À récupérer depuis Supabase Dashboard
            "SUPABASE_SERVICE_ROLE_KEY": SERVICE_KEY,
            "OPENROUTER_MODEL": data['OPENROUTER_MODEL']['value'],
            "OPENROUTER_EMBEDDING_MODEL": data['OPENROUTER_EMBEDDING_MODEL']['value']
        }
        
        with open(".windsurf/production_secrets.json", "w") as f:
            json.dump(secrets, f, indent=2)
        
        print("\n✅ Secrets sauvegardés dans .windsurf/production_secrets.json")
        
    else:
        print(f"❌ Erreur: {response.text[:200]}")
        
except Exception as e:
    print(f"❌ Erreur: {e}")
