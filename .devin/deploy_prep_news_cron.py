#!/usr/bin/env python3
"""Configure pg_cron job to call prep-feed-actuality daily at 05:00 UTC."""
import json
from pathlib import Path
from datetime import datetime
from typing import Any, Dict
import requests
from supabase_auto_manager import SupabaseAutoManager


def run_sql(m: SupabaseAutoManager, label: str, sql: str, timeout: int = 60) -> Dict[str, Any]:
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    resp = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=timeout)
    try:
        data = resp.json()
    except Exception:
        return {"label": label, "ok": False, "raw": (resp.text or "")[:2000]}
    if isinstance(data, dict):
        return {"label": label, "ok": bool(data.get("ok")),
                "rows": data.get("rows", []), "error": data.get("error")}
    return {"label": label, "ok": False, "error": "unexpected"}


def main() -> int:
    m = SupabaseAutoManager()
    results = {"timestamp": datetime.utcnow().isoformat() + "Z", "steps": []}

    # 1. Check if pg_cron and pg_net extensions are available
    r1 = run_sql(m, "check_extensions", """
        SELECT extname FROM pg_extension WHERE extname IN ('pg_cron', 'pg_net') ORDER BY extname
    """)
    results["steps"].append(r1)
    print(f"Extensions: {[r['extname'] for r in r1.get('rows', [])]}")

    has_cron = any(r.get("extname") == "pg_cron" for r in r1.get("rows", []))
    has_net = any(r.get("extname") == "pg_net" for r in r1.get("rows", []))

    if not has_cron:
        print("⚠️ pg_cron not enabled. Trying to enable...")
        r_enable = run_sql(m, "enable_pg_cron", "CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog")
        results["steps"].append(r_enable)
        print(f"  Enable pg_cron: ok={r_enable.get('ok')} error={r_enable.get('error')}")

    if not has_net:
        print("⚠️ pg_net not enabled. Trying to enable...")
        r_enable = run_sql(m, "enable_pg_net", "CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions")
        results["steps"].append(r_enable)
        print(f"  Enable pg_net: ok={r_enable.get('ok')} error={r_enable.get('error')}")

    # 2. Remove old cron job if exists
    r2 = run_sql(m, "remove_old_cron", """
        SELECT cron.unschedule('prep-feed-actuality-daily')
    """)
    results["steps"].append(r2)
    print(f"Remove old cron: ok={r2.get('ok')} (may fail if doesn't exist)")

    # 3. Create cron job: daily at 05:00 UTC (06:00 Burkina time = GMT+0, so 05:00 UTC is fine)
    service_key = m.service_key
    supabase_url = m.url

    cron_sql = f"""
        SELECT cron.schedule(
            'prep-feed-actuality-daily',
            '0 5 * * *',
            $$
            SELECT net.http_post(
                url := '{supabase_url}/functions/v1/prep-feed-actuality',
                headers := jsonb_build_object(
                    'Authorization', 'Bearer {service_key}',
                    'apikey', '{service_key}',
                    'Content-Type', 'application/json'
                ),
                body := '{{}}'::jsonb
            ) AS request_id
            $$
        )
    """

    r3 = run_sql(m, "create_cron_job", cron_sql)
    results["steps"].append(r3)
    print(f"Create cron job: ok={r3.get('ok')} error={r3.get('error')}")

    # 4. Verify cron jobs
    r4 = run_sql(m, "verify_cron_jobs", """
        SELECT jobid, schedule, command, nodename, active
        FROM cron.job
        WHERE jobname LIKE '%prep%'
        ORDER BY jobid
    """)
    results["steps"].append(r4)
    print(f"Active cron jobs: {len(r4.get('rows', []))}")
    for job in r4.get("rows", []):
        print(f"  #{job.get('jobid')} | {job.get('schedule')} | active={job.get('active')}")

    # Save
    log_dir = Path(".windsurf/logs")
    log_dir.mkdir(parents=True, exist_ok=True)
    out = log_dir / "deploy_prep_news_cron.json"
    out.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\n[OK] Saved {out.as_posix()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
