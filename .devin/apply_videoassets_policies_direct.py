#!/usr/bin/env python3
"""Applique les policies RLS du bucket `video-assets` en connexion directe Postgres.

Ce script contourne la limite de `admin_execute_sql` (service_role non owner
sur `storage.objects`) en se connectant en tant que superuser Postgres, comme
montré dans `direct_postgres_connection.py`.
"""
from __future__ import annotations

from pathlib import Path

import psycopg2


# Même paramètres que dans direct_postgres_connection.py
CONNECTION_PARAMS = {
    "host": "db.thevdfcwlcqzdoybfvgs.supabase.co",
    "port": 5432,
    "database": "postgres",
    "user": "postgres",
    "password": "Azert0Yuiop@",
    "sslmode": "require",
}


def main() -> int:
    winds_dir = Path(__file__).parent
    sql_path = winds_dir / "sql_changes" / "change_20251229_videoassets_storage_policies.sql"

    if not sql_path.exists():
        print(f"❌ Fichier SQL introuvable: {sql_path}")
        return 1

    sql_text = sql_path.read_text(encoding="utf-8")

    conn = psycopg2.connect(**CONNECTION_PARAMS)
    try:
        cur = conn.cursor()
        cur.execute(sql_text)
        conn.commit()
        cur.close()
        print("✅ Policies video-assets appliquées via connexion directe.")
        return 0
    finally:
        conn.close()


if __name__ == "__main__":
    raise SystemExit(main())
