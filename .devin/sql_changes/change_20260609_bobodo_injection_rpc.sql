-- ============================================================================
-- RPC pour injection Bobodo Knowledge (contourne RLS)
-- ============================================================================
CREATE OR REPLACE FUNCTION app_bobodo_inject_knowledge(
    p_title TEXT,
    p_content TEXT,
    p_category TEXT,
    p_tags TEXT[] DEFAULT NULL,
    p_language TEXT DEFAULT 'fr',
    p_is_active BOOLEAN DEFAULT true
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    INSERT INTO app.bobodo_knowledge (title, content, category, tags, language, is_active)
    VALUES (p_title, p_content, p_category, p_tags, p_language, p_is_active)
    RETURNING id INTO v_result;
    
    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'id', v_result);
EXCEPTION
    WHEN OTHERS THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION app_bobodo_inject_knowledge TO authenticated;
GRANT EXECUTE ON FUNCTION app_bobodo_inject_knowledge TO service_role;
