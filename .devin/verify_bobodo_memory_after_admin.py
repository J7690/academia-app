#!/usr/bin/env python3
"""Vérification de la table bobodo_conversation_memory après création via admin RPC."""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("VÉRIFICATION TABLE BOBODO_CONVERSATION_MEMORY")
print("=" * 80)

# Vérifier que la table existe
print("\n🔍 Vérification de la table...")
print("-" * 80)

result = manager.execute_sql_auto("""
    SELECT table_name 
    FROM information_schema.tables 
    WHERE table_schema = 'app' 
    AND table_name = 'bobodo_conversation_memory'
""")

if result and len(result) > 0:
    print("✅ Table bobodo_conversation_memory créée avec succès")
else:
    print("❌ Table non trouvée")
    exit(1)

# Vérifier les RPCs
print("\n🔍 Vérification des RPCs...")
print("-" * 80)

result = manager.execute_sql_auto("""
    SELECT proname 
    FROM pg_proc 
    WHERE proname IN ('save_bobodo_conversation_memory', 'get_bobodo_cross_session_memory') 
    AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'app')
""")

if result and len(result) > 0:
    print(f"✅ {len(result)} RPC(s) trouvée(s):")
    for row in result:
        print(f"  - {row}")
else:
    print("❌ Aucune RPC trouvée")
    exit(1)

print("\n" + "=" * 80)
print("VÉRIFICATION TERMINÉE")
print("=" * 80)
