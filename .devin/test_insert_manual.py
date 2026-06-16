#!/usr/bin/env python3
"""Test insertion manuelle"""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("TEST INSERTION MANUELLE")
print("=" * 80)

# Essayer d'insérer une fiche de test
test_insert = """
INSERT INTO app.bobodo_knowledge (title, content, category, tags)
VALUES (
    'TEST INJECTION LOT A',
    'Ceci est un test pour vérifier l''injection.',
    'NEXIOM_ACADEMIA_INTERNE',
    ARRAY['test']
)
"""

print("\nExécution de l'INSERT de test...")
result = manager.execute_sql_auto(test_insert)

if result and 'error' in result:
    print(f"❌ Erreur: {result['error']}")
else:
    print(f"✅ INSERT exécuté")
    print(f"Résultat: {result}")

# Vérifier si la fiche a été créée
print("\nVérification de la fiche de test...")
result = manager.execute_sql_auto("""
    SELECT id, title, created_at
    FROM app.bobodo_knowledge
    WHERE title = 'TEST INJECTION LOT A'
""")

if result and 'data' in result and len(result['data']) > 0:
    print(f"✅ Fiche de test trouvée: {result['data'][0]}")
else:
    print("❌ Fiche de test non trouvée")

print("=" * 80)
