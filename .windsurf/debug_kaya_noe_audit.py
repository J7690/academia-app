import json

from supabase_auto_manager import SupabaseAutoManager


def main() -> None:
    mgr = SupabaseAutoManager()

    queries = {
        "kayadejule_auth": """
          SELECT id, email, raw_user_meta_data->>'role' AS role, created_at
          FROM auth.users
          WHERE email = 'kayadejule@gmail.com'
        """,
        "kayadejule_commercial_profile": """
          SELECT *
          FROM app.commercial_profiles
          WHERE user_id = (
            SELECT id FROM auth.users WHERE email = 'kayadejule@gmail.com'
          )
        """,
        "kayadejule_as_referrer": """
          SELECT *
          FROM app.user_referrals
          WHERE commercial_user_id = (
            SELECT id FROM auth.users WHERE email = 'kayadejule@gmail.com'
          )
          ORDER BY attributed_at DESC
        """,
        "noegounriga_auth": """
          SELECT id, email, raw_user_meta_data->>'role' AS role, created_at
          FROM auth.users
          WHERE email = 'noegounriga@gmail.com'
        """,
        "noegounriga_commercial_profile": """
          SELECT *
          FROM app.commercial_profiles
          WHERE user_id = (
            SELECT id FROM auth.users WHERE email = 'noegounriga@gmail.com'
          )
        """,
        "noegounriga_student_profile": """
          SELECT *
          FROM app.students
          WHERE id = (
            SELECT id FROM auth.users WHERE email = 'noegounriga@gmail.com'
          )
        """,
        "noegounriga_referral_as_student": """
          SELECT *
          FROM app.user_referrals
          WHERE student_id = (
            SELECT id FROM auth.users WHERE email = 'noegounriga@gmail.com'
          )
        """,
    }

    for name, sql in queries.items():
        print(f"\n===== QUERY: {name} =====")
        res = mgr.execute_sql_auto(sql)
        print(json.dumps(res, indent=2, default=str))


if __name__ == "__main__":
    main()
