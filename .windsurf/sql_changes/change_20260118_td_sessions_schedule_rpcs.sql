-- ========================================
-- ACADEMIA - MODULE TD
-- Exposer les horaires de séances TD dans app_td_get_program_detail
-- Date: 2026-01-18
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

CREATE OR REPLACE FUNCTION app_td_get_program_detail(
  p_program_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_role        TEXT;
  v_program     app.td_programs%ROWTYPE;
  v_collections JSONB;
BEGIN
  v_role := app.app_td_get_current_role();

  IF v_role = 'admin' THEN
    SELECT *
    INTO v_program
    FROM app.td_programs
    WHERE id = p_program_id;
  ELSE
    SELECT *
    INTO v_program
    FROM app.td_programs
    WHERE id = p_program_id
      AND status = 'published';
  END IF;

  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'program_not_found_or_not_visible');
  END IF;

  SELECT COALESCE(
           JSONB_AGG(
             JSONB_BUILD_OBJECT(
               'id', c.id,
               'title', c.title,
               'description', c.description,
               'position', c.position,
               'sessions', (
                 SELECT COALESCE(
                          JSONB_AGG(
                            JSONB_BUILD_OBJECT(
                              'id', s.id,
                              'title', s.title,
                              'is_preview', s.is_preview,
                              'position', s.position,
                              'scheduled_at', s.scheduled_at,
                              'duration_minutes', s.duration_minutes
                            )
                            ORDER BY s.position
                          ),
                          '[]'::JSONB
                        )
                 FROM app.td_sessions s
                 WHERE s.collection_id = c.id
               )
             )
             ORDER BY c.position
           ),
           '[]'::JSONB
         )
  INTO v_collections
  FROM app.td_collections c
  WHERE c.program_id = p_program_id;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'program', JSONB_BUILD_OBJECT(
      'id', v_program.id,
      'field_id', v_program.field_id,
      'level', v_program.level,
      'title', v_program.title,
      'description', v_program.description,
      'modality', v_program.modality,
      'price', v_program.price,
      'currency', v_program.currency,
      'status', v_program.status
    ),
    'collections', v_collections
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app_td_get_program_detail(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_td_get_program_detail(UUID) TO service_role;
