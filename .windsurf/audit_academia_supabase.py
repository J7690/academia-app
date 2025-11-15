#!/usr/bin/env python3
"""Audit complet Supabase pour le projet Academia.

- Vérifie la présence des RPC app_* utilisées par Flutter et Bobodo
- Vérifie la présence des tables app.* créées par les scripts SQL .windsurf

Respecte les procédures .windsurf en utilisant l'API REST Supabase
via SupabaseAutoManager (service_key + /rest/v1/rpc).
"""

from __future__ import annotations

import json
from typing import Any, Dict

from supabase_auto_manager import SupabaseAutoManager
import requests


def check_rpc(manager: SupabaseAutoManager, name: str, payload: Dict[str, Any] | None = None) -> Dict[str, Any]:
    """Teste l'appel d'une RPC Supabase et indique si elle existe.

    On distingue :
    - status == "ok" : la fonction existe et répond (200)
    - status == "exists_but_error" : la fonction existe mais renvoie une erreur fonctionnelle (4xx/5xx hors PGRST202)
    - status == "missing" : fonction absente (PGRST202 / 404)
    - status == "network_error" : problème réseau côté HTTP
    """
    url = f"{manager.url}/rest/v1/rpc/{name}"
    data = payload or {}

    try:
        response = requests.post(url, headers=manager.headers, json=data, timeout=15)
    except Exception as exc:  # réseau
        return {
            "name": name,
            "status": "network_error",
            "detail": str(exc),
        }

    body_text = response.text or ""

    # Cas fonction introuvable (PGRST202 ou 404)
    if response.status_code == 404 or "PGRST202" in body_text:
        return {
            "name": name,
            "status": "missing",
            "http_status": response.status_code,
            "body": body_text[:300],
        }

    # Cas erreur mais fonction existante
    if response.status_code >= 400:
        return {
            "name": name,
            "status": "exists_but_error",
            "http_status": response.status_code,
            "body": body_text[:300],
        }

    # OK
    return {
        "name": name,
        "status": "ok",
        "http_status": response.status_code,
    }


def main() -> int:
    manager = SupabaseAutoManager()

    # RPC attendues côté Flutter + Bobodo
    rpc_definitions: Dict[str, Dict[str, Any] | None] = {
        # Offres / universités
        "app_list_home_offers": {},
        "app_list_partner_universities": {},
        "app_list_programs_by_university": {"p_university_id": None},
        # Candidatures
        "app_list_student_applications": {},
        "app_create_application": {"p_program_id": None, "p_motivation_text": None},
        # Cours
        "app_list_student_courses": {},
        "app_list_course_exercises": {"p_course_id": None},
        # Bobodo
        "app_create_bobodo_session": {"p_title": None},
        "app_list_bobodo_messages": {"p_session_id": None},
        "app_append_bobodo_message": {
            "p_session_id": None,
            "p_sender": "student",
            "p_content": "test",
            "p_safety_flag": None,
        },
        "app_search_bobodo_knowledge": {"p_query": "test", "p_category": None},
    }

    print("=== AUDIT RPC app_* ===")
    rpc_results = []
    for name, payload in rpc_definitions.items():
        result = check_rpc(manager, name, payload)
        rpc_results.append(result)
    print(json.dumps(rpc_results, indent=2, ensure_ascii=False))

    # Audit des tables app.* via execute_sql_auto (RPC execute_sql)
    print("\n=== AUDIT TABLES app.* ===")
    sql = """
    SELECT table_schema, table_name
    FROM information_schema.tables
    WHERE table_schema = 'app'
      AND table_name IN (
        'universities','programs',
        'students','applications','application_files',
        'courses','course_enrollments','exercises',
        'bobodo_sessions','bobodo_messages','bobodo_knowledge'
      )
    ORDER BY table_name;
    """

    tables_result = manager.execute_sql_auto(sql)
    print(json.dumps(tables_result, indent=2, ensure_ascii=False))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
