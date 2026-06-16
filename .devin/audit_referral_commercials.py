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
    "students_also_commercials": """
      SELECT
        u.id,
        u.email,
        u.raw_user_meta_data->>'role' AS role,
        cp.ref_code,
        cp.ref_link,
        cp.is_active,
        cp.commission_rate
      FROM auth.users u
      JOIN app.commercial_profiles cp ON cp.user_id = u.id
      WHERE u.raw_user_meta_data->>'role' = 'student'
      ORDER BY u.created_at DESC
    """,
    "commercials_with_student_profiles": """
      SELECT
        u.id,
        u.email,
        u.raw_user_meta_data->>'role' AS role,
        s.created_at AS student_profile_created_at
      FROM auth.users u
      JOIN app.students s ON s.id = u.id
      WHERE u.raw_user_meta_data->>'role' = 'commercial'
      ORDER BY s.created_at DESC
    """,
    "commercial_users_without_profile": """
      SELECT
        u.id,
        u.email,
        u.raw_user_meta_data->>'role' AS role,
        u.created_at
      FROM auth.users u
      WHERE u.raw_user_meta_data->>'role' = 'commercial'
        AND NOT EXISTS (
          SELECT 1
          FROM app.commercial_profiles cp
          WHERE cp.user_id = u.id
        )
      ORDER BY u.created_at DESC
    """,
    "commercials_missing_ref_data": """
      SELECT
        u.id,
        u.email,
        u.raw_user_meta_data->>'role' AS role,
        cp.ref_code,
        cp.ref_link,
        cp.is_active,
        cp.commission_rate,
        cp.created_at
      FROM app.commercial_profiles cp
      JOIN auth.users u ON u.id = cp.user_id
      WHERE cp.ref_code IS NULL
         OR TRIM(cp.ref_code) = ''
         OR cp.ref_link IS NULL
         OR TRIM(cp.ref_link) = ''
      ORDER BY cp.created_at DESC
    """,
    "user_referrals_roles_overview": """
      SELECT
        ur.student_id,
        u_student.email AS student_email,
        u_student.raw_user_meta_data->>'role' AS student_role,
        ur.commercial_user_id,
        u_comm.email AS commercial_email,
        u_comm.raw_user_meta_data->>'role' AS commercial_role,
        ur.ref_code,
        ur.source,
        ur.attributed_at
      FROM app.user_referrals ur
      LEFT JOIN auth.users u_student ON u_student.id = ur.student_id
      LEFT JOIN auth.users u_comm ON u_comm.id = ur.commercial_user_id
      ORDER BY ur.attributed_at DESC
    """,
    "target_kayadejule_auth": """
      SELECT id, email, raw_user_meta_data->>'role' AS role, created_at
      FROM auth.users
      WHERE email = 'kayadejule@gmail.com'
    """,
    "target_kayadejule_commercial_profile": """
      SELECT *
      FROM app.commercial_profiles
      WHERE user_id = (
        SELECT id FROM auth.users WHERE email = 'kayadejule@gmail.com'
      )
    """,
    "target_kayadejule_as_referrer": """
      SELECT *
      FROM app.user_referrals
      WHERE commercial_user_id = (
        SELECT id FROM auth.users WHERE email = 'kayadejule@gmail.com'
      )
      ORDER BY attributed_at DESC
    """,
    "target_noegrounriga_auth": """
      SELECT id, email, raw_user_meta_data->>'role' AS role, created_at
      FROM auth.users
      WHERE email = 'noegrounriga@gmail.com'
    """,
    "target_noegrounriga_commercial_profile": """
      SELECT *
      FROM app.commercial_profiles
      WHERE user_id = (
        SELECT id FROM auth.users WHERE email = 'noegrounriga@gmail.com'
      )
    """,
    "target_noegrounriga_student_profile": """
      SELECT *
      FROM app.students
      WHERE id = (
        SELECT id FROM auth.users WHERE email = 'noegrounriga@gmail.com'
      )
    """,
    "target_noegrounriga_referral_as_student": """
      SELECT *
      FROM app.user_referrals
      WHERE student_id = (
        SELECT id FROM auth.users WHERE email = 'noegrounriga@gmail.com'
      )
    """,
  }

  for name, sql in queries.items():
    print(f"\n===== QUERY: {name} =====")
    res = tester.call_rpc("execute_sql", {"sql_query": sql})
    print(json.dumps(res, indent=2, default=str))


if __name__ == "__main__":
  main()
