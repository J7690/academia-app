#!/usr/bin/env python3
"""Correction de la table app.student_home_videos via admin_execute_sql.

- Ajoute la colonne media_type si elle n'existe pas encore
- Suit les procédures .windsurf : SupabaseAutoManager + RPC admin_execute_sql
"""

from __future__ import annotations

import json
import requests

from supabase_auto_manager import SupabaseAutoManager


def main() -> int:
    m = SupabaseAutoManager()
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"

    sql = """
    ALTER TABLE app.student_home_videos
        ADD COLUMN IF NOT EXISTS media_type TEXT NOT NULL DEFAULT 'video';
    """.strip()

    print("=== FIX student_home_videos.media_type via admin_execute_sql ===")
    print(sql)

    try:
        resp = requests.post(url, headers=m.headers, json={"p_sql": sql}, timeout=30)
    except Exception as exc:  # pragma: no cover - log réseau
        print("[ERROR] Erreur réseau admin_execute_sql:", exc)
        return 1

    print("HTTP", resp.status_code)
    data = None
    try:
        data = resp.json()
        print(json.dumps(data, indent=2, ensure_ascii=False)[:800])
    except Exception:
        print(resp.text[:800])

    if resp.status_code != 200:
        print("[ERROR] admin_execute_sql a renvoyé un code HTTP non 200")
        return 1

    # Réponse JSON optionnelle, on logge juste les erreurs éventuelles
    if isinstance(data, dict) and not data.get("ok", True):
        print("[WARN] admin_execute_sql a renvoyé une erreur logique:")
        print(str(data)[:400])
        return 1

    print("[OK] Colonne media_type alignée sur app.student_home_videos (IF NOT EXISTS).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
