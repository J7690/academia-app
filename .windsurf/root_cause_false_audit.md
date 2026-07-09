# ROOT CAUSE FALSE AUDIT

## CONTRADICTION IDENTIFIÉE

**Python via admin_execute_sql**: 0 résultats
**SQL Editor Supabase**: 43 résultats

## ANALYSE DES TESTS

### Test 1: Vérifier si admin_execute_sql existe
```sql
SELECT proname, pg_get_function_identity_arguments(oid) as signature
FROM pg_proc
WHERE proname = 'admin_execute_sql';
```

**Résultat**: `{"ok": true, "mode": "exec", "affected_rows": 1}`

**Conclusion**: admin_execute_sql existe et fonctionne pour les commandes DML/DDL.

### Test 2: Compter toutes les fonctions dans pg_proc
```sql
SELECT COUNT(*) FROM pg_proc;
```

**Résultat**: `{"ok": false, "error": "syntax error at or near \";\"", "sqlstate": "42601"}`

**Conclusion**: admin_execute_sql **NE RETOURNE PAS DE DONNÉES DE SELECT**.

### Test 3: Lister tous les schémas
```sql
SELECT schema_name FROM information_schema.schemata ...
```

**Résultat**: `{"ok": true, "mode": "exec", "affected_rows": 114}`

**Conclusion**: admin_execute_sql exécute la commande mais ne retourne pas les données.

### Test 4: Vérifier pg_namespace
```sql
SELECT nspname, oid FROM pg_namespace ...
```

**Résultat**: `{"ok": true, "mode": "exec", "affected_rows": 12}`

**Conclusion**: admin_execute_sql exécute la commande mais ne retourne pas les données.

## CAUSE RACINE

**admin_execute_sql est une RPC conçue pour exécuter des commandes DML/DDL (INSERT, UPDATE, DELETE, CREATE, DROP), PAS pour retourner des données de SELECT.**

Elle retourne uniquement :
```json
{
  "ok": true/false,
  "mode": "exec",
  "affected_rows": X
}
```

Elle ne retourne JAMAIS les données d'un SELECT.

## POURQUOI L'AUDIT RETOURNAIT 0

Mon script Python utilisait admin_execute_sql pour exécuter des SELECT sur pg_proc. La RPC exécutait la requête mais ne retournait pas les données. Mon code interprétait `resp.get('data', [])` qui retournait toujours un tableau vide.

## SOLUTION

Il faut utiliser une autre méthode pour exécuter des SELECT et récupérer les données :

1. **Option 1**: Utiliser l'API REST PostgREST directement sur les tables système (si accessible)
2. **Option 2**: Créer une nouvelle RPC wrapper qui exécute des SELECT et retourne les données
3. **Option 3**: Utiliser le SQL Editor Supabase manuellement (ce que l'utilisateur fait déjà)

## CONCLUSION

L'audit Python était incorrect car admin_execute_sql ne peut pas retourner de données de SELECT. Les 43 fonctions whiteboard existent bien dans la base de données, mais mon script ne pouvait pas les voir.
