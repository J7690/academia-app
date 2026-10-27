-- Essai de la fermeture de S1 (27/10/2026), en transaction ANNULÉE.
-- Étape « AVANT » : montre la faille sur les règles en place. Puis coller la
-- migration 20261027180000 à l'endroit « MIGRATION », et l'étape « APRÈS »
-- éprouve chaque rôle. Les écritures dans storage.objects ne touchent que la
-- table (aucun fichier réel), et sont défaites par l'exception finale.
DO $essai$
DECLARE
  c_student  uuid := '0fc48f26-1f57-4e6b-96f9-1690f111cad3';  -- student.review
  c_merchant uuid := '489bff02-d74f-460d-9adb-cc3215edc4c9';  -- marchand, propriétaire de l'annonce
  c_admin    uuid := '5f0584e1-e260-4635-aba9-ad3352f31a6a';  -- admin.review
  c_listing  uuid := 'cb2cda58-de55-4af9-a1fa-b468864d115d';
  v_obj uuid; r jsonb; v_res text; v_n int; v_log text := ''; v_fail int := 0;
BEGIN
  CREATE FUNCTION pg_temp.s1_as(p_uid uuid) RETURNS void LANGUAGE plpgsql AS $f$
  BEGIN
    IF p_uid IS NULL THEN
      PERFORM set_config('request.jwt.claims', '{"role":"anon"}', true);
      PERFORM set_config('request.jwt.claim.sub', '', true);
    ELSE
      PERFORM set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
      PERFORM set_config('request.jwt.claim.sub', p_uid::text, true);
    END IF;
  END $f$;
  -- Tente un dépôt ; rend 'ok' ou le code d'erreur.
  CREATE FUNCTION pg_temp.s1_ins(p_bucket text, p_name text) RETURNS text LANGUAGE plpgsql AS $f$
  BEGIN
    INSERT INTO storage.objects (bucket_id, name, owner, owner_id)
    VALUES (p_bucket, p_name, auth.uid(), auth.uid()::text);
    RETURN 'ok';
  EXCEPTION WHEN OTHERS THEN
    RETURN SQLSTATE;
  END $f$;
  -- Tente de remplacer / supprimer ; rend le nombre de lignes touchées.
  CREATE FUNCTION pg_temp.s1_upd(p_id uuid) RETURNS int LANGUAGE plpgsql AS $f$
  DECLARE n int;
  BEGIN
    UPDATE storage.objects SET metadata = '{"essai":true}'::jsonb WHERE id = p_id;
    GET DIAGNOSTICS n = ROW_COUNT; RETURN n;
  EXCEPTION WHEN OTHERS THEN RETURN -1;
  END $f$;
  CREATE FUNCTION pg_temp.s1_del(p_id uuid) RETURNS int LANGUAGE plpgsql AS $f$
  DECLARE n int;
  BEGIN
    DELETE FROM storage.objects WHERE id = p_id;
    GET DIAGNOSTICS n = ROW_COUNT; RETURN n;
  EXCEPTION WHEN OTHERS THEN RETURN -1;
  END $f$;
  CREATE FUNCTION pg_temp.s1_ok(p_cond boolean, p_label text, p_detail text DEFAULT NULL) RETURNS text LANGUAGE sql AS $f$
    SELECT CASE WHEN COALESCE(p_cond, false) THEN 'OK ' ELSE 'ECHEC ' END || p_label
           || CASE WHEN COALESCE(p_cond, false) OR p_detail IS NULL THEN '' ELSE ' :: ' || p_detail END || E'\n'
  $f$;

  -- La suppression directe en SQL est bloquée par Supabase sauf ce réglage.
  PERFORM set_config('storage.allow_delete_query', 'true', true);
  SELECT id INTO v_obj FROM storage.objects
  WHERE bucket_id = 'landing-media' AND name LIKE '040e7e6e-%' ORDER BY created_at LIMIT 1;

  -- ===== AVANT : la faille =====
  PERFORM pg_temp.s1_as(c_student);
  SET LOCAL ROLE authenticated;
  v_res := pg_temp.s1_ins('landing-media', c_student || '/essai/avant.png');
  v_log := v_log || 'AVANT etudiant depose dans landing-media : ' || v_res || E'\n';
  v_n := pg_temp.s1_upd(v_obj);
  v_log := v_log || 'AVANT etudiant remplace un fichier admin : ' || v_n || ' ligne(s)' || E'\n';
  RESET ROLE;

  -- ===== MIGRATION =====

  -- ===== APRÈS =====
  -- Étudiant
  PERFORM pg_temp.s1_as(c_student);
  SET LOCAL ROLE authenticated;
  v_res := pg_temp.s1_ins('landing-media', c_student || '/essai/apres.png');
  v_log := v_log || pg_temp.s1_ok(v_res = '42501', '1 etudiant ne depose plus dans landing-media', v_res);
  v_res := pg_temp.s1_ins('landing-media', c_student || '/landing/hero-video/piege.mp4');
  v_log := v_log || pg_temp.s1_ok(v_res = '42501', '1 etudiant ne remplace plus la video d''accueil', v_res);
  v_n := pg_temp.s1_upd(v_obj);
  v_log := v_log || pg_temp.s1_ok(v_n = 0, '1 etudiant ne remplace plus un fichier admin', v_n::text);
  v_n := pg_temp.s1_del(v_obj);
  v_log := v_log || pg_temp.s1_ok(v_n = 0, '1 etudiant ne supprime plus un fichier admin', v_n::text);
  v_res := pg_temp.s1_ins('marketplace-media', c_student || '/marketplace/x.png');
  v_log := v_log || pg_temp.s1_ok(v_res = '42501', '1 etudiant refuse dans marketplace-media', v_res);
  SELECT count(*) INTO v_n FROM storage.objects WHERE bucket_id = 'landing-media';
  v_log := v_log || pg_temp.s1_ok(v_n > 0, '1 lecture landing-media conservee', v_n::text);
  RESET ROLE;

  -- Anonyme
  PERFORM pg_temp.s1_as(NULL);
  SET LOCAL ROLE anon;
  v_res := pg_temp.s1_ins('landing-media', 'anon/x.png');
  v_log := v_log || pg_temp.s1_ok(v_res = '42501', '2 anonyme refuse', v_res);
  RESET ROLE;

  -- Marchand
  PERFORM pg_temp.s1_as(c_merchant);
  SET LOCAL ROLE authenticated;
  v_res := pg_temp.s1_ins('marketplace-media', c_merchant || '/marketplace/' || c_listing || '/essai.png');
  v_log := v_log || pg_temp.s1_ok(v_res = 'ok', '3 marchand depose dans son dossier', v_res);
  v_res := pg_temp.s1_ins('marketplace-media', c_student || '/marketplace/usurpe.png');
  v_log := v_log || pg_temp.s1_ok(v_res = '42501', '3 marchand refuse dans le dossier d''un autre', v_res);
  v_res := pg_temp.s1_ins('landing-media', c_merchant || '/marketplace/x.png');
  v_log := v_log || pg_temp.s1_ok(v_res = '42501', '3 marchand refuse dans landing-media', v_res);
  RESET ROLE;
  r := public.app_merchant_add_marketplace_listing_media(c_listing,
         c_merchant || '/marketplace/' || c_listing || '/essai.png', 0, 'image', NULL, NULL, NULL, 'marketplace-media');
  SELECT storage_bucket INTO v_res FROM app.marketplace_listing_media WHERE id = (r->>'media_id')::uuid;
  v_log := v_log || pg_temp.s1_ok(v_res = 'marketplace-media', '3 media enregistre avec le bon dossier', r::text);
  r := public.app_merchant_add_marketplace_listing_media(c_listing, c_student || '/vol.png', 0, 'image', NULL, NULL, NULL, 'marketplace-media');
  v_log := v_log || pg_temp.s1_ok(r->>'error' = 'invalid_storage_path', '3 chemin d''un autre refuse', r::text);
  r := public.app_merchant_add_marketplace_listing_media(c_listing, c_merchant || '/ancien.png');
  SELECT storage_bucket INTO v_res FROM app.marketplace_listing_media WHERE id = (r->>'media_id')::uuid;
  v_log := v_log || pg_temp.s1_ok(v_res = 'landing-media', '3 ancien appel (app installee) accepte', r::text);

  -- Admin
  PERFORM pg_temp.s1_as(c_admin);
  SET LOCAL ROLE authenticated;
  v_res := pg_temp.s1_ins('landing-media', c_admin || '/landing/essai.png');
  v_log := v_log || pg_temp.s1_ok(v_res = 'ok', '4 admin depose dans landing-media', v_res);
  v_n := pg_temp.s1_upd(v_obj);
  v_log := v_log || pg_temp.s1_ok(v_n = 1, '4 admin remplace un fichier', v_n::text);
  v_res := pg_temp.s1_ins('marketplace-media', c_admin || '/admin/marketplace/x.png');
  v_log := v_log || pg_temp.s1_ok(v_res = 'ok', '4 admin depose dans marketplace-media', v_res);
  SELECT id INTO v_obj FROM storage.objects WHERE bucket_id = 'marketplace-media' AND name LIKE c_merchant || '/%' LIMIT 1;
  v_n := pg_temp.s1_del(v_obj);
  v_log := v_log || pg_temp.s1_ok(v_n = 1, '4 admin supprime le fichier d''un marchand (moderation)', v_n::text);
  RESET ROLE;
  r := public.app_admin_add_marketplace_listing_media(c_listing, c_admin || '/admin/marketplace/x.png', 0, 'image', NULL, NULL, NULL, 'marketplace-media');
  v_log := v_log || pg_temp.s1_ok((r->>'success')::boolean, '4 admin enregistre un media', r::text);

  v_fail := (length(v_log) - length(replace(v_log, 'ECHEC', ''))) / 5;
  RAISE EXCEPTION 'ESSAI-S1 echecs=% %', v_fail, E'\n' || v_log;
END
$essai$;
