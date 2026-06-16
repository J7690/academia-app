#!/usr/bin/env python3
"""Audit forensique - Lister tous les RPC appeles dans Flutter et verifier existence"""
import re, os, json

# 1. Extraire tous les appels RPC du code Flutter
flutter_dir = r'C:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib'
rpc_calls = set()
for root, dirs, files in os.walk(flutter_dir):
    for f in files:
        if f.endswith('.dart'):
            path = os.path.join(root, f)
            try:
                with open(path, 'r', encoding='utf-8') as fh:
                    content = fh.read()
                    # Match client.rpc('name' or "name"
                    matches = re.findall(r"rpc\s*\(\s*['\"]([^'\"]+)['\"]", content)
                    for m in matches:
                        rpc_calls.add(m)
            except:
                pass

rpc_list = sorted(rpc_calls)
print(f"Total RPC appeles dans Flutter: {len(rpc_list)}")
for r in rpc_list:
    print(r)

# Save for Supabase verification
with open('flutter_rpc_list.json', 'w') as f:
    json.dump(rpc_list, f, indent=2)
