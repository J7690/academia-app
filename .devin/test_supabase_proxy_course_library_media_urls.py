#!/usr/bin/env python3
"""Audit des ressources de cours via le proxy Supabase sur Railway.

Objectifs (lecture seule) :
- Appeler la RPC app_list_course_library via le proxy Railway avec un JWT étudiant.
- Inspecter la structure domains / units / resources renvoyée par l'API.
- Extraire quelques ressources et reconstruire les URLs candidates (Mux, external_url,
  Storage Supabase : bucket + path).
- Tester par HTTP quelques URLs candidates (sans télécharger tout le contenu) pour
  vérifier leur accessibilité (statut HTTP, Content-Type).

Aucune écriture en base, aucune suppression. Ce script est purement diagnostique.
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
    """Obtient un JWT étudiant directement depuis Supabase (sans passer par le proxy).

    On réutilise le même schéma que dans les autres scripts d'audit :
    - POST /auth/v1/token?grant_type=password
    - On récupère access_token dans la réponse JSON.
    """

    url = f"{SUPABASE_URL}/auth/v1/token?grant_type=password"
    headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    body = {"email": STUDENT_EMAIL, "password": STUDENT_PASSWORD}

    print("[LOGIN_DIRECT] POST", url)
    try:
        resp = requests.post(url, headers=headers, json=body, timeout=30)
    except Exception as exc:  # pragma: no cover
        print("[LOGIN_DIRECT][ERROR]", repr(exc))
        raise

    print("[LOGIN_DIRECT][STATUS]", resp.status_code)
    data = resp.json()
    print("[LOGIN_DIRECT][BODY][TRUNC]", json.dumps(data, ensure_ascii=False, indent=2)[:1000])

    access_token = data.get("access_token")
    if not access_token:
        raise SystemExit("[LOGIN_DIRECT] Pas d'access_token dans la réponse")
    return access_token


def call_course_library_via_proxy(jwt: str) -> Dict[str, Any]:
    """Appelle la RPC app_list_course_library via le proxy Railway.

    On envoie :
    - apikey : clé ANON publique
    - Authorization : Bearer <JWT étudiant>
    pour simuler fidèlement ce que fait Supabase Flutter côté app.
    """

    url = f"{BACKEND_PROXY_BASE}/app_list_course_library"
    headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Authorization": f"Bearer {jwt}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }

    print("\n[RPC_PROXY] app_list_course_library")
    print("[POST]", url)
    print(
        "[HEADERS]",
        {k: headers[k] for k in ("apikey", "Authorization", "Content-Type", "Accept")},
    )

    try:
        resp = requests.post(url, headers=headers, json={}, timeout=30)
    except Exception as exc:  # pragma: no cover
        print("[RPC_PROXY][ERROR]", repr(exc))
        raise

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
        raise SystemExit("[RPC_PROXY] Réponse non JSON pour app_list_course_library")

    if not isinstance(data, dict):
        raise SystemExit("[RPC_PROXY] Réponse inattendue (pas un objet JSON racine)")
    return data


def extract_course_resources(payload: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Extrait la liste plate des ressources de cours depuis la réponse.

    La structure attendue est similaire à celle consommée par StudentCourseLibraryProvider :

    {
      "success": true,
      "domains": [
        {
          "title": ..., "units": [
             {
               "title": ..., "resources": [ {...}, ... ]
             },
             ...
          ]
        },
        ...
      ]
    }
    """

    if payload.get("success") is not True:
        print("[WARN] Champ success != true dans la réponse course_library")

    domains = payload.get("domains") or []
    if not isinstance(domains, list):
        print("[WARN] Champ domains manquant ou non liste")
        return []

    resources: List[Dict[str, Any]] = []
    for d in domains:
        if not isinstance(d, dict):
            continue
        units = d.get("units") or []
        if not isinstance(units, list):
            continue
        for u in units:
            if not isinstance(u, dict):
                continue
            res_list = u.get("resources") or []
            if not isinstance(res_list, list):
                continue
            for r in res_list:
                if not isinstance(r, dict):
                    continue
                resources.append(dict(r))

    print(f"[INFO] Domains: {len(domains)}  Resources extraites: {len(resources)}")
    return resources


