#!/usr/bin/env python3
"""
Audit Phase 1 - Vérification des extensions sociales
Module Opportunités Mini-Facebook
"""

from __future__ import annotations

import json
from typing import Any, Dict, List, Tuple
from pathlib import Path

import requests

from supabase_auto_manager import SupabaseAutoManager


def run_sql(m: SupabaseAutoManager, label: str, sql: str, timeout: int = 60) -> Dict[str, Any]:
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    try:
        resp = requests.post(url, headers=m.headers, json={"p_sql": sql}, timeout=timeout)
    except Exception as e:
        return {"label": label, "http": 0, "ok": False, "error": str(e), "rows": []}

    try:
        data = resp.json()
    except Exception:
        return {"label": label, "http": resp.status_code, "ok": False, "raw": (resp.text or "")[:2000], "rows": []}

    if isinstance(data, dict):
        rows = data.get("rows")
        return {
            "label": label,
            "http": resp.status_code,
            "ok": bool(data.get("ok")),
            "mode": data.get("mode"),
            "rows_count": len(rows) if isinstance(rows, list) else 0,
            "rows": rows if isinstance(rows, list) else [],
            "error": data.get("error"),
            "sqlstate": data.get("sqlstate"),
        }

    if isinstance(data, list):
        return {
            "label": label,
            "http": resp.status_code,
            "ok": True,
            "mode": "select",
            "rows_count": len(data),
            "rows": data,
            "error": None,
            "sqlstate": None,
        }

    return {"label": label, "http": resp.status_code, "ok": False, "rows": [], "error": "unexpected_json_type"}


