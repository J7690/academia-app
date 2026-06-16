#!/usr/bin/env python3
"""Analyse des questions réelles utilisateurs Bobodo"""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("ANALYSE QUESTIONS RÉELLES UTILISATEURS BOBODO")
print("=" * 80)

# Vérifier les tables existantes
tables_to_check = [
    'bobodo_messages',
    'bobodo_detected_needs',
    'bobodo_unanswered_questions',
    'bobodo_feedback',
]

print("\nVérification des tables...")
for table in tables_to_check:
    result = manager.execute_sql_auto(f"""
        SELECT EXISTS (
            SELECT FROM information_schema.tables 
            WHERE table_schema = 'app' 
            AND table_name = '{table}'
        );
    """)
    if result and 'data' in result and len(result['data']) > 0:
        exists = result['data'][0]['exists']
        print(f"  {table}: {'✅ EXISTS' if exists else '❌ NOT EXISTS'}")
    else:
        print(f"  {table}: ❌ ERROR")

# Analyser bobodo_messages
print("\n" + "=" * 80)
print("ANALYSE BOBODO_MESSAGES")
print("=" * 80)

result = manager.execute_sql_auto("""
    SELECT COUNT(*) as total_messages
    FROM app.bobodo_messages
    WHERE sender = 'student';
""")

if result and 'data' in result and len(result['data']) > 0:
    total_messages = result['data'][0]['total_messages']
    print(f"\nTotal messages étudiants: {total_messages}")
else:
    print("\n❌ Erreur lors de la récupération des messages")
    total_messages = 0

if total_messages > 0:
    # 50 questions les plus fréquentes
    print("\n--- 50 messages les plus fréquents ---")
    result = manager.execute_sql_auto("""
        SELECT 
            content,
            COUNT(*) as frequency
        FROM app.bobodo_messages
        WHERE sender = 'student'
        GROUP BY content
        ORDER BY frequency DESC
        LIMIT 50;
    """)
    
    if result and 'data' in result and len(result['data']) > 0:
        for i, row in enumerate(result['data'], 1):
            content = row['content'][:100] + "..." if len(row['content']) > 100 else row['content']
            print(f"{i}. [{row['frequency']}] {content}")
    
    # Thèmes les plus fréquents (basés sur les mots-clés)
    print("\n--- Thèmes les plus fréquents ---")
    keywords = [
        'candidature', 'candidat', 'postuler',
        'paiement', 'crédit', 'payer',
        'université', 'partenaire', 'formation',
        'document', 'dossier',
        'compte', 'inscription', 'profil',
        'support', 'contact', 'aide',
        'challenge', 'live', 'opportunité',
        'td', 'travaux dirigés', 'cours',
        'concours', 'préparation',
        'orientation', 'emploi',
        'notification', 'message',
        'mot de passe', 'mdp',
        'supprimer', 'désactiver',
    ]
    
    for keyword in keywords:
        result = manager.execute_sql_auto(f"""
            SELECT COUNT(*) as count
            FROM app.bobodo_messages
            WHERE sender = 'student'
              AND content ILIKE '%{keyword}%';
        """)
        if result and 'data' in result and len(result['data']) > 0:
            count = result['data'][0]['count']
            if count > 0:
                print(f"  {keyword}: {count}")

# Analyser bobodo_feedback
print("\n" + "=" * 80)
print("ANALYSE BOBODO_FEEDBACK")
print("=" * 80)

result = manager.execute_sql_auto("""
    SELECT COUNT(*) as total_feedback,
           COUNT(CASE WHEN rating = 'up' THEN 1 END) as positive,
           COUNT(CASE WHEN rating = 'down' THEN 1 END) as negative
    FROM app.bobodo_feedback;
""")

if result and 'data' in result and len(result['data']) > 0:
    total_feedback = result['data'][0]['total_feedback']
    positive = result['data'][0]['positive']
    negative = result['data'][0]['negative']
    print(f"\nTotal feedback: {total_feedback}")
    print(f"  Positifs (up): {positive}")
    print(f"  Négatifs (down): {negative}")
    
    if negative > 0:
        print("\n--- Commentaires feedback négatif ---")
        result = manager.execute_sql_auto("""
            SELECT comment
            FROM app.bobodo_feedback
            WHERE rating = 'down'
              AND comment IS NOT NULL
              AND comment != ''
            LIMIT 20;
        """)
        if result and 'data' in result and len(result['data']) > 0:
            for i, row in enumerate(result['data'], 1):
                comment = row['comment'][:100] + "..." if len(row['comment']) > 100 else row['comment']
                print(f"{i}. {comment}")

# Vérifier les autres tables
print("\n" + "=" * 80)
print("VÉRIFICATION TABLES SUPPLÉMENTAIRES")
print("=" * 80)

for table in ['bobodo_detected_needs', 'bobodo_unanswered_questions']:
    result = manager.execute_sql_auto(f"""
        SELECT COUNT(*) as count
        FROM app.{table};
    """)
    if result and 'data' in result and len(result['data']) > 0:
        count = result['data'][0]['count']
        print(f"\n{table}: {count} enregistrements")
        
        if count > 0:
            result = manager.execute_sql_auto(f"""
                SELECT *
                FROM app.{table}
                LIMIT 10;
            """)
            if result and 'data' in result and len(result['data']) > 0:
                print("  Exemples:")
                for i, row in enumerate(result['data'], 1):
                    print(f"    {i}. {row}")
    else:
        print(f"\n{table}: ❌ Erreur")

print("\n" + "=" * 80)
print("ANALYSE TERMINÉE")
print("=" * 80)
