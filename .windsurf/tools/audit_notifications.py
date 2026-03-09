#!/usr/bin/env python3
"""Audit notifications Academia via Supabase RPC execute_sql (lecture seule).

Ce script utilise SupabaseAutoManager et la fonction RPC execute_sql pour :
- vérifier la présence des tables et RPC de notifications,
- lister les triggers de notifications,
- donner un aperçu des tokens devices et des événements de notification.

AUCUNE écriture n'est effectuée : uniquement des SELECT.
"""

from __future__ import annotations

import json
from pathlib import Path
import sys

WINDSURF_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(WINDSURF_DIR))

from supabase_auto_manager import SupabaseAutoManager


def run_sql(label: str, sql: str, manager: SupabaseAutoManager) -> None:
    print(f"\n=== {label} ===")
    res = manager.execute_sql_auto(sql)
    try:
        print(json.dumps(res, indent=2, ensure_ascii=False)[:8000])
    except Exception:
        print(res)


def main() -> int:
    m = SupabaseAutoManager()

    # 1) Tables notifications principales
    run_sql(
        "tables_notifications",
        """
        SELECT tablename, schemaname
        FROM pg_tables
        WHERE schemaname = 'app'
          AND tablename IN (
            'user_device_tokens',
            'notification_events',
            'user_notification_state',
            'opportunity_views'
          )
        ORDER BY tablename;
        """,
        m,
    )

    # 2) RPC liées aux notifications / badges
    run_sql(
        "rpc_notifications",
        """
        SELECT
          n.nspname AS schema,
          p.proname,
          pg_get_function_identity_arguments(p.oid) AS args
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE proname IN (
          'app_register_device_token',
          'app_unregister_device_token',
          'app_queue_notification_event',
          'app_mark_domain_seen',
          'app_get_notification_summary',
          'app_opportunity_count_new',
          'app_opportunity_mark_viewed'
        )
        ORDER BY schema, proname;
        """,
        m,
    )

    # 3) Triggers de notifications sur les tables métier
    run_sql(
        "triggers_notifications",
        """
        SELECT
          n.nspname AS schema,
          c.relname AS table_name,
          t.tgname,
          pg_get_triggerdef(t.oid, true) AS trigger_def
        FROM pg_trigger t
        JOIN pg_class c ON c.oid = t.tgrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'app'
          AND NOT t.tgisinternal
          AND (
            t.tgname LIKE 'trg_app_application_%notify'
            OR t.tgname LIKE 'trg_app_community_%notify'
            OR t.tgname LIKE 'trg_app_bobodo_%notify'
            OR t.tgname LIKE 'trg_app_opportunities_%notify'
            OR t.tgname LIKE 'trg_app_prep_%notify'
          )
        ORDER BY table_name, tgname;
        """,
        m,
    )

    # 4) Aperçu des devices enregistrés
    run_sql(
        "sample_user_device_tokens",
        """
        SELECT
          user_id,
          platform,
          is_active,
          last_seen_at,
          updated_at
        FROM app.user_device_tokens
        ORDER BY last_seen_at DESC
        LIMIT 20;
        """,
        m,
    )

    # 5) Statistiques globales sur la file d'événements
    run_sql(
        "notification_events_counts",
        """
        SELECT
          COUNT(*) AS total,
          COUNT(*) FILTER (WHERE processed_at IS NULL) AS pending,
          COUNT(*) FILTER (WHERE processed_at IS NOT NULL) AS processed,
          COUNT(*) FILTER (WHERE last_error IS NOT NULL) AS with_error
        FROM app.notification_events;
        """,
        m,
    )

    # 6) Derniers événements de notification
    run_sql(
        "notification_events_last",
        """
        SELECT
          id,
          user_id,
          domain,
          event_type,
          created_at,
          processed_at,
          attempt_count,
          LEFT(last_error, 200) AS last_error
        FROM app.notification_events
        ORDER BY created_at DESC
        LIMIT 50;
        """,
        m,
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
