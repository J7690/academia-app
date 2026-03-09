#!/usr/bin/env python3
"""Audit des fichiers de dossier/candidature via le proxy Supabase sur Railway.

Objectifs (lecture seule) :
- Se connecter en tant qu'étudiant pour obtenir un JWT.
- Appeler via le proxy les RPC suivantes :
  - app_list_student_dossier_documents
  - app_list_student_applications puis app_list_application_files(p_application_id)
- Extraire quelques "storage_path" dans le bucket "application-files".
- Utiliser l'API Storage Supabase (directement sur SUPABASE_URL) pour générer
  des URLs signées temporaires pour ces chemins.
- Tester par HTTP les URLs signées (statut HTTP + Content-Type) afin de
  vérifier l'accessibilité réelle des documents.

Aucune écriture ni suppression n'est effectuée.
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


def call_rpc_via_proxy(name: str, jwt: str, params: Dict[str, Any] | None = None) -> Any:
    """Appelle une RPC via le proxy Railway en tant qu'étudiant."""

    url = f"{BACKEND_PROXY_BASE}/{name}"
    headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Authorization": f"Bearer {jwt}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    body = params or {}

    print(f"\n[RPC_PROXY] {name}")
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
        return data
    except Exception:
        print("[RESP_BODY_RAW][TRUNC]", text_preview)
        raise SystemExit(f"[RPC_PROXY] Réponse non JSON pour {name}")


def extract_storage_paths_from_dossier(payload: Any) -> List[str]:
    paths: List[str] = []
    if not isinstance(payload, dict):
        print("[WARN] Réponse dossier inattendue (pas un dict)")
        return paths

    if payload.get("success") is not True:
        print("[WARN] success != true pour app_list_student_dossier_documents")

    docs = payload.get("documents") or []
    if not isinstance(docs, list):
        print("[WARN] Champ documents manquant ou non liste")
        return paths

    for d in docs:
        if not isinstance(d, dict):
            continue
        sp = str(d.get("storage_path") or "").strip()
        if sp:
            paths.append(sp)

    print(f"[INFO] Dossier documents: {len(paths)} storage_path trouvés")
    return paths


def extract_first_application_id(payload: Any) -> str | None:
    if not isinstance(payload, list):
        print("[WARN] Réponse app_list_student_applications inattendue (pas une liste)")
        return None

    for app in payload:
        if not isinstance(app, dict):
            continue
        app_id = str(app.get("id") or app.get("application_id") or "").strip()
        if app_id:
            print("[INFO] Application trouvée pour audit:", app_id)
            return app_id

    print("[WARN] Aucune application trouvée pour l'étudiant")
    return None


def extract_storage_paths_from_application_files(payload: Any) -> List[str]:
    paths: List[str] = []
    if not isinstance(payload, list):
        print("[WARN] Réponse app_list_application_files inattendue (pas une liste)")
        return paths

    for f in payload:
        if not isinstance(f, dict):
            continue
        sp = str(f.get("storage_path") or "").strip()
        if sp:
            paths.append(sp)

    print(f"[INFO] Application files: {len(paths)} storage_path trouvés")
    return paths


def create_signed_url(jwt: str, bucket: str, storage_path: str) -> str | None:
    """Crée une URL signée pour un objet Storage en utilisant l'API REST Supabase.

    POST /storage/v1/object/sign/<bucket>/<path>
    Body: {"expiresIn": 3600}
    Réponse attendue: {"signedURL": "/storage/v1/object/sign/..."}
    """

    # IMPORTANT: le chemin dans l'URL doit être encodé, mais pour un audit simple
    # on suppose qu'il ne contient pas de caractères exotiques.
    url = f"{SUPABASE_URL}/storage/v1/object/sign/{bucket}/{storage_path}"
    headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Authorization": f"Bearer {jwt}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    body = {"expiresIn": 3600}

    print("\n[STORAGE SIGN] POST", url)
    print("[BODY]", body)

    resp = requests.post(url, headers=headers, json=body, timeout=30)
    print("[STORAGE SIGN][STATUS]", resp.status_code)
    text = resp.text
    try:
        data = resp.json()
    except Exception:
        print("[STORAGE SIGN][RAW]", text[:500])
        return None

    print("[STORAGE SIGN][RESP_JSON][TRUNC]", json.dumps(data, ensure_ascii=False, indent=2)[:800])
    signed = data.get("signedURL") or data.get("signedUrl") or data.get("signed_url")
    if not signed:
        print("[WARN] Aucun champ signedURL dans la réponse Storage")
        return None

    # Si le backend renvoie un chemin relatif, on préfixe par SUPABASE_URL.
    if signed.startswith("http"):
        return signed
    return f"{SUPABASE_URL}{signed}"


def http_test_signed_urls(urls: List[Tuple[str, str]]) -> None:
    print("\n[INFO] Test HTTP des URLs signées (documents)")
    for full_url, desc in urls:
        print(f"\n[HTTP TEST] {full_url}")
        print("  Contexte:", desc)
        try:
            resp = requests.get(full_url, timeout=10, stream=True)
        except Exception as exc:  # pragma: no cover
            print("  [ERROR] Exception réseau:", repr(exc))
            continue
        content_type = resp.headers.get("Content-Type") or resp.headers.get("content-type")
        print("  [STATUS]", resp.status_code)
        print("  [Content-Type]", content_type)


def main() -> int:
    jwt = login_direct()

    # 1) Documents de dossier global
    dossier_payload = call_rpc_via_proxy("app_list_student_dossier_documents", jwt)
    dossier_paths = extract_storage_paths_from_dossier(dossier_payload)

    # 2) Fichiers de candidature (on récupère d'abord une candidature)
    apps_payload = call_rpc_via_proxy("app_list_student_applications", jwt)
    app_id = extract_first_application_id(apps_payload)
    app_paths: List[str] = []
    if app_id:
        files_payload = call_rpc_via_proxy(
            "app_list_application_files",
            jwt,
            params={"p_application_id": app_id},
        )
        app_paths = extract_storage_paths_from_application_files(files_payload)

    # On ne garde qu'un petit échantillon de chemins pour signer/tester.
    paths_to_test: List[Tuple[str, str]] = []
    for sp in dossier_paths[:5]:
        paths_to_test.append((sp, "dossier_document"))
    for sp in app_paths[:5]:
        paths_to_test.append((sp, "application_file"))

    if not paths_to_test:
        print("[WARN] Aucun storage_path à tester dans application-files")
        return 0

    signed_urls: List[Tuple[str, str]] = []
    for storage_path, origin in paths_to_test:
        full_url = create_signed_url(jwt, "application-files", storage_path)
        if full_url:
            desc = f"bucket=application-files | origin={origin} | storage_path={storage_path}"
            signed_urls.append((full_url, desc))

    if signed_urls:
        http_test_signed_urls(signed_urls)
    else:
        print("[WARN] Aucune URL signée générée avec succès")

    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
