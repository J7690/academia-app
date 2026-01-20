-- ========================================
-- Migration 2026-01-20 : Normalisation des liens commerciaux
-- Objectif :
--   * Abandonner totalement les domaines fictifs (academia.africa, academia.com, etc.)
--   * S'aligner sur l'URL publique actuelle de l'app (Netlify)
--   * Faire du ref_code la vérité métier, le lien complet étant dérivé dynamiquement.
--
-- Règle :
--   * La base publique de l'app est lue via le paramètre Postgres
--       app.app_public_base_url
--     avec un repli explicite sur l'URL Netlify de production :
--       https://dulcet-snickerdoodle-915a6b.netlify.app
--   * Ainsi, un futur changement de domaine pourra se faire en changeant
--     le paramètre, sans migration destructive.
-- ========================================

-- 1) Mettre à jour la fonction app_admin_set_commercial_commission_rate
--    pour utiliser le nouveau domaine comme base des ref_link.

CREATE OR REPLACE FUNCTION app_admin_set_commercial_commission_rate(
  p_user_id UUID,
  p_rate NUMERIC(5,2)
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_existing app.commercial_profiles%ROWTYPE;
  v_ref_code TEXT;
  v_base_url TEXT;
BEGIN
  -- Base publique de l'app : configurable via le paramètre Postgres
  --   app.app_public_base_url
  -- avec repli sur l'URL Netlify actuelle.
  v_base_url := COALESCE(
    current_setting('app.app_public_base_url', true),
    'https://dulcet-snickerdoodle-915a6b.netlify.app'
  );
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

  IF p_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_user_id');
  END IF;

  IF p_rate IS NULL OR p_rate < 0 THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_rate');
  END IF;

  SELECT *
  INTO v_existing
  FROM app.commercial_profiles
  WHERE user_id = p_user_id;

  IF NOT FOUND THEN
    -- Générer un ref_code simple basé sur un UUID tronqué
    v_ref_code := 'COMM-' || SUBSTR(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 8);

    INSERT INTO app.commercial_profiles (
      user_id,
      ref_code,
      ref_link,
      commission_rate,
      is_active,
      created_at,
      updated_at
    ) VALUES (
      p_user_id,
      v_ref_code,
      v_base_url || '/?ref=' || v_ref_code,
      p_rate,
      TRUE,
      NOW(),
      NOW()
    );
  ELSE
    -- Conserver le ref_code existant si présent, sinon en générer un nouveau
    IF v_existing.ref_code IS NULL OR TRIM(v_existing.ref_code) = '' THEN
      v_ref_code := 'COMM-' || SUBSTR(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 8);
    ELSE
      v_ref_code := v_existing.ref_code;
    END IF;

    UPDATE app.commercial_profiles
    SET
      ref_code = v_ref_code,
      ref_link = v_base_url || '/?ref=' || v_ref_code,
      commission_rate = p_rate,
      updated_at = NOW()
    WHERE user_id = p_user_id;
  END IF;

  RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_set_commercial_commission_rate(UUID, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_set_commercial_commission_rate(UUID, NUMERIC) TO service_role;

-- 2) Mettre à jour les ref_link existants pour qu'ils utilisent la base publique
--    actuelle de l'app (Netlify ou valeur de configuration Postgres).

UPDATE app.commercial_profiles
SET ref_link =
  COALESCE(
    current_setting('app.app_public_base_url', true),
    'https://dulcet-snickerdoodle-915a6b.netlify.app'
  ) || '/?ref=' || ref_code
WHERE ref_code IS NOT NULL
  AND TRIM(ref_code) <> '';
