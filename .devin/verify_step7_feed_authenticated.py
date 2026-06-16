#!/usr/bin/env python3
from __future__ import annotations

import json
from typing import Any, Dict, Optional

import requests

from test_auth_login import get_supabase_auth_config


STUDENT_EMAIL = "nexiomgroup@gmail.com"
STUDENT_PASSWORD = "Wenden@Koote3"


def login_and_get_access_token(base_url: str, anon_key: str) -> str:
    resp = requests.post(
        f"{base_url}/auth/v1/token?grant_type=password",
        headers={
            "apikey": anon_key,
            "Content-Type": "application/json",
        },
        json={"email": STUDENT_EMAIL, "password": STUDENT_PASSWORD},
        timeout=20,
    )
    if not resp.ok:
        raise RuntimeError(f"login_failed http={resp.status_code} body={(resp.text or '')[:400]}")

    data = resp.json()
    token = data.get("access_token")
    if not token:
        raise RuntimeError("login_missing_access_token")
    return token


def call_feed(base_url: str, anon_key: str, access_token: str, limit: int = 5) -> Dict[str, Any]:
    resp = requests.post(
        f"{base_url}/rest/v1/rpc/app_student_unified_video_feed",
        headers={
            "apikey": anon_key,
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
        },
        json={"p_cursor": None, "p_limit": limit},
        timeout=30,
    )
    if not resp.ok:
        raise RuntimeError(f"feed_failed http={resp.status_code} body={(resp.text or '')[:400]}")
    return resp.json()


def pick(obj: Any, path: str) -> Optional[Any]:
    cur = obj
    for key in path.split("."):
        if isinstance(cur, dict):
            cur = cur.get(key)
        else:
            return None
    return cur


def main() -> int:
    base_url, anon_key = get_supabase_auth_config()

    access_token = login_and_get_access_token(base_url, anon_key)
    payload = call_feed(base_url, anon_key, access_token, limit=5)

    videos = payload.get("videos") if isinstance(payload, dict) else None
    sample = videos[0] if isinstance(videos, list) and videos else None

    result = {
        "success": payload.get("success") if isinstance(payload, dict) else None,
        "error": payload.get("error") if isinstance(payload, dict) else None,
        "videos_count": len(videos) if isinstance(videos, list) else 0,
        "sample": {
            "video_type": pick(sample, "video_type"),
            "video_id": pick(sample, "video_id"),
            "video_url": pick(sample, "video_url"),
            "video_asset_id": pick(sample, "video_asset_id"),
            "playback_best_url": pick(sample, "playback.best_url"),
            "playback_poster_url": pick(sample, "playback.poster_url"),
        }
        if isinstance(sample, dict)
        else None,
    }

    print(json.dumps(result, ensure_ascii=False, indent=2)[:6000])

    ok = bool(result.get("success")) and (result.get("videos_count", 0) >= 0)
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
