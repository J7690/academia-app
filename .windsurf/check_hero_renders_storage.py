#!/usr/bin/env python3
"""Vérification des objets Hero/TV dans le bucket Supabase 'landing-media'.

Ce script interroge directement l'API Storage Supabase (en réseau réel) pour
lister les objets sous les préfixes suivants :

- hero-renders/landing_hero_main
- hero-renders/student_home_hero_main

Usage :
    python .windsurf/check_hero_renders_storage.py
"""

from __future__ import annotations

import json
from typing import Any, Dict, List

import requests

from auto_supabase_import import (  # type: ignore
    SUPABASE_URL,
    API_HEADERS,
)


def list_prefix(prefix: str) -> Dict[str, Any]:
    """Vérifie un préfixe Storage et retourne un diagnostic structuré."""

    url = f"{SUPABASE_URL}/storage/v1/object/list/landing-media"
    payload = {
        "prefix": prefix,
        "limit": 100,
        "offset": 0,
        "sortBy": {"column": "name", "order": "asc"},
    }

    print(f"=== STORAGE LIST prefix={prefix} ===")
    print("REQUEST", url)
    try:
        resp = requests.post(
            url,
            headers={**API_HEADERS, "Content-Type": "application/json"},
            json=payload,
            timeout=20,
        )
    except Exception as exc:
        print("STORAGE_NETWORK_ERROR", str(exc))
        return {
            "status": "error",
            "layer": "network_or_storage_api",
            "prefix": prefix,
            "count": 0,
            "objects": [],
            "responsibility_hint": "infra_or_supabase_network",
            "error": {
                "type": "network_error",
                "message": str(exc),
            },
        }

    print("STATUS", resp.status_code)

    if resp.status_code != 200:
        body_preview = resp.text[:2000]
        print("STORAGE_HTTP_ERROR_BODY", body_preview)
        return {
            "status": "error",
            "layer": "storage_api",
            "prefix": prefix,
            "count": 0,
            "objects": [],
            "responsibility_hint": "supabase_storage_or_permissions",
            "error": {
                "type": "http_error",
                "status_code": resp.status_code,
                "body": body_preview,
            },
        }

    try:
        data = resp.json()
    except Exception as exc:
        print("RAW", resp.text[:2000])
        return {
            "status": "error",
            "layer": "storage_api",
            "prefix": prefix,
            "count": 0,
            "objects": [],
            "responsibility_hint": "supabase_storage_or_response_format",
            "error": {
                "type": "parse_error",
                "message": str(exc),
            },
        }

    if isinstance(data, dict) and data.get("message"):
        body_preview = json.dumps(data, ensure_ascii=False, default=str)[:2000]
        print("STORAGE_ERROR_BODY", body_preview)
        return {
            "status": "error",
            "layer": "storage_api",
            "prefix": prefix,
            "count": 0,
            "objects": [],
            "responsibility_hint": "supabase_storage_or_permissions",
            "error": {
                "type": "storage_error",
                "message": data.get("message"),
                "raw": data,
            },
        }

    if isinstance(data, list):
        print("OBJECTS_JSON", json.dumps(data, ensure_ascii=False, default=str)[:2000])
        objects = [o.get("name") for o in data if isinstance(o, dict)]
        status = "ok" if objects else "missing"
        responsibility_hint = "render_pipeline_or_upload_missing" if not objects else "ok"
        return {
            "status": status,
            "layer": "storage_bucket",
            "prefix": prefix,
            "count": len(objects),
            "objects": objects,
            "responsibility_hint": responsibility_hint,
            "error": None,
        }

    print("UNEXPECTED_BODY", repr(data)[:2000])
    return {
        "status": "error",
        "layer": "storage_api",
        "prefix": prefix,
        "count": 0,
        "objects": [],
        "responsibility_hint": "supabase_storage_or_response_format",
        "error": {
            "type": "unexpected_body",
            "raw_repr": repr(data)[:2000],
        },
    }


def main() -> int:
    slot_to_prefix = {
        "landing_hero_main": "hero-renders/landing_hero_main",
        "student_home_hero_main": "hero-renders/student_home_hero_main",
    }
    results: Dict[str, Any] = {}
    for slot, prefix in slot_to_prefix.items():
        diag = list_prefix(prefix)
        diag["slot"] = slot
        results[slot] = diag

    print("\n=== SUMMARY ===")
    print(json.dumps(results, ensure_ascii=False, default=str, indent=2))
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
