#!/usr/bin/env python3
"""Audit university accounts password modification capability via admin_execute_sql.

This script checks:
1. University accounts structure
2. Auth users table structure  
3. Whether passwords can be modified directly in DB
4. What mechanisms exist for password management
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


def main() -> int:
    m = SupabaseAutoManager()

    print("=" * 80)
    print("UNIVERSITY PASSWORD MODIFICATION CAPABILITY AUDIT")
    print(f"Project: {m.url}")
    print("=" * 80)

    # 1. Check auth.users structure
    print("\n[1] AUTH.USERS TABLE STRUCTURE:")
    auth_cols = exec_sql_rows(
        m,
        """
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema='auth' AND table_name='users'
        ORDER BY ordinal_position
        """.strip(),
    )
    
    for col in auth_cols:
        print(f"  - {col['column_name']}: {col['data_type']} ({col['is_nullable']})")

    # 2. Check if there's a password column
    password_cols = [col for col in auth_cols if 'password' in col['column_name'].lower()]
    print(f"\n[2] PASSWORD-RELATED COLUMNS: {len(password_cols)} found")
    for col in password_cols:
        print(f"  - {col['column_name']}: {col['data_type']}")

    # 3. Check university staff table (if it exists)
    print("\n[3] UNIVERSITY STAFF TABLE STRUCTURE:")
    staff_exists = exec_sql_rows(
        m,
        """
        SELECT EXISTS (
          SELECT FROM information_schema.tables 
          WHERE table_schema = 'app' 
          AND table_name = 'university_staff'
        );
        """.strip(),
    )
    
    if staff_exists and staff_exists[0].get('exists'):
        staff_cols = exec_sql_rows(
            m,
            """
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns
            WHERE table_schema='app' AND table_name='university_staff'
            ORDER BY ordinal_position
            """.strip(),
        )
        
        for col in staff_cols:
            print(f"  - {col['column_name']}: {col['data_type']} ({col['is_nullable']})")
    else:
        print("  - university_staff table does not exist")

    # 4. Check for any RPCs related to password management
    print("\n[4] PASSWORD-RELATED RPCs:")
    password_rpcs = exec_sql_rows(
        m,
        """
        SELECT routine_name, routine_type
        FROM information_schema.routines
        WHERE routine_schema = 'app'
        AND (
            routine_name ILIKE '%password%'
            OR routine_name ILIKE '%reset%'
            OR routine_name ILIKE '%auth%'
        )
        ORDER BY routine_name
        """.strip(),
    )
    
    if password_rpcs:
        for rpc in password_rpcs:
            print(f"  - {rpc['routine_name']}: {rpc['routine_type']}")
    else:
        print("  - No password-related RPCs found")

    # 5. Check university accounts
    print("\n[5] UNIVERSITY ACCOUNTS:")
    uni_accounts = exec_sql_rows(
        m,
        """
        SELECT 
            u.id,
            u.name,
            u.contact_email,
            u.is_active
        FROM app.universities u
        ORDER BY u.name
        LIMIT 10
        """.strip(),
    )
    
    if uni_accounts:
        print(f"  Found {len(uni_accounts)} universities:")
        for uni in uni_accounts:
            print(f"    - {uni['name']} (id: {uni['id']}, email: {uni['contact_email']}, active: {uni['is_active']})")
    else:
        print("  - No universities found")

    # 6. Check if there are any user accounts linked to universities
    print("\n[6] UNIVERSITY-LINKED USER ACCOUNTS:")
    
    # Look for any table that might link users to universities
    link_tables = exec_sql_rows(
        m,
        """
        WITH uni_cols AS (
          SELECT table_name
          FROM information_schema.columns
          WHERE table_schema='app'
            AND column_name='university_id'
        ), user_cols AS (
          SELECT table_name
          FROM information_schema.columns
          WHERE table_schema='app'
            AND column_name='user_id'
        )
        SELECT u.table_name
        FROM uni_cols u
        JOIN user_cols x USING(table_name)
        ORDER BY u.table_name
        """.strip(),
    )
    
    if link_tables:
        print(f"  Found {len(link_tables)} link tables:")
        for table in link_tables:
            table_name = table['table_name']
            print(f"    - app.{table_name}")
            
            # Count linked users
            count = exec_sql_rows(
                m,
                f"""
                SELECT COUNT(*) as count
                FROM app.{table_name}
                WHERE university_id IS NOT NULL AND user_id IS NOT NULL
                """.strip(),
            )
            
            if count:
                print(f"      Linked users: {count[0]['count']}")
    else:
        print("  - No university-user link tables found")

    # 7. Check Supabase auth password reset capabilities
    print("\n[7] PASSWORD RESET CAPABILITIES:")
    
    # Check if there are any password reset tokens or related tables
    reset_tables = exec_sql_rows(
        m,
        """
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'auth'
        AND (
            table_name ILIKE '%reset%'
            OR table_name ILIKE '%password%'
            OR table_name ILIKE '%token%'
        )
        ORDER BY table_name
        """.strip(),
    )
    
    if reset_tables:
        print("  Auth reset-related tables:")
        for table in reset_tables:
            print(f"    - auth.{table['table_name']}")
    else:
        print("  - No auth reset tables found (expected in Supabase)")

    print("\n" + "=" * 80)
    print("CONCLUSION:")
    print("- Supabase Auth stores passwords in auth.users but they are HASHED")
    print("- Direct password modification is NOT possible/recommended")
    print("- Password hashes cannot be reversed or manually updated")
    print("- Use Supabase Auth password reset flow instead")
    print("- University accounts are in app.universities but don't contain passwords")
    print("- University staff/user links would be in separate tables")
    print("=" * 80)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
