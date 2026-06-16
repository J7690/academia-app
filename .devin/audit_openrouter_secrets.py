#!/usr/bin/env python3
"""Audit des secrets Supabase OpenRouter"""

import os
from pathlib import Path

print("=" * 80)
print("AUDIT SECRETS SUPABASE OPENROUTER")
print("=" * 80)

# Variables d'environnement à vérifier
secrets = [
    'OPENROUTER_API_KEY',
    'OPENROUTER_EMBEDDING_MODEL',
    'OPENROUTER_MODEL',
    'OPENROUTER_FALLBACK_MODEL'
]

print("\nVariables d'environnement système:\n")
for secret in secrets:
    value = os.getenv(secret)
    if value:
        print(f"✅ {secret}")
        print(f"   Longueur: {len(value)}")
        print(f"   Valeur (tronquée): {value[:10]}...{value[-4:]}")
    else:
        print(f"❌ {secret} - NON DÉFINIE")
    print()

# Vérifier le fichier .env du backend
print("=" * 80)
print("FICHIER .env BACKEND")
print("=" * 80)

root = Path(__file__).resolve().parents[1]
env_path = root / "academia_bobodo_backend" / ".env"

if env_path.exists():
    print(f"\n✅ Fichier trouvé: {env_path}")
    print("\nContenu (secrets masqués):\n")
    
    try:
        content = env_path.read_text(encoding="utf-8")
        for line in content.splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            key = key.strip()
            value = value.strip().strip('"').strip("'")
            
            if "KEY" in key or "SECRET" in key:
                print(f"✅ {key}")
                print(f"   Longueur: {len(value)}")
                print(f"   Valeur (tronquée): {value[:10]}...{value[-4:]}")
            else:
                print(f"✅ {key} = {value}")
    except Exception as e:
        print(f"❌ Erreur lecture fichier: {e}")
else:
    print(f"\n❌ Fichier non trouvé: {env_path}")

print("\n" + "=" * 80)
