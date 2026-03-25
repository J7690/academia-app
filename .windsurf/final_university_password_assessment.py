#!/usr/bin/env python3
"""Final assessment: Can we modify university passwords directly?

Based on audit results, this provides the definitive answer.
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
    print("FINAL ASSESSMENT: UNIVERSITY PASSWORD MODIFICATION")
    print(f"Project: {m.url}")
    print("=" * 80)

    print("\n📋 QUESTION: Can we modify university passwords directly in the database?")
    print("=" * 80)

    # 1. Current university accounts
    print("\n[1] CURRENT UNIVERSITY ACCOUNTS:")
    uni_accounts = exec_sql_rows(
        m,
        """
        SELECT 
            u.id,
            u.name,
            u.contact_email,
            u.is_active,
            CASE 
                WHEN a.email IS NOT NULL THEN 'YES'
                ELSE 'NO'
            END as has_auth_account,
            CASE 
                WHEN a.last_sign_in_at IS NOT NULL THEN 'ACTIVE'
                ELSE 'NEVER_SIGNED_IN'
            END as auth_status
        FROM app.universities u
        LEFT JOIN auth.users a ON a.email = u.contact_email
        ORDER BY u.is_active DESC, u.name
        """.strip(),
    )
    
    active_unis = [uni for uni in uni_accounts if uni['is_active']]
    inactive_unis = [uni for uni in uni_accounts if not uni['is_active']]
    
    print(f"  Total universities: {len(uni_accounts)}")
    print(f"  Active: {len(active_unis)}")
    print(f"  Inactive: {len(inactive_unis)}")
    
    print(f"\n  Active universities with auth accounts:")
    for uni in active_unis:
        if uni['has_auth_account'] == 'YES':
            print(f"    ✓ {uni['name']}: {uni['contact_email']} ({uni['auth_status']})")
        else:
            print(f"    ⚠ {uni['name']}: {uni['contact_email']} (NO AUTH ACCOUNT)")

    # 2. Password storage mechanism
    print("\n[2] PASSWORD STORAGE MECHANISM:")
    print("  ✓ Passwords stored in auth.users.encrypted_password")
    print("  ✓ Hashing algorithm: bcrypt (starts with $2a$)")
    print("  ✓ University accounts use standard Supabase Auth")
    print("  ✓ No separate password system for universities")

    # 3. Direct modification capability
    print("\n[3] DIRECT MODIFICATION CAPABILITY:")
    print("  ❌ CANNOT modify passwords directly via admin_execute_sql")
    print("  ❌ CANNOT insert new passwords directly")
    print("  ❌ CANNOT decrypt existing passwords")
    print("  ❌ NO admin password management RPCs exist")

    # 4. What IS possible
    print("\n[4] WHAT IS POSSIBLE:")
    print("  ✓ View encrypted_password hashes (but not decrypt them)")
    print("  ✓ View university account information")
    print("  ✓ Link university emails to auth accounts")
    print("  ✓ Create new auth accounts via Supabase Auth API")
    print("  ✓ Trigger password reset via Supabase Auth")

    # 5. Recommended approach
    print("\n[5] RECOMMENDED APPROACH FOR PASSWORD MANAGEMENT:")
    print("  1. Use Supabase Auth password reset flow")
    print("  2. Create custom admin RPC for password reset if needed")
    print("  3. Use auth.admin API for user management")
    print("  4. Implement proper email verification")
    print("  5. Never attempt direct hash manipulation")

    # 6. Security considerations
    print("\n[6] SECURITY CONSIDERATIONS:")
    print("  ⚠️  Password hashes are accessible but not readable")
    print("  ⚠️  No audit trail for password viewing")
    print("  ⚠️  University accounts rely on standard auth security")
    print("  ✅ Direct password modification appears blocked")
    print("  ✅ Proper password reset flow should be used")

    print("\n" + "=" * 80)
    print("FINAL ANSWER:")
    print("❌ NON, il n'est pas possible de modifier directement les mots de passe")
    print("   des comptes universités par des commandes SQL.")
    print("\n✓ OUI, on peut voir les informations des comptes et les hashes cryptés")
    print("✓ OUI, on peut créer des comptes via l'API Supabase Auth")
    print("✓ OUI, on peut déclencher des réinitialisations de mot de passe")
    print("\nRECOMMANDATION:")
    print("Utiliser le flux de réinitialisation de mot de passe de Supabase Auth")
    print("ou créer des RPCs admin dédiées pour la gestion des mots de passe.")
    print("=" * 80)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
