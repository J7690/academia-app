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
)

ROOT = Path.cwd().parent
sys.path.append(str(ROOT / "academia_bobodo_backend"))

# Stub minimal pour le module external "livekit" afin de pouvoir importer le backend
if "livekit" not in sys.modules:
    livekit_module = types.ModuleType("livekit")
    livekit_api_module = types.ModuleType("livekit.api")
    setattr(livekit_module, "api", livekit_api_module)
    sys.modules["livekit"] = livekit_module
    sys.modules["livekit.api"] = livekit_api_module

import main as backend  # type: ignore  # noqa: E402
from tv_pro_filter_builder import build_tv_pro_filtergraph  # type: ignore  # noqa: E402


EXECUTE_SQL_URL = f"{SUPABASE_URL}/rest/v1/rpc/execute_sql"


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
    sql = f"SELECT * FROM {table_name} ORDER BY created_at DESC LIMIT {int(limit)}"
    return exec_sql(f"READ_{table_name}", sql)


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
    return None


def _call_tv_rpc(name: str, payload: Dict[str, Any]) -> Tuple[int, Any]:
    url = f"{SUPABASE_URL}/rest/v1/rpc/{name}"
    try:
        resp = requests.post(url, headers=RPC_HEADERS, json=payload, timeout=30)
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


def test_tv_pro_builder_smoke() -> None:
    """Test simple du builder TV PRO pour vérifier que le filtergraph est construit sans erreur."""
    print("=== TV_PRO_BUILDER_SMOKE ===")
    timeline = {
        "duration": 12,
        "overlays": [
            {
                "id": "text1",
                "type": "text",
                "text": "Academia TV PRO",
                "align": "top_center",
                "start_at_seconds": 0.0,
                "end_at_seconds": 4.0,
            },
            {
                "id": "banner1",
                "type": "lower_third",
                "text": "Breaking News · TV PRO",
                "align": "bottom_center",
                "start_at_seconds": 2.0,
                "end_at_seconds": 8.0,
            },
            {
                "id": "ticker1",
                "type": "ticker",
                "text": "Ticker PRO: nouveaux cours disponibles sur Academia...",
                "start_at_seconds": 0.0,
                "end_at_seconds": 10.0,
                "speed": 120,
            },
        ],
    }
    result = build_tv_pro_filtergraph({"overlays": timeline["overlays"]})
    print("TV_PRO_BUILDER_RESULT", json.dumps(result, ensure_ascii=False, default=str))


async def test_tv_pro_render(client: httpx.AsyncClient) -> None:
    print("=== TV_PRO_STUDIO_TEST ===")
    item = _pick_hero_playlist_item()
    if item is None:
        print("TV_PRO_TEST_SKIPPED", "no_video_playlist_item_with_base_video_url")
        return

    playlist_item_id = str(item.get("id"))
    slot = str(item.get("slot") or "default")

    # 1) Construire une timeline TV PRO minimale via la RPC JSON
    overlays = [
        {
            "id": "text_pro_1",
            "type": "text",
            "text": "Academia TV PRO",
            "align": "top_center",
            "start_at_seconds": 0.0,
            "end_at_seconds": 4.0,
        },
        {
            "id": "banner_pro_1",
            "type": "lower_third",
            "text": "Edition PRO",
            "align": "bottom_center",
            "start_at_seconds": 2.0,
            "end_at_seconds": 8.0,
        },
        {
            "id": "ticker_pro_1",
            "type": "ticker",
            "text": "Ticker PRO: nouveaux cours disponibles sur Academia...",
            "start_at_seconds": 0.0,
            "end_at_seconds": 10.0,
            "speed": 120,
        },
    ]

    timeline_payload = {
        "p_playlist_item_id": playlist_item_id,
        "p_timeline": {
            "timeline": {
                "duration": 12,
                "overlays": overlays,
            }
        },
    }

    _call_tv_rpc("app_admin_tv_upsert_timeline_json", timeline_payload)
    _call_tv_rpc("app_admin_tv_get_timeline_json", {"p_playlist_item_id": playlist_item_id})

    # 2) Lancer le rendu TV PRO final
    tv_req_payload = {
        "playlist_item_id": playlist_item_id,
        "slot": slot,
        "meta": {"source": "test_script", "engine": "tv_pro"},
    }
    resp = await client.post(
        "/studio/tv_pro/render",
        json=tv_req_payload,
        headers={"Authorization": f"Bearer {SUPABASE_SERVICE_KEY}"},
    )
    print("TV_PRO_RENDER_STATUS", resp.status_code)
    try:
        tv_resp = resp.json()
    except Exception:
        tv_resp = {"raw": resp.text}
    print("TV_PRO_RENDER_RESPONSE", json.dumps(tv_resp, ensure_ascii=False, default=str))

    # 3) Tables impactées
    hero_renders_tv = debug_read_table("app.hero_renders_tv", limit=50)
    hero_playlist = debug_read_table("app.hero_playlist", limit=50)
    print("TV_PRO_RENDERS_TABLE", json.dumps(hero_renders_tv, ensure_ascii=False, default=str))
    print("TV_PRO_PLAYLIST_TABLE", json.dumps(hero_playlist, ensure_ascii=False, default=str))


