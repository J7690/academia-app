#!/usr/bin/env python3
"""Migration cache sémantique Bobodo — utilise admin_execute_sql + split $$ correct."""
from __future__ import annotations
import json, requests
from pathlib import Path
from typing import List
from supabase_auto_manager import SupabaseAutoManager


def split_sql_script(script: str) -> List[str]:
    """Copie exacte de apply_academia_schema_via_admin_rpc.py — respecte $$..$$."""
    statements: List[str] = []
    current: List[str] = []
    in_dollar = False
    in_line_comment = False
    in_block_comment = False
    i = 0
    length = len(script)
    while i < length:
        if not in_line_comment and not in_block_comment and script[i:i+2] == "$$":
            in_dollar = not in_dollar
            current.append("$$")
            i += 2; continue
        if not in_dollar and not in_block_comment and not in_line_comment and script[i:i+2] == "--":
            in_line_comment = True; current.append("--"); i += 2; continue
        if not in_dollar and not in_line_comment and not in_block_comment and script[i:i+2] == "/*":
            in_block_comment = True; current.append("/*"); i += 2; continue
        if in_block_comment and script[i:i+2] == "*/":
            in_block_comment = False; current.append("*/"); i += 2; continue
        ch = script[i]
        if in_line_comment and ch == "\n":
            in_line_comment = False; current.append(ch); i += 1; continue
        if ch == ";" and not in_dollar and not in_line_comment and not in_block_comment:
            stmt = "".join(current).strip()
            if stmt: statements.append(stmt)
            current = []
        else:
            current.append(ch)
        i += 1
    remainder = "".join(current).strip()
    if remainder: statements.append(remainder)
    return statements


def exec_stmt(url, headers, label, stmt):
    r = requests.post(url, headers=headers, json={"sql_query": stmt}, timeout=60)
    if r.status_code != 200:
        print(f"  ❌ [{label}] HTTP {r.status_code}: {r.text[:250]}")
        return False
    data = r.json()
    if isinstance(data, dict):
        if not data.get("ok", True):
            print(f"  ❌ [{label}] {data.get('error','?')[:200]}")
            return False
    print(f"  ✅ [{label}]")
    return True


def main():
    m = SupabaseAutoManager()
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    print("\n🚀 MIGRATION CACHE SÉMANTIQUE BOBODO v3\n")

    sql_file = Path(__file__).parent / "sql_changes" / "20260325_bobodo_answer_cache.sql"
    statements = split_sql_script(sql_file.read_text(encoding="utf-8"))

    print(f"  {len(statements)} statement(s) à exécuter\n")
    for i, stmt in enumerate(statements, 1):
        lines = [l.strip() for l in stmt.splitlines() if l.strip() and not l.strip().startswith("--")]
        if not lines: continue
        label = lines[0][:60]
        exec_stmt(url, m.headers, f"{i}: {label}", stmt)

    # ── Vérification ─────────────────────────────────────────────────
    print("\n📋 VÉRIFICATION FINALE")
    check_url = f"{m.url}/rest/v1/rpc/execute_sql"
    checks = [
        ("Table bobodo_answer_cache",
         "SELECT COUNT(*) AS n FROM information_schema.tables WHERE table_schema='app' AND table_name='bobodo_answer_cache'"),
        ("RPC app_search_bobodo_answer_cache",
         "SELECT 1 AS n FROM information_schema.routines WHERE routine_schema='app' AND routine_name='app_search_bobodo_answer_cache'"),
        ("RPC app_bobodo_cache_hit",
         "SELECT 1 AS n FROM information_schema.routines WHERE routine_schema='app' AND routine_name='app_bobodo_cache_hit'"),
        ("RPC app_insert_bobodo_answer_cache",
         "SELECT 1 AS n FROM information_schema.routines WHERE routine_schema='app' AND routine_name='app_insert_bobodo_answer_cache'"),
        ("RPC app_admin_bobodo_cache_stats",
         "SELECT 1 AS n FROM information_schema.routines WHERE routine_schema='app' AND routine_name='app_admin_bobodo_cache_stats'"),
    ]
    for label, sql in checks:
        r = requests.post(check_url, headers=m.headers, json={"sql_query": sql}, timeout=30)
        data = r.json() if r.status_code == 200 else []
        ok = bool(data and isinstance(data, list) and data[0] and int(data[0].get('n', 0)) > 0)
        print(f"  {'✅' if ok else '❌'} {label}")

    print("\n✅ Migration terminée.\n")

if __name__ == "__main__":
    main()
