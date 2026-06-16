#!/usr/bin/env python3
"""Construire la matrice de correspondance Flutter <-> Supabase"""
import json

with open('flutter_rpc_list.json') as f:
    flutter_rpc = json.load(f)
with open('audit_inventory_base.json') as f:
    base = json.load(f)
with open('rpc_verification_simple.json') as f:
    verification = json.load(f)

# Extract function names
public_funcs = set()
for row in base['public_functions'].get('rows', []):
    public_funcs.add(row['routine_name'])

app_funcs = set()
for row in base['app_functions'].get('rows', []):
    app_funcs.add(row['routine_name'])

flutter_set = set(r for r in flutter_rpc if r != 'admin_execute_sql')

# Build matrix
matrix = []
for rpc in sorted(flutter_set):
    in_public = rpc in public_funcs
    in_app = rpc in app_funcs
    if in_public and in_app:
        status = 'D'  # Double version
    elif in_public:
        status = 'A'  # Conforme
    elif in_app:
        status = 'B'  # Mauvais schema
    else:
        status = 'C'  # Absent
    matrix.append({'rpc': rpc, 'in_public': in_public, 'in_app': in_app, 'status': status})

# Count by category
counts = {'A': 0, 'B': 0, 'C': 0, 'D': 0}
for m in matrix:
    counts[m['status']] += 1

# Build detailed lists
conformes = [m['rpc'] for m in matrix if m['status'] == 'A']
mauvais_schema = [m['rpc'] for m in matrix if m['status'] == 'B']
absents = [m['rpc'] for m in matrix if m['status'] == 'C']
doubles = [m['rpc'] for m in matrix if m['status'] == 'D']

output = {
    'total': len(matrix),
    'counts': counts,
    'conformes': conformes,
    'mauvais_schema': mauvais_schema,
    'absents': absents,
    'doubles': doubles,
    'matrix': matrix,
}

with open('rpc_matrix_full.json', 'w', encoding='utf-8') as f:
    json.dump(output, f, indent=2, ensure_ascii=False)

print(f"Total: {len(matrix)}")
print(f"A (Conformes): {counts['A']}")
print(f"B (Mauvais schema): {counts['B']}")
print(f"C (Absents): {counts['C']}")
print(f"D (Doubles): {counts['D']}")
print(f"\nMauvais schema: {mauvais_schema}")
print(f"\nAbsents: {absents}")
print(f"\nDoubles: {doubles}")
