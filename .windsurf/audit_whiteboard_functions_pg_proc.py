"""
AUDIT WHITEBOARD FUNCTIONS - PG_PROC
Conforme aux normes supabase_audit_standards.md
"""

print("=" * 80)
print("AUDIT WHITEBOARD FUNCTIONS - PG_PROC")
print("=" * 80)

print("\nURL Supabase : https://thevdfcwlcqzdoybfvgs.supabase.co")
print("Utilisateur : service_role (via SQL Editor)")
print("Schéma interrogé : pg_proc (catalogue système)")

print("\n" + "=" * 80)
print("REQUÊTE SQL À EXÉCUTER DANS LE SQL EDITOR")
print("=" * 80)

sql = """
SELECT
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
ON n.oid = p.pronamespace
WHERE p.proname ILIKE '%whiteboard%'
ORDER BY
    n.nspname,
    p.proname;
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
