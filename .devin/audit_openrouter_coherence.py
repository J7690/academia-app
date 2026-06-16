#!/usr/bin/env python3
"""Audit de cohérence OpenRouter - Cartographie complète des clés"""

import os
from pathlib import Path

print("=" * 80)
print("AUDIT DE COHÉRENCE OPENROUTER - PHASE 1")
print("=" * 80)

# Variables d'environnement système
print("\n" + "=" * 80)
print("1. VARIABLES D'ENVIRONNEMENT SYSTÈME")
print("=" * 80)

secrets = [
    'OPENROUTER_API_KEY',
    'OPENROUTER_MODEL',
    'OPENROUTER_FALLBACK_MODEL',
    'OPENROUTER_EMBEDDING_MODEL'
]

for secret in secrets:
    value = os.getenv(secret)
    if value:
        print(f"✅ {secret}")
        print(f"   Longueur: {len(value)}")
        print(f"   Préfixe: {value[:10]}...")
        print(f"   Suffixe: ...{value[-4:]}")
    else:
        print(f"❌ {secret} - NON DÉFINIE")
    print()

# Fichiers .env du backend
print("=" * 80)
print("2. FICHIERS .env BACKEND")
print("=" * 80)

root = Path(__file__).resolve().parents[1]
backend_dir = root / "academia_bobodo_backend"

env_files = [
    backend_dir / ".env",
    backend_dir / ".env.local",
    backend_dir / ".env.production"
]

for env_file in env_files:
    print(f"\nFichier: {env_file.name}")
    if env_file.exists():
        print(f"✅ Présent")
        try:
            content = env_file.read_text(encoding="utf-8")
            print(f"   Taille: {len(content)} octets")
            
            # Extraire les variables OpenRouter
            for line in content.splitlines():
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, value = line.split("=", 1)
                key = key.strip()
                value = value.strip().strip('"').strip("'")
                
                if "OPENROUTER" in key:
                    print(f"   ✅ {key}")
                    print(f"      Longueur: {len(value)}")
                    print(f"      Préfixe: {value[:10]}...")
                    print(f"      Suffixe: ...{value[-4:]}")
        except Exception as e:
            print(f"❌ Erreur lecture: {e}")
    else:
        print(f"❌ Non présent")

# Fichiers de configuration Python
print("\n" + "=" * 80)
print("3. FICHIERS DE CONFIGURATION PYTHON (.windsurf)")
print("=" * 80)

config_files = [
    "supabase_auto_manager.py",
    "seed_bobodo_knowledge.py"
]

for config_file in config_files:
    file_path = Path(__file__).parent / config_file
    print(f"\nFichier: {config_file}")
    if file_path.exists():
        print(f"✅ Présent")
        try:
            content = file_path.read_text(encoding="utf-8")
            # Chercher les références à OPENROUTER
            if "OPENROUTER" in content:
                print(f"   ✅ Contient des références OPENROUTER")
                # Extraire les lignes pertinentes
                for i, line in enumerate(content.splitlines(), 1):
                    if "OPENROUTER" in line and not line.strip().startswith("#"):
                        print(f"      Ligne {i}: {line.strip()[:80]}")
        except Exception as e:
            print(f"❌ Erreur lecture: {e}")
    else:
        print(f"❌ Non présent")

print("\n" + "=" * 80)
