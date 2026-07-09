# AUDIT PG_PROC RAW

## REQUÊTE SQL EXACTE DU SQL EDITOR

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

## RÉSULTAT OBTENU VIA PYTHON (admin_execute_sql)

**Nombre total de fonctions whiteboard trouvées**: 0

**Liste complète**: (vide)

## RÉSULTAT AFFIRMÉ PAR L'UTILISATEUR (SQL Editor Supabase)

**Nombre total de fonctions whiteboard trouvées**: 43

**Fonctions mentionnées**:
- app.whiteboard_create_project
- public.whiteboard_create_project
- whiteboard_update_project
- whiteboard_list_projects
- whiteboard_delete_project
- etc.

## CONTRADICTION

Python via admin_execute_sql: 0 résultats
SQL Editor Supabase: 43 résultats

## ENDPOINT UTILISÉ

`https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql`

## MÉTHODE

POST avec paramètre `p_sql`
