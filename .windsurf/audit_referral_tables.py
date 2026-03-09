#!/usr/bin/env python3
"""Audit des tables liées au système de referral/commercial"""
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()

# Tables liées au commercial/referral
tables = ['commercial_profiles', 'referral_commissions', 'user_referrals', 'user_invitations', 'commission_rules', 'commercial_milestones', 'commercial_tiers', 'milestone_claims']

for table in tables:
    print(f'\n=== TABLE {table} ===')
    try:
        result = m.execute_sql_auto(f'SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_schema = \'app\' AND table_name = \'{table}\' ORDER BY ordinal_position')
        if result['success']:
            if result['data']:
                for row in result['data'][0]['result']:
                    print(f'  {row["column_name"]}: {row["data_type"]} ({row["is_nullable"]})')
            else:
                print('  Table does not exist')
        else:
            print(f'  ERROR: {result["error"]}')
    except Exception as e:
        print(f'  EXCEPTION: {e}')
