#!/usr/bin/env python3
"""Deploy all 5 prep concours Edge Functions via supabase_functions.functions table."""

import json
import requests
import time
from pathlib import Path
from auto_supabase_import import SUPABASE_URL, SUPABASE_SERVICE_KEY

HEADERS = {
    "apikey": SUPABASE_SERVICE_KEY,
    "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
    "Content-Type": "application/json",
}

def run_sql(label, sql):
    url = f"{SUPABASE_URL}/rest/v1/rpc/admin_execute_sql"
    try:
        resp = requests.post(url, headers=HEADERS, json={"p_sql": " ".join(sql.split())}, timeout=60)
        body = resp.json() if resp.status_code == 200 else {"ok": False, "error": resp.text[:500]}
        ok = isinstance(body, dict) and body.get("ok", False)
        err = body.get("error", "") if not ok else ""
        print(f"  {'OK' if ok else 'ERR'} {label} {('-- ' + err[:200]) if err else ''}")
        return ok, body
    except Exception as exc:
        print(f"  ERR {label} -- {exc}")
        return False, {"ok": False, "error": str(exc)}

def deploy_edge_function(name, file_path, verify_jwt=False):
    """Deploy a single Edge Function by inserting its code into supabase_functions.functions."""
    print(f"\n--- Deploying {name} ---")

    # Read the code
    try:
        code = Path(file_path).read_text(encoding="utf-8")
    except Exception as exc:
        print(f"  ERR Cannot read {file_path}: {exc}")
        return False

    print(f"  Code: {len(code)} chars")

    # Escape for SQL
    escaped = code.replace("'", "''")
    verify = "false" if not verify_jwt else "true"

    # Upsert into supabase_functions.functions
    upsert_sql = f"""
INSERT INTO supabase_functions.functions (name, body, verify_jwt, import_map)
VALUES (
  '{name}',
  '{escaped}',
  {verify},
  '{{}}'
)
ON CONFLICT (name) DO UPDATE SET
  body = EXCLUDED.body,
  verify_jwt = EXCLUDED.verify_jwt,
  import_map = EXCLUDED.import_map,
  updated_at = NOW();
    """.strip()

    ok, _ = run_sql(f"UPSERT {name}", upsert_sql)
    if not ok:
        return False

    # Activate
    activate_sql = f"UPDATE supabase_functions.functions SET status = 'ACTIVE' WHERE name = '{name}'"
    run_sql(f"ACTIVATE {name}", activate_sql)

    return True

def main():
    base_dir = Path(__file__).parent.parent / "supabase" / "functions"

    functions = [
        ("prep-tutor-chat", base_dir / "prep-tutor-chat" / "index.ts", False),
        ("prep-ingest-document", base_dir / "prep-ingest-document" / "index.ts", False),
        ("prep-generate-questions", base_dir / "prep-generate-questions" / "index.ts", False),
        ("prep-analyze-trends", base_dir / "prep-analyze-trends" / "index.ts", False),
        ("prep-grade-assignment", base_dir / "prep-grade-assignment" / "index.ts", False),
    ]

    print("=" * 60)
    print("DEPLOYING 5 PREP CONCOURS EDGE FUNCTIONS")
    print("=" * 60)

    ok_count = 0
    for name, path, verify in functions:
        if deploy_edge_function(name, path, verify):
            ok_count += 1
        time.sleep(0.5)

    # Verify all
    print("\n--- VERIFICATION ---")
    verify_sql = "SELECT name, verify_jwt, status, updated_at FROM supabase_functions.functions WHERE name LIKE 'prep-%' ORDER BY name"
    ok, body = run_sql("List prep Edge Functions", verify_sql)
    if ok and body.get("rows"):
        for row in body["rows"]:
            print(f"  {row.get('name'):30s} jwt={row.get('verify_jwt')} status={row.get('status')} updated={row.get('updated_at','')[:19]}")

    # Test HTTP availability
    print("\n--- HTTP AVAILABILITY TEST ---")
    for name, _, _ in functions:
        try:
            resp = requests.options(f"{SUPABASE_URL}/functions/v1/{name}", timeout=10)
            print(f"  {name}: HTTP {resp.status_code}")
        except Exception as e:
            print(f"  {name}: ERROR {e}")

    print(f"\n{'=' * 60}")
    print(f"RESULT: {ok_count}/{len(functions)} deployed successfully")
    print(f"{'=' * 60}")

if __name__ == "__main__":
    main()
