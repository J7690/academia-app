#!/usr/bin/env python3
"""Audit de gouvernance - Analyse des messages Bobodo (version corrigée)."""

from supabase_auto_manager import SupabaseAutoManager
import json

manager = SupabaseAutoManager()

print("=" * 80)
print("AUDIT GOUVERNANCE – ANALYSE MESSAGES BOBODO")
print("=" * 80)

# Analyser bobodo_messages
result = manager.execute_sql_auto("""
    SELECT COUNT(*) as total
    FROM app.bobodo_messages
""")

if result and 'data' in result and len(result['data']) > 0:
    total = result['data'][0]['total']
    print(f"\n✅ Total messages: {total}\n")
else:
    print("❌ Erreur lors du comptage")

# Récupérer les messages utilisateur
result = manager.execute_sql_auto("""
    SELECT id, content, created_at
    FROM app.bobodo_messages
    WHERE role = 'user'
    ORDER BY created_at DESC
    LIMIT 100
""")

if result and 'data' in result and len(result['data']) > 0:
    messages = result['data']
    print(f"✅ {len(messages)} derniers messages utilisateur récupérés\n")
    
    # Sauvegarder pour analyse
    with open('bobodo_user_messages.json', 'w', encoding='utf-8') as f:
        json.dump(messages, f, ensure_ascii=False, indent=2)
    
    # Afficher un échantillon
    print("Échantillon de messages utilisateur:")
    for i, msg in enumerate(messages[:10], 1):
        content = msg['content'][:100] + "..." if len(msg['content']) > 100 else msg['content']
        print(f"{i}. {content}")
else:
    print("❌ Aucun message utilisateur trouvé")

# Analyser bobodo_detected_needs
print("\n" + "=" * 80)
print("ANALYSE BOBODO_DETECTED_NEEDS")
print("=" * 80)

result = manager.execute_sql_auto("""
    SELECT id, need_type, content, created_at
    FROM app.bobodo_detected_needs
    ORDER BY created_at DESC
    LIMIT 50
""")

if result and 'data' in result and len(result['data']) > 0:
    needs = result['data']
    print(f"\n✅ {len(needs)} besoins détectés récupérés\n")
    
    # Sauvegarder
    with open('bobodo_detected_needs.json', 'w', encoding='utf-8') as f:
        json.dump(needs, f, ensure_ascii=False, indent=2)
    
    # Compter par type
    from collections import Counter
    types = [n['need_type'] for n in needs if n.get('need_type')]
    type_counts = Counter(types)
    print("Types de besoins détectés:")
    for need_type, count in type_counts.most_common():
        print(f"  - {need_type}: {count}")
else:
    print("❌ Aucun besoin détecté trouvé")

# Analyser bobodo_unanswered_questions
print("\n" + "=" * 80)
print("ANALYSE BOBODO_UNANSWERED_QUESTIONS")
print("=" * 80)

result = manager.execute_sql_auto("""
    SELECT id, question, created_at
    FROM app.bobodo_unanswered_questions
    ORDER BY created_at DESC
""")

if result and 'data' in result and len(result['data']) > 0:
    questions = result['data']
    print(f"\n✅ {len(questions)} questions sans réponse\n")
    
    # Sauvegarder
    with open('bobodo_unanswered_questions.json', 'w', encoding='utf-8') as f:
        json.dump(questions, f, ensure_ascii=False, indent=2)
    
    # Afficher
    for i, q in enumerate(questions, 1):
        print(f"{i}. {q['question']}")
else:
    print("❌ Aucune question sans réponse trouvée")

print("\n" + "=" * 80)
