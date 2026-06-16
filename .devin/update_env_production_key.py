#!/usr/bin/env python3
"""Mettre à jour OPENROUTER_API_KEY dans .env avec la clé de production"""

from pathlib import Path

root = Path(__file__).resolve().parents[1]
env_path = root / "academia_bobodo_backend" / ".env"

if not env_path.exists():
    print(f"❌ Fichier non trouvé: {env_path}")
    exit(1)

# Lire le fichier actuel
content = env_path.read_text(encoding="utf-8")

# La clé de production (à obtenir depuis Supabase Dashboard)
# Pour l'instant, nous allons utiliser un placeholder
# L'utilisateur devra remplacer par la vraie clé complète
production_key_placeholder = "sk-or-v1-6...0782"

# Mettre à jour la clé
updated_content = content
if "OPENROUTER_API_KEY=" in updated_content:
    lines = updated_content.splitlines()
    updated_lines = []
    for line in lines:
        if line.startswith("OPENROUTER_API_KEY="):
            # Remplacer par la clé de production
            updated_lines.append(f"OPENROUTER_API_KEY={production_key_placeholder}")
        else:
            updated_lines.append(line)
    updated_content = "\n".join(updated_lines)

# Sauvegarder
env_path.write_text(updated_content, encoding="utf-8")

print(f"⚠️ OPENROUTER_API_KEY mise à jour avec placeholder")
print(f"   IMPORTANT: Remplacer '{production_key_placeholder}' par la clé complète depuis Supabase Dashboard")
print(f"   Fichier: {env_path}")
print(f"\nPour obtenir la clé complète:")
print(f"   1. Ouvrir Supabase Dashboard")
print(f"   2. Edge Functions → Settings → Environment Variables")
print(f"   3. Copier la valeur de OPENROUTER_API_KEY")
print(f"   4. Remplacer dans le fichier .env")
