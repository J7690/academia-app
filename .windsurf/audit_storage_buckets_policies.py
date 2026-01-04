#!/usr/bin/env python3
"""Audit complet du Storage Supabase : buckets et policies RLS.

Vérifie :
1. Quels buckets existent dans storage.buckets
2. Quelles policies RLS existent sur storage.objects
3. Si le bucket community-media existe et est public
"""

from __future__ import annotations

import json
from supabase_auto_manager import SupabaseAutoManager


def main() -> int:
    manager = SupabaseAutoManager()

    print("=" * 60)
    print("AUDIT STORAGE SUPABASE")
    print("=" * 60)

    # 1. Lister tous les buckets
    print("\n[1] BUCKETS EXISTANTS (storage.buckets)")
    print("-" * 40)
    buckets_sql = "SELECT id, name, public, created_at FROM storage.buckets ORDER BY name;"
    result = manager.execute_sql_auto(buckets_sql)
    if result.get("ok"):
        rows = result.get("rows", [])
        if rows:
            for row in rows:
                bucket_id, bucket_name, is_public, created_at = row
                status = "PUBLIC" if is_public else "PRIVATE"
                print(f"  - {bucket_name} (id={bucket_id}) [{status}] created={created_at}")
        else:
            print("  Aucun bucket trouvé.")
    else:
        print(f"  ERREUR: {result.get('error')}")

    # 2. Vérifier spécifiquement community-media
    print("\n[2] BUCKET community-media")
    print("-" * 40)
    check_sql = "SELECT id, name, public FROM storage.buckets WHERE id = 'community-media';"
    result = manager.execute_sql_auto(check_sql)
    if result.get("ok"):
        rows = result.get("rows", [])
        if rows:
            bucket_id, bucket_name, is_public = rows[0]
            print(f"  ✅ Bucket trouvé: {bucket_name} (public={is_public})")
        else:
            print("  ❌ Bucket community-media N'EXISTE PAS")
    else:
        print(f"  ERREUR: {result.get('error')}")

    # 3. Lister toutes les policies RLS sur storage.objects
    print("\n[3] POLICIES RLS SUR storage.objects")
    print("-" * 40)
    policies_sql = """
    SELECT 
        polname AS policy_name,
        polcmd AS command,
        polroles::regrole[] AS roles,
        pg_get_expr(polqual, polrelid) AS using_expr,
        pg_get_expr(polwithcheck, polrelid) AS with_check_expr
    FROM pg_policy
    WHERE polrelid = 'storage.objects'::regclass
    ORDER BY polname;
    """
    result = manager.execute_sql_auto(policies_sql)
    if result.get("ok"):
        rows = result.get("rows", [])
        if rows:
            for row in rows:
                policy_name, cmd, roles, using_expr, with_check = row
                cmd_map = {'r': 'SELECT', 'a': 'INSERT', 'w': 'UPDATE', 'd': 'DELETE', '*': 'ALL'}
                cmd_str = cmd_map.get(cmd, cmd)
                print(f"\n  Policy: {policy_name}")
                print(f"    Command: {cmd_str}")
                print(f"    Roles: {roles}")
                if using_expr:
                    print(f"    USING: {using_expr[:100]}...")
                if with_check:
                    print(f"    WITH CHECK: {with_check[:100]}...")
        else:
            print("  Aucune policy trouvée sur storage.objects")
    else:
        print(f"  ERREUR: {result.get('error')}")

    # 4. Vérifier si RLS est activé sur storage.objects
    print("\n[4] RLS ACTIVÉ SUR storage.objects ?")
    print("-" * 40)
    rls_sql = """
    SELECT relrowsecurity, relforcerowsecurity 
    FROM pg_class 
    WHERE oid = 'storage.objects'::regclass;
    """
    result = manager.execute_sql_auto(rls_sql)
    if result.get("ok"):
        rows = result.get("rows", [])
        if rows:
            rls_enabled, rls_forced = rows[0]
            print(f"  RLS enabled: {rls_enabled}")
            print(f"  RLS forced: {rls_forced}")
        else:
            print("  Impossible de déterminer l'état RLS")
    else:
        print(f"  ERREUR: {result.get('error')}")

    # 5. Chercher spécifiquement les policies pour community-media
    print("\n[5] POLICIES MENTIONNANT 'community-media'")
    print("-" * 40)
    community_policies_sql = """
    SELECT 
        polname AS policy_name,
        polcmd AS command,
        pg_get_expr(polqual, polrelid) AS using_expr,
        pg_get_expr(polwithcheck, polrelid) AS with_check_expr
    FROM pg_policy
    WHERE polrelid = 'storage.objects'::regclass
      AND (
        pg_get_expr(polqual, polrelid) LIKE '%community-media%'
        OR pg_get_expr(polwithcheck, polrelid) LIKE '%community-media%'
      );
    """
    result = manager.execute_sql_auto(community_policies_sql)
    if result.get("ok"):
        rows = result.get("rows", [])
        if rows:
            for row in rows:
                policy_name, cmd, using_expr, with_check = row
                cmd_map = {'r': 'SELECT', 'a': 'INSERT', 'w': 'UPDATE', 'd': 'DELETE', '*': 'ALL'}
                cmd_str = cmd_map.get(cmd, cmd)
                print(f"  ✅ Policy: {policy_name} ({cmd_str})")
        else:
            print("  ❌ Aucune policy spécifique pour community-media")
    else:
        print(f"  ERREUR: {result.get('error')}")

    print("\n" + "=" * 60)
    print("FIN DE L'AUDIT STORAGE")
    print("=" * 60)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
