#!/usr/bin/env python3
"""Audit existing media/images architecture in Supabase.

Checks:
- storage buckets relevant to marketplace
- existing tables/columns that could store listing media

Writes .windsurf/logs/audit_marketplace_images_existing.json
"""

import json
from typing import Any, Dict, List, Tuple

import requests

from supabase_auto_manager import SupabaseAutoManager


def run_sql(m: SupabaseAutoManager, label: str, sql: str, timeout: int = 120) -> Dict[str, Any]:
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    resp = requests.post(url, headers=m.headers, json={"p_sql": sql}, timeout=timeout)
    try:
        data = resp.json()
    except Exception:
        return {"label": label, "http": resp.status_code, "ok": False, "raw": (resp.text or "")[:2000]}

    if isinstance(data, dict):
        rows = data.get("rows")
        return {
            "label": label,
            "http": resp.status_code,
            "ok": bool(data.get("ok")),
            "mode": data.get("mode"),
            "rows": rows if isinstance(rows, list) else [],
            "error": data.get("error"),
            "sqlstate": data.get("sqlstate"),
        }

    if isinstance(data, list):
        return {"label": label, "http": resp.status_code, "ok": True, "mode": "select", "rows": data}

    return {"label": label, "http": resp.status_code, "ok": False, "error": "unexpected_json_type"}


def main() -> int:
    m = SupabaseAutoManager()

    queries: List[Tuple[str, str]] = [
        (
            "STORAGE_BUCKETS",
            """
            SELECT id, name, public
            FROM storage.buckets
            ORDER BY name
            """.strip(),
        ),
        (
            "APP_TABLES_LIKE_MEDIA",
            """
            SELECT table_schema, table_name
            FROM information_schema.tables
            WHERE table_schema IN ('app','public')
              AND table_name ILIKE '%media%'
            ORDER BY table_schema, table_name
            """.strip(),
        ),
        (
            "APP_COLS_LISTINGS_LIKE_MEDIA",
            """
            SELECT column_name, data_type
            FROM information_schema.columns
            WHERE table_schema='app'
              AND table_name='marketplace_listings'
              AND (
                column_name ILIKE '%image%'
                OR column_name ILIKE '%photo%'
                OR column_name ILIKE '%cover%'
                OR column_name ILIKE '%media%'
                OR column_name ILIKE '%thumbnail%'
                OR column_name ILIKE '%gallery%'
              )
            ORDER BY column_name
            """.strip(),
        ),
        (
            "APP_TABLES_LIKE_LISTING_MEDIA",
            """
            SELECT table_schema, table_name
            FROM information_schema.tables
            WHERE table_schema='app'
              AND (
                table_name ILIKE '%listing%media%'
                OR table_name ILIKE '%marketplace%media%'
                OR table_name ILIKE '%listing%image%'
              )
            ORDER BY table_schema, table_name
            """.strip(),
        ),
        (
            "STORAGE_POLICIES",
            """
            SELECT schemaname, tablename, policyname, cmd, roles
            FROM pg_policies
            WHERE schemaname='storage' AND tablename='objects'
            ORDER BY policyname
            """.strip(),
        ),
    ]

    out: Dict[str, Any] = {}
    for label, sql in queries:
        print(f"Exécution: {label}...")
        res = run_sql(m, label, sql)
        out[label] = {
            "ok": res.get("ok"),
            "http": res.get("http"),
            "mode": res.get("mode"),
            "rows": res.get("rows"),
            "error": res.get("error"),
            "sqlstate": res.get("sqlstate"),
        }
        if res.get("ok"):
            print(f"  ✓ {label}: {len(res.get('rows') or [])} lignes")
        else:
            print(f"  ✗ {label}: {res.get('error')}")

    out_path = ".windsurf/logs/audit_marketplace_images_existing.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    print(f"\n[OK] Résultats sauvegardés dans {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
