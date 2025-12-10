import asyncio
import json
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import httpx
import requests
import types

from auto_supabase_import import (
    SUPABASE_URL,
    SUPABASE_SERVICE_KEY,
    RPC_HEADERS,
    supabase_read_data,
    supabase_insert_data,
    _build_table_request,
)


ROOT = Path.cwd().parent
sys.path.append(str(ROOT / "academia_bobodo_backend"))

EXECUTE_SQL_URL = f"{SUPABASE_URL}/rest/v1/rpc/execute_sql"


# Stub minimal pour le module external "livekit" afin de pouvoir importer le backend
if "livekit" not in sys.modules:
    livekit_module = types.ModuleType("livekit")
    livekit_api_module = types.ModuleType("livekit.api")
    setattr(livekit_module, "api", livekit_api_module)
    sys.modules["livekit"] = livekit_module
    sys.modules["livekit.api"] = livekit_api_module

import main as backend  # type: ignore  # noqa: E402


def exec_sql(label: str, sql: str) -> List[Dict[str, Any]]:
    """Exécute un SQL arbitraire via la RPC execute_sql et retourne une liste de lignes (dict)."""
    print(f"=== SQL {label} ===")
    print(sql)
    try:
        resp = requests.post(
            EXECUTE_SQL_URL,
            headers=RPC_HEADERS,
            json={"sql_query": sql},
            timeout=60,
        )
    except Exception as exc:
        print("SQL_NETWORK_ERROR", str(exc))
        return []

    print("SQL_STATUS", resp.status_code)
    try:
        data = resp.json()
    except Exception:
        print("SQL_RAW", resp.text[:2000])
        return []

    if isinstance(data, dict) and "error" in data:
        print("SQL_ERROR_BODY", json.dumps(data, ensure_ascii=False, default=str)[:2000])
        return []
    if isinstance(data, list):
        print("SQL_ROWS", json.dumps(data, ensure_ascii=False, default=str)[:2000])
        return data
    if data is None:
        print("SQL_NO_ROWS")
        return []
    print("SQL_UNEXPECTED", repr(data)[:2000])
    return []


def _sql_escape(value: str) -> str:
    return value.replace("'", "''")


def debug_read_table(table_name: str, limit: int = 10) -> List[Dict[str, Any]]:
    """Lecture d'une table app.* via execute_sql pour contourner les limitations PostgREST."""
    sql = f"SELECT * FROM {table_name} LIMIT {int(limit)}"
    return exec_sql(f"READ_{table_name}", sql)


def _pick_challenge_participation() -> Optional[Dict[str, Any]]:
    """Sélectionne une participation de challenge avec video_url non vide (via SQL direct)."""
    rows = exec_sql(
        "PICK_CHALLENGE_PARTICIPATION",
        "SELECT id, video_url, is_active, started_at "
        "FROM app.challenge_participations "
        "WHERE is_active = TRUE AND video_url IS NOT NULL "
        "ORDER BY started_at DESC "
        "LIMIT 20",
    )
    for row in rows:
        if not isinstance(row, dict):
            continue
        url = str(row.get("video_url") or "").strip()
        if url:
            return row
    return None


def _pick_hero_playlist_item() -> Optional[Dict[str, Any]]:
    """Sélectionne (ou crée) un item de playlist vidéo avec base_video_url non vide."""
    rows = exec_sql(
        "PICK_HERO_PLAYLIST",
        "SELECT id, slot, media_type, base_video_url, base_image_url, sort_order, created_at "
        "FROM app.hero_playlist "
        "ORDER BY created_at DESC "
        "LIMIT 20",
    )
    for row in rows:
        if not isinstance(row, dict):
            continue
        media_type = str(row.get("media_type") or "video").strip().lower()
        base_video_url = str(row.get("base_video_url") or "").strip()
        if media_type == "video" and base_video_url:
            return row

    # Si aucun item valide, on tente d'en créer un à partir d'une participation challenge existante
    src = _pick_challenge_participation()
    if not src:
        print("NO_CHALLENGE_SOURCE_FOR_HERO_PLAYLIST")
        return None
    video_url = str(src.get("video_url") or "").strip()
    if not video_url:
        print("CHALLENGE_SOURCE_HAS_NO_VIDEO_URL")
        return None

    video_sql = _sql_escape(video_url)
    insert_sql = (
        "INSERT INTO app.hero_playlist (slot, media_type, base_video_url, base_image_url, title, subtitle, sort_order, is_active) "
        f"VALUES ('landing_hero_main', 'video', '{video_sql}', NULL, 'Test Hero', 'Test Hero Render', 0, TRUE) "
        "RETURNING id, slot, media_type, base_video_url, base_image_url, sort_order, created_at"
    )
    new_rows = exec_sql("INSERT_HERO_PLAYLIST_TEST_ITEM", insert_sql)
    return new_rows[0] if new_rows else None


def _call_tv_rpc(name: str, payload: Dict[str, Any]) -> Tuple[int, Any]:
    url = f"{SUPABASE_URL}/rest/v1/rpc/{name}"
    try:
        resp = requests.post(url, headers=RPC_HEADERS, json=payload, timeout=15)
        try:
            body = resp.json()
        except Exception:
            body = {"raw": resp.text}
    except Exception as exc:  # réseau
        resp = None  # type: ignore[assignment]
        body = {"error": str(exc)}
        status_code = 0
    else:
        status_code = resp.status_code  # type: ignore[assignment]

    print(f"TV_RPC_{name.upper()}_STATUS", status_code)
    print(f"TV_RPC_{name.upper()}_RESPONSE", json.dumps(body, ensure_ascii=False, default=str))
    return status_code, body


