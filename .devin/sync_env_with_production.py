#!/usr/bin/env python3
"""Synchroniser le fichier .env local avec les secrets de production"""

from pathlib import Path

root = Path(__file__).resolve().parents[1]
env_path = root / "academia_bobodo_backend" / ".env"

if not env_path.exists():
    print(f"❌ Fichier non trouvé: {env_path}")
    exit(1)

# Lire le fichier actuel
content = env_path.read_text(encoding="utf-8")

# Mettre à jour avec les valeurs de production
updated_content = content
updated_content = updated_content.replace("OPENROUTER_API_KEY=sk-or-v1-1...4fc6", "OPENROUTER_API_KEY=sk-or-v1-6...0782")
# Note: La vraie clé complète doit être obtenue depuis Supabase Dashboard

# Sauvegarder
env_path.write_text(updated_content, encoding="utf-8")

print(f"⚠️ Fichier .env mis à jour avec la clé de production")
print(f"   IMPORTANT: La clé sk-or-v1-6...0782 doit être remplacée par la clé complète depuis Supabase Dashboard")
print(f"   Fichier: {env_path}")
