#!/usr/bin/env python3
"""Outils admin pour app.hero_playlist / Hero Studio Télé.

Modes principaux (ligne de commande) :
- audit :
    * Liste complète de app.hero_playlist.
    * Liste des items media_type='video' AND is_active=TRUE AND base_video_url NULL/vide.
- fix_inconsistent :
    * Pour chaque item vidéo actif sans base_video_url, applique une correction "logique" :
        - Si un rendu existe déjà dans app.hero_renders, copie render_url -> base_video_url.
        - Sinon, désactive l'item (is_active=FALSE).
    * Affiche le résumé des corrections et vérifie qu'il ne reste plus d'items incohérents.
- render_tests :
    * Pour les slots landing_hero_main et student_home_hero_main :
        - garantit un item vidéo actif avec base_video_url.
        - lance un rendu Hero classique (/hero/studio/render).
        - crée une timeline TV minimale et lance un rendu TV (/studio/tv/render).
        - affiche les URLs de rendu et l'état final de hero_playlist.

Ce script utilise la RPC execute_sql exposée par le backend Supabase.
"""

from __future__ import annotations

import asyncio
import json
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

import httpx
import requests
import types

# Préparer l'import de auto_supabase_import et du backend FastAPI
ROOT = Path(__file__).resolve().parent.parent
WINDSURF_DIR = Path(__file__).resolve().parent

if str(WINDSURF_DIR) not in sys.path:
    sys.path.append(str(WINDSURF_DIR))

from auto_supabase_import import (  # type: ignore
    SUPABASE_URL,
    SUPABASE_SERVICE_KEY,
    RPC_HEADERS,
    supabase_update_data,
)

EXECUTE_SQL_URL = f"{SUPABASE_URL}/rest/v1/rpc/execute_sql"


def exec_sql(label: str, sql: str) -> List[Dict[str, Any]]:
    """Exécute un SQL arbitraire via execute_sql et retourne une liste de lignes (dict)."""
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


def audit_hero_playlist() -> int:
    """Audit complet de app.hero_playlist + items vidéo actifs sans base_video_url."""

    full_rows = exec_sql(
        "HERO_PLAYLIST_FULL",
        """
        SELECT *
        FROM app.hero_playlist
        ORDER BY slot, sort_order NULLS LAST, created_at ASC
        """,
    )
    print("HERO_PLAYLIST_FULL_JSON", json.dumps(full_rows, ensure_ascii=False, default=str))

    inconsistent_rows = exec_sql(
        "HERO_PLAYLIST_INCONSISTENT",
        """
        SELECT *
        FROM app.hero_playlist
        WHERE media_type = 'video'
          AND is_active = TRUE
          AND (base_video_url IS NULL OR TRIM(base_video_url) = '')
        ORDER BY slot, created_at ASC
        """,
    )
    print(
        "HERO_PLAYLIST_INCONSISTENT_JSON",
        json.dumps(inconsistent_rows, ensure_ascii=False, default=str),
    )

    return 0


def _get_last_render_url_for_item(playlist_item_id: str) -> Optional[str]:
    rows = exec_sql(
        "HERO_LAST_RENDER_FOR_ITEM",
        f"""
        SELECT id, render_url, thumbnail_url, created_at
        FROM app.hero_renders
        WHERE playlist_item_id = '{playlist_item_id}'
        ORDER BY created_at DESC
        LIMIT 1
        """,
    )
    if not rows:
        return None
    row = rows[0]
    url = str(row.get("render_url") or "").strip()
    return url or None


def fix_inconsistent_items() -> int:
    """Corrige les items vidéo actifs sans base_video_url.

    Stratégie :
    - Si un rendu existe dans hero_renders, copie render_url -> base_video_url.
    - Sinon, désactive l'item (is_active = FALSE).
    """

    inconsistent_rows = exec_sql(
        "HERO_PLAYLIST_INCONSISTENT_FOR_FIX",
        """
        SELECT *
        FROM app.hero_playlist
        WHERE media_type = 'video'
          AND is_active = TRUE
          AND (base_video_url IS NULL OR TRIM(base_video_url) = '')
        ORDER BY slot, created_at ASC
        """,
    )

    applied: List[Dict[str, Any]] = []

    for row in inconsistent_rows:
        if not isinstance(row, dict):
            continue
        playlist_item_id = str(row.get("id"))
        slot = str(row.get("slot") or "")
        print(f"FIX_ITEM playlist_item_id={playlist_item_id} slot={slot}")

        last_render_url = _get_last_render_url_for_item(playlist_item_id)
        if last_render_url:
            condition = f"id=eq.{playlist_item_id}"
            update_payload = {"base_video_url": last_render_url}
            result = supabase_update_data("app.hero_playlist", update_payload, condition)
            data = result.get("data") if isinstance(result, dict) else None
            updated_row = data[0] if isinstance(data, list) and data else None
            applied.append(
                {
                    "playlist_item_id": playlist_item_id,
                    "slot": slot,
                    "action": "set_base_video_url_from_last_render",
                    "last_render_url": last_render_url,
                    "updated_row": updated_row,
                }
            )
        else:
            condition = f"id=eq.{playlist_item_id}"
            update_payload = {"is_active": False}
            result = supabase_update_data("app.hero_playlist", update_payload, condition)
            data = result.get("data") if isinstance(result, dict) else None
            updated_row = data[0] if isinstance(data, list) and data else None
            applied.append(
                {
                    "playlist_item_id": playlist_item_id,
                    "slot": slot,
                    "action": "deactivate_item_no_render",
                    "updated_row": updated_row,
                }
            )

    print("HERO_PLAYLIST_FIX_SUMMARY_JSON", json.dumps(applied, ensure_ascii=False, default=str))

    remaining = exec_sql(
        "HERO_PLAYLIST_INCONSISTENT_AFTER_FIX",
        """
        SELECT *
        FROM app.hero_playlist
        WHERE media_type = 'video'
          AND is_active = TRUE
          AND (base_video_url IS NULL OR TRIM(base_video_url) = '')
        ORDER BY slot, created_at ASC
        """,
    )
    print(
        "HERO_PLAYLIST_INCONSISTENT_AFTER_FIX_JSON",
        json.dumps(remaining, ensure_ascii=False, default=str),
    )

    return 0


