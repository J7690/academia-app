#!/usr/bin/env python3
from __future__ import annotations

import json
from typing import Any, Dict, Optional, Tuple

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


def call_rpc(base_url: str, anon_key: str, access_token: Optional[str], name: str, payload: Dict[str, Any]) -> Tuple[int, Any]:
    headers = {"apikey": anon_key, "Content-Type": "application/json"}
    if access_token:
        headers["Authorization"] = f"Bearer {access_token}"
    resp = requests.post(
        f"{base_url}/rest/v1/rpc/{name}",
        headers=headers,
        json=payload,
        timeout=45,
    )
    try:
        body = resp.json()
    except Exception:
        body = {"_raw": (resp.text or "")[:1200]}
    return resp.status_code, body


def pick(obj: Any, path: str) -> Optional[Any]:
    cur = obj
    for key in path.split("."):
        if isinstance(cur, dict):
            cur = cur.get(key)
        else:
            return None
    return cur


def validate_has_playback(item: Any) -> bool:
    if not isinstance(item, dict):
        return False
    pb = item.get("playback")
    if not isinstance(pb, dict):
        return False
    # allow null URLs for non-video media; presence of keys is enough
    return ("best_url" in pb) and ("poster_url" in pb)


def main() -> int:
    base_url, anon_key = get_supabase_auth_config()

    student_token = login(base_url, anon_key, STUDENT_EMAIL, STUDENT_PASSWORD)
    admin_token = login(base_url, anon_key, ADMIN_EMAIL, ADMIN_PASSWORD)

    report: Dict[str, Any] = {"checks": [], "ok": True}

    def record(name: str, ok: bool, details: Dict[str, Any]) -> None:
        report["checks"].append({"name": name, "ok": ok, **details})
        if not ok:
            report["ok"] = False

    # 7a) unified feed
    st, body = call_rpc(base_url, anon_key, student_token, "app_student_unified_video_feed", {"p_cursor": None, "p_limit": 5})
    videos = body.get("videos") if isinstance(body, dict) else None
    v0 = videos[0] if isinstance(videos, list) and videos else None
    record(
        "feed_unified",
        st == 200 and isinstance(body, dict) and body.get("success") is True and isinstance(videos, list)
        and (v0 is None or ("video_asset_id" in v0 and validate_has_playback(v0))),
        {
            "http": st,
            "success": body.get("success") if isinstance(body, dict) else None,
            "videos_count": len(videos) if isinstance(videos, list) else None,
            "sample_keys": sorted(list(v0.keys())) if isinstance(v0, dict) else None,
        },
    )

    # 7b) landing public
    st, body = call_rpc(base_url, anon_key, None, "app_public_landing_content", {})
    cfg = body.get("config") if isinstance(body, dict) else None
    lvideos = body.get("videos") if isinstance(body, dict) else None
    lv0 = lvideos[0] if isinstance(lvideos, list) and lvideos else None
    record(
        "landing_public",
        st == 200 and isinstance(body, dict) and body.get("success") is True
        and (not isinstance(cfg, dict) or validate_has_playback(cfg))
        and (lv0 is None or validate_has_playback(lv0)),
        {
            "http": st,
            "success": body.get("success") if isinstance(body, dict) else None,
            "videos_count": len(lvideos) if isinstance(lvideos, list) else None,
        },
    )

    # 7c) student home public
    st, body = call_rpc(base_url, anon_key, student_token, "app_public_student_home_content", {})
    sh_videos = body.get("videos") if isinstance(body, dict) else None
    sh0 = sh_videos[0] if isinstance(sh_videos, list) and sh_videos else None
    record(
        "student_home_public",
        st == 200 and isinstance(body, dict) and body.get("success") is True
        and (sh0 is None or validate_has_playback(sh0)),
        {
            "http": st,
            "success": body.get("success") if isinstance(body, dict) else None,
            "videos_count": len(sh_videos) if isinstance(sh_videos, list) else None,
        },
    )

    # 7c) hero playlist public/admin (known slots)
    for slot in ("student_home_hero_main", "landing_hero_main"):
        st, body = call_rpc(base_url, anon_key, student_token, "app_public_hero_playlist", {"p_slot": slot})
        items = body.get("items") if isinstance(body, dict) else None
        it0 = items[0] if isinstance(items, list) and items else None
        record(
            f"hero_public[{slot}]",
            st == 200 and isinstance(body, dict) and body.get("success") is True and (it0 is None or validate_has_playback(it0)),
            {"http": st, "items_count": len(items) if isinstance(items, list) else None},
        )

        st, body = call_rpc(base_url, anon_key, admin_token, "app_admin_get_hero_playlist", {"p_slot": slot})
        items = body.get("items") if isinstance(body, dict) else None
        it0 = items[0] if isinstance(items, list) and items else None
        record(
            f"hero_admin[{slot}]",
            st == 200 and isinstance(body, dict) and body.get("success") is True and (it0 is None or validate_has_playback(it0)),
            {"http": st, "items_count": len(items) if isinstance(items, list) else None},
        )

    # 7d) university site public/admin
    slug = "universite-arbilo"
    st, body = call_rpc(base_url, anon_key, student_token, "app_public_university_site", {"p_slug": slug})
    media = body.get("media") if isinstance(body, dict) else None
    m0 = media[0] if isinstance(media, list) and media else None
    record(
        "university_site_public",
        st == 200 and isinstance(body, dict) and body.get("success") is True and (m0 is None or validate_has_playback(m0)),
        {"http": st, "media_count": len(media) if isinstance(media, list) else None},
    )

    uni_id = pick(body, "university.id") if isinstance(body, dict) else None
    if isinstance(uni_id, str) and uni_id:
        st, body = call_rpc(base_url, anon_key, admin_token, "app_admin_get_university_site", {"p_university_id": uni_id})
        media = body.get("media") if isinstance(body, dict) else None
        m0 = media[0] if isinstance(media, list) and media else None
        record(
            "university_site_admin",
            st == 200 and isinstance(body, dict) and body.get("success") is True and (m0 is None or validate_has_playback(m0)),
            {"http": st, "media_count": len(media) if isinstance(media, list) else None},
        )

    # 7e) challenges student feed/detail
    st, body = call_rpc(
        base_url,
        anon_key,
        student_token,
        "app_student_challenge_video_feed",
        {"p_cursor": None, "p_limit": 5, "p_challenge_id": None},
    )
    cvideos = body.get("videos") if isinstance(body, dict) else None
    cv0 = cvideos[0] if isinstance(cvideos, list) and cvideos else None
    record(
        "challenges_student_feed",
        st == 200 and isinstance(body, dict) and body.get("success") is True and (cv0 is None or validate_has_playback(cv0)),
        {"http": st, "videos_count": len(cvideos) if isinstance(cvideos, list) else None},
    )

    if isinstance(cv0, dict) and cv0.get("participation_id"):
        st, body = call_rpc(
            base_url,
            anon_key,
            student_token,
            "app_student_get_challenge_video",
            {"p_participation_id": cv0.get("participation_id")},
        )
        v = body.get("video") if isinstance(body, dict) else None
        record(
            "challenges_student_detail",
            st == 200 and isinstance(body, dict) and body.get("success") is True and validate_has_playback(v),
            {"http": st, "has_video": isinstance(v, dict)},
        )

    # 7e) challenges admin list videos
    st, body = call_rpc(
        base_url,
        anon_key,
        admin_token,
        "app_admin_list_challenge_videos",
        {"p_challenge_id": None, "p_moderation_status": None, "p_has_pending_reports": None},
    )
    avideos = body.get("videos") if isinstance(body, dict) else None
    av0 = avideos[0] if isinstance(avideos, list) and avideos else None
    record(
        "challenges_admin_list",
        st == 200 and isinstance(body, dict) and body.get("success") is True and (av0 is None or validate_has_playback(av0)),
        {"http": st, "videos_count": len(avideos) if isinstance(avideos, list) else None},
    )

    out_path = ".windsurf/logs/step7_validation_all_authenticated.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)

    print(f"[OK] wrote {out_path}")
    print(json.dumps(report, ensure_ascii=False, indent=2)[:7000])

    return 0 if report.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())