async def _run_tv_pro_scenario(
    client: httpx.AsyncClient,
    item: Dict[str, Any],
    overlays: List[Dict[str, Any]],
    label: str,
) -> None:
    playlist_item_id = str(item.get("id"))
    slot = str(item.get("slot") or "default")

    timeline_payload = {
        "p_playlist_item_id": playlist_item_id,
        "p_timeline": {
            "timeline": {
                "duration": 15,
                "overlays": overlays,
            }
        },
    }

    _call_tv_rpc("app_admin_tv_upsert_timeline_json", timeline_payload)
    _call_tv_rpc("app_admin_tv_get_timeline_json", {"p_playlist_item_id": playlist_item_id})

    tv_req_payload = {
        "playlist_item_id": playlist_item_id,
        "slot": slot,
        "meta": {"source": "test_script", "engine": "tv_pro", "scenario": label},
    }
    resp = await client.post(
        "/studio/tv_pro/render",
        json=tv_req_payload,
        headers={"Authorization": f"Bearer {SUPABASE_SERVICE_KEY}"},
    )
    print(f"TV_PRO_{label.upper()}_STATUS", resp.status_code)
    try:
        tv_resp = resp.json()
    except Exception:
        tv_resp = {"raw": resp.text}
    print(f"TV_PRO_{label.upper()}_RESPONSE", json.dumps(tv_resp, ensure_ascii=False, default=str))


async def test_tv_pro_slide_animation(client: httpx.AsyncClient) -> None:
    print("=== TV_PRO_SLIDE_ANIMATION ===")
    item = _pick_hero_playlist_item()
    if item is None:
        print("TV_PRO_SLIDE_SKIPPED", "no_video_playlist_item_with_base_video_url")
        return

    overlays = [
        {
            "id": "slide_text",
            "type": "text",
            "text": "Slide from left",
            "align": "top_left",
            "start_at_seconds": 0.0,
            "end_at_seconds": 4.0,
            "animation": {"mode": "slide_from_left"},
        }
    ]

    await _run_tv_pro_scenario(client, item, overlays, "slide")


async def test_tv_pro_zoom_animation(client: httpx.AsyncClient) -> None:
    print("=== TV_PRO_ZOOM_ANIMATION ===")
    item = _pick_hero_playlist_item()
    if item is None:
        print("TV_PRO_ZOOM_SKIPPED", "no_video_playlist_item_with_base_video_url")
        return

    base_video_url = str(item.get("base_video_url") or "").strip()
    if not base_video_url:
        print("TV_PRO_ZOOM_SKIPPED", "playlist_item_has_no_base_video_url")
        return

    overlays = [
        {
            "id": "pip_zoom",
            "type": "pip",
            "source_url": base_video_url,
            "start_at_seconds": 0.0,
            "end_at_seconds": 5.0,
            "pip_options": {"scale": 0.3},
        }
    ]

    await _run_tv_pro_scenario(client, item, overlays, "zoom")


