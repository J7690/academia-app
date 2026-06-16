#!/usr/bin/env python3
"""Injection LOT B Phase 1 - 5 fiches CRITIQUES"""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("INJECTION LOT B PHASE 1 - 5 FICHES CRITIQUES")
print("=" * 80)

# Compter les fiches avant injection
print("\n--- Comptage avant injection ---")
result = manager.execute_sql_auto("""
    SELECT COUNT(*) as count
    FROM app.bobodo_knowledge;
""")

if result and 'data' in result and len(result['data']) > 0:
    count_before = result['data'][0]['count']
    print(f"Nombre de fiches avant injection : {count_before}")
else:
    print("❌ Erreur lors du comptage avant injection")
    count_before = 0

# Lire le fichier SQL
print("\n--- Lecture du fichier SQL ---")
with open('LOT_B_PHASE1_SQL.sql', 'r', encoding='utf-8') as f:
    sql_content = f.read()

print(f"Taille du fichier SQL : {len(sql_content)} caractères")

# Exécuter le SQL
print("\n--- Exécution du SQL ---")
try:
    result = manager.execute_sql_auto(sql_content)
    if result and 'error' in result:
        print(f"❌ Erreur SQL : {result['error']}")
    else:
        print("✅ SQL exécuté avec succès")
except Exception as e:
    print(f"❌ Erreur lors de l'exécution : {e}")

# Compter les fiches après injection
print("\n--- Comptage après injection ---")
result = manager.execute_sql_auto("""
    SELECT COUNT(*) as count
    FROM app.bobodo_knowledge;
""")

if result and 'data' in result and len(result['data']) > 0:
    count_after = result['data'][0]['count']
    print(f"Nombre de fiches après injection : {count_after}")
    print(f"Différence : {count_after - count_before} fiches ajoutées")
else:
    print("❌ Erreur lors du comptage après injection")
    count_after = 0

# Vérifier les 5 nouvelles fiches
print("\n--- Vérification des 5 nouvelles fiches ---")
new_fiches = [
    "Comment créer un compte sur Academia ?",
    "Comment modifier mon profil ?",
    "Mon paiement est en attente",
    "Ma candidature est bloquée",
    "Comment accéder aux cours d'appui ?"
]

for fiche_title in new_fiches:
    result = manager.execute_sql_auto(f"""
        SELECT id, title, category, tags, is_active
        FROM app.bobodo_knowledge
        WHERE title = '{fiche_title}';
    """)
    
    if result and 'data' in result and len(result['data']) > 0:
        fiche = result['data'][0]
        print(f"✅ {fiche_title}")
        print(f"   ID : {fiche['id']}")
        print(f"   Catégorie : {fiche['category']}")
        print(f"   Tags : {fiche['tags']}")
        print(f"   Actif : {fiche['is_active']}")
    else:
        print(f"❌ {fiche_title} - NON TROUVÉE")

print("\n" + "=" * 80)
print("INJECTION TERMINÉE")
print("=" * 80)
