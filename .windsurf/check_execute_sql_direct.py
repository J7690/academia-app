#!/usr/bin/env python3
"""Appelle la RPC execute_sql directement via REST.

Ce petit utilitaire permet maintenant de passer une requête SQL en argument :

    python .windsurf/check_execute_sql_direct.py "SELECT 1 AS x;"

Sans argument, il exécute une requête de test simple.
"""

import sys
import requests
import json
from pathlib import Path


def main():
    url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/execute_sql"
    headers = {
        "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
        "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Prefer": "return=minimal",
    }

    if len(sys.argv) > 1:
        raw_arg = " ".join(sys.argv[1:])
        path = Path(raw_arg)
        if path.suffix.lower() == ".sql" and path.exists():
            with path.open("r", encoding="utf-8") as f:
                sql_query = f.read()
        else:
            sql_query = raw_arg
    else:
        sql_query = "SELECT current_schema() AS schema, current_database() AS db;"

    payload = {"sql_query": sql_query}
    print("[check_execute_sql_direct] Executing SQL:\n", sql_query)

    r = requests.post(url, headers=headers, json=payload, timeout=10)
    print("[check_execute_sql_direct] Status:", r.status_code)
    try:
        # La fonction execute_sql retourne JSONB; on l'affiche joliment si possible.
        data = r.json()
        print("[check_execute_sql_direct] JSON response:")
        print(json.dumps(data, indent=2, ensure_ascii=False)[:4000])
    except Exception:
        print("[check_execute_sql_direct] Raw text response:")
        print(r.text[:4000])


if __name__ == "__main__":
    main()
