-- ============================================================================
-- Filet de secours des alertes administrateur (29/10/2026)
-- ============================================================================
-- Constat mesuré le 29/10 : du 10/09 au 29/10, le compte administrateur
-- n'avait AUCUN téléphone relié (l'appareil avait été repris par un compte
-- étudiant — « un appareil = une session »). Pendant sept semaines, les
-- alertes support, comptes, candidatures sont parties dans le vide, et rien
-- ne l'a signalé.
--
-- Deux gestes :
--   1. Copie par courriel des alertes `admin_*` (sauf `admin_audience`), par
--      `send-push-notifications` (courriel.ts) via Resend. Inerte tant que
--      les secrets RESEND_API_KEY et RESEND_FROM_EMAIL ne sont pas posés.
--   2. `app_admin_etat_alertes()` : la console affiche un bandeau quand aucun
--      téléphone ne reçoit les alertes de l'administrateur connecté.
--
-- VALEUR COUPLÉE : noms de tables et de colonnes lus par
-- `supabase/functions/send-push-notifications/courriel.ts`, et clés du jsonb
-- lues par `academia_app/lib/features/admin/admin_alertes_bandeau.dart`.
-- ============================================================================

CREATE TABLE IF NOT EXISTS app.alertes_courriel_destinataires (
    user_id    UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    courriel   TEXT NOT NULL CHECK (courriel ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
    actif      BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Une ligne par événement : sert d'anti-doublon (le cron et l'envoi immédiat
-- peuvent lire le même événement) ET de journal lisible.
CREATE TABLE IF NOT EXISTS app.alertes_courriel_envois (
    event_id   UUID PRIMARY KEY REFERENCES app.notification_events(id) ON DELETE CASCADE,
    user_id    UUID NOT NULL,
    courriel   TEXT NOT NULL,
    statut     TEXT NOT NULL DEFAULT 'en_cours' CHECK (statut IN ('en_cours', 'envoye', 'echec')),
    erreur     TEXT,
    resend_id  TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    envoye_at  TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS alertes_courriel_envois_user_idx
    ON app.alertes_courriel_envois (user_id, created_at DESC);

-- Service seulement : aucune politique RLS, aucun droit aux rôles clients.
ALTER TABLE app.alertes_courriel_destinataires ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.alertes_courriel_envois ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON app.alertes_courriel_destinataires FROM PUBLIC, anon, authenticated;
REVOKE ALL ON app.alertes_courriel_envois FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON app.alertes_courriel_destinataires TO service_role;
GRANT SELECT, INSERT, UPDATE ON app.alertes_courriel_envois TO service_role;

-- Le compte administrateur de Jocelyn, avec son adresse de connexion.
INSERT INTO app.alertes_courriel_destinataires (user_id, courriel)
SELECT u.id, u.email
  FROM auth.users u
 WHERE u.email = 'wendenkoote@gmail.com'
ON CONFLICT (user_id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.app_admin_etat_alertes()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'app', 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid UUID := auth.uid();
BEGIN
    IF NOT public.app_is_admin_user() THEN
        RAISE EXCEPTION 'admin_requis' USING ERRCODE = '42501';
    END IF;

    RETURN JSONB_BUILD_OBJECT(
        'telephones', (SELECT COUNT(*) FROM app.user_device_tokens
                        WHERE user_id = v_uid AND is_active AND platform <> 'web'),
        'navigateurs', (SELECT COUNT(*) FROM app.user_device_tokens
                         WHERE user_id = v_uid AND is_active AND platform = 'web'),
        'courriel', (SELECT courriel FROM app.alertes_courriel_destinataires
                      WHERE user_id = v_uid AND actif),
        'dernier_courriel', (SELECT JSONB_BUILD_OBJECT('statut', e.statut, 'erreur', e.erreur,
                                                       'le', e.created_at)
                               FROM app.alertes_courriel_envois e
                              WHERE e.user_id = v_uid
                              ORDER BY e.created_at DESC
                              LIMIT 1)
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.app_admin_etat_alertes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_admin_etat_alertes() TO authenticated;
