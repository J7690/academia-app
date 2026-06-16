#!/usr/bin/env python3
"""Création RPC injection Bobodo"""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("CRÉATION RPC app_bobodo_inject_knowledge")
print("=" * 80)

# Lire le script SQL
with open('sql_changes/change_20260609_bobodo_injection_rpc.sql', 'r', encoding='utf-8') as f:
    sql_script = f.read()

print("\nExécution du script SQL...")
result = manager.execute_sql_auto(sql_script)

if result and 'error' in result:
    print(f"❌ Erreur: {result['error']}")
else:
    print(f"✅ RPC créée avec succès")

print("=" * 80)