async def test_hero_classic(client: httpx.AsyncClient) -> None:
    print("=== HERO_CLASSIC_TEST ===")
    item = _pick_hero_playlist_item()
    if item is None:
        print("HERO_TEST_SKIPPED", "no_video_playlist_item_with_base_video_url")
        return

    playlist_item_id = str(item.get("id"))
    slot = str(item.get("slot") or "default")
    payload = {"playlist_item_id": playlist_item_id, "slot": slot}

    resp = await client.post(
        "/hero/studio/render",
        json=payload,
        headers={"Authorization": f"Bearer {SUPABASE_SERVICE_KEY}"},
    )
    print("HERO_RENDER_STATUS", resp.status_code)
    try:
        hero_resp = resp.json()
    except Exception:
        hero_resp = {"raw": resp.text}
    print("HERO_RENDER_RESPONSE", json.dumps(hero_resp, ensure_ascii=False, default=str))

    # Afficher les tables impactées (lecture brute)
    hero_renders = debug_read_table("app.hero_renders", limit=50)
    hero_playlist = debug_read_table("app.hero_playlist", limit=50)
    print("HERO_RENDERS_TABLE", json.dumps(hero_renders, ensure_ascii=False, default=str))
    print("HERO_PLAYLIST_TABLE", json.dumps(hero_playlist, ensure_ascii=False, default=str))


async def test_tv_studio(client: httpx.AsyncClient) -> None:
    print("=== TV_STUDIO_TEST ===")
    item = _pick_hero_playlist_item()
    if item is None:
        print("TV_TEST_SKIPPED", "no_video_playlist_item_with_base_video_url")
        return

    playlist_item_id = str(item.get("id"))
    slot = str(item.get("slot") or "default")

    # Construire une timeline TV minimale via RPC upsert_overlay
    overlays_specs: List[Dict[str, Any]] = [
        {
            "p_id": None,
            "p_playlist_item_id": playlist_item_id,
            "p_overlay_type": "text",
            "p_config": {
                "text": "Bienvenue sur Academia TV",
                "align": "top_center",
                "fontcolor": "white",
                "fontsize": 40,
            },
            "p_start_at_seconds": 0.0,
            "p_end_at_seconds": 5.0,
            "p_sort_order": 0,
        },
        {
            "p_id": None,
            "p_playlist_item_id": playlist_item_id,
            "p_overlay_type": "banner",
            "p_config": {
                "text": "Inscris-toi dès maintenant",
                "align": "bottom_center",
                "fontcolor": "yellow",
                "fontsize": 32,
                "boxcolor": "black@0.8",
                "animation": "fade",
                "fade_in_duration": 0.5,
                "fade_out_duration": 0.5,
            },
            "p_start_at_seconds": 2.0,
            "p_end_at_seconds": 8.0,
            "p_sort_order": 1,
        },
        {
            "p_id": None,
            "p_playlist_item_id": playlist_item_id,
            "p_overlay_type": "ticker",
            "p_config": {
                "text": "Breaking: Nouveaux cours disponibles sur Academia...",
                "align": "bottom_center",
                "speed": 120,
            },
            "p_start_at_seconds": 0.0,
            "p_end_at_seconds": 12.0,
            "p_sort_order": 2,
        },
    ]

    for spec in overlays_specs:
        _call_tv_rpc("app_admin_tv_upsert_overlay", spec)

    # Lecture de la timeline via RPC TV
    _call_tv_rpc("app_admin_tv_get_timeline", {"p_playlist_item_id": playlist_item_id})

    # Lancer le rendu complet via l'endpoint /studio/tv/render (qui utilise app_admin_tv_request_render)
    tv_req_payload = {
        "playlist_item_id": playlist_item_id,
        "slot": slot,
        "meta": {"source": "test_script"},
    }
    resp = await client.post(
        "/studio/tv/render",
        json=tv_req_payload,
        headers={"Authorization": f"Bearer {SUPABASE_SERVICE_KEY}"},
    )
    print("TV_RENDER_STATUS", resp.status_code)
    try:
        tv_resp = resp.json()
    except Exception:
        tv_resp = {"raw": resp.text}
    print("TV_RENDER_RESPONSE", json.dumps(tv_resp, ensure_ascii=False, default=str))

    # Tables impactées
    hero_renders_tv = debug_read_table("app.hero_renders_tv", limit=50)
    hero_playlist = debug_read_table("app.hero_playlist", limit=50)
    print("TV_RENDERS_TABLE", json.dumps(hero_renders_tv, ensure_ascii=False, default=str))
    print("TV_PLAYLIST_TABLE", json.dumps(hero_playlist, ensure_ascii=False, default=str))


async def test_challenge_engine(client: httpx.AsyncClient) -> None:
    print("=== CHALLENGE_ENGINE_TEST ===")
    participation = _pick_challenge_participation()
    if participation is None:
        print("CHALLENGE_TEST_SKIPPED", "no_participation_with_video_url")
        return

    participation_id = str(participation.get("id"))

    resp = await client.post(
        f"/admin/challenge_videos/{participation_id}/rerender",
        headers={"Authorization": f"Bearer {SUPABASE_SERVICE_KEY}"},
    )
    print("CHALLENGE_RERENDER_STATUS", resp.status_code)
    try:
        ch_resp = resp.json()
    except Exception:
        ch_resp = {"raw": resp.text}
    print("CHALLENGE_RERENDER_RESPONSE", json.dumps(ch_resp, ensure_ascii=False, default=str))


async def main() -> None:
    transport = httpx.ASGITransport(app=backend.app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
        await test_hero_classic(client)
        await test_tv_studio(client)
        await test_challenge_engine(client)


if __name__ == "__main__":
    asyncio.run(main())
