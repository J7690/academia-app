#!/usr/bin/env python3
"""PHASE 1: Inventaire détaillé des RPC Flutter - fichier, ligne, écran, fonctionnalité"""
import os, re, json

with open('rpc_matrix_full.json') as f:
    matrix = json.load(f)

# Only problematic RPCs: B (mauvais schema), C (absent), D (double)
problematic_rpc = set()
for m in matrix['matrix']:
    if m['status'] in ('B', 'C', 'D'):
        problematic_rpc.add(m['rpc'])

flutter_dir = r'C:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib'

# Map: rpc_name -> list of occurrences
occurrences = {rpc: [] for rpc in problematic_rpc}

for root, dirs, files in os.walk(flutter_dir):
    for filename in files:
        if not filename.endswith('.dart'):
            continue
        filepath = os.path.join(root, filename)
        rel_path = os.path.relpath(filepath, flutter_dir)
        try:
            with open(filepath, 'r', encoding='utf-8') as fh:
                lines = fh.readlines()
                for i, line in enumerate(lines, 1):
                    # Match rpc('name' or "name"
                    matches = re.findall(r"rpc\s*\(\s*['\"]([^'\"]+)['\"]", line)
                    for rpc_name in matches:
                        if rpc_name in problematic_rpc:
                            # Try to extract surrounding context (widget/class/screen name)
                            context = line.strip()
                            occurrences[rpc_name].append({
                                'file': rel_path,
                                'line': i,
                                'context': context[:200]
                            })
        except Exception:
            pass

# Build summary
summary = []
for rpc in sorted(problematic_rpc):
    occ_list = occurrences[rpc]
    files = list(set(o['file'] for o in occ_list))
    summary.append({
        'rpc': rpc,
        'status': next(m['status'] for m in matrix['matrix'] if m['rpc'] == rpc),
        'occurrence_count': len(occ_list),
        'files': files,
        'occurrences': occ_list[:5]  # max 5 per RPC
    })

with open('flutter_rpc_detailed.json', 'w', encoding='utf-8') as f:
    json.dump(summary, f, indent=2, ensure_ascii=False)

print(f"OK. Processed {len(problematic_rpc)} problematic RPCs.")
for s in summary:
    print(f"{s['rpc']} ({s['status']}): {s['occurrence_count']} occurrences in {len(s['files'])} files")
