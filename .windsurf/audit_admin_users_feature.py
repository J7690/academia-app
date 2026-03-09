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
from pathlib import Path
from typing import Any, Dict

import requests

from supabase_auto_manager import SupabaseAutoManager


def run_admin_sql(manager: SupabaseAutoManager, sql: str, timeout: int = 60) -> Dict[str, Any]:
    sql = (sql or "").strip()
    url = f"{manager.url}/rest/v1/rpc/admin_execute_sql"
    try:
        response = requests.post(
            url,
            headers=manager.headers,
            json={"p_sql": sql},
            timeout=timeout,
        )
    except Exception as exc:
        return {
            "ok": False,
            "http_status": None,
            "error": str(exc),
            "rows": [],
        }

    try:
        data = response.json()
    except Exception:
        return {
            "ok": False,
            "http_status": response.status_code,
            "error": "non_json_response",
            "raw": (response.text or "")[:2000],
            "rows": [],
        }

    if isinstance(data, dict):
        rows = data.get("rows")
        return {
            "ok": bool(data.get("ok", False)),
            "http_status": response.status_code,
            "mode": data.get("mode"),
            "error": data.get("error"),
            "sqlstate": data.get("sqlstate"),
            "rows": rows if isinstance(rows, list) else [],
        }

    if isinstance(data, list):
        return {
            "ok": True,
            "http_status": response.status_code,
            "error": None,
            "sqlstate": None,
            "rows": data,
        }

    return {
        "ok": False,
        "http_status": response.status_code,
        "error": "unexpected_json_type",
        "rows": [],
    }


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

    print("=== SMOKE TEST admin_execute_sql ===")
    smoke = run_admin_sql(manager, "SELECT 1 AS ok")
    print(json.dumps(smoke, indent=2, ensure_ascii=False))

    print("\n=== INVENTAIRE OBJETS 'deleted' (tables + fonctions) ===")
    deleted_tables = run_admin_sql(
        manager,
        """
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE table_name ILIKE '%deleted%'
        ORDER BY table_schema, table_name
        """,
    )
    deleted_routines = run_admin_sql(
        manager,
        """
        SELECT routine_schema, routine_name, routine_type, data_type
        FROM information_schema.routines
        WHERE routine_name ILIKE '%deleted%'
        ORDER BY routine_schema, routine_name
        """,
    )
    print(
        json.dumps(
            {
                "tables": {
                    "ok": deleted_tables.get("ok"),
                    "rows_count": len(deleted_tables.get("rows") or []),
                    "rows": deleted_tables.get("rows"),
                },
                "routines": {
                    "ok": deleted_routines.get("ok"),
                    "rows_count": len(deleted_routines.get("rows") or []),
                    "rows": deleted_routines.get("rows"),
                },
            },
            indent=2,
            ensure_ascii=False,
        )[:8000]
    )

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
        'admin_user_action_logs',
        'admin_deleted_users_archive',
        'universities',
        'commercial_profiles',
        'user_referrals',
        'referral_commissions',
        'td_teachers'
      )
    ORDER BY table_name
    """

    tables_result = run_admin_sql(manager, sql)
    print(
        json.dumps(
            {
                "ok": tables_result.get("ok"),
                "mode": tables_result.get("mode"),
                "http_status": tables_result.get("http_status"),
                "rows_count": len(tables_result.get("rows") or []),
                "sample_rows": (tables_result.get("rows") or [])[:20],
                "error": tables_result.get("error"),
            },
            indent=2,
            ensure_ascii=False,
        )
    )

    # Détail de la structure des tables (colonnes, types, nullabilité, défauts)
    print("\n=== STRUCTURE TABLES UTILISATEURS (app.*) ===")
    sql_columns = """
    SELECT
      table_schema,
      table_name,
      column_name,
      data_type,
      is_nullable,
      column_default
    FROM information_schema.columns
    WHERE table_schema = 'app'
      AND table_name IN (
        'user_invitations',
        'user_presence',
        'user_admin_status',
        'admin_user_action_logs',
        'admin_deleted_users_archive',
        'universities',
        'commercial_profiles',
        'user_referrals',
        'referral_commissions',
        'td_teachers'
      )
    ORDER BY table_name, ordinal_position
    """

    columns_result = run_admin_sql(manager, sql_columns)
    print(
        json.dumps(
            {
                "ok": columns_result.get("ok"),
                "mode": columns_result.get("mode"),
                "http_status": columns_result.get("http_status"),
                "rows_count": len(columns_result.get("rows") or []),
                "sample_rows": (columns_result.get("rows") or [])[:30],
                "error": columns_result.get("error"),
            },
            indent=2,
            ensure_ascii=False,
        )
    )

    print("\n=== POLICIES RLS (app.*) - COMPTES/UNIVERSITES/COMMERCIAUX/TD ===")
    sql_policies = """
    SELECT schemaname, tablename, policyname, roles, cmd, qual, with_check
    FROM pg_policies
    WHERE schemaname = 'app'
      AND tablename IN (
        'user_invitations',
        'user_presence',
        'user_admin_status',
        'admin_user_action_logs',
        'admin_deleted_users_archive',
        'universities',
        'commercial_profiles',
        'user_referrals',
        'referral_commissions',
        'td_teachers'
      )
    ORDER BY tablename, policyname
    """
    policies_result = run_admin_sql(manager, sql_policies, timeout=90)
    print(
        json.dumps(
            {
                "ok": policies_result.get("ok"),
                "mode": policies_result.get("mode"),
                "http_status": policies_result.get("http_status"),
                "rows_count": len(policies_result.get("rows") or []),
                "sample_rows": (policies_result.get("rows") or [])[:30],
                "error": policies_result.get("error"),
            },
            indent=2,
            ensure_ascii=False,
        )[:8000]
    )

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

    # Structure SQL des fonctions (signature, type de retour, security definer)
    print("\n=== STRUCTURE FONCTIONS ADMIN UTILISATEURS ===")
    sql_functions = """
    SELECT
      n.nspname AS schema,
      p.proname AS name,
      pg_get_function_identity_arguments(p.oid) AS arguments,
      pg_get_function_result(p.oid) AS result_type,
      p.prosecdef AS security_definer
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN (
        'app_admin_list_user_invitations',
        'app_admin_create_user_invitation',
        'app_admin_cancel_user_invitation',
        'app_accept_user_invitation',
        'app_admin_list_users_overview',
        'app_admin_update_user_status',
        'app_admin_delete_user_account',
        'app_admin_list_deleted_users',
        'app_admin_list_user_action_logs',
        'app_track_user_activity',
        'app_admin_update_university_status',
        'app_list_partner_universities',
        'app_admin_list_commercials_overview',
        'app_admin_get_commercial_detail',
        'app_admin_update_referral_commission_status',
        'app_admin_set_commercial_commission_rate'
      )
    ORDER BY name
    """

    functions_result = run_admin_sql(manager, sql_functions, timeout=90)
    print(
        json.dumps(
            {
                "ok": functions_result.get("ok"),
                "mode": functions_result.get("mode"),
                "http_status": functions_result.get("http_status"),
                "rows_count": len(functions_result.get("rows") or []),
                "sample_rows": (functions_result.get("rows") or [])[:50],
                "error": functions_result.get("error"),
            },
            indent=2,
            ensure_ascii=False,
        )
    )

    print("\n=== DEFINITIONS (EXTRAIT) - SUPPRESSION/UNIVERSITES/COMMERCIAUX ===")
    sql_defs = """
    SELECT
      p.proname AS name,
      pg_get_function_identity_arguments(p.oid) AS arguments,
      pg_get_function_result(p.oid) AS result_type,
      p.prosecdef AS security_definer,
      pg_get_functiondef(p.oid) AS definition
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN (
        'app_admin_list_users_overview',
        'app_admin_list_user_invitations',
        'app_admin_create_user_invitation',
        'app_admin_cancel_user_invitation',
        'app_list_partner_universities',
        'app_admin_delete_user_account',
        'app_admin_update_university_status',
        'app_admin_list_commercials_overview',
        'app_admin_get_commercial_detail',
        'app_admin_update_referral_commission_status',
        'app_admin_set_commercial_commission_rate'
      )
    ORDER BY p.proname
    """
    defs_result = run_admin_sql(manager, sql_defs, timeout=120)
    print(
        json.dumps(
            {
                "ok": defs_result.get("ok"),
                "mode": defs_result.get("mode"),
                "http_status": defs_result.get("http_status"),
                "rows_count": len(defs_result.get("rows") or []),
                "sample_names": [
                    (r.get("name") if isinstance(r, dict) else None)
                    for r in (defs_result.get("rows") or [])
                ],
                "error": defs_result.get("error"),
            },
            indent=2,
            ensure_ascii=False,
        )[:8000]
    )

    out_path = Path(".windsurf/logs/audit_admin_users_feature_real_db.json")
    out_payload = {
        "smoke": smoke,
        "tables": tables_result,
        "columns": columns_result,
        "policies": policies_result,
        "functions": functions_result,
        "definitions": defs_result,
    }
    out_path.write_text(
        json.dumps(out_payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"[OK] wrote {out_path.as_posix()}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