def _pick_challenge_source_video() -> Optional[str]:
    """Sélectionne une participation challenge avec video_url utilisable comme source Hero."""
    rows = exec_sql(
        "PICK_CHALLENGE_SOURCE_FOR_HERO",
        """
        SELECT id, video_url, is_active, started_at
        FROM app.challenge_participations
        WHERE is_active = TRUE
          AND video_url IS NOT NULL
        ORDER BY started_at DESC
        LIMIT 20
        """,
    )
    for row in rows:
        if not isinstance(row, dict):
            continue
        url = str(row.get("video_url") or "").strip()
        if url:
            return url
    return None


def _pick_or_create_item_for_slot(slot: str) -> Optional[Dict[str, Any]]:
    """Trouve ou crée un item vidéo actif avec base_video_url pour un slot donné."""
    rows = exec_sql(
        f"PICK_HERO_ITEM_FOR_SLOT_{slot}",
        f"""
        SELECT id, slot, media_type, base_video_url, base_image_url, sort_order, is_active, created_at
        FROM app.hero_playlist
        WHERE slot = '{slot}'
          AND media_type = 'video'
          AND is_active = TRUE
          AND base_video_url IS NOT NULL
          AND TRIM(base_video_url) <> ''
        ORDER BY sort_order NULLS LAST, created_at DESC
        LIMIT 5
        """,
    )
    for row in rows:
        if not isinstance(row, dict):
            continue
        url = str(row.get("base_video_url") or "").strip()
        if url:
            return row

    # Sinon, tenter de créer un item de test à partir d'une vidéo de challenge existante
    src_url = _pick_challenge_source_video()
    if not src_url:
        print(f"NO_CHALLENGE_SOURCE_FOR_SLOT_{slot}")
        return None

    video_sql = _sql_escape(src_url)
    insert_sql = (
        "INSERT INTO app.hero_playlist (slot, media_type, base_video_url, base_image_url, title, subtitle, sort_order, is_active) "
        f"VALUES ('{slot}', 'video', '{video_sql}', NULL, 'Test {slot}', 'Test Hero Render', 0, TRUE) "
        "RETURNING id, slot, media_type, base_video_url, base_image_url, sort_order, is_active, created_at"
    )
    new_rows = exec_sql(f"INSERT_HERO_ITEM_FOR_SLOT_{slot}", insert_sql)
    return new_rows[0] if new_rows else None


def _ensure_backend_imported() -> None:
    """Prépare l'import de backend.main (FastAPI) avec stub livekit si nécessaire."""
    if "livekit" not in sys.modules:
        livekit_module = types.ModuleType("livekit")
        livekit_api_module = types.ModuleType("livekit.api")
        setattr(livekit_module, "api", livekit_api_module)
        sys.modules["livekit"] = livekit_module
        sys.modules["livekit.api"] = livekit_api_module

    backend_dir = ROOT / "academia_bobodo_backend"
    if str(backend_dir) not in sys.path:
        sys.path.append(str(backend_dir))


def _call_tv_rpc(name: str, payload: Dict[str, Any]) -> None:
    url = f"{SUPABASE_URL}/rest/v1/rpc/{name}"
    try:
        resp = requests.post(url, headers=RPC_HEADERS, json=payload, timeout=15)
        try:
            body = resp.json()
        except Exception:
            body = {"raw": resp.text}
    except Exception as exc:
        status_code = 0
        body = {"error": str(exc)}
    else:
        status_code = resp.status_code

    print(f"TV_RPC_{name.upper()}_STATUS", status_code)
    print(f"TV_RPC_{name.upper()}_RESPONSE", json.dumps(body, ensure_ascii=False, default=str))


