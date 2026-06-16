-- Fix surcharge de la RPC public.app_admin_upsert_opportunity
-- Objectif : ne garder qu'une seule version exposée à PostgREST (avec p_price)

-- 1) Supprimer l'ancienne version sans p_price
DROP FUNCTION IF EXISTS public.app_admin_upsert_opportunity(
    UUID,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    BOOLEAN,
    TEXT,
    INTEGER,
    DATE,
    DATE,
    TEXT,
    BOOLEAN,
    BOOLEAN
);

-- 2) S'assurer que la version avec p_price est bien exécutable par les rôles API
GRANT EXECUTE ON FUNCTION public.app_admin_upsert_opportunity(
    UUID,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    BOOLEAN,
    TEXT,
    INTEGER,
    DATE,
    DATE,
    TEXT,
    BOOLEAN,
    BOOLEAN,
    NUMERIC
) TO authenticated, service_role;
