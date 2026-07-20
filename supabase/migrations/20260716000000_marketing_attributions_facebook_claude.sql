-- Attribution marketing (campagnes Facebook pilotées par Claude, multi-canal).
-- ADDITIF et ISOLÉ du système commercial (user_referrals / commissions) : aucune régression.
-- Capture la source d'acquisition d'un compte à partir d'un ref « canal-pilote-campagne-format-variante ».

CREATE TABLE IF NOT EXISTS app.marketing_attributions (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  channel      text,           -- fb, wa, ig, tiktok, yt, radio, direct...
  pilote       text,           -- claude, equipe, partenaire
  campaign     text,           -- ex. vac2026, session2
  format       text,           -- post, reel, story, carrousel, ad, bio, spot
  variant      text,           -- a / b (A/B testing)
  ref_code_raw text,           -- le ref complet reçu
  landed_at    timestamptz NOT NULL DEFAULT now(),
  created_at   timestamptz NOT NULL DEFAULT now(),
  metadata     jsonb NOT NULL DEFAULT '{}'::jsonb,
  CONSTRAINT marketing_attributions_user_unique UNIQUE (user_id)  -- first-touch
);

CREATE INDEX IF NOT EXISTS idx_mkt_attr_channel  ON app.marketing_attributions(channel);
CREATE INDEX IF NOT EXISTS idx_mkt_attr_pilote   ON app.marketing_attributions(pilote);
CREATE INDEX IF NOT EXISTS idx_mkt_attr_campaign ON app.marketing_attributions(campaign);

ALTER TABLE app.marketing_attributions ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='app' AND tablename='marketing_attributions' AND policyname='mkt_attr_insert_own') THEN
    CREATE POLICY mkt_attr_insert_own ON app.marketing_attributions
      FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='app' AND tablename='marketing_attributions' AND policyname='mkt_attr_select_own') THEN
    CREATE POLICY mkt_attr_select_own ON app.marketing_attributions
      FOR SELECT TO authenticated USING (user_id = auth.uid());
  END IF;
END $$;

-- RPC : enregistre l'attribution du compte courant à partir d'un ref marketing.
-- N'écrit QUE dans marketing_attributions. Ne touche jamais user_referrals ni les commissions.
CREATE OR REPLACE FUNCTION app.app_register_marketing_attribution(
  p_ref text,
  p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = app, public, pg_temp
AS $$
DECLARE
  v_user     uuid := auth.uid();
  v_ref      text := lower(trim(coalesce(p_ref, '')));
  v_channel  text; v_pilote text; v_campaign text; v_format text; v_variant text;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;
  IF v_ref = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'empty_ref');
  END IF;

  v_channel  := nullif(split_part(v_ref, '-', 1), '');
  v_pilote   := nullif(split_part(v_ref, '-', 2), '');
  v_campaign := nullif(split_part(v_ref, '-', 3), '');
  v_format   := nullif(split_part(v_ref, '-', 4), '');
  v_variant  := nullif(split_part(v_ref, '-', 5), '');

  INSERT INTO app.marketing_attributions
    (user_id, channel, pilote, campaign, format, variant, ref_code_raw, metadata)
  VALUES
    (v_user, v_channel, v_pilote, v_campaign, v_format, v_variant, v_ref, coalesce(p_metadata, '{}'::jsonb))
  ON CONFLICT (user_id) DO NOTHING;

  RETURN jsonb_build_object(
    'success', true,
    'channel', v_channel,
    'pilote', v_pilote,
    'campaign', v_campaign,
    'format', v_format,
    'variant', v_variant
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app.app_register_marketing_attribution(text, jsonb) TO authenticated;
