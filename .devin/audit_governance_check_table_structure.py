#!/usr/bin/env python3
"""Audit de gouvernance - Vérification structure tables Bobodo."""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("AUDIT GOUVERNANCE – STRUCTURE TABLES BOBODO")
print("=" * 80)

# Vérifier la structure de bobodo_messages
print("\n--- STRUCTURE BOBODO_MESSAGES ---")
result = manager.execute_sql_auto("""
    SELECT column_name, data_type
    FROM information_schema.columns
    WHERE table_schema = 'app' 
    AND table_name = 'bobodo_messages'
    ORDER BY ordinal_position
""")

if result and 'data' in result and len(result['data']) > 0:
    for col in result['data']:
        print(f"  - {col['column_name']}: {col['data_type']}")
else:
    print("  ❌ Table inexistante")

# Vérifier la structure de bobodo_detected_needs
print("\n--- STRUCTURE BOBODO_DETECTED_NEEDS ---")
result = manager.execute_sql_auto("""
    SELECT column_name, data_type
    FROM information_schema.columns
    WHERE table_schema = 'app' 
    AND table_name = 'bobodo_detected_needs'
    ORDER BY ordinal_position
""")

if result and 'data' in result and len(result['data']) > 0:
    for col in result['data']:
        print(f"  - {col['column_name']}: {col['data_type']}")
else:
    print("  ❌ Table inexistante")

# Vérifier la structure de bobodo_unanswered_questions
print("\n--- STRUCTURE BOBODO_UNANSWERED_QUESTIONS ---")
result = manager.execute_sql_auto("""
    SELECT column_name, data_type
    FROM information_schema.columns
    WHERE table_schema = 'app' 
    AND table_name = 'bobodo_unanswered_questions'
    ORDER BY ordinal_position
""")

if result and 'data' in result and len(result['data']) > 0:
    for col in result['data']:
        print(f"  - {col['column_name']}: {col['data_type']}")
else:
    print("  ❌ Table inexistante")

print("\n" + "=" * 80)
