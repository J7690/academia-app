-- Actions administrateur sur les comptes utilisateurs
-- + journal d'audit des actions

CREATE SCHEMA IF NOT EXISTS app;

-- Statut admin des comptes (suspension / réactivation)
CREATE TABLE IF NOT EXISTS app.user_admin_status (
    user_id UUID PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
    is_suspended BOOLEAN NOT NULL DEFAULT FALSE,
    suspended_reason TEXT,
    suspended_at TIMESTAMPTZ,
    reactivated_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_reason TEXT,
    deleted_at TIMESTAMPTZ
);

-- S'assurer que les colonnes de suppression logique existent aussi
-- si la table a été créée dans une version antérieure sans ces champs.
ALTER TABLE app.user_admin_status
  ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE app.user_admin_status
  ADD COLUMN IF NOT EXISTS deleted_reason TEXT;

ALTER TABLE app.user_admin_status
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

ALTER TABLE app.user_admin_status ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS admin_manage_user_status ON app.user_admin_status;
CREATE POLICY admin_manage_user_status
ON app.user_admin_status
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
);

GRANT SELECT, INSERT, UPDATE, DELETE ON app.user_admin_status TO authenticated;
GRANT ALL ON app.user_admin_status TO service_role;

-- Journal des actions admin sur les comptes
CREATE TABLE IF NOT EXISTS app.admin_user_action_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    performed_by UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    target_user UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    action TEXT NOT NULL CHECK (action IN ('suspend', 'reactivate', 'delete')),
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    meta JSONB
);

-- Harmoniser la contrainte CHECK même si la table existait déjà sans l'action 'delete'.
ALTER TABLE app.admin_user_action_logs
  DROP CONSTRAINT IF EXISTS admin_user_action_logs_action_check;

ALTER TABLE app.admin_user_action_logs
  ADD CONSTRAINT admin_user_action_logs_action_check
  CHECK (action IN ('suspend', 'reactivate', 'delete'));

ALTER TABLE app.admin_user_action_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS admin_all_user_action_logs ON app.admin_user_action_logs;
CREATE POLICY admin_all_user_action_logs
ON app.admin_user_action_logs
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid()
      AND u.raw_user_meta_data->>'role' = 'admin'
  )
);

GRANT SELECT, INSERT, UPDATE, DELETE ON app.admin_user_action_logs TO authenticated;
GRANT ALL ON app.admin_user_action_logs TO service_role;

