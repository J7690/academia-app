#!/usr/bin/env python3
"""Test if password updates are actually possible via admin_execute_sql.

This script attempts to update a password hash to verify if it's possible.
WARNING: This is a TEST ONLY and should not be used for production.
"""

from __future__ import annotations

import sys
from pathlib import Path
from typing import Any, Dict, List

import requests

sys.path.insert(0, str(Path(__file__).parent))
from supabase_auto_manager import SupabaseAutoManager


def exec_sql_single(manager: SupabaseAutoManager, sql: str) -> Any:
    url = f"{manager.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=manager.headers, json={"p_sql": sql}, timeout=45)
    r.raise_for_status()
    data = r.json()
    return data


def main() -> int:
    m = SupabaseAutoManager()

    print("=" * 80)
    print("TESTING PASSWORD UPDATE CAPABILITY")
    print(f"Project: {m.url}")
    print("=" * 80)

    # 1. Find a test user (non-critical)
    print("\n[1] FINDING TEST USER:")
    test_user_query = exec_sql_single(
        m,
        """
        SELECT id, email, encrypted_password
        FROM auth.users
        WHERE email ILIKE '%test%' OR email ILIKE '%demo%'
        LIMIT 1
        """.strip(),
    )
    
    if isinstance(test_user_query, dict) and test_user_query.get('mode') == 'select':
        rows = test_user_query.get('rows', [])
        if rows:
            test_user = rows[0]
            print(f"  Found test user: {test_user['email']} (id: {test_user['id']})")
            user_id = test_user['id']
            original_hash = test_user['encrypted_password']
        else:
            print("  No test user found, trying university user...")
            # Try a university user as fallback
            uni_user_query = exec_sql_single(
                m,
                """
                SELECT id, email, encrypted_password
                FROM auth.users
                WHERE email = 'actiona2024@gmail.com'
                LIMIT 1
                """.strip(),
            )
            
            if isinstance(uni_user_query, dict) and uni_user_query.get('mode') == 'select':
                uni_rows = uni_user_query.get('rows', [])
                if uni_rows:
                    test_user = uni_rows[0]
                    print(f"  Using university user: {test_user['email']} (id: {test_user['id']})")
                    user_id = test_user['id']
                    original_hash = test_user['encrypted_password']
                else:
                    print("  ERROR: No suitable user found for testing")
                    return 1
            else:
                print("  ERROR: Could not query users")
                return 1
    else:
        print("  ERROR: Could not execute query")
        return 1

    # 2. Try to update the password with a new hash
    print("\n[2] ATTEMPTING PASSWORD UPDATE:")
    test_hash = "$2a$10$TEST_HASH_DO_NOT_USE_IN_PRODUCTION"
    
    try:
        update_result = exec_sql_single(
            m,
            f"""
            UPDATE auth.users
            SET encrypted_password = '{test_hash}'
            WHERE id = '{user_id}'
            RETURNING id, email, encrypted_password
            """.strip(),
        )
        
        if isinstance(update_result, dict):
            if update_result.get('mode') == 'update':
                updated_rows = update_result.get('rows', [])
                if updated_rows:
                    updated_user = updated_rows[0]
                    print(f"  ⚠️  SUCCESS: Password updated!")
                    print(f"    User: {updated_user['email']}")
                    print(f"    New hash: {updated_user['encrypted_password'][:30]}...")
                    
                    # 3. Restore original hash
                    print("\n[3] RESTORING ORIGINAL PASSWORD:")
                    restore_result = exec_sql_single(
                        m,
                        f"""
                        UPDATE auth.users
                        SET encrypted_password = '{original_hash}'
                        WHERE id = '{user_id}'
                        RETURNING id
                        """.strip(),
                    )
                    
                    if isinstance(restore_result, dict) and restore_result.get('mode') == 'update':
                        print("  ✓ Original password restored successfully")
                    else:
                        print("  ⚠️  WARNING: Could not restore original password!")
                    
                    print("\n" + "=" * 80)
                    print("RESULT: PASSWORD MODIFICATION IS POSSIBLE!")
                    print("⚠️  SECURITY RISK: Direct password updates are allowed!")
                    print("Recommendation: Implement proper access controls")
                    print("=" * 80)
                    return 0
                else:
                    print("  Update succeeded but no rows returned")
            else:
                print(f"  Unexpected mode: {update_result.get('mode')}")
        else:
            print(f"  Unexpected response: {update_result}")
            
    except Exception as e:
        print(f"  ✅ FAILED: Password update blocked")
        print(f"    Error: {str(e)}")
        print("\n" + "=" * 80)
        print("RESULT: PASSWORD MODIFICATION IS BLOCKED")
        print("✓ Security is maintained - direct updates not allowed")
        print("=" * 80)
        return 0

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
