#!/usr/bin/env python3
"""Test end-to-end Bobodo via Supabase Edge Function `bobodo-chat`.

Ce script effectue les étapes suivantes :
- Login Supabase en tant qu'étudiant de dev (rôle "student").
- Création d'une nouvelle session Bobodo via la RPC `app_create_bobodo_session`.
- Envoi d'un message réel à l'Edge Function `bobodo-chat`.
- Vérification de la réponse IA non vide.
- Vérification de l'enregistrement des messages via `app_list_bobodo_messages` (côté étudiant).
- Login Supabase en tant qu'admin de dev (rôle "admin").
- Vérification de l'apparition de la session via `app_admin_list_bobodo_sessions`.

Les résultats sont imprimés sous forme de lignes JSON préfixées par
`BOBODO_E2E_*` pour une analyse facile dans les logs.

ATTENTION : ce script appelle Supabase et OpenRouter en production de dev.
Il ne modifie que les tables Bobodo (sessions/messages) déjà prévues à cet effet.
"""

from __future__ import annotations

import json
import sys
from typing import Any, Dict, List, Tuple

import requests

from test_auth_login import get_supabase_auth_config, DEV_USERS


def _get_credentials_for_role(role: str) -> Tuple[str, str]:
    for r, email, password in DEV_USERS:
        if r == role:
            return email, password
    raise RuntimeError(f"Aucun utilisateur de dev pour le rôle {role!r}")


def _login_role(role: str) -> Tuple[str, str, str, str]:
    """Retourne (base_url, anon_key, access_token, user_id) pour le rôle donné."""
    base_url, anon_key = get_supabase_auth_config()
    email, password = _get_credentials_for_role(role)

    resp = requests.post(
        f"{base_url}/auth/v1/token?grant_type=password",
        headers={
            "apikey": anon_key,
            "Content-Type": "application/json",
        },
        json={"email": email, "password": password},
        timeout=20,
    )

    summary: Dict[str, Any] = {
        "role": role,
        "email": email,
        "status_code": resp.status_code,
    }

    if not resp.ok:
        try:
            body = resp.json()
        except Exception:
            body = resp.text[:300]
        summary["error"] = body
        print("BOBODO_E2E_LOGIN:", json.dumps(summary, ensure_ascii=False))
        raise SystemExit(1)

    data = resp.json()
    access_token = data.get("access_token") or ""
    user = data.get("user") or {}
    user_id = user.get("id") or ""

    if not access_token or not user_id:
        summary["error"] = "missing access_token or user.id in auth response"
        print("BOBODO_E2E_LOGIN:", json.dumps(summary, ensure_ascii=False))
        raise SystemExit(1)

    summary["result"] = "success"
    print("BOBODO_E2E_LOGIN:", json.dumps(summary, ensure_ascii=False))

    return base_url, anon_key, access_token, user_id


def _parse_session_id(raw: Any) -> str | None:
    """Extrait au mieux un session_id depuis la réponse RPC.

    Supabase peut renvoyer :
    - une chaîne JSON brute ("uuid")
    - un dict {"data": "uuid"}
    - un dict {"session_id": "uuid"} ou {"id": "uuid"}
    - une liste de dicts [{"id": "uuid"}, ...]
    """
    if isinstance(raw, str):
        return raw

    if isinstance(raw, dict):
        if isinstance(raw.get("session_id"), str):
            return raw["session_id"]
        if isinstance(raw.get("id"), str):
            return raw["id"]
        data = raw.get("data")
        if isinstance(data, str):
            return data
        if isinstance(data, dict) and isinstance(data.get("id"), str):
            return data["id"]

    if isinstance(raw, list) and raw:
        first = raw[0]
        if isinstance(first, dict):
            if isinstance(first.get("session_id"), str):
                return first["session_id"]
            if isinstance(first.get("id"), str):
                return first["id"]

    return None


