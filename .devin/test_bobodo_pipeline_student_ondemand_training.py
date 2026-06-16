#!/usr/bin/env python3
"""Test pipeline Bobodo (étudiant dev) pour les formations non listées / sur demande.

Étapes :
- Auth Supabase (grant_type=password) pour l'étudiant nexiomgroup
- Création d'une session Bobodo via la RPC app_create_bobodo_session
- Appels au backend Bobodo /bobodo/chat sur Railway avec des questions sur des formations
  non présentes explicitement dans la liste des offres

Objectif : vérifier, via les procédures .windsurf uniquement, que Bobodo s'appuie
sur le contenu local Nexiom/Academia pour expliquer :
- le rôle de Nexiom Group dans les formations non diplômantes / certifiantes
- la possibilité d'écrire à l'administrateur quand une formation n'apparaît pas
  dans les offres visibles.
"""

from __future__ import annotations

import json
from typing import Any, Dict

import requests

from supabase_permanent_access import SupabasePermanentAccess


def get_supabase_auth_config() -> tuple[str, str]:
    access = SupabasePermanentAccess()
    permanent = access.get_permanent_config()
    base_url = permanent.get("url", "https://thevdfcwlcqzdoybfvgs.supabase.co")
    # Clé anon utilisée côté Flutter / .windsurf
    anon_key = (
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMwNTY1NjAsImV4cCI6MjA3ODYzMjU2MH0.8Zm6i6UaOrEOUvOafHOXOf0UiPOdp7on-aajYASOdk8"
    )
    return base_url, anon_key


DEV_STUDENT_EMAIL = "nexiomgroup@gmail.com"
DEV_STUDENT_PASSWORD = "Wenden@Koote3"
BACKEND_BOBODO_URL = "https://academia-app-production.up.railway.app/bobodo/chat"


def login_student() -> tuple[str, str, str]:
    base_url, anon_key = get_supabase_auth_config()
    print(f"[INFO] Auth Supabase: {base_url}")

    resp = requests.post(
        f"{base_url}/auth/v1/token?grant_type=password",
        headers={
            "apikey": anon_key,
            "Content-Type": "application/json",
        },
        json={"email": DEV_STUDENT_EMAIL, "password": DEV_STUDENT_PASSWORD},
        timeout=20,
    )
    print("[AUTH] STATUS", resp.status_code)
    if not resp.ok:
        try:
            print("[AUTH] BODY", resp.json())
        except Exception:
            print("[AUTH] BODY_RAW", resp.text[:400])
        raise SystemExit(1)

    data = resp.json()
    access_token = data.get("access_token")
    if not access_token:
        print("[ERROR] access_token manquant dans la réponse Auth")
        raise SystemExit(1)

    print("[AUTH] Login étudiant OK")
    return base_url, anon_key, access_token


def create_bobodo_session(base_url: str, anon_key: str, access_token: str) -> str:
    url = f"{base_url}/rest/v1/rpc/app_create_bobodo_session"
    headers = {
        "apikey": anon_key,
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    payload = {"p_title": "Test pipeline formations sur demande (.windsurf)"}

    resp = requests.post(url, headers=headers, json=payload, timeout=20)
    print("[SESSION] STATUS", resp.status_code)
    if not resp.ok:
        try:
            print("[SESSION] BODY", resp.json())
        except Exception:
            print("[SESSION] BODY_RAW", resp.text[:400])
        raise SystemExit(1)

    try:
        session_id_raw: Any = resp.json()
    except Exception as exc:  # pragma: no cover
        print("[SESSION] Erreur JSON:", exc)
        raise SystemExit(1)

    session_id = str(session_id_raw)
    print("[SESSION] session_id =", session_id)
    return session_id


def call_bobodo(session_id: str, message: str) -> Dict[str, Any]:
    print("\n[CHAT] Question:", message)
    body = {
        "session_id": session_id,
        "message": message,
    }
    resp = requests.post(
        BACKEND_BOBODO_URL,
        headers={"Content-Type": "application/json"},
        json=body,
        timeout=60,
    )
    print("[CHAT] STATUS", resp.status_code)
    try:
        data = resp.json()
        print("[CHAT] BODY", json.dumps(data, ensure_ascii=False, indent=2)[:2000])
        return data
    except Exception:
        print("[CHAT] BODY_RAW", resp.text[:400])
        return {"raw": resp.text}


def main() -> int:
    # 1) Login étudiant dev
    base_url, anon_key, access_token = login_student()

    # 2) Création d'une session Bobodo pour cet étudiant
    session_id = create_bobodo_session(base_url, anon_key, access_token)

    # 3) Questions sur des formations non listées / sur demande
    questions = [
        "Je cherche une formation pratique en graphisme avancé mais je ne la trouve pas dans la liste des formations sur Academia. Est-ce que Nexiom Group peut m'aider ?",
        "Je voudrais une formation certifiante en gestion de projet qui n'apparaît pas dans vos offres actuelles. Est-ce que Nexiom peut organiser quelque chose pour moi ?",
        "Si la formation que je veux n'est pas sur Academia mais qu'elle n'est pas diplômante, qu'est-ce que je peux faire ?",
    ]

    for q in questions:
        call_bobodo(session_id, q)

    print("\n[INFO] Pipeline Bobodo exécuté pour la session:", session_id)
    print("[INFO] Tu peux maintenant lancer:\n  python .windsurf/test_bobodo_knowledge_list.py")
    print("pour vérifier les connaissances locales utilisées.")

    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
