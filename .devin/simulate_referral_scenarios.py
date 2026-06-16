#!/usr/bin/env python3
"""Simulation automatique de scénarios de parrainage commerciaux.

Objectifs métier :
- Créer un étudiant test rattaché à un commercial existant (via ref_code).
- Simuler un paiement confirmé qui génère une commission.
- Observer l'impact sur :
  - app.user_referrals
  - app.referral_commissions
  - app_commercial_get_dashboard (côté commercial)
  - app_admin_list_commercials_overview (côté admin)

Ce script utilise la fonction execute_sql et simule auth.uid() via
set_config('request.jwt.claim.sub', ...).
"""

import json
import uuid
from typing import Any, Dict, Optional

from test_rpc_final import SupabaseRPCTestFinal


def call_sql(tester: SupabaseRPCTestFinal, label: str, sql: str) -> Dict[str, Any]:
    """Appelle la RPC execute_sql avec un SQL donné."""
    res = tester.call_rpc("execute_sql", {"sql_query": sql})
    print(f"\n===== SQL: {label} =====")
    print(json.dumps(res, indent=2, default=str))
    if not res.get("success"):
        raise RuntimeError(f"SQL '{label}' failed: {res.get('status_code')} - {res.get('error')}")

    # execute_sql retourne toujours un JSONB. En cas d'erreur SQL interne,
    # il renvoie un objet {error, sqlstate}. On le traite comme une erreur.
    data = res.get("data")
    if isinstance(data, dict) and "error" in data:
        raise RuntimeError(f"SQL '{label}' returned error JSONB: {data}")
    return res


def pick_active_commercial(tester: SupabaseRPCTestFinal) -> Dict[str, Any]:
    """Récupère un commercial actif avec un ref_code et ref_link."""
    sql = """
      SELECT user_id, ref_code, ref_link, commission_rate
      FROM app.commercial_profiles
      WHERE is_active = TRUE
      ORDER BY created_at DESC
      LIMIT 1
    """
    res = call_sql(tester, "pick_active_commercial", sql)
    data = res.get("data") or []
    if not data:
        raise RuntimeError("Aucun commercial actif trouvé dans app.commercial_profiles")
    row = data[0]
    return {
        "user_id": row["user_id"],
        "ref_code": row["ref_code"],
        "ref_link": row["ref_link"],
        "commission_rate": row["commission_rate"],
    }


def get_admin_user_id(tester: SupabaseRPCTestFinal) -> Optional[str]:
    """Récupère un utilisateur admin (auth.users)."""
    sql = """
      SELECT id, email
      FROM auth.users
      WHERE raw_user_meta_data->>'role' = 'admin'
      ORDER BY created_at ASC
      LIMIT 1
    """
    res = call_sql(tester, "get_admin_user_id", sql)
    data = res.get("data") or []
    if not data:
        return None
    return data[0]["id"]


