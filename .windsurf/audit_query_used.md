# AUDIT QUERY USED

## FICHIER
`c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\audit_whiteboard_rpc_inventory.py`

## FONCTION
`execute_sql(sql)` (lignes 11-13)

```python
def execute_sql(sql):
    resp = requests.post(admin_url, headers=headers, json={"p_sql": sql}, timeout=30)
    return resp.json()
```

## ENDPOINT
`https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql`

## MÉTHODE
POST

## PARAMÈTRES
```json
{
  "p_sql": "<SQL_QUERY>"
}
```

## SQL EXÉCUTÉ (lignes 20-30)
```sql
SELECT
    oid,
    proname,
    pg_get_function_identity_arguments(oid) as signature,
    pg_get_functiondef(oid) as full_definition,
    pronamespace::regnamespace as schema
FROM pg_proc
WHERE proname LIKE '%whiteboard%'
ORDER BY schema, proname, oid;
```

## RÉSULTAT OBTENU
```
Nombre total de fonctions whiteboard trouvées : 0
```

## DIFFÉRENCES AVEC LA REQUÊTE SQL EDITOR

### Requête SQL Editor (celle qui retourne 43 résultats)
```sql
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
```

### Différences identifiées
1. **JOIN vs cast**: SQL Editor utilise `JOIN pg_namespace n ON n.oid = p.pronamespace`, ma requête utilise `pronamespace::regnamespace`
2. **LIKE vs ILIKE**: SQL Editor utilise `ILIKE` (case-insensitive), ma requête utilise `LIKE` (case-sensitive)
3. **Colonnes retournées**: SQL Editor retourne moins de colonnes (schema_name, function_name, arguments)

### Analyse
Ces différences ne devraient pas causer un retour de 0 résultats si les fonctions existent vraiment. Le problème est probablement ailleurs.
