#!/usr/bin/env python3
"""Mise à jour du fichier .env avec OPENROUTER_EMBEDDING_MODEL"""

from pathlib import Path

root = Path(__file__).resolve().parents[1]
env_path = root / "academia_bobodo_backend" / ".env"

if not env_path.exists():
    print(f"❌ Fichier non trouvé: {env_path}")
    exit(1)

# Lire le fichier actuel
content = env_path.read_text(encoding="utf-8")

# Vérifier si OPENROUTER_EMBEDDING_MODEL existe déjà
if "OPENROUTER_EMBEDDING_MODEL" in content:
    print("✅ OPENROUTER_EMBEDDING_MODEL déjà présent dans le fichier .env")
    exit(0)

# Ajouter OPENROUTER_EMBEDDING_MODEL
updated_content = content + "\nOPENROUTER_EMBEDDING_MODEL=openai/text-embedding-3-small\n"

# Sauvegarder
env_path.write_text(updated_content, encoding="utf-8")

print(f"✅ OPENROUTER_EMBEDDING_MODEL ajouté au fichier .env")
print(f"   Fichier: {env_path}")
