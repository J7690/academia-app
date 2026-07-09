"""
Chercher l'RPC de référenciation dans les fichiers SQL locaux
"""

import os
import re

sql_dir = r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf"
search_terms = [
    "app_register_referral_for_current_user",
    "register_referral",
    "referral",
    "commission"
]

print("=== RECHERCHE RPC RÉFÉRENCIATION DANS FICHIERS SQL ===\n")

found_files = []

for root, dirs, files in os.walk(sql_dir):
    for file in files:
        if file.endswith('.sql'):
            file_path = os.path.join(root, file)
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    for term in search_terms:
                        if term.lower() in content.lower():
                            found_files.append((file_path, term))
                            print(f"✅ '{term}' trouvé dans: {file_path}")
                            break
            except Exception as e:
                print(f"❌ Erreur lecture {file_path}: {e}")

if not found_files:
    print("❌ Aucun terme de référenciation trouvé dans les fichiers SQL")
else:
    print(f"\n=== {len(found_files)} fichiers trouvés ===")

# Maintenant chercher spécifiquement app_register_referral_for_current_user
print("\n=== RECHERCHE SPÉCIFIQUE: app_register_referral_for_current_user ===\n")
for root, dirs, files in os.walk(sql_dir):
    for file in files:
        if file.endswith('.sql'):
            file_path = os.path.join(root, file)
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    if "app_register_referral_for_current_user" in content:
                        print(f"✅ TROUVÉ dans: {file_path}")
                        # Afficher les lignes autour
                        lines = content.split('\n')
                        for i, line in enumerate(lines):
                            if "app_register_referral_for_current_user" in line:
                                start = max(0, i - 5)
                                end = min(len(lines), i + 20)
                                print(f"\n--- Contexte (lignes {start+1}-{end}) ---")
                                for j in range(start, end):
                                    print(f"{j+1:4}: {lines[j]}")
                                break
            except Exception as e:
                print(f"❌ Erreur lecture {file_path}: {e}")
