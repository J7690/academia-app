"""
AUDIT WHITEBOARD TRIGGERS - PG_TRIGGER
Conforme aux normes supabase_audit_standards.md
"""

print("=" * 80)
print("AUDIT WHITEBOARD TRIGGERS - PG_TRIGGER")
print("=" * 80)

print("\nURL Supabase : https://thevdfcwlcqzdoybfvgs.supabase.co")
print("Utilisateur : service_role (via SQL Editor)")
print("Schéma interrogé : pg_trigger (catalogue système)")

print("\n" + "=" * 80)
print("REQUÊTE SQL À EXÉCUTER DANS LE SQL EDITOR")
print("=" * 80)

sql = """
SELECT
    n.nspname,
    c.relname,
    t.tgname
FROM pg_trigger t
JOIN pg_class c
ON c.oid = t.tgrelid
JOIN pg_namespace n
ON n.oid = c.relnamespace
WHERE
    NOT t.tgisinternal
    AND (
        c.relname ILIKE '%whiteboard%'
        OR t.tgname ILIKE '%whiteboard%'
    )
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
