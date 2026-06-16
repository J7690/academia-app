#!/usr/bin/env python3
"""Nettoyage ciblé des universités liées à des comptes université supprimés.

Utilise directement la RPC admin_execute_sql (via auto_supabase_import):
- Liste les comptes avec role = 'university' et leur éventuelle université liée.
- Met app.universities.is_active = FALSE pour les universités dont le compte est marqué is_deleted = TRUE.
- Affiche un avant / après.
"""

import json
import textwrap
import requests

import auto_supabase_import as a


URL = f"{a.SUPABASE_URL}/rest/v1/rpc/admin_execute_sql"
HEADERS = a.RPC_HEADERS


def run_sql(label: str, sql: str) -> None:
    print("\n==============================")
    print(label)
    print("------------------------------")
    sql = textwrap.dedent(sql).strip()
    try:
        r = requests.post(URL, headers=HEADERS, json={"p_sql": sql}, timeout=60)
    except Exception as exc:
        print("network_error", str(exc))
        return
    print("status", r.status_code)
    try:
        data = r.json()
        print(json.dumps(data, indent=2, ensure_ascii=False)[:2000])
    except Exception:
        print(r.text[:2000])


def main() -> None:
    # 1) Aperçu des comptes université et du lien avec app.universities
    run_sql(
        "Comptes université et mapping vers app.universities (AVANT)",
        """
        SELECT
          u.id               AS university_id,
          u.name             AS university_name,
          u.slug             AS university_slug,
          u.is_active        AS university_is_active,
          au.id              AS user_id,
          au.email           AS user_email,
          au.raw_user_meta_data->>'role' AS role,
          au.raw_user_meta_data->>'university_id' AS user_university_id,
          s.is_deleted,
          s.deleted_at
        FROM auth.users au
        LEFT JOIN app.user_admin_status s ON s.user_id = au.id
        LEFT JOIN app.universities u
          ON u.id::text = au.raw_user_meta_data->>'university_id'
        WHERE au.raw_user_meta_data->>'role' = 'university'
        ORDER BY u.name NULLS LAST, au.created_at DESC
        LIMIT 200;
        """,
    )

    # 2) Mise à jour: désactiver les universités dont le compte est marqué supprimé
    run_sql(
        "UPDATE: set is_active = FALSE pour les universités liées à des comptes is_deleted=TRUE",
        """
        UPDATE app.universities u
        SET is_active = FALSE,
            updated_at = NOW()
        WHERE u.id IN (
          SELECT u2.id
          FROM auth.users au2
          JOIN app.user_admin_status s2 ON s2.user_id = au2.id
          JOIN app.universities u2
            ON u2.id::text = au2.raw_user_meta_data->>'university_id'
          WHERE au2.raw_user_meta_data->>'role' = 'university'
            AND s2.is_deleted = TRUE
            AND COALESCE(u2.is_active, TRUE) = TRUE
        )
        RETURNING id, name, slug, is_active;
        """,
    )

    # 3) Vérification après mise à jour
    run_sql(
        "Comptes université et mapping vers app.universities (APRES)",
        """
        SELECT
          u.id               AS university_id,
          u.name             AS university_name,
          u.slug             AS university_slug,
          u.is_active        AS university_is_active,
          au.id              AS user_id,
          au.email           AS user_email,
          au.raw_user_meta_data->>'role' AS role,
          au.raw_user_meta_data->>'university_id' AS user_university_id,
          s.is_deleted,
          s.deleted_at
        FROM auth.users au
        LEFT JOIN app.user_admin_status s ON s.user_id = au.id
        LEFT JOIN app.universities u
          ON u.id::text = au.raw_user_meta_data->>'university_id'
        WHERE au.raw_user_meta_data->>'role' = 'university'
        ORDER BY u.name NULLS LAST, au.created_at DESC
        LIMIT 200;
        """,
    )


if __name__ == "__main__":
    main()
