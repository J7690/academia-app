-- Drop legacy overloads for opportunity feed RPCs.
-- Keep the "Phase 7" signatures used by Flutter:
-- - app_student_list_opportunities(p_type, p_search, p_limit, p_offset, p_sort, p_verified_only, p_ready_to_ship_only)
-- - app_student_list_bookmarked_opportunities(p_type, p_search, p_limit, p_offset, p_sort, p_verified_only, p_ready_to_ship_only)

DO $$
BEGIN
  -- app_student_list_opportunities legacy overloads
  IF EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'app_student_list_opportunities'
      AND pg_get_function_identity_arguments(p.oid) = 'p_type text, p_search text'
  ) THEN
    EXECUTE 'DROP FUNCTION public.app_student_list_opportunities(text, text)';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'app_student_list_opportunities'
      AND pg_get_function_identity_arguments(p.oid) = 'p_type text, p_search text, p_limit integer, p_offset integer'
  ) THEN
    EXECUTE 'DROP FUNCTION public.app_student_list_opportunities(text, text, integer, integer)';
  END IF;

  -- app_student_list_bookmarked_opportunities legacy overload
  IF EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'app_student_list_bookmarked_opportunities'
      AND pg_get_function_identity_arguments(p.oid) = 'p_type text, p_search text, p_limit integer, p_offset integer'
  ) THEN
    EXECUTE 'DROP FUNCTION public.app_student_list_bookmarked_opportunities(text, text, integer, integer)';
  END IF;
END;
$$;
