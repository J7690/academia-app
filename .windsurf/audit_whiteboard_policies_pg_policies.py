"""
AUDIT WHITEBOARD POLICIES - PG_POLICIES
Conforme aux normes supabase_audit_standards.md
"""

print("=" * 80)
print("AUDIT WHITEBOARD POLICIES - PG_POLICIES")
print("=" * 80)

print("\nURL Supabase : https://thevdfcwlcqzdoybfvgs.supabase.co")
print("Utilisateur : service_role (via SQL Editor)")
print("Schéma interrogé : pg_policies (vue système)")

print("\n" + "=" * 80)
print("REQUÊTE SQL À EXÉCUTER DANS LE SQL EDITOR")
print("=" * 80)

sql = """
SELECT
    schemaname,
    tablename,
    policyname
FROM pg_policies
WHERE
    tablename ILIKE '%whiteboard%'
ORDER BY
    schemaname,
    tablename;
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
