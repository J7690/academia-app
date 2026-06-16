import json
import sys

import requests

sys.path.insert(0, ".windsurf")

from auto_supabase_import import RPC_HEADERS, SUPABASE_URL  # noqa: E402


def main() -> None:
    sql = (
        "select n.nspname as schema_name, p.proname as func_name "
        "from pg_proc p "
        "join pg_namespace n on n.oid = p.pronamespace "
        "where p.proname like 'app_admin_prep_%' "
        "order by 1, 2"
    )

    url = f"{SUPABASE_URL}/rest/v1/rpc/execute_sql"
    resp = requests.post(url, headers=RPC_HEADERS, json={"sql_query": sql}, timeout=30)

    print("HTTP_STATUS", resp.status_code)
    try:
        data = resp.json()
    except Exception:
        print(resp.text)
        raise

    print(json.dumps(data, ensure_ascii=False, indent=2)[:8000])


if __name__ == "__main__":
    main()
