#!/usr/bin/env python3
"""Re-render massif des vidéos de challenges via l'API admin du backend.

- Utilise SupabaseAutoManager/admin_execute_sql pour lister les participations vidéo.
- Appelle l'endpoint backend `/admin/challenge_videos/{participation_id}/rerender` pour régénérer
  les renditions avec le profil ffmpeg actuel.
- Loggue les résultats dans .windsurf/logs/rerender_all_challenge_videos_YYYYMMDD_HHMMSS.json.

Lecture/écriture contrôlée, pas de DDL.
"""

from __future__ import annotations

import json
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List

import requests

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from supabase_auto_manager import SupabaseAutoManager


BACKEND_BASE_URL = "https://academia-app-production.up.railway.app"


def fetch_participations_with_videos(manager: SupabaseAutoManager, limit: int = 2000) -> List[Dict[str, Any]]:
    """Récupère les participations avec video_url non nul depuis app.challenge_participations.

    Utilise execute_sql (lecture seule).
    """

    sql = f"""
    SELECT
      id,
      challenge_id,
      user_id,
      video_url,
      video_renditions,
      created_at,
      status,
      remix_type,
      parent_participation_id
    FROM app.challenge_participations
    WHERE video_url IS NOT NULL
      AND TRIM(video_url) <> ''
    ORDER BY created_at DESC
    LIMIT {int(limit)};
    """.strip()

    result = manager.execute_sql_auto(sql)
    if not result.get("success"):
        print(f"[ERROR] SQL list participations failed: {result.get('error')}")
        return []

    data = result.get("data") or []
    if not isinstance(data, list):
        return []
    return data


def call_admin_rerender(participation_id: str) -> Dict[str, Any]:
    """Appelle l'endpoint backend admin de re-render pour une participation donnée.

    Utilise la service_role via le proxy SupabaseAutoManager (mêmes clés que Supabase).
    """

    url = f"{BACKEND_BASE_URL}/admin/challenge_videos/{participation_id}/rerender"

    # On réutilise la configuration SupabaseAutoManager pour les credentials
    m = SupabaseAutoManager()
    headers = {
        "Authorization": f"Bearer {m.service_key}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }

    try:
        resp = requests.post(url, headers=headers, timeout=600)
    except Exception as exc:
        return {
            "success": False,
            "error": f"network_exception: {exc}",
        }

    if resp.status_code >= 400:
        try:
            body = resp.json()
        except Exception:
            body = {"raw": resp.text[:1000]}
        return {
            "success": False,
            "status_code": resp.status_code,
            "error": body,
        }

    try:
        payload = resp.json()
    except Exception:
        payload = {"raw": resp.text[:1000]}

    if isinstance(payload, dict) and payload.get("success"):
        return {
            "success": True,
            "data": payload,
        }

    return {
        "success": False,
        "status_code": resp.status_code,
        "error": payload,
    }


def main() -> int:
    winds_dir = Path(__file__).resolve().parent.parent
    logs_dir = winds_dir / "logs"
    logs_dir.mkdir(parents=True, exist_ok=True)

    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_path = logs_dir / f"rerender_all_challenge_videos_{ts}.json"

    manager = SupabaseAutoManager()

    print("=== RERENDER ALL CHALLENGE VIDEOS (admin endpoint) ===")
    participations = fetch_participations_with_videos(manager)
    print(f"Found {len(participations)} participations with a non-empty video_url")

    results: List[Dict[str, Any]] = []
    total = len(participations)

    for idx, row in enumerate(participations, start=1):
        pid = str(row.get("id") or "").strip()
        if not pid:
            continue

        print(f"[{idx}/{total}] Re-render participation_id={pid} ...", flush=True)
        res = call_admin_rerender(pid)
        entry: Dict[str, Any] = {
            "participation_id": pid,
            "challenge_id": row.get("challenge_id"),
            "user_id": row.get("user_id"),
            "status": row.get("status"),
            "original_video_url": row.get("video_url"),
            "success": bool(res.get("success")),
            "response": res,
        }
        results.append(entry)

        # Petit throttle pour ne pas saturer Railway
        time.sleep(0.5)

    report = {
        "timestamp": datetime.now().isoformat(),
        "total_participations": total,
        "results": results,
    }

    log_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Report written to {log_path}")

    # Résumé rapide
    ok = sum(1 for r in results if r.get("success"))
    ko = total - ok
    print(f"Summary: {ok} success, {ko} errors")

    return 0 if ko == 0 else 1


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
