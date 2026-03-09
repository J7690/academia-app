#!/usr/bin/env python3
"""Applique le schéma de notifications Academia via la RPC admin_execute_sql.

ATTENTION: ce script exécute du SQL DDL/DML sur la base Supabase pointée par
SupabaseAutoManager (service_role). À utiliser uniquement sur l'instance
ciblée volontairement.

Il applique, dans cet ordre :
- .windsurf/supabase_notifications.sql
- .windsurf/sql_changes/20260101_push_notifications_arch.sql
- .windsurf/sql_changes/phase6_opportunities_notifications.sql

Puis affiche un petit récapitulatif.
"""

from __future__ import annotations

import json
from pathlib import Path
import sys

import requests

WINDSURF_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(WINDSURF_DIR))

from supabase_auto_manager import SupabaseAutoManager


def call_admin_execute_sql(m: SupabaseAutoManager, sql: str) -> tuple[int, object]:
    sql_clean = (sql or "").strip()
    if sql_clean.endswith(";"):
        sql_clean = sql_clean[:-1].rstrip()
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    resp = requests.post(url, headers=m.headers, json={"p_sql": sql_clean}, timeout=180)
    try:
        data = resp.json()
    except Exception:
        data = resp.text
    return resp.status_code, data


def load_sql(rel_path: str) -> str:
    path = WINDSURF_DIR / rel_path
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def apply_file(m: SupabaseAutoManager, label: str, rel_path: str) -> None:
    print(f"\n=== APPLY {label} ({rel_path}) ===")
    sql = load_sql(rel_path)
    status, data = call_admin_execute_sql(m, sql)
    print("HTTP", status)
    # admin_execute_sql renvoie typiquement {ok:bool, mode:'exec'|'query', rows:[]?}
    try:
        print(json.dumps(data, indent=2, ensure_ascii=False)[:4000])
    except Exception:
        print(str(data)[:4000])
    if status != 200:
        raise SystemExit(f"admin_execute_sql failed on {rel_path} (HTTP {status})")


def main() -> int:
    m = SupabaseAutoManager()
    print("Supabase URL:", m.url)

    # 1) Module notifications génériques (badges, user_notification_state)
    apply_file(m, "supabase_notifications", "supabase_notifications.sql")

    # 2) Architecture push notifications (devices + file d'événements + triggers)
    apply_file(m, "push_notifications_arch", "sql_changes/20260101_push_notifications_arch.sql")

    # 3) Notifications/badges spécifiques Opportunités
    apply_file(m, "phase6_opportunities_notifications", "sql_changes/phase6_opportunities_notifications.sql")

    print("\n[OK] Schéma notifications appliqué (3 fichiers).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
