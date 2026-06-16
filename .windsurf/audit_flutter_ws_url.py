#!/usr/bin/env python3
"""Mission 5 — Identifier URL exacte utilisée par Flutter"""
import os

results = []
results.append("# BOBODO_FLUTTER_WS_URL\n")
results.append("## Mission 5 — Constantes URL vocales dans le code Flutter\n")

files_to_check = [
    r"c:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib\services\voice_provider.dart",
    r"c:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib\services\bobodo_vocal_service.dart",
]

for path in files_to_check:
    name = os.path.basename(path)
    results.append(f"\n### {name}")
    results.append(f"**Chemin:** `{path}`")
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
        results.append("```dart")
        results.append(content)
        results.append("```")
    else:
        results.append("**FICHIER ABSENT**")

# Recherche globale de toute constante WS
import subprocess
results.append("\n### Recherche globale de '8000', 'ws://', 'websocket' dans lib/services/")
search_dirs = [
    r"c:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib\services",
    r"c:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib\features\student\tabs",
]

for search_dir in search_dirs:
    if os.path.exists(search_dir):
        results.append(f"\n**Dans:** `{search_dir}`")
        for root, dirs, files in os.walk(search_dir):
            for file in files:
                if file.endswith('.dart'):
                    filepath = os.path.join(root, file)
                    with open(filepath, "r", encoding="utf-8") as f:
                        content = f.read()
                    if '8000' in content or 'ws://' in content or 'websocket' in content.lower() or 'voice' in content.lower():
                        results.append(f"\n#### {os.path.basename(filepath)}")
                        lines = content.split('\n')
                        for i, line in enumerate(lines, 1):
                            if '8000' in line or 'ws://' in line or 'websocket' in line.lower() or ('voice' in line.lower() and 'url' in line.lower()):
                                results.append(f"  Ligne {i}: `{line.strip()}`")

output = "\n".join(results)
with open(r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\BOBODO_FLUTTER_WS_URL.md", "w", encoding="utf-8") as f:
    f.write(output)
print(output)
