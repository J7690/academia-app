#!/usr/bin/env python3
"""Forcer la base pour que seule l'université IIM reste active.

- Liste les universités (AVANT)
- Met is_active = TRUE pour IIM, FALSE pour toutes les autres
- Liste les universités (APRES)

Utilise la RPC public.admin_execute_sql via auto_supabase_import.
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
    # 1) Universités avant
    run_sql(
        "Universités (AVANT)",
        """
        SELECT id, name, slug, is_active
        FROM app.universities
        ORDER BY name ASC
        LIMIT 100
        """,
    )

    # 2) S'assurer qu'IIM est bien active
    run_sql(
        "UPDATE: forcer IIM en is_active = TRUE",
        """
        UPDATE app.universities
        SET is_active = TRUE,
            updated_at = NOW()
        WHERE name = 'IIM'
        """,
    )

    # 3) Désactiver toutes les autres universités
    run_sql(
        "UPDATE: toutes les universités sauf IIM passent à is_active = FALSE",
        """
        UPDATE app.universities
        SET is_active = FALSE,
            updated_at = NOW()
        WHERE name <> 'IIM'
        """,
    )

    # 4) Universités après
    run_sql(
        "Universités (APRES)",
        """
        SELECT id, name, slug, is_active
        FROM app.universities
        ORDER BY name ASC
        LIMIT 100
        """,
    )


if __name__ == "__main__":
    main()
