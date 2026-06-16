-- ============================================================================
-- PHASE 7 — pg_cron jobs : expiration abonnements + payouts automatiques
-- 19 Mars 2026
-- ============================================================================

-- 1. Expiration automatique des abonnements expirés (quotidien 2h du matin)
SELECT cron.schedule(
  'expire_subscriptions',
  '0 2 * * *',
  $$UPDATE app.subscriptions SET status = 'expired', updated_at = NOW() WHERE status = 'active' AND expires_at IS NOT NULL AND expires_at < NOW()$$
);

-- 2. Nettoyage des paiements en status 'processing' depuis plus de 2h (reset vers pending)
SELECT cron.schedule(
  'reset_stale_processing_payments',
  '30 * * * *',
  $$UPDATE app.application_payments SET status = 'pending', updated_at = NOW() WHERE status = 'processing' AND updated_at < NOW() - INTERVAL '2 hours'$$
);
