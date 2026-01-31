import json
from test_rpc_final import SupabaseRPCTestFinal


def main() -> None:
  tester = SupabaseRPCTestFinal()

  queries = {
    "tables_app_referral": """
      SELECT table_schema, table_name
      FROM information_schema.tables
      WHERE table_schema = 'app'
        AND table_name IN ('commercial_profiles','user_referrals','referral_commissions')
      ORDER BY table_name
    """,
    "sample_commercial_profiles": "SELECT * FROM app.commercial_profiles ORDER BY created_at DESC LIMIT 10",
    "sample_user_referrals": "SELECT * FROM app.user_referrals ORDER BY attributed_at DESC LIMIT 10",
    "sample_referral_commissions": "SELECT * FROM app.referral_commissions ORDER BY created_at DESC LIMIT 10",
    "rpc_presence": """
      SELECT proname
      FROM pg_proc
      WHERE proname IN (
        'app_admin_list_commercials_overview',
        'app_admin_get_commercial_detail',
        'app_commercial_get_dashboard',
        'app_register_referral_for_current_user',
        'app_admin_update_referral_commission_status'
      )
      ORDER BY proname
    """,
    "roles_in_auth_users": """
      SELECT
        raw_user_meta_data->>'role' AS role,
        COUNT(*) AS users_count,
        MIN(created_at) AS first_created_at,
        MAX(created_at) AS last_created_at
      FROM auth.users
      GROUP BY raw_user_meta_data->>'role'
      ORDER BY role
    """,
    "students_overview": """
      SELECT
        COUNT(*) AS students_count,
        MIN(created_at) AS first_created_at,
        MAX(created_at) AS last_created_at
      FROM app.students
    """,
    "students_without_profile": """
      SELECT COUNT(*) AS students_without_profile
      FROM auth.users u
      WHERE u.raw_user_meta_data->>'role' = 'student'
        AND NOT EXISTS (
          SELECT 1 FROM app.students s WHERE s.id = u.id
        )
    """,
    "students_profile_without_auth": """
      SELECT COUNT(*) AS profiles_without_auth
      FROM app.students s
      WHERE NOT EXISTS (
        SELECT 1 FROM auth.users u WHERE u.id = s.id
      )
    """,
    "commercial_profiles_vs_roles": """
      SELECT
        u.id AS user_id,
        u.email,
        u.raw_user_meta_data->>'role' AS role,
        cp.ref_code,
        cp.ref_link,
        cp.commission_rate,
        cp.is_active
      FROM app.commercial_profiles cp
      JOIN auth.users u ON u.id = cp.user_id
      ORDER BY cp.created_at DESC
    """,
    "fn_def_app_register_referral_for_current_user": """
      SELECT pg_get_functiondef(p.oid) AS definition
      FROM pg_proc p
      WHERE p.proname = 'app_register_referral_for_current_user'
      ORDER BY p.oid DESC
      LIMIT 1
    """,
  }

  for name, sql in queries.items():
    print(f"\n===== QUERY: {name} =====")
    res = tester.call_rpc("execute_sql", {"sql_query": sql})
    print(json.dumps(res, indent=2, default=str))


if __name__ == "__main__":
  main()
