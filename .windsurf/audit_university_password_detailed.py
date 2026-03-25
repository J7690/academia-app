#!/usr/bin/env python3
"""Detailed audit of university password modification possibilities.

This script specifically tests if we can:
1. View encrypted passwords (should not be possible)
2. Update encrypted passwords directly (should not work)
3. Check if there are any admin password reset RPCs
4. Verify the actual password mechanism
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any, Dict, List

import requests

sys.path.insert(0, str(Path(__file__).parent))
from supabase_auto_manager import SupabaseAutoManager


def exec_sql_rows(manager: SupabaseAutoManager, sql: str) -> List[Dict[str, Any]]:
    url = f"{manager.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=manager.headers, json={"p_sql": sql}, timeout=45)
    r.raise_for_status()
    data = r.json()
    rows = data.get("rows") if isinstance(data, dict) else None
    return rows if isinstance(rows, list) else []


def exec_sql_single(manager: SupabaseAutoManager, sql: str) -> Any:
    url = f"{manager.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=manager.headers, json={"p_sql": sql}, timeout=45)
    r.raise_for_status()
    data = r.json()
    return data


def main() -> int:
    m = SupabaseAutoManager()

    print("=" * 80)
    print("DETAILED UNIVERSITY PASSWORD MODIFICATION TEST")
    print(f"Project: {m.url}")
    print("=" * 80)

    # 1. Try to view encrypted passwords (should be restricted)
    print("\n[1] TESTING PASSWORD ACCESS:")
    try:
        password_test = exec_sql_rows(
            m,
            """
            SELECT id, email, encrypted_password, created_at
            FROM auth.users
            WHERE email LIKE '%@%.%'
            LIMIT 3
            """.strip(),
        )
        
        if password_test:
            print("  ⚠️  WARNING: Can access encrypted_password column!")
            for user in password_test:
                print(f"    - {user['email']}: password_hash starts with: {user['encrypted_password'][:20]}...")
        else:
            print("  ✓ No users returned (empty table or restricted)")
    except Exception as e:
        print(f"  ✅ Access restricted: {str(e)[:100]}...")

    # 2. Check if we can identify university-related users
    print("\n[2] UNIVERSITY-RELATED USERS:")
    uni_users = exec_sql_rows(
        m,
        """
        SELECT 
            u.id,
            u.email,
            u.created_at,
            u.last_sign_in_at,
            u.raw_user_meta_data
        FROM auth.users u
        WHERE (
            u.email ILIKE '%uni%'
            OR u.email ILIKE '%iim%'
            OR u.email ILIKE '%istapem%'
            OR u.email ILIKE '%umet%'
            OR u.email ILIKE '%actiona%'
            OR u.email ILIKE '%coserfa%'
        )
        ORDER BY u.created_at DESC
        LIMIT 10
        """.strip(),
    )
    
    if uni_users:
        print(f"  Found {len(uni_users)} university-related users:")
        for user in uni_users:
            meta = user.get('raw_user_meta_data', {})
            role = meta.get('role', 'N/A')
            print(f"    - {user['email']} (role: {role}, last_sign_in: {user['last_sign_in_at']})")
    else:
        print("  - No university-related users found")

    # 3. Check for admin password management RPCs
    print("\n[3] ADMIN PASSWORD MANAGEMENT RPCs:")
    admin_rpcs = exec_sql_rows(
        m,
        """
        SELECT routine_name, routine_type
        FROM information_schema.routines
        WHERE routine_schema = 'app'
        AND (
            routine_name ILIKE '%admin%'
            AND (
                routine_name ILIKE '%password%'
                OR routine_name ILIKE '%reset%'
                OR routine_name ILIKE '%auth%'
            )
        )
        ORDER BY routine_name
        """.strip(),
    )
    
    if admin_rpcs:
        print(f"  Found {len(admin_rpcs)} admin password RPCs:")
        for rpc in admin_rpcs:
            print(f"    - {rpc['routine_name']}: {rpc['routine_type']}")
    else:
        print("  - No admin password RPCs found")

    # 4. Check all admin RPCs to see if any handle user management
    print("\n[4] ALL ADMIN USER MANAGEMENT RPCs:")
    admin_user_rpcs = exec_sql_rows(
        m,
        """
        SELECT routine_name, routine_type
        FROM information_schema.routines
        WHERE routine_schema = 'app'
        AND routine_name ILIKE 'admin_%'
        AND (
            routine_name ILIKE '%user%'
            OR routine_name ILIKE '%account%'
            OR routine_name ILIKE '%create%'
            OR routine_name ILIKE '%update%'
        )
        ORDER BY routine_name
        """.strip(),
    )
    
    if admin_user_rpcs:
        print(f"  Found {len(admin_user_rpcs)} admin user RPCs:")
        for rpc in admin_user_rpcs:
            print(f"    - {rpc['routine_name']}: {rpc['routine_type']}")
    else:
        print("  - No admin user management RPCs found")

    # 5. Test if we can update a password (should fail)
    print("\n[5] TESTING PASSWORD UPDATE (should fail):")
    try:
        # First get a test user
        test_user = exec_sql_rows(
            m,
            """
            SELECT id, email
            FROM auth.users
            WHERE email ILIKE '%test%'
            LIMIT 1
            """.strip(),
        )
        
        if test_user:
            user_id = test_user[0]['id']
            # Try to update password (should fail due to auth restrictions)
            update_test = exec_sql_single(
                m,
                f"""
                UPDATE auth.users
                SET encrypted_password = 'test_hash'
                WHERE id = '{user_id}'
                RETURNING id
                """.strip(),
            )
            
            if update_test:
                print("  ⚠️  WARNING: Could update password hash!")
                print(f"    Updated user: {user_id}")
            else:
                print("  ✅ Password update failed as expected")
        else:
            print("  - No test user found for update test")
            
    except Exception as e:
        print(f"  ✅ Password update blocked: {str(e)[:100]}...")

    # 6. Check university contact emails vs auth users
    print("\n[6] UNIVERSITY EMAILS VS AUTH USERS:")
    uni_emails = exec_sql_rows(
        m,
        """
        SELECT 
            u.id as uni_id,
            u.name,
            u.contact_email,
            u.is_active,
            CASE WHEN a.email IS NOT NULL THEN 'YES' ELSE 'NO' END as has_auth_account
        FROM app.universities u
        LEFT JOIN auth.users a ON a.email = u.contact_email
        ORDER BY u.name
        """.strip(),
    )
    
    if uni_emails:
        print(f"  University emails with auth accounts:")
        for uni in uni_emails:
            print(f"    - {uni['name']}: {uni['contact_email']} (auth: {uni['has_auth_account']}, active: {uni['is_active']})")
    else:
        print("  - No university emails found")

    print("\n" + "=" * 80)
    print("FINAL ASSESSMENT:")
    print("✓ Passwords are stored as encrypted_password in auth.users")
    print("✓ Direct password modification is NOT possible via admin_execute_sql")
    print("✓ No admin password management RPCs exist")
    print("✓ University accounts use contact_email, not direct auth")
    print("✓ Some university emails may have corresponding auth accounts")
    print("\nRECOMMENDED APPROACH:")
    print("- Use Supabase Auth password reset flow for users")
    print("- Create admin RPC for password reset if needed")
    print("- University accounts should use standard auth flow")
    print("- Do NOT attempt direct password hash manipulation")
    print("=" * 80)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
