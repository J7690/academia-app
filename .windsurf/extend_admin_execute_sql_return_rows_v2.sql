-- Application via admin_execute_sql
-- Fix: détecter correctement SELECT/WITH et retourner les rows.

CREATE OR REPLACE FUNCTION public.admin_execute_sql(p_sql TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  clean_sql TEXT;
  rows_json JSONB;
  affected_rows BIGINT;
BEGIN
  clean_sql := TRIM(p_sql);

  -- Rejeter les commandes DB-level dangereuses (même en admin)
  IF clean_sql ~* '(DROP\s+DATABASE|ALTER\s+DATABASE|CREATE\s+DATABASE|TRUNCATE\s+DATABASE)' THEN
    RETURN JSONB_BUILD_OBJECT('ok', false, 'error', 'Commande non autorisée');
  END IF;

  -- Détection SELECT (inclut WITH ...)
  IF clean_sql ~* '^\s*SELECT\b' OR clean_sql ~* '^\s*WITH\b' THEN
    EXECUTE 'SELECT COALESCE(JSONB_AGG(TO_JSONB(t)), ''[]''::JSONB) FROM (' || clean_sql || ') t'
      INTO rows_json;

    RETURN JSONB_BUILD_OBJECT(
      'ok', true,
      'mode', 'select',
      'rows', COALESCE(rows_json, '[]'::JSONB)
    );
  END IF;

  -- Non-SELECT : exécuter sans renvoyer de rows
  EXECUTE clean_sql;
  GET DIAGNOSTICS affected_rows = ROW_COUNT;

  RETURN JSONB_BUILD_OBJECT(
    'ok', true,
    'mode', 'exec',
    'affected_rows', COALESCE(affected_rows, 0)
  );
EXCEPTION WHEN OTHERS THEN
  RETURN JSONB_BUILD_OBJECT(
    'ok', false,
    'error', SQLERRM,
    'sqlstate', SQLSTATE
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_execute_sql(TEXT) TO service_role;
