-- ============================================================
-- Fondation multi-acteurs pour le référencement / commissions
-- Additif uniquement : n'altère aucun comportement existant.
-- Appliqué en prod le 2026-07-14 (version 20260714000106).
-- ============================================================

ALTER TABLE app.commission_share_config
  ADD COLUMN IF NOT EXISTS creator_percentage numeric(5,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS promoter_window_days integer NOT NULL DEFAULT 30;

ALTER TABLE app.share_tracking
  ADD COLUMN IF NOT EXISTS content_asset_id uuid,
  ADD COLUMN IF NOT EXISTS creator_commercial_id uuid;

ALTER TABLE app.referral_commissions
  ADD COLUMN IF NOT EXISTS beneficiary_role text,
  ADD COLUMN IF NOT EXISTS creator_commercial_id uuid,
  ADD COLUMN IF NOT EXISTS creator_commission_amount numeric(12,2) DEFAULT 0;

UPDATE app.referral_commissions SET beneficiary_role = 'owner' WHERE beneficiary_role IS NULL;

CREATE TABLE IF NOT EXISTS app.content_assets (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  creator_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title         text NOT NULL,
  asset_type    text NOT NULL DEFAULT 'video',
  storage_path  text,
  external_url  text,
  thumbnail_url text,
  description   text,
  is_active     boolean NOT NULL DEFAULT true,
  approved_by   uuid REFERENCES auth.users(id),
  approved_at   timestamptz,
  metadata      jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'share_tracking_content_asset_id_fkey') THEN
    ALTER TABLE app.share_tracking
      ADD CONSTRAINT share_tracking_content_asset_id_fkey
      FOREIGN KEY (content_asset_id) REFERENCES app.content_assets(id) ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'share_tracking_creator_commercial_id_fkey') THEN
    ALTER TABLE app.share_tracking
      ADD CONSTRAINT share_tracking_creator_commercial_id_fkey
      FOREIGN KEY (creator_commercial_id) REFERENCES auth.users(id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'referral_commissions_creator_commercial_id_fkey') THEN
    ALTER TABLE app.referral_commissions
      ADD CONSTRAINT referral_commissions_creator_commercial_id_fkey
      FOREIGN KEY (creator_commercial_id) REFERENCES auth.users(id);
  END IF;
END$$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_referral_commissions_payment_beneficiary_role
  ON app.referral_commissions (payment_id, commercial_user_id, beneficiary_role);

CREATE INDEX IF NOT EXISTS idx_content_assets_creator ON app.content_assets (creator_user_id);
CREATE INDEX IF NOT EXISTS idx_content_assets_active ON app.content_assets (is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_share_tracking_content_asset ON app.share_tracking (content_asset_id);
CREATE INDEX IF NOT EXISTS idx_referral_commissions_beneficiary_role ON app.referral_commissions (beneficiary_role);

ALTER TABLE app.content_assets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS content_assets_admin_all ON app.content_assets;
CREATE POLICY content_assets_admin_all ON app.content_assets
  FOR ALL USING (
    (SELECT raw_user_meta_data->>'role' FROM auth.users WHERE id = auth.uid()) IN ('admin','super_admin')
  );

DROP POLICY IF EXISTS content_assets_creator_own ON app.content_assets;
CREATE POLICY content_assets_creator_own ON app.content_assets
  FOR ALL USING (creator_user_id = auth.uid());

DROP POLICY IF EXISTS content_assets_commercial_browse ON app.content_assets;
CREATE POLICY content_assets_commercial_browse ON app.content_assets
  FOR SELECT USING (
    is_active = true
    AND approved_at IS NOT NULL
    AND (SELECT raw_user_meta_data->>'role' FROM auth.users WHERE id = auth.uid()) IN ('commercial','content_creator','admin','super_admin')
  );
