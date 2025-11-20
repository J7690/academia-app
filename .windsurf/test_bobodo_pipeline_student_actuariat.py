#!/usr/bin/env python3
"""Test complet du pipeline Bobodo (étudiant dev) via procédures .windsurf.

Étapes :
- Auth Supabase (grant_type=password) pour l'étudiant nexiomgroup
- Création d'une session Bobodo via la RPC app_create_bobodo_session
- Appels au backend Bobodo /bobodo/chat sur Railway avec des questions ciblées
- Audit des tables app.bobodo_detected_needs et app.bobodo_unanswered_questions

Ce script:
- utilise uniquement les endpoints décrits dans .windsurf (Auth, RPC, execute_sql)
- ne fait que des INSERT via les pipelines normaux (aucune écriture directe sur app.*)
"""

from __future__ import annotations

import json
from typing import Any, Dict

import requests

from supabase_permanent_access import SupabasePermanentAccess

# On réutilise la même logique que test_auth_login pour récupérer URL + anon_key.


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
    payload = {"p_title": "Test pipeline actuariat (.windsurf)"}

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

    # 3) Questions qui devraient générer des besoins détectés (orientation / actuariat)
    questions = [
        "Je veux faire la filière Actuariat, quelles études je dois envisager ?",
        "Quels métiers sont possibles après des études en actuariat ?",
        "Comment Nexiom et la plateforme Academia peuvent m'aider si je veux une carrière d'actuaire ?",
    ]

    for q in questions:
        call_bobodo(session_id, q)

    # 4) Question potentiellement non couverte (très spécifique Nexiom/Academia)
    q_unanswered = (
        "Donne moi les conditions exactes, les montants et le calendrier détaillé d'une bourse d'études en actuariat "
        "spécifique à Nexiom Group via Academia pour l'année prochaine."
    )
    call_bobodo(session_id, q_unanswered)

    print("\n[INFO] Pipeline Bobodo exécuté pour la session:", session_id)
    print("[INFO] Tu peux maintenant lancer:\n  python .windsurf/test_bobodo_needs_unanswered_list.py")
    print("pour voir ce qui a été loggé dans app.bobodo_detected_needs et app.bobodo_unanswered_questions.")

    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
