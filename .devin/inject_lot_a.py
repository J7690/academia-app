#!/usr/bin/env python3
"""Injection LOT A Bobodo Knowledge"""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("INJECTION LOT A – BOBODO KNOWLEDGE")
print("=" * 80)

# Lire le script SQL
with open('sql_changes/change_20260608_lot_a_bobodo_knowledge.sql', 'r', encoding='utf-8') as f:
    sql_script = f.read()

print("\nExécution du script SQL...")

# Exécuter chaque instruction INSERT individuellement
lines = sql_script.split('\n')
current_insert = []
in_insert = False
success_count = 0

for line in lines:
    if 'INSERT INTO app.bobodo_knowledge' in line:
        in_insert = True
        current_insert = [line]
    elif in_insert:
        current_insert.append(line)
        if line.strip().endswith(');'):
            # Exécuter l'INSERT complet
            insert_sql = '\n'.join(current_insert)
            try:
                result = manager.execute_sql_auto(insert_sql)
                if result and 'error' in result:
                    print(f"❌ Erreur INSERT: {result['error']}")
                else:
                    print(f"✅ INSERT exécuté avec succès")
                    success_count += 1
            except Exception as e:
                print(f"❌ Erreur INSERT: {e}")
            current_insert = []
            in_insert = False

print(f"\n{success_count} INSERT(s) exécuté(s) avec succès")
print("=" * 80)
