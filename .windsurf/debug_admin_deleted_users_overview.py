#!/usr/bin/env python3
"""Aperçu des comptes marqués supprimés et de leurs universités éventuelles.

Utilise SupabaseAutoManager/execute_sql_auto pour:
- lister les entrées app.user_admin_status.is_deleted = TRUE avec rôle et university_id,
- lister les universités actives liées à ces comptes (celles à potentiellement nettoyer).
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
    # 1) Universités: simple aperçu
    run_query(
        "Universités (max 20)",
        """
        SELECT id, name, slug, is_active, created_at
        FROM app.universities
        ORDER BY created_at DESC
        LIMIT 20;
        """,
    )

    # 2) Comptes marqués supprimés avec rôle + university_id
    run_query(
        "Comptes marqués is_deleted=TRUE (max 50)",
        """
        SELECT
            s.user_id,
            s.is_deleted,
            s.deleted_at,
            s.suspended_reason,
            au.email,
            au.raw_user_meta_data->>'role' AS role,
            au.raw_user_meta_data->>'university_id' AS university_id
        FROM app.user_admin_status s
        JOIN auth.users au ON au.id = s.user_id
        WHERE s.is_deleted = TRUE
        ORDER BY s.updated_at DESC
        LIMIT 50;
        """,
    )

    # 3) Universités actives liées à des comptes marqués supprimés (cibles de nettoyage)
    run_query(
        "Universités actives liées à des comptes supprimés (cibles nettoyage)",
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
          ON s.user_id = au.id AND s.is_deleted = TRUE
        WHERE u.is_active = TRUE
          AND au.raw_user_meta_data->>'role' = 'university'
        ORDER BY s.updated_at DESC
        LIMIT 50;
        """,
    )


if __name__ == "__main__":
    main()
