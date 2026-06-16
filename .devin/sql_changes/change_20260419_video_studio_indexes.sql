-- ============================================================================
-- Indexes manquants pour le système vidéo/studio
-- Détectés par audit Supabase du 19 avril 2026
-- ============================================================================

-- video_assets: lookup par owner_user_id (feed, mes vidéos)
CREATE INDEX IF NOT EXISTS idx_video_assets_owner_user_id 
  ON app.video_assets (owner_user_id);

-- video_assets: lookup par status (feed filtre ready)
CREATE INDEX IF NOT EXISTS idx_video_assets_status 
  ON app.video_assets (status);

-- video_assets: tri par date de création (feed ORDER BY)
CREATE INDEX IF NOT EXISTS idx_video_assets_created_at 
  ON app.video_assets (created_at DESC);

-- video_sources: lookup par video_asset_id (JOIN)
CREATE INDEX IF NOT EXISTS idx_video_sources_video_asset_id 
  ON app.video_sources (video_asset_id);

-- video_renditions: lookup par video_asset_id (JOIN principal du feed)
CREATE INDEX IF NOT EXISTS idx_video_renditions_video_asset_id 
  ON app.video_renditions (video_asset_id);

-- video_renditions: filtre par rendition_key (480p, legacy_primary, etc.)
CREATE INDEX IF NOT EXISTS idx_video_renditions_key 
  ON app.video_renditions (rendition_key);

-- free_videos: lookup par user_id (mes vidéos libres)
CREATE INDEX IF NOT EXISTS idx_free_videos_user_id 
  ON app.free_videos (user_id);

-- free_videos: lookup par video_asset_id (JOIN)
CREATE INDEX IF NOT EXISTS idx_free_videos_video_asset_id 
  ON app.free_videos (video_asset_id);

-- free_videos: feed public (is_active + moderation)
CREATE INDEX IF NOT EXISTS idx_free_videos_active_moderation 
  ON app.free_videos (is_active, moderation_status);

-- free_video_overlays: lookup par free_video_id (JOIN)
CREATE INDEX IF NOT EXISTS idx_free_video_overlays_fv_id 
  ON app.free_video_overlays (free_video_id);

-- challenge_participations: lookup par video_asset_id (JOIN)
CREATE INDEX IF NOT EXISTS idx_challenge_participations_video_asset_id 
  ON app.challenge_participations (video_asset_id);

-- challenge_participations: lookup par challenge_id
CREATE INDEX IF NOT EXISTS idx_challenge_participations_challenge_id 
  ON app.challenge_participations (challenge_id);
