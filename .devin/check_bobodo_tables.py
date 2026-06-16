#!/usr/bin/env python3
"""Vérifier les tables Bobodo existantes"""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("VÉRIFICATION TABLES BOBODO")
print("=" * 80)

# Lister toutes les tables du schema app
result = manager.execute_sql_auto("""
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'app'
    ORDER BY table_name;
""")

if result and 'data' in result and len(result['data']) > 0:
    tables = [row['table_name'] for row in result['data']]
    
    # Filtrer les tables bobodo
    bobodo_tables = [t for t in tables if 'bobodo' in t.lower()]
    
    print(f"\nTotal tables app: {len(tables)}")
    print(f"Tables bobodo: {len(bobodo_tables)}")
    
    if bobodo_tables:
        print("\nTables bobodo trouvées:")
        for table in bobodo_tables:
            print(f"  - {table}")
            
            # Compter les enregistrements
            count_result = manager.execute_sql_auto(f"""
                SELECT COUNT(*) as count
                FROM app.{table};
            """)
            if count_result and 'data' in count_result and len(count_result['data']) > 0:
                count = count_result['data'][0]['count']
                print(f"    Enregistrements: {count}")
    else:
        print("\n❌ Aucune table bobodo trouvée")
else:
    print("\n❌ Erreur lors de la récupération des tables")
