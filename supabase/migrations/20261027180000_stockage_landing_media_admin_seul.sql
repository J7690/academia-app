-- Faille S1 (relevée le 05/10, mesurée encore ouverte le 27/10) : FERMÉE.
--
-- Avant : quatre règles (`landing_media_write`, `authenticated_insert_…`,
-- `authenticated_update_…`, `authenticated_delete_…`) laissaient TOUT compte
-- connecté écrire, remplacer et supprimer n'importe quel fichier de
-- `landing-media` : images de la page publique, médias des annonces, contenus
-- de l'accueil étudiant, bibliothèque de cours. Pire, le déclencheur
-- `on_landing_media_object_insert` fait de toute vidéo déposée sous
-- `…/landing/hero-video/` la vidéo d'accueil du site : un étudiant pouvait
-- remplacer la vidéo de la page publique.
--
-- Après :
--   * `landing-media` : lecture publique inchangée ; écriture, remplacement et
--     suppression réservés aux administrateurs (`public.is_admin()`, qui lit
--     `raw_app_meta_data`). Le serveur (clé de service, Hero Studio) n'est pas
--     concerné : il contourne les règles.
--   * `marketplace-media` (n'avait AUCUNE règle) : lecture publique ; un
--     marchand écrit seulement sous son dossier `<id utilisateur>/…` ; un
--     administrateur écrit sous le sien et peut supprimer ou remplacer tout
--     fichier (modération).
--   * Les fonctions d'ajout de média d'annonce enregistrent désormais le
--     dossier réel (`p_storage_bucket`) au lieu de `'landing-media'` en dur.
--     Défaut `'landing-media'` pour les versions déjà installées de l'app.
--
-- Les fichiers existants ne bougent pas : 89 objets dans `landing-media`
-- (77 admin, 10 rendus Hero Studio, 2 marchand), toujours lisibles.

-- ─── 1. landing-media : écriture admin seulement ───────────────────────────

DROP POLICY IF EXISTS landing_media_write ON storage.objects;
DROP POLICY IF EXISTS authenticated_insert_landing_media ON storage.objects;
DROP POLICY IF EXISTS authenticated_update_landing_media ON storage.objects;
DROP POLICY IF EXISTS authenticated_delete_landing_media ON storage.objects;

DROP POLICY IF EXISTS landing_media_admin_insert ON storage.objects;
CREATE POLICY landing_media_admin_insert ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'landing-media' AND public.is_admin());

DROP POLICY IF EXISTS landing_media_admin_update ON storage.objects;
CREATE POLICY landing_media_admin_update ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'landing-media' AND public.is_admin())
  WITH CHECK (bucket_id = 'landing-media' AND public.is_admin());

DROP POLICY IF EXISTS landing_media_admin_delete ON storage.objects;
CREATE POLICY landing_media_admin_delete ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'landing-media' AND public.is_admin());

-- ─── 2. marketplace-media : chaque marchand dans son dossier ───────────────

DROP POLICY IF EXISTS marketplace_media_select ON storage.objects;
CREATE POLICY marketplace_media_select ON storage.objects
  FOR SELECT TO anon, authenticated
  USING (bucket_id = 'marketplace-media');

DROP POLICY IF EXISTS marketplace_media_insert ON storage.objects;
CREATE POLICY marketplace_media_insert ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'marketplace-media'
    AND (storage.foldername(name))[1] = auth.uid()::text
    AND public.current_user_role() IN ('merchant', 'admin', 'super_admin')
  );

DROP POLICY IF EXISTS marketplace_media_update ON storage.objects;
CREATE POLICY marketplace_media_update ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'marketplace-media'
    AND (public.is_admin()
         OR ((storage.foldername(name))[1] = auth.uid()::text
             AND public.current_user_role() = 'merchant'))
  )
  WITH CHECK (
    bucket_id = 'marketplace-media'
    AND (public.is_admin()
         OR ((storage.foldername(name))[1] = auth.uid()::text
             AND public.current_user_role() = 'merchant'))
  );

DROP POLICY IF EXISTS marketplace_media_delete ON storage.objects;
CREATE POLICY marketplace_media_delete ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'marketplace-media'
    AND (public.is_admin()
         OR ((storage.foldername(name))[1] = auth.uid()::text
             AND public.current_user_role() = 'merchant'))
  );

