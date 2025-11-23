#!/usr/bin/env python3
from __future__ import annotations

"""Tests ciblés pour vérifier l'installation de app.landing_videos et des RPC associées.

Utilise la RPC admin_execute_sql via SupabaseAutoManager, conformément aux patterns .windsurf.
"""

import json
import requests

from supabase_auto_manager import SupabaseAutoManager


def main() -> int:
    m = SupabaseAutoManager()
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"

    tests = [
        # 1) Vérifier l'existence de la table app.landing_videos
        """SELECT table_schema, table_name
           FROM information_schema.tables
           WHERE table_schema = 'app' AND table_name = 'landing_videos'""",
        # 2) Décrire les colonnes de app.landing_videos
        """SELECT column_name, data_type, is_nullable, column_default
           FROM information_schema.columns
           WHERE table_schema = 'app' AND table_name = 'landing_videos'
           ORDER BY ordinal_position""",
        # 3) Vérifier la présence des fonctions RPC liées aux vidéos de landing
        """SELECT routine_schema, routine_name
           FROM information_schema.routines
           WHERE routine_schema = 'app'
             AND routine_name IN (
                 'app_public_landing_content',
                 'app_admin_get_landing_content',
                 'app_admin_upsert_landing_video',
                 'app_admin_delete_landing_video'
             )
           ORDER BY routine_name""",
        # 4) Lister quelques lignes éventuelles de app.landing_videos
        """SELECT id, video_url, title, sort_order, is_active, created_at
           FROM app.landing_videos
           ORDER BY sort_order NULLS LAST, created_at
           LIMIT 5""",
    ]

    for sql in tests:
        print("\n=== SQL ===")
        print(sql)
        try:
            r = requests.post(url, headers=m.headers, json={"p_sql": sql}, timeout=30)
        except Exception as exc:
            print(f"❌ Erreur réseau: {exc}")
            continue

        print(f"HTTP {r.status_code}")
        try:
            data = r.json()
            print(json.dumps(data, indent=2, ensure_ascii=False))
        except Exception:
            print(r.text)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
