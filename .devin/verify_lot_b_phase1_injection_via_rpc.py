#!/usr/bin/env python3
"""Vérification injection LOT B Phase 1 via RPC admin_execute_sql"""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("VÉRIFICATION INJECTION LOT B PHASE 1 - VIA RPC")
print("=" * 80)

# Compter les fiches avant injection
print("\n--- Comptage des fiches ---")
result = manager.execute_sql_auto("""
    SELECT COUNT(*) as count
    FROM app.bobodo_knowledge;
""")

if result and 'data' in result and len(result['data']) > 0:
    count = result['data'][0]['count']
    print(f"Nombre total de fiches : {count}")
else:
    print("❌ Erreur lors du comptage")

# Vérifier les 5 nouvelles fiches
print("\n--- Vérification des 5 nouvelles fiches ---")
new_fiches = [
    "Comment créer un compte sur Academia ?",
    "Comment modifier mon profil ?",
    "Mon paiement est en attente",
    "Ma candidature est bloquée",
    "Comment accéder aux cours d''appui ?"
]

for fiche_title in new_fiches:
    result = manager.execute_sql_auto(f"""
        SELECT id, title, category, tags, is_active, created_at
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
        print(f"   Créé le : {fiche['created_at']}")
    else:
        print(f"❌ {fiche_title} - NON TROUVÉE")

print("\n" + "=" * 80)
print("VÉRIFICATION TERMINÉE")
print("=" * 80)
