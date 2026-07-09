-- Script pour vérifier la structure de la table whiteboard_renders
-- Phase C.3 – Renderer Core Implementation

SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'app' 
AND table_name = 'whiteboard_renders'
ORDER BY ordinal_position;
