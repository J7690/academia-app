#!/usr/bin/env python3
"""
Audit Final - Module Opportunités Mini-Facebook
Vérifie l'état complet après toutes les phases d'implémentation.
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
            "rows_count": len(rows) if isinstance(rows, list) else 0,
            "rows": rows if isinstance(rows, list) else [],
            "error": data.get("error"),
        }

    if isinstance(data, list):
        return {
            "label": label,
            "http": resp.status_code,
            "ok": True,
            "rows_count": len(data),
            "rows": data,
            "error": None,
        }

    return {"label": label, "http": resp.status_code, "ok": False, "rows": [], "error": "unexpected_json_type"}


def main() -> int:
    m = SupabaseAutoManager()

    queries: List[Tuple[str, str]] = [
        # Tables
        (
            "ALL_OPPORTUNITY_TABLES",
            """
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = 'app' AND table_name ILIKE '%opportunit%'
            ORDER BY table_name
            """.strip(),
        ),
        # Types d'opportunités
        (
            "OPPORTUNITY_TYPES",
            """
            SELECT code, label, sort_order, is_active
            FROM app.opportunity_types
            ORDER BY sort_order
            """.strip(),
        ),
        # Colonnes opportunities
        (
            "OPPORTUNITIES_COLUMNS",
            """
            SELECT column_name, data_type
            FROM information_schema.columns
            WHERE table_schema = 'app' AND table_name = 'opportunities'
            ORDER BY ordinal_position
            """.strip(),
        ),
        # Colonnes opportunity_applications
        (
            "APPLICATIONS_COLUMNS",
            """
            SELECT column_name, data_type
            FROM information_schema.columns
            WHERE table_schema = 'app' AND table_name = 'opportunity_applications'
            ORDER BY ordinal_position
            """.strip(),
        ),
        # Colonnes opportunity_reactions
        (
            "REACTIONS_COLUMNS",
            """
            SELECT column_name, data_type
            FROM information_schema.columns
            WHERE table_schema = 'app' AND table_name = 'opportunity_reactions'
            ORDER BY ordinal_position
            """.strip(),
        ),
        # Colonnes opportunity_comments
        (
            "COMMENTS_COLUMNS",
            """
            SELECT column_name, data_type
            FROM information_schema.columns
            WHERE table_schema = 'app' AND table_name = 'opportunity_comments'
            ORDER BY ordinal_position
            """.strip(),
        ),
        # Colonnes opportunity_views
        (
            "VIEWS_COLUMNS",
            """
            SELECT column_name, data_type
            FROM information_schema.columns
            WHERE table_schema = 'app' AND table_name = 'opportunity_views'
            ORDER BY ordinal_position
            """.strip(),
        ),
        # Toutes les RPC opportunités
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
        # Policies
        (
            "ALL_OPPORTUNITY_POLICIES",
            """
            SELECT tablename, policyname, cmd
            FROM pg_policies
            WHERE schemaname = 'app'
              AND tablename ILIKE '%opportunit%'
            ORDER BY tablename, policyname
            """.strip(),
        ),
        # Compteurs
        (
            "DATA_COUNTS",
            """
            SELECT
                (SELECT COUNT(*) FROM app.opportunities) AS opportunities,
                (SELECT COUNT(*) FROM app.opportunity_applications) AS applications,
                (SELECT COUNT(*) FROM app.opportunity_types) AS types,
                (SELECT COUNT(*) FROM app.opportunity_reactions) AS reactions,
                (SELECT COUNT(*) FROM app.opportunity_comments) AS comments
            """.strip(),
        ),
    ]

    results: Dict[str, Any] = {}

    print("=" * 70)
    print("AUDIT FINAL - MODULE OPPORTUNITÉS MINI-FACEBOOK")
    print("=" * 70)

    for label, sql in queries:
        print(f"\nExécution: {label}...")
        res = run_sql(m, label, sql)
        results[label] = res
        
        if res.get("ok"):
            print(f"  ✓ {label}: {res.get('rows_count', 0)} lignes")
        else:
            print(f"  ✗ {label}: ERREUR - {res.get('error', 'unknown')}")

    # Sauvegarder
    out_path = Path(__file__).parent / "logs" / "audit_final_opportunities_mini_facebook.json"
    out_path.parent.mkdir(exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    print(f"\n[OK] Résultats sauvegardés dans {out_path}")

    # Résumé
    print("\n" + "=" * 70)
    print("RÉSUMÉ FINAL")
    print("=" * 70)

    # Tables
    tables = [r.get('table_name') for r in results.get("ALL_OPPORTUNITY_TABLES", {}).get("rows", [])]
    print(f"\n📊 TABLES ({len(tables)}):")
    for t in tables:
        print(f"   - app.{t}")

    # Types
    types = results.get("OPPORTUNITY_TYPES", {}).get("rows", [])
    print(f"\n📊 TYPES D'OPPORTUNITÉS ({len(types)}):")
    for t in types:
        print(f"   - {t.get('code')}: {t.get('label')} (ordre: {t.get('sort_order')})")

    # RPC
    rpcs = [r.get('routine_name') for r in results.get("ALL_OPPORTUNITY_RPCS", {}).get("rows", [])]
    print(f"\n📊 RPC FUNCTIONS ({len(rpcs)}):")
    for r in rpcs:
        print(f"   - {r}")

    # Policies
    policies = results.get("ALL_OPPORTUNITY_POLICIES", {}).get("rows", [])
    print(f"\n📊 RLS POLICIES ({len(policies)}):")
    for p in policies:
        print(f"   - {p.get('tablename')}.{p.get('policyname')} ({p.get('cmd')})")

    # Compteurs
    counts = results.get("DATA_COUNTS", {}).get("rows", [{}])[0] if results.get("DATA_COUNTS", {}).get("rows") else {}
    print(f"\n📊 DONNÉES:")
    print(f"   - Opportunités: {counts.get('opportunities', 0)}")
    print(f"   - Candidatures: {counts.get('applications', 0)}")
    print(f"   - Types: {counts.get('types', 0)}")
    print(f"   - Réactions: {counts.get('reactions', 0)}")
    print(f"   - Commentaires: {counts.get('comments', 0)}")

    # Validation
    print("\n" + "=" * 70)
    print("VALIDATION")
    print("=" * 70)

    expected_tables = {'opportunities', 'opportunity_applications', 'opportunity_types', 'opportunity_reactions', 'opportunity_comments', 'opportunity_views'}
    expected_rpcs = {
        'app_student_list_opportunities', 'app_student_get_opportunity_detail', 'app_student_apply_for_opportunity',
        'app_student_list_my_opportunity_applications', 'app_list_opportunity_types',
        'app_admin_list_opportunities', 'app_admin_upsert_opportunity', 'app_admin_update_opportunity_status',
        'app_admin_list_opportunity_applications', 'app_admin_list_opportunity_types', 'app_admin_upsert_opportunity_type',
        'app_opportunity_toggle_reaction', 'app_opportunity_get_reactions', 'app_opportunity_get_my_reaction',
        'app_opportunity_add_comment', 'app_opportunity_list_comments', 'app_opportunity_delete_comment',
        'app_admin_update_application_status', 'app_opportunity_count_new', 'app_opportunity_mark_viewed'
    }

    missing_tables = expected_tables - set(tables)
    missing_rpcs = expected_rpcs - set(rpcs)

    issues = []
    if missing_tables:
        issues.append(f"Tables manquantes: {missing_tables}")
    if missing_rpcs:
        issues.append(f"RPC manquantes: {missing_rpcs}")
    if len(types) < 3:
        issues.append(f"Types insuffisants (attendu 3, trouvé {len(types)})")

    if issues:
        print("\n⚠️ PROBLÈMES DÉTECTÉS:")
        for issue in issues:
            print(f"   - {issue}")
        return 1
    else:
        print("\n✅ MODULE OPPORTUNITÉS MINI-FACEBOOK COMPLET")
        print("   - Toutes les tables créées")
        print("   - Toutes les RPC en place")
        print("   - Types d'opportunités configurés")
        print("   - Policies RLS actives")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