-- RPC : mise à jour du statut d'un compte utilisateur (suspension / réactivation)
CREATE OR REPLACE FUNCTION app_admin_update_user_status(
    p_target_user_id UUID,
    p_action TEXT,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_action TEXT := lower(trim(p_action));
  v_target_exists BOOLEAN;
  v_is_suspended BOOLEAN;
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

  IF v_action NOT IN ('suspend', 'reactivate') THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_action');
  END IF;

  SELECT EXISTS (SELECT 1 FROM auth.users WHERE id = p_target_user_id)
  INTO v_target_exists;

  IF NOT v_target_exists THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'user_not_found');
  END IF;

  IF v_action = 'suspend' THEN
    INSERT INTO app.user_admin_status (
      user_id, is_suspended, suspended_reason, suspended_at, reactivated_at, updated_at
    ) VALUES (
      p_target_user_id, TRUE, p_reason, NOW(), NULL, NOW()
    )
    ON CONFLICT (user_id)
    DO UPDATE SET
      is_suspended = TRUE,
      suspended_reason = COALESCE(EXCLUDED.suspended_reason, app.user_admin_status.suspended_reason),
      suspended_at = COALESCE(app.user_admin_status.suspended_at, NOW()),
      reactivated_at = NULL,
      updated_at = NOW();

    v_is_suspended := TRUE;
  ELSE
    INSERT INTO app.user_admin_status (
      user_id, is_suspended, suspended_reason, suspended_at, reactivated_at, updated_at
    ) VALUES (
      p_target_user_id, FALSE, NULL, NULL, NOW(), NOW()
    )
    ON CONFLICT (user_id)
    DO UPDATE SET
      is_suspended = FALSE,
      reactivated_at = NOW(),
      updated_at = NOW();

    v_is_suspended := FALSE;
  END IF;

  INSERT INTO app.admin_user_action_logs (
    performed_by,
    target_user,
    action,
    reason,
    meta
  ) VALUES (
    v_user_id,
    p_target_user_id,
    v_action,
    p_reason,
    JSONB_BUILD_OBJECT(
      'is_suspended', v_is_suspended,
      'performed_by', v_user_id,
      'target_user', p_target_user_id
    )
  );

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'user_id', p_target_user_id,
    'action', v_action,
    'is_suspended', v_is_suspended
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_update_user_status(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_update_user_status(UUID, TEXT, TEXT) TO service_role;

-- RPC : liste des actions admin pour un compte donné
CREATE OR REPLACE FUNCTION app_admin_list_user_action_logs(
    p_target_user_id UUID
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

  SELECT COALESCE(
    JSONB_AGG(
      JSONB_BUILD_OBJECT(
        'id', l.id,
        'performed_by', l.performed_by,
        'target_user', l.target_user,
        'action', l.action,
        'reason', l.reason,
        'created_at', l.created_at,
        'meta', l.meta
      )
      ORDER BY l.created_at DESC
    ),
    '[]'::JSONB
  ) INTO v_result
  FROM app.admin_user_action_logs l
  WHERE l.target_user = p_target_user_id;

  RETURN JSONB_BUILD_OBJECT('success', TRUE, 'logs', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_user_action_logs(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_user_action_logs(UUID) TO service_role;

CREATE OR REPLACE FUNCTION app_admin_delete_user_account(
    p_target_user_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_target_exists BOOLEAN;
  v_target_role TEXT;
  v_target_university_id UUID;
  v_other_admins_count INTEGER;
  v_is_deleted BOOLEAN := FALSE;
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

  IF p_target_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_target_user_id');
  END IF;

  IF p_target_user_id = v_user_id THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'cannot_delete_self');
  END IF;

  SELECT EXISTS (SELECT 1 FROM auth.users WHERE id = p_target_user_id)
  INTO v_target_exists;

  IF NOT v_target_exists THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'user_not_found');
  END IF;

  SELECT
    raw_user_meta_data->>'role',
    (raw_user_meta_data->>'university_id')::UUID
  INTO v_target_role, v_target_university_id
  FROM auth.users
  WHERE id = p_target_user_id;

  IF v_target_role = 'admin' THEN
    SELECT COUNT(*)
    INTO v_other_admins_count
    FROM auth.users u
    WHERE u.raw_user_meta_data->>'role' = 'admin'
      AND u.id <> p_target_user_id;

    IF v_other_admins_count = 0 THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'cannot_delete_last_admin');
    END IF;
  END IF;

  -- Si on supprime un compte université, désactiver aussi l'université associée
  -- afin que ses offres et sa fiche disparaissent des vues côté étudiant.
  IF v_target_role = 'university' AND v_target_university_id IS NOT NULL THEN
    PERFORM app_admin_update_university_status(
      v_target_university_id,
      FALSE,
      COALESCE(p_reason, 'university_account_deleted')
    );
  END IF;

  INSERT INTO app.user_admin_status (
    user_id,
    is_suspended,
    suspended_reason,
    suspended_at,
    reactivated_at,
    updated_at,
    is_deleted,
    deleted_reason,
    deleted_at
  ) VALUES (
    p_target_user_id,
    TRUE,
    COALESCE(p_reason, 'account_deleted'),
    NOW(),
    NULL,
    NOW(),
    TRUE,
    p_reason,
    NOW()
  )
  ON CONFLICT (user_id)
  DO UPDATE SET
    is_suspended = TRUE,
    suspended_reason = COALESCE(EXCLUDED.suspended_reason, app.user_admin_status.suspended_reason),
    suspended_at = COALESCE(app.user_admin_status.suspended_at, NOW()),
    reactivated_at = NULL,
    updated_at = NOW(),
    is_deleted = TRUE,
    deleted_reason = COALESCE(EXCLUDED.deleted_reason, app.user_admin_status.deleted_reason),
    deleted_at = COALESCE(app.user_admin_status.deleted_at, NOW());

  v_is_deleted := TRUE;

  INSERT INTO app.admin_user_action_logs (
    performed_by,
    target_user,
    action,
    reason,
    meta
  ) VALUES (
    v_user_id,
    p_target_user_id,
    'delete',
    p_reason,
    JSONB_BUILD_OBJECT(
      'is_deleted', v_is_deleted,
      'performed_by', v_user_id,
      'target_user', p_target_user_id
    )
  );

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'user_id', p_target_user_id,
    'action', 'delete',
    'is_deleted', v_is_deleted
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_delete_user_account(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_delete_user_account(UUID, TEXT) TO service_role;