async def test_tv_pro_rotation_animation(client: httpx.AsyncClient) -> None:
    print("=== TV_PRO_ROTATION_ANIMATION ===")
    item = _pick_hero_playlist_item()
    if item is None:
        print("TV_PRO_ROTATION_SKIPPED", "no_video_playlist_item_with_base_video_url")
        return

    base_video_url = str(item.get("base_video_url") or "").strip()
    if not base_video_url:
        print("TV_PRO_ROTATION_SKIPPED", "playlist_item_has_no_base_video_url")
        return

    overlays = [
        {
            "id": "pip_rotate",
            "type": "pip",
            "source_url": base_video_url,
            "start_at_seconds": 0.0,
            "end_at_seconds": 5.0,
            "transform": {"rotate": 45.0},
        }
    ]

    await _run_tv_pro_scenario(client, item, overlays, "rotation")


async def test_tv_pro_background_blur(client: httpx.AsyncClient) -> None:
    print("=== TV_PRO_BACKGROUND_BLUR ===")
    item = _pick_hero_playlist_item()
    if item is None:
        print("TV_PRO_BG_BLUR_SKIPPED", "no_video_playlist_item_with_base_video_url")
        return

    overlays = [
        {
            "id": "bg_blur",
            "type": "background",
            "background_mode": "blur",
            "start_at_seconds": 0.0,
            "end_at_seconds": 10.0,
        },
        {
            "id": "text_on_blur",
            "type": "text",
            "text": "Blurred background",
            "align": "center",
            "start_at_seconds": 1.0,
            "end_at_seconds": 6.0,
        },
    ]

    await _run_tv_pro_scenario(client, item, overlays, "background_blur")


async def test_tv_pro_pip_rounded(client: httpx.AsyncClient) -> None:
    print("=== TV_PRO_PIP_ROUNDED ===")
    item = _pick_hero_playlist_item()
    if item is None:
        print("TV_PRO_PIP_ROUNDED_SKIPPED", "no_video_playlist_item_with_base_video_url")
        return

    base_video_url = str(item.get("base_video_url") or "").strip()
    if not base_video_url:
        print("TV_PRO_PIP_ROUNDED_SKIPPED", "playlist_item_has_no_base_video_url")
        return

    overlays = [
        {
            "id": "pip_rounded",
            "type": "pip",
            "source_url": base_video_url,
            "start_at_seconds": 0.0,
            "end_at_seconds": 8.0,
            "pip_options": {
                "scale": 0.35,
                "rounded_corners": True,
                "corner_radius": 24,
                "border_width": 4,
                "border_color": "white",
                "shadow": True,
            },
        },
    ]

    await _run_tv_pro_scenario(client, item, overlays, "pip_rounded")


async def test_tv_pro_keyframes(client: httpx.AsyncClient) -> None:
    print("=== TV_PRO_KEYFRAMES ===")
    item = _pick_hero_playlist_item()
    if item is None:
        print("TV_PRO_KEYFRAMES_SKIPPED", "no_video_playlist_item_with_base_video_url")
        return

    base_video_url = str(item.get("base_video_url") or "").strip()
    if not base_video_url:
        print("TV_PRO_KEYFRAMES_SKIPPED", "playlist_item_has_no_base_video_url")
        return

    overlays = [
        {
            "id": "pip_kf",
            "type": "pip",
            "source_url": base_video_url,
            "start_at_seconds": 0.0,
            "end_at_seconds": 8.0,
            "keyframes": [
                {
                    "t": 0.0,
                    "x": 40,
                    "y": 40,
                    "opacity": 0.0,
                    "scale": 0.25,
                    "rotate": 0.0,
                },
                {
                    "t": 3.0,
                    "x": 320,
                    "y": 180,
                    "opacity": 1.0,
                    "scale": 0.5,
                    "rotate": 20.0,
                },
            ],
        },
    ]

    await _run_tv_pro_scenario(client, item, overlays, "keyframes")


async def main() -> None:
    test_tv_pro_builder_smoke()

    transport = httpx.ASGITransport(app=backend.app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
        await test_tv_pro_render(client)
        await test_tv_pro_slide_animation(client)
        await test_tv_pro_zoom_animation(client)
        await test_tv_pro_rotation_animation(client)
        await test_tv_pro_background_blur(client)
        await test_tv_pro_pip_rounded(client)
        await test_tv_pro_keyframes(client)


if __name__ == "__main__":
    asyncio.run(main())
