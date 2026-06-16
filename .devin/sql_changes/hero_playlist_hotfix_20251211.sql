-- Hotfix 2025-12-11 pour app.hero_playlist
-- 1) Désactiver l'item vidéo incohérent (actif sans base_video_url)
-- 2) Activer un item vidéo cohérent pour student_home_hero_main

UPDATE app.hero_playlist
SET is_active = FALSE,
    updated_at = NOW()
WHERE id = 'd92386b1-8da3-4c98-bf36-fb779903bc7a';

UPDATE app.hero_playlist
SET is_active = TRUE,
    updated_at = NOW()
WHERE id = '396617ec-aec4-433c-8a95-7d3c003a992e';
