#!/usr/bin/env python3
from supabase_auto_manager import SupabaseAutoManager
m = SupabaseAutoManager()
r = m.execute_sql_auto("SELECT routine_name FROM information_schema.routines WHERE routine_name IN ('app_admin_get_treasury_summary','app_admin_list_payout_queue','app_admin_list_ledger','app_admin_list_subscriptions','app_admin_manage_subscription_plan') ORDER BY routine_name")
print("RPCs admin Phase 1:", r)
