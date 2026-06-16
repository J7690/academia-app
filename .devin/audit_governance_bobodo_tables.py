#!/usr/bin/env python3
"""Audit de gouvernance - Analyse des tables Bobodo (messages, besoins, questions)."""

from supabase_auto_manager import SupabaseAutoManager
import json

manager = SupabaseAutoManager()

print("=" * 80)
print("AUDIT GOUVERNANCE – ANALYSE TABLES BOBODO")
print("=" * 80)

# Vérifier l'existence des tables
tables_to_check = [
    'app.bobodo_messages',
    'app.bobodo_detected_needs',
    'app.bobodo_unanswered_questions',
    'app.bobodo_conversation_memory'
]

for table in tables_to_check:
    result = manager.execute_sql_auto(f"""
        SELECT COUNT(*) as total
        FROM {table}
    """)
    
    if result and 'data' in result and len(result['data']) > 0:
        count = result['data'][0]['total']
        print(f"✅ {table}: {count} enregistrement(s)")
    else:
        print(f"❌ {table}: Table inexistante ou vide")

print("\n" + "=" * 80)

# Analyser bobodo_messages si elle existe
print("\n--- ANALYSE BOBODO_MESSAGES ---")
result = manager.execute_sql_auto("""
    SELECT id, user_id, role, content, created_at
    FROM app.bobodo_messages
    ORDER BY created_at DESC
    LIMIT 50
""")

if result and 'data' in result and len(result['data']) > 0:
    messages = result['data']
    print(f"✅ {len(messages)} derniers messages analysés\n")
    
    # Sauvegarder pour analyse
    with open('bobodo_messages_sample.json', 'w', encoding='utf-8') as f:
        json.dump(messages, f, ensure_ascii=False, indent=2)
    
    # Compter par rôle
    user_count = sum(1 for m in messages if m['role'] == 'user')
    assistant_count = sum(1 for m in messages if m['role'] == 'assistant')
    print(f"Messages utilisateur: {user_count}")
    print(f"Messages assistant: {assistant_count}")
else:
    print("❌ Aucun message trouvé")

print("\n" + "=" * 80)
