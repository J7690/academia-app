SELECT
  to_regclass('supabase_functions.functions') AS functions_table,
  to_regclass('supabase_functions.migrations') AS migrations_table,
  current_database() AS db;
