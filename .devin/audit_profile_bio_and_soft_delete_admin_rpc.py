#!/usr/bin/env python3
"""Audit ciblé (bio profil + soft delete vidéos) via admin_execute_sql.

- SELECT only
- Donne les colonnes réelles + policies RLS + définitions des RPCs concernées.
"""

from __future__ import annotations

import json
from typing import Any, Dict, List, Tuple

import requests

from supabase_auto_manager import SupabaseAutoManager


def run_sql(m: SupabaseAutoManager, sql: str, timeout: int = 120) -> Dict[str, Any]:
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    resp = requests.post(url, headers=m.headers, json={"p_sql": sql.rstrip().rstrip(";")}, timeout=timeout)
    try:
        data = resp.json()
    except Exception:
        return {"ok": False, "http": resp.status_code, "raw": (resp.text or "")[:2000]}

    if not isinstance(data, dict):
        return {"ok": False, "http": resp.status_code, "raw": str(data)[:2000]}

    return {
        "ok": bool(data.get("ok", True)),
        "http": resp.status_code,
        "mode": data.get("mode"),
        "rows": data.get("rows", []),
        "error": data.get("error"),
        "sqlstate": data.get("sqlstate"),
    }


def print_block(title: str) -> None:
    print("\n" + "=" * 100)
    print(title)
    print("=" * 100)


def main() -> int:
    m = SupabaseAutoManager()

    # 1) Colonnes des tables clés
    tables: List[Tuple[str, str]] = [
        ("app", "students"),
        ("app", "challenge_participations"),
        ("app", "free_videos"),
        ("app", "video_assets"),
        ("app", "video_sources"),
        ("app", "video_renditions"),
        ("app", "video_comments"),
        ("app", "video_likes"),
        ("app", "challenge_favorites"),
        ("app", "challenge_video_overlays"),
        ("app", "free_video_overlays"),
    ]

    for schema, table in tables:
        print_block(f"COLUMNS {schema}.{table}")
        sql = (
            "SELECT column_name, data_type, is_nullable, column_default "
            "FROM information_schema.columns "
            f"WHERE table_schema = '{schema}' AND table_name = '{table}' "
            "ORDER BY ordinal_position"
        )
        res = run_sql(m, sql)
        if not res.get("ok"):
            print(json.dumps(res, ensure_ascii=False, indent=2)[:4000])
            continue
        rows = res.get("rows")
        if not isinstance(rows, list) or not rows:
            print("(no rows)")
            continue
        for r in rows:
            if isinstance(r, dict):
                print(
                    f"- {r.get('column_name','?'):30s} {r.get('data_type','?'):25s} "
                    f"null={r.get('is_nullable','?'):3s} default={str(r.get('column_default'))[:80]}"
                )
            else:
                print(r)

    # 2) Policies RLS
    print_block("RLS POLICIES (app) — tables clés")
    sql_policies = """
    SELECT schemaname, tablename, policyname, roles, cmd, qual, with_check
    FROM pg_policies
    WHERE schemaname = 'app'
      AND tablename IN (
        'students',
        'challenge_participations',
        'free_videos',
        'video_assets',
        'video_sources',
        'video_renditions',
        'video_comments',
        'video_likes',
        'challenge_favorites',
        'challenge_video_overlays',
        'free_video_overlays'
      )
    ORDER BY tablename, policyname
    """.strip()
    res = run_sql(m, sql_policies)
    if not res.get("ok"):
        print(json.dumps(res, ensure_ascii=False, indent=2)[:4000])
    else:
        rows = res.get("rows")
        print(json.dumps(rows, ensure_ascii=False, indent=2)[:8000])

    # 3) RPC defs à patcher
    print_block("RPC DEFS — app_student_unified_video_feed / app_student_list_user_videos")
    sql_defs = """
    SELECT n.nspname AS schema,
           p.proname AS name,
           pg_get_functiondef(p.oid) AS def
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN ('app_student_unified_video_feed', 'app_student_list_user_videos')
    ORDER BY p.proname
    """.strip()
    res = run_sql(m, sql_defs, timeout=180)
    if not res.get("ok"):
        print(json.dumps(res, ensure_ascii=False, indent=2)[:4000])
    else:
        rows = res.get("rows")
        for r in rows if isinstance(rows, list) else []:
            if not isinstance(r, dict):
                continue
            name = r.get("name")
            print("\n---", name, "---")
            print((r.get("def") or "")[:12000])

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