def _extract_list(raw: Any) -> List[Dict[str, Any]]:
    """Tente d'extraire une liste de messages/sessions depuis une réponse RPC."""
    if isinstance(raw, list):
        return [x for x in raw if isinstance(x, dict)]
    if isinstance(raw, dict) and isinstance(raw.get("result"), list):
        return [x for x in raw["result"] if isinstance(x, dict)]
    return []


def run_bobodo_e2e() -> int:
    # 1) Login student
    base_url, anon_key, student_token, student_id = _login_role("student")

    # 2) Créer une session Bobodo via RPC
    session_title = "Test E2E Bobodo .windsurf"
    headers_student_rpc = {
        "apikey": anon_key,
        "Authorization": f"Bearer {student_token}",
        "Content-Type": "application/json",
    }

    resp_session = requests.post(
        f"{base_url}/rest/v1/rpc/app_create_bobodo_session",
        headers=headers_student_rpc,
        json={"p_title": session_title},
        timeout=20,
    )

    session_summary: Dict[str, Any] = {
        "step": "create_session",
        "status_code": resp_session.status_code,
    }

    try:
        raw = resp_session.json()
    except Exception:
        raw = resp_session.text[:300]

    session_summary["raw"] = raw

    if not resp_session.ok:
        session_summary["error"] = "RPC app_create_bobodo_session failed"
        print("BOBODO_E2E_SESSION:", json.dumps(session_summary, ensure_ascii=False))
        return 1

    session_id = _parse_session_id(raw)
    session_summary["session_id"] = session_id

    if not session_id:
        session_summary["error"] = "Impossible d'extraire le session_id depuis la réponse RPC"
        print("BOBODO_E2E_SESSION:", json.dumps(session_summary, ensure_ascii=False))
        return 1

    print("BOBODO_E2E_SESSION:", json.dumps(session_summary, ensure_ascii=False))

    # 3) Appel réel de l'Edge Function bobodo-chat
    message = "Bonjour Bobodo, ceci est un test end-to-end depuis .windsurf. Peux-tu répondre en une ou deux phrases ?"
    headers_edge = {
        "Authorization": f"Bearer {student_token}",
        "Content-Type": "application/json",
        "Accept": "application/json",
        "apikey": anon_key,
    }

    resp_chat = requests.post(
        f"{base_url}/functions/v1/bobodo-chat",
        headers=headers_edge,
        json={"session_id": session_id, "message": message},
        timeout=60,
    )

    chat_summary: Dict[str, Any] = {
        "step": "edge_function",
        "status_code": resp_chat.status_code,
    }

    try:
        chat_body = resp_chat.json()
    except Exception:
        chat_body = {"raw": resp_chat.text[:300]}

    chat_summary["body"] = chat_body

    if not resp_chat.ok:
        chat_summary["error"] = "Edge Function bobodo-chat a renvoyé une erreur"
        print("BOBODO_E2E_CHAT:", json.dumps(chat_summary, ensure_ascii=False))
        return 1

    reply = ""
    if isinstance(chat_body, dict):
        val = chat_body.get("reply") or chat_body.get("message") or chat_body.get("detail")
        if isinstance(val, str):
            reply = val.strip()

    chat_summary["reply_preview"] = reply[:200]
    chat_summary["reply_non_empty"] = bool(reply)

    if not reply:
        chat_summary["error"] = "Réponse IA vide ou absente dans la réponse HTTP"
        print("BOBODO_E2E_CHAT:", json.dumps(chat_summary, ensure_ascii=False))
        return 1

    print("BOBODO_E2E_CHAT:", json.dumps(chat_summary, ensure_ascii=False))

    # 4) Vérifier les messages côté étudiant via app_list_bobodo_messages
    resp_messages = requests.post(
        f"{base_url}/rest/v1/rpc/app_list_bobodo_messages",
        headers=headers_student_rpc,
        json={"p_session_id": session_id},
        timeout=20,
    )

    student_msgs_summary: Dict[str, Any] = {
        "step": "student_messages",
        "status_code": resp_messages.status_code,
    }

    try:
        raw_msgs = resp_messages.json()
    except Exception:
        raw_msgs = resp_messages.text[:300]

    messages_list = _extract_list(raw_msgs)
    student_msgs_summary["count"] = len(messages_list)

    if messages_list:
        last = messages_list[-1]
        last_sender = last.get("sender")
        last_content = str(last.get("content", ""))
        student_msgs_summary["last_sender"] = last_sender
        student_msgs_summary["last_content_preview"] = last_content[:200]

    if not resp_messages.ok:
        student_msgs_summary["error"] = "RPC app_list_bobodo_messages a renvoyé une erreur"
        print("BOBODO_E2E_STUDENT_MESSAGES:", json.dumps(student_msgs_summary, ensure_ascii=False))
        return 1

    if len(messages_list) < 2:
        student_msgs_summary["warning"] = "Moins de 2 messages dans la session (étudiant + assistant attendus)"

    print("BOBODO_E2E_STUDENT_MESSAGES:", json.dumps(student_msgs_summary, ensure_ascii=False))

    # 5) Login admin et vérification via app_admin_list_bobodo_sessions
    base_url_admin, anon_key_admin, admin_token, admin_id = _login_role("admin")
    if base_url_admin != base_url or anon_key_admin != anon_key:
        print(
            "BOBODO_E2E_WARNING:",
            json.dumps(
                {
                    "message": "Config Supabase différente entre student et admin, vérifiez .windsurf si nécessaire.",
                    "base_url_student": base_url,
                    "base_url_admin": base_url_admin,
                },
                ensure_ascii=False,
            ),
        )

    headers_admin_rpc = {
        "apikey": anon_key_admin,
        "Authorization": f"Bearer {admin_token}",
        "Content-Type": "application/json",
    }

    resp_admin_sessions = requests.post(
        f"{base_url_admin}/rest/v1/rpc/app_admin_list_bobodo_sessions",
        headers=headers_admin_rpc,
        json={"p_student_id": student_id},
        timeout=20,
    )

    admin_sessions_summary: Dict[str, Any] = {
        "step": "admin_sessions",
        "status_code": resp_admin_sessions.status_code,
    }

    try:
        raw_admin = resp_admin_sessions.json()
    except Exception:
        raw_admin = resp_admin_sessions.text[:300]

    sessions_list = _extract_list(raw_admin)
    admin_sessions_summary["count"] = len(sessions_list)

    found_session = any(isinstance(s, dict) and s.get("id") == session_id for s in sessions_list)
    admin_sessions_summary["found_session"] = found_session

    if not resp_admin_sessions.ok:
        admin_sessions_summary["error"] = "RPC app_admin_list_bobodo_sessions a renvoyé une erreur"
        print("BOBODO_E2E_ADMIN_SESSIONS:", json.dumps(admin_sessions_summary, ensure_ascii=False))
        return 1

    print("BOBODO_E2E_ADMIN_SESSIONS:", json.dumps(admin_sessions_summary, ensure_ascii=False))

    result = "OK" if (reply and len(messages_list) >= 1 and found_session) else "KO"
    summary: Dict[str, Any] = {
        "result": result,
        "session_id": session_id,
        "student_message_count": len(messages_list),
        "admin_found_session": found_session,
    }
    print("BOBODO_E2E_SUMMARY:", json.dumps(summary, ensure_ascii=False))

    return 0 if result == "OK" else 1


def main() -> int:
    try:
        return run_bobodo_e2e()
    except SystemExit as e:
        return int(e.code) if isinstance(e.code, int) else 1
    except Exception as e:  # pragma: no cover - protection ultime
        print(
            "BOBODO_E2E_EXCEPTION:",
            json.dumps({"error": str(e)}, ensure_ascii=False),
        )
        return 1


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
