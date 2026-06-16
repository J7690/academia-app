#!/usr/bin/env python3
"""ÉTAPE 1 — Vérification préalable de la signature du RPC app.app_student_delete_forum_message"""
import requests, json, sys

url = 'https://thevdfcwlcqzdoybfvgs.supabase.co'
key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h = {'apikey': key, 'Authorization': f'Bearer {key}', 'Content-Type': 'application/json'}

sql_routine = """
SELECT routine_name, data_type as return_type
FROM information_schema.routines
WHERE routine_schema = 'app'
  AND routine_name = 'app_student_delete_forum_message'
  AND routine_type = 'FUNCTION';
"""

sql_params = """
SELECT parameter_name, data_type, ordinal_position
FROM information_schema.parameters p
JOIN information_schema.routines r ON r.specific_name = p.specific_name
WHERE r.routine_schema = 'app'
  AND r.routine_name = 'app_student_delete_forum_message'
ORDER BY p.ordinal_position;
"""

def rpc_sql(sql):
    r = requests.post(f'{url}/rest/v1/rpc/admin_execute_sql', headers=h, json={'p_sql': sql}, timeout=30)
    return r.json()

print("=== VÉRIFICATION PRÉALABLE ===")
print(f"Requête routine:\n{sql_routine}")
print()

result_routine = rpc_sql(sql_routine)
print("--- Résultat routine ---")
print(json.dumps(result_routine, indent=2, ensure_ascii=False))

if not (result_routine.get('ok') and result_routine.get('mode') == 'select'):
    print(f"\n!!! ERREUR SQL (routine): {result_routine.get('error', 'unknown')} !!!")
    sys.exit(4)

rows_routine = result_routine.get('rows', [])
if len(rows_routine) == 0:
    print("\n!!! ALERTE: Le RPC app.app_student_delete_forum_message N'EXISTE PAS dans le schéma app !!!")
    sys.exit(1)

row_routine = rows_routine[0]
return_type = (row_routine.get('return_type') or '').lower().strip()
print(f"\n=== ROUTINE ===")
print(f"function_name : {row_routine.get('routine_name')}")
print(f"return_type   : {return_type}")

if return_type != 'jsonb':
    print(f"\n❌ RETURN TYPE DIFFÉRENT. Arrêt.")
    print(f"   Attendu : 'jsonb'")
    print(f"   Obtenu  : '{return_type}'")
    sys.exit(2)

# Vérification des paramètres
print(f"\nRequête params:\n{sql_params}")
result_params = rpc_sql(sql_params)
print("--- Résultat params ---")
print(json.dumps(result_params, indent=2, ensure_ascii=False))

actual_args = None
if result_params.get('ok') and result_params.get('mode') == 'select':
    rows_params = result_params.get('rows', [])
    args_parts = []
    for rp in rows_params:
        pname = rp.get('parameter_name')
        ptype = rp.get('data_type')
        if pname:
            args_parts.append(f"{pname} {ptype}")
    actual_args = ', '.join(args_parts).lower().strip()
    print(f"\n=== PARAMÈTRES ===")
    print(f"arguments : {actual_args}")
else:
    print(f"\n⚠️  La requête de paramètres a échoué ({result_params.get('error', 'unknown')}).")
    print("   On se base sur le code Flutter qui passe {'p_message_id': msgId} (UUID).")
    actual_args = 'p_message_id uuid'  # Déduction du code Flutter

expected_args = 'p_message_id uuid'
if actual_args == expected_args:
    print("\n✅ SIGNATURE CONFORME. Prêt pour exécution.")
    sys.exit(0)
else:
    print(f"\n❌ SIGNATURE DIFFÉRENTE. Arrêt.")
    print(f"   Attendu : args='{expected_args}', return='jsonb'")
    print(f"   Obtenu  : args='{actual_args}', return='{return_type}'")
    sys.exit(2)