def main() -> int:
    m = SupabaseAutoManager()

    queries: List[Tuple[str, str]] = [
        # 1. Nouvelles colonnes opportunities
        (
            "OPPORTUNITIES_NEW_COLUMNS",
            """
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns
            WHERE table_schema = 'app' AND table_name = 'opportunities'
              AND column_name IN ('price', 'reactions_count', 'comments_count')
            ORDER BY column_name
            """.strip(),
        ),
        # 2. Nouvelles colonnes opportunity_applications
        (
            "APPLICATIONS_NEW_COLUMNS",
            """
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns
            WHERE table_schema = 'app' AND table_name = 'opportunity_applications'
              AND column_name IN ('admin_notes', 'reviewed_at', 'reviewed_by')
            ORDER BY column_name
            """.strip(),
        ),
        # 3. Table opportunity_reactions existe
        (
            "REACTIONS_TABLE_EXISTS",
            """
            SELECT table_name, table_type
            FROM information_schema.tables
            WHERE table_schema = 'app' AND table_name = 'opportunity_reactions'
            """.strip(),
        ),
        # 4. Structure opportunity_reactions
        (
            "REACTIONS_TABLE_STRUCTURE",
            """
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns
            WHERE table_schema = 'app' AND table_name = 'opportunity_reactions'
            ORDER BY ordinal_position
            """.strip(),
        ),
        # 5. Table opportunity_comments existe
        (
            "COMMENTS_TABLE_EXISTS",
            """
            SELECT table_name, table_type
            FROM information_schema.tables
            WHERE table_schema = 'app' AND table_name = 'opportunity_comments'
            """.strip(),
        ),
        # 6. Structure opportunity_comments
        (
            "COMMENTS_TABLE_STRUCTURE",
            """
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns
            WHERE table_schema = 'app' AND table_name = 'opportunity_comments'
            ORDER BY ordinal_position
            """.strip(),
        ),
        # 7. Nouvelles RPC créées
        (
            "NEW_RPCS",
            """
            SELECT routine_name, data_type
            FROM information_schema.routines
            WHERE routine_schema = 'public'
              AND routine_name IN (
                'app_opportunity_toggle_reaction',
                'app_opportunity_get_reactions',
                'app_opportunity_get_my_reaction',
                'app_opportunity_add_comment',
                'app_opportunity_list_comments',
                'app_opportunity_delete_comment',
                'app_admin_update_application_status'
              )
            ORDER BY routine_name
            """.strip(),
        ),
        # 8. Toutes les RPC opportunités
        (
            "ALL_OPPORTUNITY_RPCS",
            """
            SELECT routine_name
            FROM information_schema.routines
            WHERE routine_schema = 'public'
              AND routine_name ILIKE '%opportunit%'
            ORDER BY routine_name
            """.strip(),
        ),
        # 9. Policies sur les nouvelles tables
        (
            "NEW_TABLES_POLICIES",
            """
            SELECT tablename, policyname, cmd, qual, with_check
            FROM pg_policies
            WHERE schemaname = 'app'
              AND tablename IN ('opportunity_reactions', 'opportunity_comments')
            ORDER BY tablename, policyname
            """.strip(),
        ),
        # 10. Index sur les nouvelles tables
        (
            "NEW_TABLES_INDEXES",
            """
            SELECT indexname, tablename
            FROM pg_indexes
            WHERE schemaname = 'app'
              AND tablename IN ('opportunity_reactions', 'opportunity_comments')
            ORDER BY tablename, indexname
            """.strip(),
        ),
    ]

    results: Dict[str, Any] = {}

    print("=" * 60)
    print("AUDIT PHASE 1 - EXTENSIONS SOCIALES")
    print("=" * 60)

    for label, sql in queries:
        print(f"\nExécution: {label}...")
        res = run_sql(m, label, sql)
        results[label] = res
        
        if res.get("ok"):
            print(f"  ✓ {label}: {res.get('rows_count', 0)} lignes")
        else:
            print(f"  ✗ {label}: ERREUR - {res.get('error', 'unknown')}")

    # Sauvegarder
    out_path = Path(__file__).parent / "logs" / "audit_phase1_social_features.json"
    out_path.parent.mkdir(exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    print(f"\n[OK] Résultats sauvegardés dans {out_path}")

    # Résumé
    print("\n" + "=" * 60)
    print("RÉSUMÉ PHASE 1")
    print("=" * 60)

    # Nouvelles colonnes opportunities
    opp_cols = results.get("OPPORTUNITIES_NEW_COLUMNS", {}).get("rows", [])
    print(f"\n📊 NOUVELLES COLONNES opportunities: {len(opp_cols)}")
    for c in opp_cols:
        print(f"   - {c.get('column_name')}: {c.get('data_type')}")

    # Nouvelles colonnes applications
    app_cols = results.get("APPLICATIONS_NEW_COLUMNS", {}).get("rows", [])
    print(f"\n📊 NOUVELLES COLONNES opportunity_applications: {len(app_cols)}")
    for c in app_cols:
        print(f"   - {c.get('column_name')}: {c.get('data_type')}")

    # Tables reactions et comments
    reactions_exists = len(results.get("REACTIONS_TABLE_EXISTS", {}).get("rows", [])) > 0
    comments_exists = len(results.get("COMMENTS_TABLE_EXISTS", {}).get("rows", [])) > 0
    print(f"\n📊 NOUVELLES TABLES:")
    print(f"   - opportunity_reactions: {'✅ Créée' if reactions_exists else '❌ Manquante'}")
    print(f"   - opportunity_comments: {'✅ Créée' if comments_exists else '❌ Manquante'}")

    # Nouvelles RPC
    new_rpcs = results.get("NEW_RPCS", {}).get("rows", [])
    print(f"\n📊 NOUVELLES RPC: {len(new_rpcs)}")
    for r in new_rpcs:
        print(f"   - {r.get('routine_name')}")

    # Total RPC opportunités
    all_rpcs = results.get("ALL_OPPORTUNITY_RPCS", {}).get("rows", [])
    print(f"\n📊 TOTAL RPC OPPORTUNITÉS: {len(all_rpcs)}")

    # Policies
    policies = results.get("NEW_TABLES_POLICIES", {}).get("rows", [])
    print(f"\n📊 POLICIES NOUVELLES TABLES: {len(policies)}")
    for p in policies:
        print(f"   - {p.get('tablename')}.{p.get('policyname')} ({p.get('cmd')})")

    # Indexes
    indexes = results.get("NEW_TABLES_INDEXES", {}).get("rows", [])
    print(f"\n📊 INDEX NOUVELLES TABLES: {len(indexes)}")
    for i in indexes:
        print(f"   - {i.get('indexname')}")

    # Validation finale
    print("\n" + "=" * 60)
    print("VALIDATION PHASE 1")
    print("=" * 60)
    
    issues = []
    if len(opp_cols) < 3:
        issues.append("Colonnes manquantes dans opportunities")
    if len(app_cols) < 3:
        issues.append("Colonnes manquantes dans opportunity_applications")
    if not reactions_exists:
        issues.append("Table opportunity_reactions manquante")
    if not comments_exists:
        issues.append("Table opportunity_comments manquante")
    if len(new_rpcs) < 7:
        issues.append(f"RPC manquantes (attendu 7, trouvé {len(new_rpcs)})")

    if issues:
        print("\n⚠️ PROBLÈMES:")
        for issue in issues:
            print(f"   - {issue}")
        return 1
    else:
        print("\n✅ PHASE 1 VALIDÉE - Toutes les extensions sociales sont en place")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
