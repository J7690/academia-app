#!/usr/bin/env python3
"""Nettoyage des universités liées à des comptes université supprimés.

- Localise les comptes avec role = 'university' et is_deleted = TRUE dans app.user_admin_status.
- Met app.universities.is_active = FALSE pour les universités correspondantes.

À utiliser via RPC-PY (SupabaseAutoManager) sur l'instance active.
"""

from supabase_auto_manager import SupabaseAutoManager


def run_query(label: str, sql: str) -> None:
  print("\n==============================")
  print(label)
  print("------------------------------")
  m = SupabaseAutoManager()
  res = m.execute_sql_auto(sql)
  print(res)


def main() -> None:
  m = SupabaseAutoManager()

  # 1) Aperçu avant nettoyage
  run_query(
    "Universités liées à des comptes université is_deleted=TRUE (AVANT)",
    """
    SELECT
      u.id,
      u.name,
      u.slug,
      u.is_active,
      au.email,
      au.raw_user_meta_data->>'role' AS role,
      au.raw_user_meta_data->>'university_id' AS university_id,
      s.is_deleted,
      s.deleted_at
    FROM app.universities u
    JOIN auth.users au
      ON au.raw_user_meta_data->>'university_id' = u.id::text
    JOIN app.user_admin_status s
      ON s.user_id = au.id
    WHERE au.raw_user_meta_data->>'role' = 'university'
      AND s.is_deleted = TRUE
    ORDER BY u.name ASC
    LIMIT 100;
    """,
  )

  # 2) Mise à jour: désactiver ces universités côté étudiant
  print("\n==============================")
  print("Mise à jour des universités (set is_active = FALSE)...")
  print("------------------------------")
  update_sql = """
  UPDATE app.universities u
  SET is_active = FALSE,
      updated_at = NOW()
  WHERE EXISTS (
    SELECT 1
    FROM auth.users au
    JOIN app.user_admin_status s ON s.user_id = au.id
    WHERE au.raw_user_meta_data->>'role' = 'university'
      AND au.raw_user_meta_data->>'university_id' = u.id::text
      AND s.is_deleted = TRUE
  )
  RETURNING id, name, slug, is_active;
  """
  res_update = m.execute_sql_auto(update_sql)
  print(res_update)

  # 3) Vérification après nettoyage
  run_query(
    "Universités liées à des comptes université is_deleted=TRUE (APRES)",
    """
    SELECT
      u.id,
      u.name,
      u.slug,
      u.is_active,
      au.email,
      au.raw_user_meta_data->>'role' AS role,
      au.raw_user_meta_data->>'university_id' AS university_id,
      s.is_deleted,
      s.deleted_at
    FROM app.universities u
    JOIN auth.users au
      ON au.raw_user_meta_data->>'university_id' = u.id::text
    JOIN app.user_admin_status s
      ON s.user_id = au.id
    WHERE au.raw_user_meta_data->>'role' = 'university'
      AND s.is_deleted = TRUE
    ORDER BY u.name ASC
    LIMIT 100;
    """,
  )


if __name__ == "__main__":
  main()
