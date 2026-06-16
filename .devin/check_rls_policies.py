#!/usr/bin/env python3
"""Vérification RLS policies sur bobodo_knowledge"""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("RLS POLICIES SUR app.bobodo_knowledge")
print("=" * 80)

# Vérifier si RLS est activé
result = manager.execute_sql_auto("""
    SELECT relname, relrowsecurity
    FROM pg_class
    WHERE relname = 'bobodo_knowledge'
    AND relnamespace = 'app'::regnamespace
""")

if result and 'data' in result and len(result['data']) > 0:
    rls_enabled = result['data'][0]['relrowsecurity']
    print(f"\nRLS activé: {rls_enabled}")
else:
    print("❌ Erreur lors de la vérification RLS")

# Vérifier les policies
result = manager.execute_sql_auto("""
    SELECT policyname, permissive, roles, cmd, qual
    FROM pg_policies
    WHERE tablename = 'bobodo_knowledge'
    AND schemaname = 'app'
""")

if result and 'data' in result and len(result['data']) > 0:
    print(f"\n{len(result['data'])} RLS policy(s):\n")
    for policy in result['data']:
        print(f"  - {policy['policyname']}")
        print(f"    Permissive: {policy['permissive']}")
        print(f"    Roles: {policy['roles']}")
        print(f"    Command: {policy['cmd']}")
        print()
else:
    print("\n✅ Aucune RLS policy")

print("=" * 80)
