-- Liste consolidée des comptes utilisateurs pour l'admin
-- Inspiré de supabase_admin_users.sql et supabase_live_sessions.sql

CREATE OR REPLACE FUNCTION app_admin_list_users_overview()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_admin_role TEXT;
  v_result JSONB;
BEGIN
  -- Vérifier l'authentification
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  -- Vérifier le rôle admin
  SELECT raw_user_meta_data->>'role'
  INTO v_admin_role
  FROM auth.users
  WHERE id = v_user_id;

  IF v_admin_role <> 'admin' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
  END IF;

  -- Construire la liste des comptes utilisateurs avec présence et statut admin
  SELECT COALESCE(
    JSONB_AGG(
      JSONB_BUILD_OBJECT(
        'id', u.id,
        'email', u.email,
        'role', u.raw_user_meta_data->>'role',
        'full_name', u.raw_user_meta_data->>'full_name',
        'created_at', u.created_at,
        'last_activity_at', p.last_activity_at,
        'is_online', CASE
          WHEN p.last_activity_at IS NOT NULL
               AND p.last_activity_at >= NOW() - INTERVAL '5 minutes'
            THEN TRUE
          ELSE FALSE
        END,
        'is_suspended', COALESCE(s.is_suspended, FALSE),
        'suspended_reason', s.suspended_reason,
        'is_deleted', COALESCE(s.is_deleted, FALSE),
        'deleted_reason', s.deleted_reason
      )
      ORDER BY u.created_at DESC
    ),
    '[]'::JSONB
  ) INTO v_result
  FROM auth.users u
  LEFT JOIN app.user_presence p ON p.user_id = u.id
  LEFT JOIN app.user_admin_status s ON s.user_id = u.id;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'users', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_users_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_users_overview() TO service_role;
