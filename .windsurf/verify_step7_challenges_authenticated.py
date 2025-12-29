#!/usr/bin/env python3
from __future__ import annotations

import json
from typing import Any, Dict, Optional

import requests

from test_auth_login import get_supabase_auth_config


STUDENT_EMAIL = "nexiomgroup@gmail.com"
STUDENT_PASSWORD = "Wenden@Koote3"
ADMIN_EMAIL = "wendenkoote@gmail.com"
ADMIN_PASSWORD = "Wenden@Koote0"


def login(base_url: str, anon_key: str, email: str, password: str) -> str:
    resp = requests.post(
        f"{base_url}/auth/v1/token?grant_type=password",
        headers={"apikey": anon_key, "Content-Type": "application/json"},
        json={"email": email, "password": password},
        timeout=20,
    )
    if not resp.ok:
        raise RuntimeError(f"login_failed http={resp.status_code} body={(resp.text or '')[:400]}")
    token = resp.json().get("access_token")
    if not token:
        raise RuntimeError("login_missing_access_token")
    return token


def call_rpc(base_url: str, anon_key: str, access_token: Optional[str], name: str, payload: Dict[str, Any]) -> Any:
    headers = {"apikey": anon_key, "Content-Type": "application/json"}
    if access_token:
        headers["Authorization"] = f"Bearer {access_token}"
    resp = requests.post(
        f"{base_url}/rest/v1/rpc/{name}",
        headers=headers,
        json=payload,
        timeout=45,
    )
    if not resp.ok:
        raise RuntimeError(f"rpc_failed name={name} http={resp.status_code} body={(resp.text or '')[:900]}")
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

    student_token = login(base_url, anon_key, STUDENT_EMAIL, STUDENT_PASSWORD)
    admin_token = login(base_url, anon_key, ADMIN_EMAIL, ADMIN_PASSWORD)

    # 1) Student feed (should contain new fields)
    feed = call_rpc(
        base_url,
        anon_key,
        student_token,
        "app_student_challenge_video_feed",
        {"p_cursor": None, "p_limit": 5, "p_challenge_id": None},
    )
    videos = feed.get("videos") if isinstance(feed, dict) else None
    v0 = videos[0] if isinstance(videos, list) and videos else None

    # 2) Student detail: needs a participation_id
    detail = None
    if isinstance(v0, dict) and v0.get("participation_id"):
        detail = call_rpc(
            base_url,
            anon_key,
            student_token,
            "app_student_get_challenge_video",
            {"p_participation_id": v0.get("participation_id")},
        )

    # 3) Admin list videos
    admin_list = call_rpc(
        base_url,
        anon_key,
        admin_token,
        "app_admin_list_challenge_videos",
        {"p_challenge_id": None, "p_moderation_status": None, "p_has_pending_reports": None},
    )
    admin_videos = admin_list.get("videos") if isinstance(admin_list, dict) else None
    av0 = admin_videos[0] if isinstance(admin_videos, list) and admin_videos else None

    result = {
        "student_feed": {
            "success": feed.get("success") if isinstance(feed, dict) else None,
            "videos_count": len(videos) if isinstance(videos, list) else 0,
            "sample": {
                "participation_id": pick(v0, "participation_id"),
                "video_url": pick(v0, "video_url"),
                "video_asset_id": pick(v0, "video_asset_id"),
                "playback_best_url": pick(v0, "playback.best_url"),
                "playback_poster_url": pick(v0, "playback.poster_url"),
            }
            if isinstance(v0, dict)
            else None,
        },
        "student_detail": {
            "called": bool(detail is not None),
            "success": detail.get("success") if isinstance(detail, dict) else None,
            "video_asset_id": pick(detail, "video.video_asset_id") if isinstance(detail, dict) else None,
            "playback_best_url": pick(detail, "video.playback.best_url") if isinstance(detail, dict) else None,
        }
        if detail is not None
        else {"called": False},
        "admin_list": {
            "success": admin_list.get("success") if isinstance(admin_list, dict) else None,
            "videos_count": len(admin_videos) if isinstance(admin_videos, list) else 0,
            "sample": {
                "participation_id": pick(av0, "participation_id"),
                "video_url": pick(av0, "video_url"),
                "video_asset_id": pick(av0, "video_asset_id"),
                "playback_best_url": pick(av0, "playback.best_url"),
            }
            if isinstance(av0, dict)
            else None,
        },
    }

    print(json.dumps(result, ensure_ascii=False, indent=2)[:7000])

    ok = bool(result["student_feed"]["success"]) and bool(result["admin_list"]["success"])
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
