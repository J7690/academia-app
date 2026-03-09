#!/usr/bin/env python3
"""Inventaire Supabase exhaustif (vidéo) via admin_execute_sql.

- Requêtes SELECT uniquement.
- Produit des preuves sous forme de rows renvoyées par admin_execute_sql.
"""

from __future__ import annotations

import json
import sys
from typing import Any, Dict, List, Tuple

import requests

from supabase_auto_manager import SupabaseAutoManager


def run_sql(m: SupabaseAutoManager, label: str, sql: str) -> Dict[str, Any]:
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    resp = requests.post(url, headers=m.headers, json={"p_sql": sql}, timeout=120)
    try:
        data = resp.json()
    except Exception:
        return {"ok": False, "http": resp.status_code, "raw": resp.text[:2000]}

    out: Dict[str, Any] = {
        "http": resp.status_code,
        "ok": bool(data.get("ok")) if isinstance(data, dict) else False,
        "mode": data.get("mode") if isinstance(data, dict) else None,
        "rows": data.get("rows") if isinstance(data, dict) else None,
        "error": data.get("error") if isinstance(data, dict) else None,
    }

    rows = out.get("rows")
    if not isinstance(rows, list):
        rows = []
    out["rows_count"] = len(rows)
    return out


def main() -> int:
    m = SupabaseAutoManager()

    queries: List[Tuple[str, str]] = [
        (
            "TABLES_APP_VIDEO_MEDIA",
            """
            SELECT table_schema, table_name
            FROM information_schema.tables
            WHERE table_schema = 'app'
              AND (
                table_name ILIKE '%video%'
                OR table_name ILIKE '%media%'
                OR table_name ILIKE '%asset%'
                OR table_name ILIKE '%rendition%'
                OR table_name ILIKE '%thumbnail%'
                OR table_name ILIKE '%mux%'
              )
            ORDER BY table_name
            """.strip(),
        ),
        (
            "COLUMNS_APP_VIDEO_MEDIA",
            """
            SELECT table_name, column_name, data_type, is_nullable, column_default
            FROM information_schema.columns
            WHERE table_schema = 'app'
              AND (
                column_name ILIKE '%video%'
                OR column_name ILIKE '%thumbnail%'
                OR column_name ILIKE '%rendition%'
                OR column_name ILIKE '%asset%'
                OR column_name ILIKE '%media%'
                OR column_name ILIKE '%mux%'
              )
            ORDER BY table_name, ordinal_position
            """.strip(),
        ),
        (
            "ROUTINES_PUBLIC_VIDEO_MEDIA",
            """
            SELECT routine_schema, routine_name, routine_type, data_type
            FROM information_schema.routines
            WHERE routine_schema = 'public'
              AND (
                routine_name ILIKE '%video%'
                OR routine_name ILIKE '%media%'
                OR routine_name ILIKE '%mux%'
                OR routine_name ILIKE '%thumbnail%'
                OR routine_name ILIKE '%rendition%'
                OR routine_name ILIKE '%asset%'
                OR routine_name ILIKE '%admin_execute_sql%'
              )
            ORDER BY routine_name
            """.strip(),
        ),
        (
            "VIEWS_APP_VIDEO_MEDIA",
            """
            SELECT table_schema, table_name
            FROM information_schema.views
            WHERE table_schema = 'app'
              AND (
                table_name ILIKE '%video%'
                OR table_name ILIKE '%media%'
                OR table_name ILIKE '%asset%'
                OR table_name ILIKE '%rendition%'
                OR table_name ILIKE '%thumbnail%'
                OR table_name ILIKE '%mux%'
              )
            ORDER BY table_name
            """.strip(),
        ),
        (
            "TRIGGERS_VIDEO_MEDIA",
            """
            SELECT
              n.nspname AS table_schema,
              c.relname AS table_name,
              t.tgname AS trigger_name,
              pg_get_triggerdef(t.oid) AS trigger_def
            FROM pg_trigger t
            JOIN pg_class c ON c.oid = t.tgrelid
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE NOT t.tgisinternal
              AND (
                n.nspname IN ('app','storage','public')
              )
              AND (
                c.relname ILIKE '%video%'
                OR c.relname ILIKE '%media%'
                OR c.relname ILIKE '%asset%'
                OR t.tgname ILIKE '%video%'
                OR t.tgname ILIKE '%media%'
                OR t.tgname ILIKE '%asset%'
              )
            ORDER BY table_schema, table_name, trigger_name
            """.strip(),
        ),
        (
            "STORAGE_BUCKETS",
            """
            SELECT id, name, public, created_at, updated_at
            FROM storage.buckets
            ORDER BY id
            """.strip(),
        ),
        (
            "STORAGE_POLICIES_OBJECTS",
            """
            SELECT policyname, roles, cmd, qual, with_check
            FROM pg_policies
            WHERE schemaname = 'storage'
              AND tablename = 'objects'
            ORDER BY policyname
            """.strip(),
        ),
        (
            "APP_POLICIES_VIDEO_RELATED",
            """
            SELECT schemaname, tablename, policyname, roles, cmd, qual, with_check
            FROM pg_policies
            WHERE schemaname = 'app'
              AND (
                tablename ILIKE '%video%'
                OR tablename ILIKE '%media%'
                OR tablename ILIKE '%asset%'
              )
            ORDER BY schemaname, tablename, policyname
            """.strip(),
        ),
        (
            "FUNCTION_DEFS_PUBLIC_VIDEO_RELATED",
            """
            SELECT n.nspname AS schema,
                   p.proname AS name,
                   pg_get_functiondef(p.oid) AS def
            FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'public'
              AND (
                p.proname ILIKE '%video%'
                OR p.proname ILIKE '%media%'
                OR p.proname ILIKE '%mux%'
                OR p.proname ILIKE '%thumbnail%'
                OR p.proname ILIKE '%rendition%'
                OR p.proname ILIKE '%asset%'
              )
            ORDER BY n.nspname, p.proname
            """.strip(),
        ),
    ]

    results: Dict[str, Any] = {}

    for label, sql in queries:
        res = run_sql(m, label, sql)
        rows = res.get("rows")
        if not isinstance(rows, list):
            rows = []
        # conserver seulement un échantillon pour lisibilité
        results[label] = {
            "http": res.get("http"),
            "ok": res.get("ok"),
            "mode": res.get("mode"),
            "rows_count": res.get("rows_count"),
            "sample_rows": rows[:10],
            "error": res.get("error"),
        }

        print(f"\n=== {label} ===")
        print(f"http={results[label]['http']} ok={results[label]['ok']} mode={results[label]['mode']} rows={results[label]['rows_count']}")
        print(json.dumps(results[label]["sample_rows"], ensure_ascii=False, indent=2)[:8000])

    # dump complet si besoin
    out_path = "./.windsurf/logs/video_inventory_admin_rpc.json"
    try:
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(results, f, ensure_ascii=False, indent=2)
        print(f"\n[OK] Inventaire écrit: {out_path}")
    except Exception as exc:
        print(f"\n[WARN] Impossible d'écrire le fichier: {exc}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
