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
        timeout=30,
    )
    if not resp.ok:
        raise RuntimeError(f"rpc_failed name={name} http={resp.status_code} body={(resp.text or '')[:600]}")
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

    # Student home public (authorized for anon/authenticated)
    student_home = call_rpc(base_url, anon_key, student_token, "app_public_student_home_content", {})
    sh_videos = student_home.get("videos") if isinstance(student_home, dict) else None
    sh_sample = sh_videos[0] if isinstance(sh_videos, list) and sh_videos else None

    hero_slots = ["student_home_hero_main", "landing_hero_main"]
    hero_by_slot: Dict[str, Any] = {}
    hero_admin_by_slot: Dict[str, Any] = {}

    for slot in hero_slots:
        hero = call_rpc(base_url, anon_key, student_token, "app_public_hero_playlist", {"p_slot": slot})
        hero_items = hero.get("items") if isinstance(hero, dict) else None
        hero_sample = hero_items[0] if isinstance(hero_items, list) and hero_items else None

        hero_by_slot[slot] = {
            "success": hero.get("success") if isinstance(hero, dict) else None,
            "items_count": len(hero_items) if isinstance(hero_items, list) else 0,
            "sample": {
                "media_type": pick(hero_sample, "media_type"),
                "base_video_url": pick(hero_sample, "base_video_url"),
                "video_asset_id": pick(hero_sample, "video_asset_id"),
                "playback_best_url": pick(hero_sample, "playback.best_url"),
                "playback_poster_url": pick(hero_sample, "playback.poster_url"),
            }
            if isinstance(hero_sample, dict)
            else None,
        }

        hero_admin = call_rpc(base_url, anon_key, admin_token, "app_admin_get_hero_playlist", {"p_slot": slot})
        hero_admin_by_slot[slot] = {
            "success": hero_admin.get("success") if isinstance(hero_admin, dict) else None,
            "error": hero_admin.get("error") if isinstance(hero_admin, dict) else None,
            "items_count": len(hero_admin.get("items")) if isinstance(hero_admin, dict) and isinstance(hero_admin.get("items"), list) else 0,
        }

    result = {
        "student_home": {
            "success": student_home.get("success") if isinstance(student_home, dict) else None,
            "videos_count": len(sh_videos) if isinstance(sh_videos, list) else 0,
            "sample": {
                "video_url": pick(sh_sample, "video_url"),
                "video_asset_id": pick(sh_sample, "video_asset_id"),
                "playback_best_url": pick(sh_sample, "playback.best_url"),
                "playback_poster_url": pick(sh_sample, "playback.poster_url"),
                "media_type": pick(sh_sample, "media_type"),
            }
            if isinstance(sh_sample, dict)
            else None,
        },
        "hero_public_by_slot": hero_by_slot,
        "hero_admin_by_slot": hero_admin_by_slot,
    }

    print(json.dumps(result, ensure_ascii=False, indent=2)[:7000])

    ok = bool(result["student_home"]["success"]) and all(
        bool(v.get("success")) for v in hero_by_slot.values()
    ) and all(
        bool(v.get("success")) for v in hero_admin_by_slot.values()
    )
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