def summarize_url_usage(resources: List[Dict[str, Any]]) -> None:
    """Affiche un résumé des types d'URL utilisés par les ressources.

    Permet de mesurer, avant migration, combien de ressources dépendent encore de
    mux_playback_id, external_url ou d'un schéma Storage propre.
    """

    counts = {
        "mux_playback_id": 0,
        "external_url": 0,
        "bucket_http_only": 0,
        "storage_bucket_path": 0,
        "no_url_fields": 0,
    }
    examples_mux: List[str] = []
    examples_external: List[str] = []

    for r in resources:
        url, desc = build_candidate_url(r)
        if "mux_playback_id" in desc or "mux_url" in desc:
            counts["mux_playback_id"] += 1
            if len(examples_mux) < 5:
                examples_mux.append(desc)
        elif "external_url" in desc:
            counts["external_url"] += 1
            if len(examples_external) < 5:
                examples_external.append(desc)
        elif "bucket_http_only" in desc:
            counts["bucket_http_only"] += 1
        elif "storage_bucket_path" in desc:
            counts["storage_bucket_path"] += 1
        else:
            counts["no_url_fields"] += 1

    print("\n[SUMMARY] Répartition des types d'URL pour les ressources de cours :")
    for key, value in counts.items():
        print(f"  - {key}: {value}")

    if examples_mux:
        print("\n[SUMMARY] Exemples de ressources utilisant Mux :")
        for e in examples_mux:
            print("  *", e)

    if examples_external:
        print("\n[SUMMARY] Exemples de ressources utilisant external_url :")
        for e in examples_external:
            print("  *", e)


def build_candidate_url(resource: Dict[str, Any]) -> Tuple[str | None, str]:
    """Construit une URL candidate à partir d'une ressource.

    On reproduit la logique de CourseResourceViewerScreen côté Flutter :
    - mux_playback_id -> URL Mux .m3u8 (ou URL Mux déjà complète)
    - sinon external_url
    - sinon bucket+path (on ne signe pas encore ici, on retourne un pseudo-URL
      descriptif de la forme "storage://bucket/path").
    """

    title = str(resource.get("title") or "").strip()
    rtype = str(resource.get("resource_type") or "").strip()

    mux_raw = str(resource.get("mux_playback_id") or "").strip()
    if mux_raw:
        if mux_raw.startswith("http"):
            return mux_raw, f"mux_url (direct) | type={rtype} | title={title}"
        url = f"https://stream.mux.com/{mux_raw}.m3u8"
        return url, f"mux_playback_id | type={rtype} | title={title}"

    external_url = str(resource.get("external_url") or "").strip()
    if external_url:
        return external_url, f"external_url | type={rtype} | title={title}"

    bucket = str(resource.get("storage_bucket") or "").strip()
    path = str(resource.get("storage_path") or "").strip()

    if bucket and bucket.startswith("http") and not path:
        # Cas particulier toléré dans CourseResourceViewerScreen : bucket contient une URL complète.
        return bucket, f"bucket_http_only | type={rtype} | title={title}"

    if bucket and path:
        pseudo = f"storage://{bucket}/{path}"
        return None, f"storage_bucket_path ({pseudo}) | type={rtype} | title={title}"

    return None, f"no_url_fields | type={rtype} | title={title}"


def sample_and_test_urls(resources: List[Dict[str, Any]], max_tests: int = 10) -> None:
    """Prend un échantillon de ressources et teste les URLs HTTP accessibles.

    - On limite à max_tests URLs HTTP (commençant par http).
    - Pour chacune : requête GET avec timeout court et affichage du
      status code + Content-Type.
    """

    http_urls: List[Tuple[str, str]] = []
    storage_descriptors: List[str] = []

    print("\n[INFO] Échantillon de ressources (premières 20)")
    for idx, res in enumerate(resources[:20]):
        url, desc = build_candidate_url(res)
        print(f"  #{idx+1}: {desc}")
        if url and url.startswith("http"):
            http_urls.append((url, desc))
        elif url is None and "storage_bucket_path" in desc:
            storage_descriptors.append(desc)

    if storage_descriptors:
        print("\n[INFO] Ressources basées sur Storage (à auditer séparément avec createSignedUrl):")
        for d in storage_descriptors[:10]:
            print("  -", d)

    print("\n[INFO] Test HTTP sur quelques URLs candidates (Mux / externes)")
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
    payload = call_course_library_via_proxy(jwt)
    resources = extract_course_resources(payload)
    if not resources:
        print("[WARN] Aucune ressource de cours trouvée dans app_list_course_library")
        return 0

    summarize_url_usage(resources)
    sample_and_test_urls(resources)
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
