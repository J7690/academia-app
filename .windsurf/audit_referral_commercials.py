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
      ORDER BY table_name;
    """,
    "sample_commercial_profiles": "SELECT * FROM app.commercial_profiles ORDER BY created_at DESC LIMIT 10;",
    "sample_user_referrals": "SELECT * FROM app.user_referrals ORDER BY attributed_at DESC LIMIT 10;",
    "sample_referral_commissions": "SELECT * FROM app.referral_commissions ORDER BY created_at DESC LIMIT 10;",
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
      ORDER BY proname;
    """,
  }

  for name, sql in queries.items():
    print(f"\n===== QUERY: {name} =====")
    res = tester.call_rpc("execute_sql", {"sql_query": sql})
    print(json.dumps(res, indent=2, default=str))


if __name__ == "__main__":
  main()
