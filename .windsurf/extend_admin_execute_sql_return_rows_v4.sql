-- Application via admin_execute_sql
-- Fix v4: détection SELECT/WITH sans regex d'échappement (compatible standard_conforming_strings).

CREATE OR REPLACE FUNCTION public.admin_execute_sql(p_sql TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  clean_sql TEXT;
  clean_lower TEXT;
  rows_json JSONB;
  affected_rows BIGINT;
BEGIN
  clean_sql := TRIM(p_sql);
  clean_lower := LOWER(clean_sql);

  -- Rejeter les commandes DB-level dangereuses (même en admin)
  IF clean_lower ~ '(drop\s+database|alter\s+database|create\s+database|truncate\s+database)' THEN
    RETURN JSONB_BUILD_OBJECT('ok', false, 'error', 'Commande non autorisée');
  END IF;

  -- Détection SELECT/WITH
  IF clean_lower = 'select' OR clean_lower LIKE 'select %' OR clean_lower = 'with' OR clean_lower LIKE 'with %' THEN
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
