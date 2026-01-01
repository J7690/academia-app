#!/usr/bin/env python3
"""Audit simple des comptes utilisateurs (admin) pour Academia.

- Vérifie la présence des tables app.user_invitations, app.user_presence,
  app.user_admin_status, app.admin_user_action_logs.
- Vérifie l'existence des RPC liées à la gestion des comptes utilisateurs :
  - app_admin_list_user_invitations
  - app_admin_create_user_invitation
  - app_admin_cancel_user_invitation
  - app_accept_user_invitation
  - app_admin_list_users_overview
  - app_admin_update_user_status
  - app_admin_list_user_action_logs
  - app_track_user_activity

Audit strictement en lecture seule : on ne fait que des SELECT et des appels
RPC avec un contexte où auth.uid() est nul (service_role), ce qui renvoie
"not_authenticated" pour les RPC mutantes, sans toucher aux données.
"""

from __future__ import annotations

import json
from typing import Any, Dict

import requests

from supabase_auto_manager import SupabaseAutoManager


def check_rpc(manager: SupabaseAutoManager, name: str, payload: Dict[str, Any] | None = None) -> Dict[str, Any]:
    """Teste l'appel d'une RPC Supabase et indique si elle existe.

    Statuts possibles :
    - ok : la fonction existe et répond avec un code HTTP 2xx
    - exists_but_error : la fonction existe mais renvoie une erreur fonctionnelle (4xx/5xx hors PGRST202)
    - missing : fonction absente (PGRST202 / 404)
    - network_error : problème réseau côté HTTP
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

    # Audit des tables app.* utilisées par l'onglet comptes utilisateurs
    print("=== AUDIT TABLES UTILISATEURS (app.*) ===")
    sql = """
    SELECT table_schema, table_name
    FROM information_schema.tables
    WHERE table_schema = 'app'
      AND table_name IN (
        'user_invitations',
        'user_presence',
        'user_admin_status',
        'admin_user_action_logs'
      )
    ORDER BY table_name;
    """

    tables_result = manager.execute_sql_auto(sql)
    print(json.dumps(tables_result, indent=2, ensure_ascii=False))

    # Audit des RPC liées à la gestion des comptes utilisateurs
    print("\n=== AUDIT RPC UTILISATEURS ===")

    # Utiliser un payload représentatif pour les fonctions avec paramètres, afin
    # de ne pas les classer à tort comme "missing" (PGRST202) alors qu'elles
    # existent mais attendent des arguments scalaires.
    rpc_definitions: Dict[str, Dict[str, Any] | None] = {
        # Liste des invitations : sans paramètres
        "app_admin_list_user_invitations": {},
        # Création d'une invitation : on envoie des valeurs factices
        "app_admin_create_user_invitation": {
            "p_email": "audit@example.com",
            "p_role": "admin",
            "p_university_id": None,
            "p_full_name": None,
            "p_notes": None,
            "p_expires_at": None,
        },
        # Annulation d'une invitation : UUID factice
        "app_admin_cancel_user_invitation": {
            "p_invitation_id": "00000000-0000-0000-0000-000000000000",
        },
        # Acceptation d'une invitation : token factice
        "app_accept_user_invitation": {
            "p_token": "dummy-token",
            "p_full_name": "Audit User",
        },
        # Vue d'ensemble des comptes : sans paramètres
        "app_admin_list_users_overview": {},
        # Mise à jour du statut : UUID factice + action suspend
        "app_admin_update_user_status": {
            "p_target_user_id": "00000000-0000-0000-0000-000000000000",
            "p_action": "suspend",
            "p_reason": "audit_test",
        },
        # Journal des actions : UUID factice
        "app_admin_list_user_action_logs": {
            "p_target_user_id": "00000000-0000-0000-0000-000000000000",
        },
        # Suivi de présence : sans paramètres
        "app_track_user_activity": {},
    }

    rpc_results = [
        check_rpc(manager, name, payload or {})
        for name, payload in rpc_definitions.items()
    ]
    print(json.dumps(rpc_results, indent=2, ensure_ascii=False))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
