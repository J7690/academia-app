#!/usr/bin/env python3
"""Audit des médias de mini-site université via le proxy Supabase sur Railway.

Objectifs (lecture seule) :
- Appeler la RPC app_public_university_site via le proxy Railway avec un JWT étudiant
  pour un slug de mini-site réel (ex: universite-arbilo).
- Inspecter la structure renvoyée (champ "media").
- Extraire les médias (videos / images) et construire des URLs candidates :
  - media['url'] directe si présente,
  - sinon stockage Supabase (bucket "university-media" + storage_path) pour audit ultérieur.
- Tester par HTTP quelques URLs directes (Mux / externes) pour voir si elles sont
  accessibles (statut, Content-Type).

Aucune écriture en base.
"""

from __future__ import annotations

import json
from typing import Any, Dict, List, Tuple

import requests

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SUPABASE_ANON_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    "eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMwNTY1NjAsImV4cCI6MjA3ODYzMjU2MH0."
    "8Zm6i6UaOrEOUvOafHOXOf0UiPOdp7on-aajYASOdk8"
)

BACKEND_PROXY_BASE = (
    "https://academia-app-production.up.railway.app/supabase/rest/v1/rpc"
)

STUDENT_EMAIL = "nexiomgroup@gmail.com"
STUDENT_PASSWORD = "Wenden@Koote3"


def login_direct() -> str:
    """Obtient un JWT étudiant directement depuis Supabase (sans proxy)."""

    url = f"{SUPABASE_URL}/auth/v1/token?grant_type=password"
    headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    body = {"email": STUDENT_EMAIL, "password": STUDENT_PASSWORD}

    print("[LOGIN_DIRECT] POST", url)
    resp = requests.post(url, headers=headers, json=body, timeout=30)
    print("[LOGIN_DIRECT][STATUS]", resp.status_code)
    data = resp.json()
    print("[LOGIN_DIRECT][BODY][TRUNC]", json.dumps(data, ensure_ascii=False, indent=2)[:800])

    access_token = data.get("access_token")
    if not access_token:
        raise SystemExit("[LOGIN_DIRECT] Pas d'access_token dans la réponse")
    return access_token


def call_university_site_via_proxy(jwt: str, slug: str) -> Dict[str, Any]:
    """Appelle la RPC app_public_university_site via le proxy Railway."""

    url = f"{BACKEND_PROXY_BASE}/app_public_university_site"
    headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Authorization": f"Bearer {jwt}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    body = {"p_slug": slug}

    print("\n[RPC_PROXY] app_public_university_site")
    print("[POST]", url)
    print(
        "[HEADERS]",
        {k: headers[k] for k in ("apikey", "Authorization", "Content-Type", "Accept")},
    )
    print("[BODY]", body)

    resp = requests.post(url, headers=headers, json=body, timeout=30)
    print("[STATUS]", resp.status_code)
    text = resp.text
    if len(text) > 2000:
        text_preview = text[:2000] + "... (troncature)"
    else:
        text_preview = text

    try:
        data = resp.json()
        print(
            "[RESP_BODY_JSON][TRUNC]",
            json.dumps(data, ensure_ascii=False, indent=2)[:2000],
        )
    except Exception:
        print("[RESP_BODY_RAW][TRUNC]", text_preview)
        raise SystemExit("[RPC_PROXY] Réponse non JSON pour app_public_university_site")

    if not isinstance(data, dict):
        raise SystemExit("[RPC_PROXY] Réponse inattendue (pas un objet JSON racine)")
    return data


def extract_media(payload: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Extrait la liste des médias depuis la réponse.

    StudentUniversitySiteProvider s'attend à un objet avec au moins un champ
    "media" qui est une liste.
    """

    if payload.get("success") is not True:
        print("[WARN] Champ success != true dans la réponse university_site")

    media = payload.get("media") or []
    if not isinstance(media, list):
        print("[WARN] Champ media manquant ou non liste")
        return []

    print(f"[INFO] Nombre de médias: {len(media)}")
    return [dict(m) for m in media if isinstance(m, dict)]


def build_candidate_url(media: Dict[str, Any]) -> Tuple[str | None, str]:
    """Construit une URL candidate à partir d'un média de mini-site.

    On s'aligne sur la logique de MiniSiteMediaViewerScreen / MiniSiteHeroVideo :
    - media['url'] directe si présente
    - sinon storage_path dans le bucket "university-media" (on renvoie un descripteur
      storage://university-media/path pour un audit ultérieur via Storage).
    """

    title = str(media.get("title") or "").strip()
    mtype = str(media.get("media_type") or "").strip()
    direct_url = str(media.get("url") or "").strip()
    storage_path = str(media.get("storage_path") or "").strip()

    if direct_url:
        return direct_url, f"direct_url | type={mtype} | title={title}"

    if storage_path:
        pseudo = f"storage://university-media/{storage_path}"
        return None, f"storage_path ({pseudo}) | type={mtype} | title={title}"

    return None, f"no_url_fields | type={mtype} | title={title}"


def sample_and_test_urls(media_list: List[Dict[str, Any]], max_tests: int = 10) -> None:
    """Affiche un échantillon de médias et teste quelques URLs HTTP directes."""

    http_urls: List[Tuple[str, str]] = []
    storage_descriptors: List[str] = []

    print("\n[INFO] Échantillon de médias (premiers 20)")
    for idx, m in enumerate(media_list[:20]):
        url, desc = build_candidate_url(m)
        print(f"  #{idx+1}: {desc}")
        if url and url.startswith("http"):
            http_urls.append((url, desc))
        elif url is None and "storage_path (storage://" in desc:
            storage_descriptors.append(desc)

    if storage_descriptors:
        print("\n[INFO] Médias basés sur Storage (à auditer via createSignedUrl):")
        for d in storage_descriptors[:10]:
            print("  -", d)

    print("\n[INFO] Test HTTP sur quelques URLs directes (Mux / externes)")
    for url, desc in http_urls[:max_tests]:
        print(f"\n[HTTP TEST] {url}")
        print("  Contexte:", desc)
        try:
            resp = requests.get(url, timeout=10, stream=True)
        except Exception as exc:  # pragma: no cover
            print("  [ERROR] Exception réseau:", repr(exc))
            continue
        content_type = resp.headers.get("Content-Type") or resp.headers.get("content-type")
        print("  [STATUS]", resp.status_code)
        print("  [Content-Type]", content_type)


def main() -> int:
    jwt = login_direct()
    # On utilise un slug réel observé dans app_list_home_offers.
    slug = "universite-arbilo"
    payload = call_university_site_via_proxy(jwt, slug)
    media_list = extract_media(payload)
    if not media_list:
        print("[WARN] Aucun média trouvé pour le mini-site", slug)
        return 0

    sample_and_test_urls(media_list)
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
