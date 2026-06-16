#!/usr/bin/env python3
"""PHASE 7: Analyse des migrations SQL - quels fichiers créent les RPC problématiques"""
import os, re, json

with open('rpc_matrix_full.json') as f:
    matrix = json.load(f)

# RPCs to search for
problematic = []
for m in matrix['matrix']:
    if m['status'] in ('B', 'C', 'D'):
        problematic.append(m['rpc'])

sql_dir = r'C:\Users\fasop\AndroidStudioProjects\academia\.windsurf\sql_changes'
results = {}

for root, dirs, files in os.walk(sql_dir):
    for filename in files:
        if not filename.endswith('.sql'):
            continue
        filepath = os.path.join(root, filename)
        try:
            with open(filepath, 'r', encoding='utf-8') as fh:
                content = fh.read()
                for rpc in problematic:
                    # Search for CREATE FUNCTION with this name
                    pattern = rf"CREATE\s+(OR\s+REPLACE\s+)?FUNCTION\s+\w*\.{re.escape(rpc)}\s*\("
                    if re.search(pattern, content, re.IGNORECASE):
                        if rpc not in results:
                            results[rpc] = []
                        results[rpc].append(filename)
        except Exception:
            pass

# Summary
summary = []
for rpc in sorted(problematic):
    files = results.get(rpc, [])
    status = next(m['status'] for m in matrix['matrix'] if m['rpc'] == rpc)
    summary.append({'rpc': rpc, 'status': status, 'found_in_files': files})

with open('audit_migrations_rpc.json', 'w', encoding='utf-8') as f:
    json.dump(summary, f, indent=2, ensure_ascii=False)

print(f"OK. Searched {len(problematic)} RPCs in migrations.")
for s in summary:
    if s['found_in_files']:
        print(f"{s['rpc']} ({s['status']}): {s['found_in_files']}")
    else:
        print(f"{s['rpc']} ({s['status']}): NOT FOUND in any migration file")
