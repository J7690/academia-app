#!/usr/bin/env python3
from __future__ import annotations

"""Audit du module bibliothèque de cours via admin_execute_sql (procédure .windsurf).

- Vérifie l'existence des tables app.course_domains / app.course_units / app.course_resources
- Affiche quelques lignes réelles de chaque table

Ce script est *en lecture seule* (SELECT uniquement).
"""

import json
from typing import Any

import requests

from auto_supabase_import import SUPABASE_URL, SUPABASE_SERVICE_KEY


HEADERS = {
    "apikey": SUPABASE_SERVICE_KEY,
    "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
    "Content-Type": "application/json",
}


def run_sql(label: str, sql: str) -> None:
    url = f"{SUPABASE_URL}/rest/v1/rpc/admin_execute_sql"
    print("\n===", label, "===")
    print(sql)
    try:
        resp = requests.post(url, headers=HEADERS, json={"p_sql": sql}, timeout=30)
    except Exception as exc:
        print("[ERROR] Exception réseau:", exc)
        return

    print("STATUS", resp.status_code)
    try:
        body: Any = resp.json()
        print("BODY", json.dumps(body, ensure_ascii=False, indent=2)[:4000])
    except Exception:
        print("BODY_RAW", resp.text[:4000])


def main() -> int:
    # 1) Vérifier l'existence des tables
    run_sql(
        "CHECK course tables exist",
        """
        SELECT
          (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'course_domains')) AS course_domains_table_exists,
          (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'course_units')) AS course_units_table_exists,
          (SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'course_resources')) AS course_resources_table_exists;
        """.strip(),
    )

    # 2) Compter les enregistrements
    run_sql(
        "COUNT course tables",
        """
        SELECT
          (SELECT COUNT(*) FROM app.course_domains) AS course_domains_count,
          (SELECT COUNT(*) FROM app.course_units) AS course_units_count,
          (SELECT COUNT(*) FROM app.course_resources) AS course_resources_count;
        """.strip(),
    )

    # 3) Lister quelques domaines / unités / ressources pour audit visuel
    run_sql(
        "LIST course_domains",
        """
        SELECT id, title, description, sort_order, is_active, created_at, updated_at
        FROM app.course_domains
        ORDER BY created_at DESC
        LIMIT 20;
        """.strip(),
    )

    run_sql(
        "LIST course_units",
        """
        SELECT id, domain_id, title, description, sort_order, is_active, created_at, updated_at
        FROM app.course_units
        ORDER BY created_at DESC
        LIMIT 20;
        """.strip(),
    )

    run_sql(
        "LIST course_resources",
        """
        SELECT id, unit_id, title, description, resource_type, storage_bucket, storage_path,
               external_url, mux_playback_id, sort_order, is_active, created_at, updated_at
        FROM app.course_resources
        ORDER BY created_at DESC
        LIMIT 20;
        """.strip(),
    )

    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
