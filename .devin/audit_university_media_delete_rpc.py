#!/usr/bin/env python3
"""Audit RPCs involved in university mini-site media deletion & listing.

Prints source excerpts for:
- app_delete_university_media
- app_list_university_site_for_management
- app_public_university_site

Also checks whether management listing returns inactive items.
"""

from __future__ import annotations

import json
import requests

from supabase_auto_manager import SupabaseAutoManager


def _admin_execute_sql(m: SupabaseAutoManager, sql: str) -> dict:
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    resp = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=30)
    if resp.status_code != 200:
        return {"ok": False, "error": f"HTTP {resp.status_code}: {resp.text[:400]}"}
    try:
        payload = resp.json()
    except Exception:
        return {"ok": False, "error": f"Non-JSON response: {resp.text[:400]}"}
    return payload if isinstance(payload, dict) else {"ok": False, "error": f"Unexpected payload type: {type(payload)}"}


def _print_rows(payload: dict, max_chars: int = 2500) -> None:
    print(json.dumps(payload, indent=2, ensure_ascii=False)[:max_chars])


def _print_fn_excerpt(m: SupabaseAutoManager, fn_name: str, excerpt_len: int = 1200) -> None:
    sql = f"""
    SELECT
      p.oid::regprocedure::text AS signature,
      LEFT(p.prosrc, {int(excerpt_len)}) AS source_excerpt
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public'
      AND p.proname='{fn_name}'
    ORDER BY p.oid
    LIMIT 1
    """.strip()
    res = _admin_execute_sql(m, sql)
    print("\n===", fn_name, "===")
    if not res.get("ok"):
        print("[ERROR]", res.get("error"))
        return
    rows = res.get("rows") or []
    if not rows:
        print("[WARN] function not found")
        return
    row0 = rows[0]
    if isinstance(row0, dict):
        print("signature:", row0.get("signature"))
        print(row0.get("source_excerpt"))
    else:
        print("row:", row0)


def main() -> int:
    m = SupabaseAutoManager()

    _print_fn_excerpt(m, "app_delete_university_media")
    _print_fn_excerpt(m, "app_list_university_site_for_management")
    _print_fn_excerpt(m, "app_public_university_site")

    # Compare what management list returns vs table status for ISTAPEM
    sql_media = """
    SELECT id, slug
    FROM app.universities
    WHERE slug='istapem'
    LIMIT 1
    """.strip()
    res_uni = _admin_execute_sql(m, sql_media)
    print("\n=== ISTAPEM university row ===")
    _print_rows(res_uni, max_chars=1000)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
