import json
from pathlib import Path
from datetime import datetime

import requests

from supabase_auto_manager import SupabaseAutoManager


def run_sql(m: SupabaseAutoManager, label: str, sql: str, timeout: int = 120):
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

    return {
        "label": label,
        "http": resp.status_code,
        "ok": False,
        "mode": None,
        "rows_count": 0,
        "rows": [],
        "error": "unexpected_json_type",
        "sqlstate": None,
    }


def main() -> None:
    mgr = SupabaseAutoManager()

    queries = {
        "PHASE4_FUNCTION_EXISTS": """
            SELECT n.nspname AS schema_name, p.proname AS function_name
            FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'public'
              AND p.proname IN (
                'app_merchant_list_my_opportunities',
                'app_merchant_upsert_opportunity',
                'app_merchant_submit_opportunity_for_review',
                'app_merchant_list_inquiries',
                'app_merchant_reply_inquiry'
              )
            ORDER BY p.proname;
        """,
        "MARKETPLACE_TABLES": """
            SELECT table_schema, table_name
            FROM information_schema.tables
            WHERE table_schema = 'app'
              AND table_name IN (
                'merchant_profiles',
                'opportunity_inquiries',
                'opportunity_inquiry_messages',
                'opportunities'
              )
            ORDER BY table_name;
        """,
    }

    results = {}
    for key, sql in queries.items():
        results[key] = run_sql(mgr, key, sql)

    log_dir = Path('.windsurf/logs')
    log_dir.mkdir(parents=True, exist_ok=True)
    payload = {
        "timestamp": datetime.utcnow().isoformat() + 'Z',
        "queries": list(queries.keys()),
        "results": results,
    }

    out_path = log_dir / 'audit_marketplace_phase4_precheck.json'
    out_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding='utf-8')

    print('[OK] Résultats sauvegardés dans', out_path.as_posix())


if __name__ == '__main__':
    main()
