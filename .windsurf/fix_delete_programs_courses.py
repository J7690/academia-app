#!/usr/bin/env python3
"""Cree les RPCs de suppression hard-delete pour programmes et cours."""

import sys
sys.path.insert(0, str(__import__('pathlib').Path(__file__).parent))

from supabase_auto_manager import SupabaseAutoManager


def main():
    m = SupabaseAutoManager()

    # RPC 1: app_admin_delete_program (supprime le programme ET ses cours)
    sql1 = """
    CREATE OR REPLACE FUNCTION public.app_admin_delete_program(p_program_id UUID)
    RETURNS JSONB
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $$
    DECLARE
      v_user_id UUID := auth.uid();
      v_role TEXT;
      v_found BOOLEAN;
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

      IF p_program_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'missing_program_id');
      END IF;

      SELECT EXISTS(SELECT 1 FROM app.programs WHERE id = p_program_id) INTO v_found;
      IF NOT v_found THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'program_not_found');
      END IF;

      -- Supprimer d abord les cours lies au programme
      DELETE FROM app.courses WHERE program_id = p_program_id;

      -- Supprimer le programme
      DELETE FROM app.programs WHERE id = p_program_id;

      RETURN JSONB_BUILD_OBJECT('success', TRUE);
    END;
    $$;
    """

    result1 = m.execute_sql_auto(sql1)
    if result1.get("success"):
        print("OK [1/4] RPC app_admin_delete_program creee.")
    else:
        print("ERREUR [1/4]:", result1.get("error"))

    # RPC 2: app_admin_delete_course
    sql2 = """
    CREATE OR REPLACE FUNCTION public.app_admin_delete_course(p_course_id UUID)
    RETURNS JSONB
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $$
    DECLARE
      v_user_id UUID := auth.uid();
      v_role TEXT;
      v_found BOOLEAN;
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

      IF p_course_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'missing_course_id');
      END IF;

      SELECT EXISTS(SELECT 1 FROM app.courses WHERE id = p_course_id) INTO v_found;
      IF NOT v_found THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'course_not_found');
      END IF;

      DELETE FROM app.courses WHERE id = p_course_id;

      RETURN JSONB_BUILD_OBJECT('success', TRUE);
    END;
    $$;
    """

    result2 = m.execute_sql_auto(sql2)
    if result2.get("success"):
        print("OK [2/4] RPC app_admin_delete_course creee.")
    else:
        print("ERREUR [2/4]:", result2.get("error"))

    # GRANT
    sql3 = """
    GRANT EXECUTE ON FUNCTION public.app_admin_delete_program(UUID) TO authenticated;
    """
    result3 = m.execute_sql_auto(sql3)
    if result3.get("success"):
        print("OK [3/4] GRANT app_admin_delete_program.")
    else:
        print("ERREUR [3/4]:", result3.get("error"))

    sql4 = """
    GRANT EXECUTE ON FUNCTION public.app_admin_delete_course(UUID) TO authenticated;
    """
    result4 = m.execute_sql_auto(sql4)
    if result4.get("success"):
        print("OK [4/4] GRANT app_admin_delete_course.")
    else:
        print("ERREUR [4/4]:", result4.get("error"))


if __name__ == "__main__":
    main()