def simulate_single_referral_and_conversion(tester: SupabaseRPCTestFinal) -> Dict[str, Any]:
    """Scénario A : 1 étudiant référé + 1 paiement confirmé.

    Étapes :
    - Choisir un commercial actif (COMM-XXXX).
    - Créer un étudiant test (UUID synthétique) via app_register_referral_for_current_user.
    - Créer une application + un payment confirmé pour cet étudiant.
    - Générer la commission via app_generate_referral_commission_for_payment.
    - Lire les dashboards avant/après.
    """

    commercial = pick_active_commercial(tester)
    commercial_id = commercial["user_id"]
    ref_code = commercial["ref_code"]

    # Étudiant de test (UUID synthétique, non lié à auth.users)
    student_id = str(uuid.uuid4())

    # Claims JWT simulés pour l'étudiant
    student_claims = json.dumps({"sub": student_id, "role": "authenticated"})
    student_claims_sql = student_claims.replace("'", "''")

    # 1) État initial des compteurs pour ce commercial (dashboard commercial)
    claims_commercial = json.dumps({"sub": commercial_id, "role": "authenticated"})
    claims_commercial_sql = claims_commercial.replace("'", "''")

    sql_dash_before = f"""
      WITH _claims AS (
        SELECT
          set_config('request.jwt.claim.sub', '{commercial_id}', true),
          set_config('request.jwt.claims', '{claims_commercial_sql}', true)
      )
      SELECT app_commercial_get_dashboard() AS payload
    """
    dash_before_res = call_sql(tester, "commercial_dashboard_before", sql_dash_before)
    dash_before_payload = (dash_before_res.get("data") or [{}])[0].get(
        "app_commercial_get_dashboard"
    )

    # 2) Enregistrer le parrainage pour l'étudiant test
    sql_attach = f"""
      WITH _claims AS (
        SELECT
          set_config('request.jwt.claim.sub', '{student_id}', true),
          set_config('request.jwt.claims', '{student_claims_sql}', true)
      )
      SELECT
        app_register_referral_for_current_user('{ref_code}', 'link', '{{}}'::JSONB) AS result,
        (SELECT COUNT(*) FROM app.user_referrals WHERE student_id = '{student_id}'::UUID) AS referrals_for_student,
        (SELECT COUNT(*) FROM app.user_referrals WHERE commercial_user_id = '{commercial_id}'::UUID) AS referrals_for_commercial
    """
    attach_res = call_sql(tester, "attach_referral", sql_attach)
    attach_row = (attach_res.get("data") or [{}])[0]
    attach_result = attach_row.get("result")
    referrals_for_student = attach_row.get("referrals_for_student", 0)
    referrals_for_commercial = attach_row.get("referrals_for_commercial", 0)

    # 3) Créer une application + paiement confirmé et générer une commission
    sql_payment = f"""
      WITH base_univ AS (
        SELECT id FROM app.universities LIMIT 1
      ),
      new_app AS (
        INSERT INTO app.applications (student_id, program_id, status)
        VALUES ('{student_id}'::UUID, gen_random_uuid(), 'submitted')
        RETURNING id, student_id
      ),
      new_payment AS (
        INSERT INTO app.application_payments (
          application_id, student_id, university_id,
          amount_due, amount_paid, currency,
          payment_reason, channel, status,
          reference_code
        )
        VALUES (
          (SELECT id FROM new_app),
          '{student_id}'::UUID,
          (SELECT id FROM base_univ),
          10000, 10000, 'XOF',
          'registration_fee', 'cash', 'confirmed',
          'SIM-' || SUBSTR(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 10)
        )
        RETURNING id
      ),
      gen_commission AS (
        SELECT app_generate_referral_commission_for_payment(id) AS result
        FROM new_payment
      )
      SELECT
        (SELECT result FROM gen_commission) AS commission_result,
        (SELECT COUNT(*) FROM app.referral_commissions WHERE student_id = '{student_id}'::UUID) AS commissions_for_student,
        (SELECT COUNT(*) FROM app.referral_commissions WHERE commercial_user_id = '{commercial_id}'::UUID) AS commissions_for_commercial
    """
    payment_res = call_sql(tester, "generate_commission", sql_payment)
    payment_row = (payment_res.get("data") or [{}])[0]
    commission_result = payment_row.get("commission_result")
    commissions_for_student = payment_row.get("commissions_for_student", 0)
    commissions_for_commercial = payment_row.get("commissions_for_commercial", 0)

    # 4) Dashboard commercial après
    dash_after_res = call_sql(tester, "commercial_dashboard_after", sql_dash_before)
    dash_after_payload = (dash_after_res.get("data") or [{}])[0].get(
        "app_commercial_get_dashboard"
    )

    # 5) Vue admin globale pour ce commercial
    admin_id = get_admin_user_id(tester)
    admin_overview_for_commercial: Optional[Dict[str, Any]] = None
    if admin_id:
        admin_claims = json.dumps({"sub": admin_id, "role": "admin"})
        admin_claims_sql = admin_claims.replace("'", "''")
        sql_admin = f"""
          WITH _claims AS (
            SELECT
              set_config('request.jwt.claim.sub', '{admin_id}', true),
              set_config('request.jwt.claims', '{admin_claims_sql}', true)
          )
          SELECT app_admin_list_commercials_overview() AS payload
        """
        admin_res = call_sql(tester, "admin_overview", sql_admin)
        admin_payload = (admin_res.get("data") or [{}])[0].get(
            "app_admin_list_commercials_overview"
        ) or {}
        commercials_list = admin_payload.get("commercials") or []
        for c in commercials_list:
            if c.get("user_id") == commercial_id:
                admin_overview_for_commercial = c
                break

    return {
        "scenario": "single_referral_single_conversion",
        "commercial": commercial,
        "student_id": student_id,
        "attach_result": attach_result,
        "referrals_for_student": referrals_for_student,
        "referrals_for_commercial": referrals_for_commercial,
        "commission_result": commission_result,
        "commissions_for_student": commissions_for_student,
        "commissions_for_commercial": commissions_for_commercial,
        "commercial_dashboard_before": dash_before_payload,
        "commercial_dashboard_after": dash_after_payload,
        "admin_overview_for_commercial": admin_overview_for_commercial,
    }


def main() -> int:
    tester = SupabaseRPCTestFinal()

    print("\n🚀 Simulation automatique des scénarios de parrainage (Supabase)")
    print("=" * 70)

    result_a = simulate_single_referral_and_conversion(tester)

    print("\n===== RÉSUMÉ SCÉNARIO A: single_referral_single_conversion =====")
    print(json.dumps(result_a, indent=2, default=str))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
