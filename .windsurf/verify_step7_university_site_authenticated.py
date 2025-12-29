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
        raise RuntimeError(f"rpc_failed name={name} http={resp.status_code} body={(resp.text or '')[:800]}")
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

    # Public university site (student JWT)
    slug = "universite-arbilo"
    pub = call_rpc(base_url, anon_key, student_token, "app_public_university_site", {"p_slug": slug})
    media = pub.get("media") if isinstance(pub, dict) else None
    media_sample = media[0] if isinstance(media, list) and media else None

    # Identify a university_id from public payload
    uni_id = pick(pub, "university.id")

    # Admin get university site
    admin = None
    if isinstance(uni_id, str) and uni_id:
        admin = call_rpc(base_url, anon_key, admin_token, "app_admin_get_university_site", {"p_university_id": uni_id})

    result = {
        "public": {
            "success": pub.get("success") if isinstance(pub, dict) else None,
            "slug": slug,
            "media_count": len(media) if isinstance(media, list) else 0,
            "sample": {
                "media_type": pick(media_sample, "media_type"),
                "url": pick(media_sample, "url"),
                "storage_path": pick(media_sample, "storage_path"),
                "thumbnail_url": pick(media_sample, "thumbnail_url"),
                "video_asset_id": pick(media_sample, "video_asset_id"),
                "playback_best_url": pick(media_sample, "playback.best_url"),
                "playback_poster_url": pick(media_sample, "playback.poster_url"),
            }
            if isinstance(media_sample, dict)
            else None,
        },
        "admin": {
            "called": bool(admin is not None),
            "success": admin.get("success") if isinstance(admin, dict) else None,
            "error": admin.get("error") if isinstance(admin, dict) else None,
            "media_count": len(admin.get("media")) if isinstance(admin, dict) and isinstance(admin.get("media"), list) else 0,
        }
        if admin is not None
        else {"called": False},
    }

    print(json.dumps(result, ensure_ascii=False, indent=2)[:7000])

    ok = bool(result["public"]["success"]) and (not result["admin"]["called"] or bool(result["admin"].get("success")))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