async def _run_hero_render_for_slot(client: httpx.AsyncClient, slot: str) -> None:
    print(f"=== HERO_CLASSIC_TEST slot={slot} ===")
    item = _pick_or_create_item_for_slot(slot)
    if item is None:
        print(f"HERO_CLASSIC_SKIPPED slot={slot} no_video_playlist_item_with_base_video_url")
        return

    playlist_item_id = str(item.get("id"))
    payload = {"playlist_item_id": playlist_item_id, "slot": slot}

    resp = await client.post(
        "/hero/studio/render",
        json=payload,
        headers={"Authorization": f"Bearer {SUPABASE_SERVICE_KEY}"},
    )
    print("HERO_RENDER_STATUS", slot, resp.status_code)
    try:
        hero_resp = resp.json()
    except Exception:
        hero_resp = {"raw": resp.text}
    print("HERO_RENDER_RESPONSE", slot, json.dumps(hero_resp, ensure_ascii=False, default=str))

    # Tables impactées pour ce playlist_item_id
    hero_renders = exec_sql(
        f"HERO_RENDERS_FOR_SLOT_{slot}",
        f"""
        SELECT id, playlist_item_id, status, render_url, thumbnail_url, created_at, updated_at
        FROM app.hero_renders
        WHERE playlist_item_id = '{playlist_item_id}'
        ORDER BY created_at DESC
        LIMIT 5
        """,
    )
    hero_playlist = exec_sql(
        f"HERO_PLAYLIST_ROW_AFTER_CLASSIC_{slot}",
        f"""
        SELECT id, slot, media_type, base_video_url, base_image_url, is_active, created_at, updated_at
        FROM app.hero_playlist
        WHERE id = '{playlist_item_id}'
        """,
    )
    print(
        "HERO_CLASSIC_RESULT",
        slot,
        json.dumps(
            {
                "playlist_item": hero_playlist[0] if hero_playlist else None,
                "hero_renders": hero_renders,
            },
            ensure_ascii=False,
            default=str,
        ),
    )


async def _run_tv_render_for_slot(client: httpx.AsyncClient, slot: str) -> None:
    print(f"=== TV_STUDIO_TEST slot={slot} ===")
    item = _pick_or_create_item_for_slot(slot)
    if item is None:
        print(f"TV_STUDIO_SKIPPED slot={slot} no_video_playlist_item_with_base_video_url")
        return

    playlist_item_id = str(item.get("id"))

    overlays_specs: List[Dict[str, Any]] = [
        {
            "p_id": None,
            "p_playlist_item_id": playlist_item_id,
            "p_overlay_type": "text",
            "p_config": {
                "text": f"Bienvenue sur Academia TV ({slot})",
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

    _call_tv_rpc("app_admin_tv_get_timeline", {"p_playlist_item_id": playlist_item_id})

    tv_req_payload = {
        "playlist_item_id": playlist_item_id,
        "slot": slot,
        "meta": {"source": "hero_playlist_admin_render_tests"},
    }
    resp = await client.post(
        "/studio/tv/render",
        json=tv_req_payload,
        headers={"Authorization": f"Bearer {SUPABASE_SERVICE_KEY}"},
    )
    print("TV_RENDER_STATUS", slot, resp.status_code)
    try:
        tv_resp = resp.json()
    except Exception:
        tv_resp = {"raw": resp.text}
    print("TV_RENDER_RESPONSE", slot, json.dumps(tv_resp, ensure_ascii=False, default=str))

    hero_renders_tv = exec_sql(
        f"HERO_RENDERS_TV_FOR_SLOT_{slot}",
        f"""
        SELECT id, playlist_item_id, status, render_url, thumbnail_url, created_at, updated_at
        FROM app.hero_renders_tv
        WHERE playlist_item_id = '{playlist_item_id}'
        ORDER BY created_at DESC
        LIMIT 5
        """,
    )
    hero_playlist = exec_sql(
        f"HERO_PLAYLIST_ROW_AFTER_TV_{slot}",
        f"""
        SELECT id, slot, media_type, base_video_url, base_image_url, is_active, created_at, updated_at
        FROM app.hero_playlist
        WHERE id = '{playlist_item_id}'
        """,
    )

    print(
        "HERO_TV_RESULT",
        slot,
        json.dumps(
            {
                "playlist_item": hero_playlist[0] if hero_playlist else None,
                "hero_renders_tv": hero_renders_tv,
            },
            ensure_ascii=False,
            default=str,
        ),
    )


async def run_render_tests() -> None:
    """Lance les rendus Hero classique + TV pour les slots clés."""
    _ensure_backend_imported()
    import main as backend  # type: ignore  # noqa: E402

    transport = httpx.ASGITransport(app=backend.app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
        for slot in ["landing_hero_main", "student_home_hero_main"]:
            await _run_hero_render_for_slot(client, slot)
            await _run_tv_render_for_slot(client, slot)


def main(argv: List[str]) -> int:
    if len(argv) < 2:
        print("Usage: hero_playlist_admin.py [audit|fix_inconsistent|render_tests]")
        return 1

    mode = argv[1]
    if mode == "audit":
        return audit_hero_playlist()
    if mode == "fix_inconsistent":
        return fix_inconsistent_items()
    if mode == "render_tests":
        asyncio.run(run_render_tests())
        return 0

    print(f"Unknown mode: {mode}")
    return 1


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main(sys.argv))
