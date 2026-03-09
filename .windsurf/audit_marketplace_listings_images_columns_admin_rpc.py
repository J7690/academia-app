#!/usr/bin/env python3
"""Audit marketplace_listings: detect image/media-related columns.

Writes .windsurf/logs/audit_marketplace_listings_images_columns.json
"""

import json
from typing import Any, Dict

import requests

from supabase_auto_manager import SupabaseAutoManager


def run_sql(m: SupabaseAutoManager, label: str, sql: str, timeout: int = 120) -> Dict[str, Any]:
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    resp = requests.post(url, headers=m.headers, json={"p_sql": sql}, timeout=timeout)
    try:
        data = resp.json()
    except Exception:
        return {
            "label": label,
            "http": resp.status_code,
            "ok": False,
            "raw": (resp.text or "")[:2000],
        }

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

    sql = """SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'app'
  AND table_name = 'marketplace_listings'
  AND (
    column_name ILIKE '%image%'
    OR column_name ILIKE '%photo%'
    OR column_name ILIKE '%cover%'
    OR column_name ILIKE '%media%'
    OR column_name ILIKE '%thumbnail%'
    OR column_name ILIKE '%gallery%'
  )
ORDER BY column_name""".strip()

    res = run_sql(m, "MARKETPLACE_LISTINGS_IMAGE_COLUMNS", sql)

    out = {
        "MARKETPLACE_LISTINGS_IMAGE_COLUMNS": {
            "ok": res.get("ok"),
            "http": res.get("http"),
            "mode": res.get("mode"),
            "rows": res.get("rows"),
            "error": res.get("error"),
            "sqlstate": res.get("sqlstate"),
        }
    }

    out_path = ".windsurf/logs/audit_marketplace_listings_images_columns.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    print(f"[OK] Résultats sauvegardés dans {out_path}")
    rows = out["MARKETPLACE_LISTINGS_IMAGE_COLUMNS"].get("rows") or []
    print(f"Colonnes détectées: {len(rows)}")
    for r in rows:
        if isinstance(r, dict):
            print(f"- {r.get('column_name')} ({r.get('data_type')})")
        else:
            print(f"- {r}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
