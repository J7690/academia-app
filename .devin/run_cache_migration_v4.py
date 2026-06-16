#!/usr/bin/env python3
"""Migration cache Bobodo — essaie execute_ddl, admin_execute_sql, et execute_sql."""
from __future__ import annotations
import requests, json
from pathlib import Path
from typing import List
from supabase_auto_manager import SupabaseAutoManager


def split_sql_script(script: str) -> List[str]:
    statements, current = [], []
    in_dollar = False
    in_line_comment = False
    in_block_comment = False
    i, length = 0, len(script)
    while i < length:
        if not in_line_comment and not in_block_comment and script[i:i+2] == "$$":
            in_dollar = not in_dollar; current.append("$$"); i += 2; continue
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


def try_rpc(m, rpc_name, param_name, sql, label):
    """Essaie un appel RPC. Retourne True si succès."""
    url = f"{m.url}/rest/v1/rpc/{rpc_name}"
    try:
        r = requests.post(url, headers=m.headers, json={param_name: sql}, timeout=60)
        if r.status_code == 404:
            return None  # RPC introuvable
        data = r.json() if r.status_code == 200 else None
        if isinstance(data, dict):
            if data.get("ok") is False:
                print(f"  ❌ [{label}] {data.get('error','?')[:150]}")
                return False
            if "error" in data and data["error"]:
                err = str(data["error"])
                if "already exists" in err.lower() or "does not exist" in err.lower():
                    print(f"  ⚠️  [{label}] {err[:100]} (non bloquant)")
                    return True
                print(f"  ❌ [{label}] {err[:150]}")
                return False
        print(f"  ✅ [{label}]")
        return True
    except Exception as e:
        print(f"  ❌ [{label}] Exception: {e}")
        return False


def main():
    m = SupabaseAutoManager()
    print("\n🚀 MIGRATION CACHE SÉMANTIQUE BOBODO v4\n")

    sql_file = Path(__file__).parent / "sql_changes" / "20260325_bobodo_answer_cache.sql"
    statements = split_sql_script(sql_file.read_text(encoding="utf-8"))
    # Filtrer les statements purs commentaires
    clean = []
    for s in statements:
        lines = [l.strip() for l in s.splitlines() if l.strip() and not l.strip().startswith("--")]
        if lines:
            clean.append(s)
    statements = clean

    print(f"  {len(statements)} statement(s) à exécuter\n")

    # Déterminer quel RPC fonctionne pour le DDL
    rpcs_to_try = [
        ("execute_ddl", "ddl_query"),
        ("admin_execute_sql", "p_sql"),
        ("execute_sql", "sql_query"),
    ]

    working_rpc = None
    for rpc_name, param_name in rpcs_to_try:
        result = try_rpc(m, rpc_name, param_name,
                         "SELECT 1 AS probe", f"probe {rpc_name}")
        if result is not None:  # RPC existe (même si erreur)
            # Tester avec un vrai DDL
            ddl_result = try_rpc(m, rpc_name, param_name,
                "CREATE TABLE IF NOT EXISTS app._probe_ddl_test (id int)",
                f"DDL test {rpc_name}")
            if ddl_result:
                # Nettoyer
                try_rpc(m, rpc_name, param_name,
                    "DROP TABLE IF EXISTS app._probe_ddl_test",
                    f"cleanup {rpc_name}")
                working_rpc = (rpc_name, param_name)
                print(f"\n  ✅ RPC DDL fonctionnelle : {rpc_name}({param_name})\n")
                break

    if not working_rpc:
        print("\n  ⚠️  Aucune RPC DDL disponible. Tentative statement par statement via execute_sql...\n")
        # Dernière tentative : envoyer chaque statement via execute_sql
        # qui pourrait accepter CREATE FUNCTION même s'il refuse CREATE TABLE
        working_rpc = ("execute_sql", "sql_query")

    rpc_name, param_name = working_rpc

    success_count = 0
    fail_count = 0
    for i, stmt in enumerate(statements, 1):
        lines = [l.strip() for l in stmt.splitlines() if l.strip() and not l.strip().startswith("--")]
        label = lines[0][:55] if lines else f"stmt {i}"
        result = try_rpc(m, rpc_name, param_name, stmt, f"{i}: {label}")
        if result:
            success_count += 1
        else:
            fail_count += 1

    # ── Vérification ─────────────────────────────────────────────
    print(f"\n📋 RÉSULTAT: {success_count} succès, {fail_count} échec(s)\n")

    check_url = f"{m.url}/rest/v1/rpc/execute_sql"
    checks = {
        "Table bobodo_answer_cache":
            "SELECT COUNT(*) AS n FROM information_schema.tables WHERE table_schema='app' AND table_name='bobodo_answer_cache'",
        "RPC app_search_bobodo_answer_cache":
            "SELECT 1 AS n FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='app' AND p.proname='app_search_bobodo_answer_cache'",
        "RPC app_bobodo_cache_hit":
            "SELECT 1 AS n FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='app' AND p.proname='app_bobodo_cache_hit'",
        "RPC app_insert_bobodo_answer_cache":
            "SELECT 1 AS n FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='app' AND p.proname='app_insert_bobodo_answer_cache'",
    }
    all_ok = True
    for label, sql in checks.items():
        r = requests.post(check_url, headers=m.headers, json={"sql_query": sql}, timeout=30)
        data = r.json() if r.status_code == 200 else []
        ok = bool(isinstance(data, list) and data and data[0] and int(data[0].get('n', 0)) > 0)
        print(f"  {'✅' if ok else '❌'} {label}")
        if not ok:
            all_ok = False

    if all_ok:
        print("\n✅ Migration complète et vérifiée !\n")
    else:
        print("\n⚠️  Certains éléments manquent. Le SQL corrigé est dans:")
        print("  .windsurf/sql_changes/20260325_bobodo_answer_cache.sql")
        print("  → Coller dans Supabase SQL Editor et exécuter.\n")


if __name__ == "__main__":
    main()
