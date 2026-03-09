#!/usr/bin/env python3
"""Cree la table app.admin_deleted_users_archive et met a jour la RPC app_admin_list_deleted_users."""

import sys
sys.path.insert(0, str(__import__('pathlib').Path(__file__).parent))

from supabase_auto_manager import SupabaseAutoManager


def main():
    m = SupabaseAutoManager()

    # 1) Creer la table admin_deleted_users_archive
    sql_table = """
    CREATE TABLE IF NOT EXISTS app.admin_deleted_users_archive (
      id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
      user_id UUID NOT NULL,
      email TEXT,
      role TEXT,
      full_name TEXT,
      original_university_id UUID,
      original_metadata JSONB,
      original_created_at TIMESTAMPTZ,
      original_last_sign_in_at TIMESTAMPTZ,
      deleted_reason TEXT,
      deleted_by UUID,
      deleted_at TIMESTAMPTZ DEFAULT NOW()
    );
    """
    r1 = m.execute_sql_auto(sql_table)
    if r1.get("success"):
        print("OK [1/4] Table app.admin_deleted_users_archive creee.")
    else:
        print("ERREUR [1/4]:", r1.get("error"))

    # 2) Index sur user_id
    sql_idx = """
    CREATE INDEX IF NOT EXISTS idx_admin_deleted_users_archive_user_id
    ON app.admin_deleted_users_archive(user_id);
    """
    r2 = m.execute_sql_auto(sql_idx)
    if r2.get("success"):
        print("OK [2/4] Index cree.")
    else:
        print("ERREUR [2/4]:", r2.get("error"))

    # 3) Mettre a jour la RPC app_admin_list_deleted_users pour lire depuis la table d archive
    sql_rpc = """
    CREATE OR REPLACE FUNCTION public.app_admin_list_deleted_users(
      p_limit INTEGER DEFAULT 200,
      p_offset INTEGER DEFAULT 0
    )
    RETURNS JSONB
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $$
    DECLARE
      v_user_id UUID := auth.uid();
      v_role TEXT;
      v_result JSONB;
    BEGIN
      IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
      END IF;

      SELECT raw_user_meta_data->>'role'
      INTO v_role
      FROM auth.users
      WHERE id = v_user_id;

      IF v_role <> 'admin' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
      END IF;

      SELECT COALESCE(JSONB_AGG(row_data ORDER BY deleted_at DESC), '[]'::JSONB)
      INTO v_result
      FROM (
        -- Comptes hard-deleted (archives)
        SELECT JSONB_BUILD_OBJECT(
          'user_id', a.user_id,
          'deleted_at', a.deleted_at,
          'deleted_reason', a.deleted_reason,
          'email', a.email,
          'role', a.role,
          'full_name', COALESCE(a.full_name, ''),
          'university_id', a.original_university_id,
          'created_at', a.original_created_at,
          'type', 'hard_delete'
        ) AS row_data,
        a.deleted_at
        FROM app.admin_deleted_users_archive a

        UNION ALL

        -- Comptes soft-deleted (encore dans auth.users mais marques is_deleted)
        SELECT JSONB_BUILD_OBJECT(
          'user_id', s.user_id,
          'deleted_at', s.deleted_at,
          'deleted_reason', s.deleted_reason,
          'email', u.email,
          'role', u.raw_user_meta_data->>'role',
          'full_name', COALESCE(u.raw_user_meta_data->>'full_name', ''),
          'university_id', u.raw_user_meta_data->>'university_id',
          'created_at', u.created_at,
          'type', 'soft_delete'
        ) AS row_data,
        s.deleted_at
        FROM app.user_admin_status s
        JOIN auth.users u ON u.id = s.user_id
        WHERE s.is_deleted = TRUE
          AND NOT EXISTS (
            SELECT 1 FROM app.admin_deleted_users_archive a2
            WHERE a2.user_id = s.user_id
          )

        ORDER BY deleted_at DESC
        LIMIT p_limit
        OFFSET p_offset
      ) sub;

      RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'deleted_users', v_result
      );
    END;
    $$;
    """
    r3 = m.execute_sql_auto(sql_rpc)
    if r3.get("success"):
        print("OK [3/4] RPC app_admin_list_deleted_users mise a jour.")
    else:
        print("ERREUR [3/4]:", r3.get("error"))

    # 4) Grant
    sql_grant = """
    GRANT ALL ON app.admin_deleted_users_archive TO service_role;
    """
    r4 = m.execute_sql_auto(sql_grant)
    if r4.get("success"):
        print("OK [4/4] GRANT sur admin_deleted_users_archive.")
    else:
        print("ERREUR [4/4]:", r4.get("error"))


if __name__ == "__main__":
    main()