-- ─── 3. Les fonctions d'ajout de média enregistrent le vrai dossier ────────
-- DROP puis CREATE : ajouter un paramètre avec CREATE OR REPLACE créerait une
-- seconde fonction, et PostgREST refuserait l'appel comme ambigu.

DROP FUNCTION IF EXISTS public.app_merchant_add_marketplace_listing_media(uuid, text, integer, text, text, text, text);
CREATE FUNCTION public.app_merchant_add_marketplace_listing_media(
  p_listing_id     uuid,
  p_storage_path   text,
  p_sort_order     integer DEFAULT 0,
  p_media_type     text    DEFAULT 'image'::text,
  p_external_url   text    DEFAULT NULL::text,
  p_title          text    DEFAULT NULL::text,
  p_description    text    DEFAULT NULL::text,
  p_storage_bucket text    DEFAULT 'landing-media'::text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $function$
DECLARE
  v_user     uuid := auth.uid();
  v_bucket   text := COALESCE(NULLIF(trim(p_storage_bucket), ''), 'landing-media');
  v_path     text := NULLIF(trim(p_storage_path), '');
  v_media_id uuid;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;
  IF p_listing_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_listing_id');
  END IF;
  IF v_bucket NOT IN ('landing-media', 'marketplace-media') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_bucket');
  END IF;
  -- Dans le dossier marchand, le chemin doit être celui du marchand : on
  -- n'accroche pas à son annonce le fichier d'un autre.
  IF v_bucket = 'marketplace-media' AND v_path IS NOT NULL
     AND split_part(v_path, '/', 1) <> v_user::text THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_storage_path');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM app.marketplace_listings l
    WHERE l.id = p_listing_id AND l.merchant_id = v_user
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_owner');
  END IF;

  INSERT INTO app.marketplace_listing_media(
    listing_id, media_type, title, description, storage_bucket, storage_path,
    external_url, sort_order, is_active, updated_at
  ) VALUES (
    p_listing_id, COALESCE(NULLIF(trim(p_media_type), ''), 'image'), p_title, p_description,
    v_bucket, v_path, NULLIF(trim(p_external_url), ''), COALESCE(p_sort_order, 0), true, now()
  )
  RETURNING id INTO v_media_id;

  RETURN jsonb_build_object('success', true, 'media_id', v_media_id);
END;
$function$;

REVOKE ALL ON FUNCTION public.app_merchant_add_marketplace_listing_media(uuid, text, integer, text, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_merchant_add_marketplace_listing_media(uuid, text, integer, text, text, text, text, text) TO authenticated;

DROP FUNCTION IF EXISTS public.app_admin_add_marketplace_listing_media(uuid, text, integer, text, text, text, text);
CREATE FUNCTION public.app_admin_add_marketplace_listing_media(
  p_listing_id     uuid,
  p_storage_path   text,
  p_sort_order     integer DEFAULT 0,
  p_media_type     text    DEFAULT 'image'::text,
  p_external_url   text    DEFAULT NULL::text,
  p_title          text    DEFAULT NULL::text,
  p_description    text    DEFAULT NULL::text,
  p_storage_bucket text    DEFAULT 'landing-media'::text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $function$
DECLARE
  v_user     uuid := auth.uid();
  v_bucket   text := COALESCE(NULLIF(trim(p_storage_bucket), ''), 'landing-media');
  v_media_id uuid;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;
  IF public.app_get_current_role() <> 'admin' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_admin');
  END IF;
  IF p_listing_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_listing_id');
  END IF;
  IF v_bucket NOT IN ('landing-media', 'marketplace-media') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_bucket');
  END IF;

  INSERT INTO app.marketplace_listing_media(
    listing_id, media_type, title, description, storage_bucket, storage_path,
    external_url, sort_order, is_active, updated_at
  ) VALUES (
    p_listing_id, COALESCE(NULLIF(trim(p_media_type), ''), 'image'), p_title, p_description,
    v_bucket, NULLIF(trim(p_storage_path), ''), NULLIF(trim(p_external_url), ''),
    COALESCE(p_sort_order, 0), true, now()
  )
  RETURNING id INTO v_media_id;

  RETURN jsonb_build_object('success', true, 'media_id', v_media_id);
END;
$function$;

REVOKE ALL ON FUNCTION public.app_admin_add_marketplace_listing_media(uuid, text, integer, text, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_admin_add_marketplace_listing_media(uuid, text, integer, text, text, text, text, text) TO authenticated;
