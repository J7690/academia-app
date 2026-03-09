#!/usr/bin/env python3
"""Cree la RPC app_admin_list_deleted_users pour lister les comptes supprimes."""

import sys
sys.path.insert(0, str(__import__('pathlib').Path(__file__).parent))

from supabase_auto_manager import SupabaseAutoManager


def main():
    m = SupabaseAutoManager()

    sql = """
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
        SELECT JSONB_BUILD_OBJECT(
          'user_id', s.user_id,
          'deleted_at', s.deleted_at,
          'deleted_reason', s.deleted_reason,
          'suspended_reason', s.suspended_reason,
          'email', u.email,
          'role', u.raw_user_meta_data->>'role',
          'full_name', COALESCE(u.raw_user_meta_data->>'full_name', ''),
          'university_id', u.raw_user_meta_data->>'university_id',
          'created_at', u.created_at
        ) AS row_data,
        s.deleted_at
        FROM app.user_admin_status s
        LEFT JOIN auth.users u ON u.id = s.user_id
        WHERE s.is_deleted = TRUE
        ORDER BY s.deleted_at DESC
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

    result = m.execute_sql_auto(sql)
    if result.get("success"):
        print("OK [1/2] RPC app_admin_list_deleted_users creee.")
    else:
        print("ERREUR [1/2]:", result.get("error"))

    sql_grant = """
    GRANT EXECUTE ON FUNCTION public.app_admin_list_deleted_users(INTEGER, INTEGER) TO authenticated;
    """
    result2 = m.execute_sql_auto(sql_grant)
    if result2.get("success"):
        print("OK [2/2] GRANT app_admin_list_deleted_users.")
    else:
        print("ERREUR [2/2]:", result2.get("error"))


if __name__ == "__main__":
    main()
