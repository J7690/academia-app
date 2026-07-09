"""
AUDIT WHITEBOARD TABLES - PG_CLASS
Conforme aux normes supabase_audit_standards.md
"""

print("=" * 80)
print("AUDIT WHITEBOARD TABLES - PG_CLASS")
print("=" * 80)

print("\nURL Supabase : https://thevdfcwlcqzdoybfvgs.supabase.co")
print("Utilisateur : service_role (via SQL Editor)")
print("Schéma interrogé : pg_class (catalogue système)")

print("\n" + "=" * 80)
print("REQUÊTE SQL À EXÉCUTER DANS LE SQL EDITOR")
print("=" * 80)

sql = """
SELECT
    n.nspname,
    c.relname,
    c.relkind
FROM pg_class c
JOIN pg_namespace n
ON n.oid = c.relnamespace
WHERE c.relname ILIKE '%whiteboard%'
ORDER BY
    n.nspname,
    c.relname;
"""

print(sql)

print("\n" + "=" * 80)
print("INSTRUCTIONS")
print("=" * 80)
print("1. Copier la requête SQL ci-dessus")
print("2. Ouvrir le SQL Editor sur https://supabase.com/dashboard/project/thevdfcwlcqzdoybfvgs/sql")
print("3. Coller et exécuter la requête")
print("4. Copier les résultats ici pour analyse")

print("\n" + "=" * 80)
print("ATTENTE DES RÉSULTATS...")
print("=" * 80)
