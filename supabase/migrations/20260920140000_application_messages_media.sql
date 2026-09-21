-- Phase 3 : PREPAREE LOCALEMENT, accord requis avant application en production.
-- Migration additive : les RPC texte à deux arguments restent disponibles.
-- Les nouvelles surcharges à cinq arguments sont SANS valeurs par défaut.
-- Aucun abonnement Realtime ni publication ajouté.
-- Exécuter atomiquement (fichier complet dans une seule invocation admin_execute_sql).
-- Ne pas ajouter BEGIN/COMMIT dans cette RPC.
-- Définitions de production du 20/09/2026 conservées ci-dessous pour audit.
/*
CREATE OR REPLACE FUNCTION public.app_add_application_message_from_student(p_application_id uuid, p_content text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_app_student_id UUID;
    v_message_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    IF p_content IS NULL OR LENGTH(TRIM(p_content)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'empty_content');
    END IF;

    SELECT student_id INTO v_app_student_id
    FROM app.applications
    WHERE id = p_application_id;

    IF v_app_student_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    IF v_app_student_id <> v_user_id THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_owner');
    END IF;

    INSERT INTO app.application_messages (application_id, sender_role, audience, content)
    VALUES (p_application_id, 'student', 'admin_only', p_content)
    RETURNING id INTO v_message_id;

    UPDATE app.applications
    SET
        last_message_at = NOW(),
        updated_at = NOW()
    WHERE id = p_application_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'message_id', v_message_id
    );
END;
$function$


CREATE OR REPLACE FUNCTION public.app_mark_application_messages_read_for_student(p_application_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_owner_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT student_id INTO v_owner_id
    FROM app.applications
    WHERE id = p_application_id;

    IF v_owner_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    IF v_owner_id <> v_user_id THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_owner');
    END IF;

    UPDATE app.applications
    SET last_student_read_at = NOW()
    WHERE id = p_application_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$function$


CREATE OR REPLACE FUNCTION public.app_list_application_messages_for_university(p_application_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_university_id UUID;
    v_exists BOOLEAN;
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT
        raw_user_meta_data->>'role',
        (raw_user_meta_data->>'university_id')::UUID
    INTO v_role, v_university_id
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'university' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_university');
    END IF;

    IF v_university_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'university_not_configured');
    END IF;

    SELECT EXISTS(
        SELECT 1
        FROM app.applications a
        JOIN app.programs p ON p.id = a.program_id
        WHERE a.id = p_application_id
          AND p.university_id = v_university_id
    ) INTO v_exists;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', m.id,
                'application_id', m.application_id,
                'sender_role', m.sender_role,
                'audience', m.audience,
                'content', m.content,
                'created_at', m.created_at
            )
            ORDER BY m.created_at ASC
        ),
        '[]'::JSONB
    )
    INTO v_result
    FROM app.application_messages m
    JOIN app.applications a ON a.id = m.application_id
    JOIN app.programs p ON p.id = a.program_id
    WHERE m.application_id = p_application_id
      AND p.university_id = v_university_id
      AND (m.audience = 'university' OR m.sender_role = 'university');

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'messages', v_result
    );
END;
$function$


CREATE OR REPLACE FUNCTION public.app_list_application_messages_for_student(p_application_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN '[]'::JSONB;
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', m.id,
                'application_id', m.application_id,
                'sender_role', m.sender_role,
                'audience', m.audience,
                'content', m.content,
                'created_at', m.created_at
            )
            ORDER BY m.created_at ASC
        ),
        '[]'::JSONB
    )
    INTO v_result
    FROM app.application_messages m
    JOIN app.applications a ON a.id = m.application_id
    WHERE m.application_id = p_application_id
      AND a.student_id = v_user_id
      AND (m.sender_role = 'student' OR m.audience = 'student');

    RETURN v_result;
END;
$function$


CREATE OR REPLACE FUNCTION public.app_list_application_messages_for_admin(p_application_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_exists BOOLEAN;
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'admin' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
    END IF;

    SELECT EXISTS(SELECT 1 FROM app.applications a WHERE a.id = p_application_id)
    INTO v_exists;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', m.id,
                'application_id', m.application_id,
                'sender_role', m.sender_role,
                'audience', m.audience,
                'content', m.content,
                'created_at', m.created_at
            )
            ORDER BY m.created_at ASC
        ),
        '[]'::JSONB
    )
    INTO v_result
    FROM app.application_messages m
    WHERE m.application_id = p_application_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'messages', v_result
    );
END;
$function$


CREATE OR REPLACE FUNCTION public.app_add_application_message_from_admin_to_student(p_application_id uuid, p_content text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_exists BOOLEAN;
    v_message_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'admin' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
    END IF;

    IF p_content IS NULL OR LENGTH(TRIM(p_content)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'empty_content');
    END IF;

    SELECT EXISTS(SELECT 1 FROM app.applications a WHERE a.id = p_application_id)
    INTO v_exists;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    INSERT INTO app.application_messages (application_id, sender_role, audience, content)
    VALUES (p_application_id, 'admin', 'student', p_content)
    RETURNING id INTO v_message_id;

    UPDATE app.applications
    SET
        last_message_at = NOW(),
        updated_at = NOW()
    WHERE id = p_application_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'message_id', v_message_id
    );
END;
$function$


CREATE OR REPLACE FUNCTION public.app_add_application_message_from_admin_to_university(p_application_id uuid, p_content text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_exists BOOLEAN;
    v_message_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'admin' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
    END IF;

    IF p_content IS NULL OR LENGTH(TRIM(p_content)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'empty_content');
    END IF;

    SELECT EXISTS(SELECT 1 FROM app.applications a WHERE a.id = p_application_id)
    INTO v_exists;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    INSERT INTO app.application_messages (application_id, sender_role, audience, content)
    VALUES (p_application_id, 'admin', 'university', p_content)
    RETURNING id INTO v_message_id;

    UPDATE app.applications
    SET
        last_message_at = NOW(),
        updated_at = NOW()
    WHERE id = p_application_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'message_id', v_message_id
    );
END;
$function$


CREATE OR REPLACE FUNCTION public.app_mark_application_messages_read_for_admin(p_application_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_exists BOOLEAN;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_user_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'admin' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
    END IF;

    SELECT EXISTS(SELECT 1 FROM app.applications a WHERE a.id = p_application_id)
    INTO v_exists;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    UPDATE app.applications
    SET last_admin_read_at = NOW()
    WHERE id = p_application_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$function$


CREATE OR REPLACE FUNCTION public.app_add_application_message_from_university(p_application_id uuid, p_content text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_university_id UUID;
    v_exists BOOLEAN;
    v_message_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT
        raw_user_meta_data->>'role',
        (raw_user_meta_data->>'university_id')::UUID
    INTO v_role, v_university_id
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'university' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_university');
    END IF;

    IF v_university_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'university_not_configured');
    END IF;

    IF p_content IS NULL OR LENGTH(TRIM(p_content)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'empty_content');
    END IF;

    SELECT EXISTS(
        SELECT 1
        FROM app.applications a
        JOIN app.programs p ON p.id = a.program_id
        WHERE a.id = p_application_id
          AND p.university_id = v_university_id
    ) INTO v_exists;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    INSERT INTO app.application_messages (application_id, sender_role, audience, content)
    VALUES (p_application_id, 'university', 'admin_only', p_content)
    RETURNING id INTO v_message_id;

    UPDATE app.applications
    SET
        last_message_at = NOW(),
        updated_at = NOW()
    WHERE id = p_application_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'message_id', v_message_id
    );
END;
$function$


CREATE OR REPLACE FUNCTION public.app_mark_application_messages_read_for_university(p_application_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_university_id UUID;
    v_exists BOOLEAN;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT
        raw_user_meta_data->>'role',
        (raw_user_meta_data->>'university_id')::UUID
    INTO v_role, v_university_id
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role <> 'university' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_university');
    END IF;

    IF v_university_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'university_not_configured');
    END IF;

    SELECT EXISTS(
        SELECT 1
        FROM app.applications a
        JOIN app.programs p ON p.id = a.program_id
        WHERE a.id = p_application_id
          AND p.university_id = v_university_id
    ) INTO v_exists;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    UPDATE app.applications
    SET last_university_read_at = NOW()
    WHERE id = p_application_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$function$

*/

ALTER TABLE app.application_messages
  ADD COLUMN type TEXT NOT NULL DEFAULT 'text',
  ADD COLUMN media_url TEXT,
  ADD COLUMN media_mime TEXT,
  ADD COLUMN read_at TIMESTAMPTZ;

ALTER TABLE app.application_messages ADD CONSTRAINT application_messages_media_shape CHECK (
  (type = 'text' AND media_url IS NULL AND media_mime IS NULL)
  OR (type IN ('image', 'audio', 'video') AND media_url IS NOT NULL AND media_mime IS NOT NULL)
);
CREATE UNIQUE INDEX application_messages_media_unique
  ON app.application_messages(media_url) WHERE media_url IS NOT NULL;

-- Rôles et rattachement université tirés des métadonnées serveur protégées.
CREATE FUNCTION app.application_message_channel_allowed(p_application_id UUID, p_channel TEXT)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM app.applications a
    JOIN app.programs p ON p.id = a.program_id
    JOIN auth.users u ON u.id = auth.uid()
    WHERE a.id = p_application_id AND p_channel IN ('student', 'university')
      AND (
        u.raw_app_meta_data->>'role' IN ('admin', 'super_admin')
        OR (p_channel = 'student' AND a.student_id = u.id)
        OR (p_channel = 'university' AND a.sent_to_university IS TRUE
          AND u.raw_app_meta_data->>'role' = 'university'
          AND u.raw_app_meta_data->>'university_id' = p.university_id::TEXT)
      )
  );
$$;
REVOKE ALL ON FUNCTION app.application_message_channel_allowed(UUID,TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION app.application_message_channel_allowed(UUID,TEXT) TO authenticated;

-- Chemin : candidature/canal/propriétaire/nom-unique.ext (jamais une URL publique).
CREATE FUNCTION app.application_media_access(p_name TEXT, p_operation TEXT)
RETURNS BOOLEAN LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_parts TEXT[] := string_to_array(p_name, '/');
  v_app UUID;
  v_own BOOLEAN;
  v_linked BOOLEAN;
BEGIN
  IF auth.uid() IS NULL OR cardinality(v_parts) <> 4
    OR v_parts[4] !~ '^[a-zA-Z0-9_-]+\.(jpg|jpeg|png|webp|mp4|mov|webm|m4a|mp3|wav|ogg)$'
    THEN RETURN FALSE; END IF;
  v_app := v_parts[1]::UUID;
  v_own := v_parts[3] = auth.uid()::TEXT;
  IF NOT app.application_message_channel_allowed(v_app, v_parts[2]) THEN RETURN FALSE; END IF;
  SELECT EXISTS (SELECT 1 FROM app.application_messages m WHERE m.media_url = p_name
    AND m.application_id = v_app
    AND CASE WHEN m.sender_role = 'university' OR m.audience = 'university'
      THEN 'university' ELSE 'student' END = v_parts[2]) INTO v_linked;
  RETURN CASE p_operation
    WHEN 'read' THEN v_own OR v_linked
    WHEN 'insert' THEN v_own AND NOT v_linked
    WHEN 'delete' THEN v_own AND NOT v_linked
    ELSE FALSE END;
EXCEPTION WHEN invalid_text_representation THEN RETURN FALSE;
END;
$$;
REVOKE ALL ON FUNCTION app.application_media_access(TEXT,TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION app.application_media_access(TEXT,TEXT) TO authenticated;

INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
VALUES ('application-media','application-media',FALSE,26214400,
  ARRAY['image/jpeg','image/png','image/webp','audio/mp4','audio/mpeg','audio/wav',
        'audio/ogg','audio/webm','video/mp4','video/quicktime','video/webm']);

CREATE POLICY application_media_read ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'application-media' AND app.application_media_access(name,'read'));
CREATE POLICY application_media_insert ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'application-media' AND app.application_media_access(name,'insert'));
CREATE POLICY application_media_delete_pending ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'application-media' AND app.application_media_access(name,'delete'));
-- Garde-fous même si une future policy permissive est trop large.
CREATE POLICY application_media_read_guard ON storage.objects AS RESTRICTIVE FOR SELECT TO public
  USING (bucket_id <> 'application-media' OR app.application_media_access(name,'read'));
CREATE POLICY application_media_insert_guard ON storage.objects AS RESTRICTIVE FOR INSERT TO public
  WITH CHECK (bucket_id <> 'application-media' OR app.application_media_access(name,'insert'));
CREATE POLICY application_media_delete_guard ON storage.objects AS RESTRICTIVE FOR DELETE TO public
  USING (bucket_id <> 'application-media' OR app.application_media_access(name,'delete'));
CREATE POLICY application_media_no_replace ON storage.objects AS RESTRICTIVE FOR UPDATE TO public
  USING (bucket_id <> 'application-media') WITH CHECK (bucket_id <> 'application-media');
-- Les policies public ci-dessus doivent pouvoir refuser les appels anonymes.
GRANT EXECUTE ON FUNCTION app.application_media_access(TEXT,TEXT) TO anon;

ALTER TABLE app.application_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY application_messages_channel_guard ON app.application_messages
  AS RESTRICTIVE FOR SELECT TO public USING (
    app.application_message_channel_allowed(application_id,
      CASE WHEN sender_role = 'university' OR audience = 'university' THEN 'university'
        WHEN sender_role = 'student' OR audience = 'student' THEN 'student' END)
  );
GRANT EXECUTE ON FUNCTION app.application_message_channel_allowed(UUID,TEXT) TO anon;
-- Les écritures passent exclusivement par les RPC SECURITY DEFINER contrôlées.
CREATE POLICY application_messages_rpc_insert_only ON app.application_messages
  AS RESTRICTIVE FOR INSERT TO public WITH CHECK (FALSE);
CREATE POLICY application_messages_rpc_update_only ON app.application_messages
  AS RESTRICTIVE FOR UPDATE TO public USING (FALSE) WITH CHECK (FALSE);
CREATE POLICY application_messages_rpc_delete_only ON app.application_messages
  AS RESTRICTIVE FOR DELETE TO public USING (FALSE);

CREATE FUNCTION app.send_application_media(
  p_application_id UUID,p_content TEXT,p_type TEXT,p_media_url TEXT,p_media_mime TEXT,
  p_sender TEXT,p_audience TEXT,p_channel TEXT
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_role TEXT; v_id UUID;
BEGIN
  SELECT raw_app_meta_data->>'role' INTO v_role FROM auth.users WHERE id=auth.uid();
  IF auth.uid() IS NULL OR NOT app.application_message_channel_allowed(p_application_id,p_channel)
    OR (p_sender = 'admin' AND COALESCE(v_role,'') NOT IN ('admin','super_admin'))
    OR (p_sender = 'university' AND v_role IS DISTINCT FROM 'university')
    OR (p_sender = 'student' AND NOT EXISTS (
      SELECT 1 FROM app.applications WHERE id=p_application_id AND student_id=auth.uid()))
    THEN RETURN jsonb_build_object('success',FALSE,'error','forbidden'); END IF;
  IF p_type IS NULL OR p_type NOT IN ('image','audio','video')
    OR p_media_url IS NULL OR p_media_mime IS NULL
    OR split_part(p_media_url,'/',1) <> p_application_id::TEXT
    OR split_part(p_media_url,'/',2) <> p_channel
    OR split_part(p_media_url,'/',3) <> auth.uid()::TEXT
    OR NOT app.application_media_access(p_media_url,'read')
    OR NOT ((p_type='image' AND p_media_mime IN ('image/jpeg','image/png','image/webp'))
      OR (p_type='audio' AND p_media_mime IN ('audio/mp4','audio/mpeg','audio/wav','audio/ogg','audio/webm'))
      OR (p_type='video' AND p_media_mime IN ('video/mp4','video/quicktime','video/webm')))
    THEN RETURN jsonb_build_object('success',FALSE,'error','invalid_media'); END IF;
  -- Réessayer après une réponse réseau perdue ne duplique pas le message.
  SELECT id INTO v_id FROM app.application_messages WHERE media_url=p_media_url
    AND application_id=p_application_id AND sender_role=p_sender AND audience=p_audience
    AND type=p_type AND media_mime=p_media_mime;
  IF v_id IS NOT NULL THEN RETURN jsonb_build_object('success',TRUE,'message_id',v_id); END IF;
  IF NOT EXISTS (SELECT 1 FROM storage.objects o WHERE o.bucket_id='application-media'
    AND o.name=p_media_url AND o.metadata->>'mimetype'=p_media_mime
    AND (o.metadata->>'size')::BIGINT BETWEEN 1 AND 26214400)
    THEN RETURN jsonb_build_object('success',FALSE,'error','media_not_found'); END IF;
  INSERT INTO app.application_messages(application_id,sender_role,audience,content,type,media_url,media_mime)
  VALUES(p_application_id,p_sender,p_audience,
    COALESCE(NULLIF(btrim(p_content),''),CASE p_type WHEN 'image' THEN 'Image'
      WHEN 'audio' THEN 'Message vocal' ELSE 'Vidéo' END),p_type,p_media_url,p_media_mime)
  RETURNING id INTO v_id;
  UPDATE app.applications SET last_message_at=NOW(),updated_at=NOW() WHERE id=p_application_id;
  RETURN jsonb_build_object('success',TRUE,'message_id',v_id);
END;
$$;
REVOKE ALL ON FUNCTION app.send_application_media(UUID,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.app_add_application_message_from_student(p_application_id UUID,p_content TEXT,p_type TEXT,p_media_url TEXT,p_media_mime TEXT) RETURNS JSONB LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ SELECT app.send_application_media(p_application_id,p_content,p_type,p_media_url,p_media_mime,'student','admin_only','student'); $$;
REVOKE ALL ON FUNCTION public.app_add_application_message_from_student(UUID,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.app_add_application_message_from_student(UUID,TEXT,TEXT,TEXT,TEXT) TO authenticated;

CREATE FUNCTION public.app_add_application_message_from_university(p_application_id UUID,p_content TEXT,p_type TEXT,p_media_url TEXT,p_media_mime TEXT) RETURNS JSONB LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ SELECT app.send_application_media(p_application_id,p_content,p_type,p_media_url,p_media_mime,'university','admin_only','university'); $$;
REVOKE ALL ON FUNCTION public.app_add_application_message_from_university(UUID,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.app_add_application_message_from_university(UUID,TEXT,TEXT,TEXT,TEXT) TO authenticated;

CREATE FUNCTION public.app_add_application_message_from_admin_to_student(p_application_id UUID,p_content TEXT,p_type TEXT,p_media_url TEXT,p_media_mime TEXT) RETURNS JSONB LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ SELECT app.send_application_media(p_application_id,p_content,p_type,p_media_url,p_media_mime,'admin','student','student'); $$;
REVOKE ALL ON FUNCTION public.app_add_application_message_from_admin_to_student(UUID,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.app_add_application_message_from_admin_to_student(UUID,TEXT,TEXT,TEXT,TEXT) TO authenticated;

CREATE FUNCTION public.app_add_application_message_from_admin_to_university(p_application_id UUID,p_content TEXT,p_type TEXT,p_media_url TEXT,p_media_mime TEXT) RETURNS JSONB LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ SELECT app.send_application_media(p_application_id,p_content,p_type,p_media_url,p_media_mime,'admin','university','university'); $$;
REVOKE ALL ON FUNCTION public.app_add_application_message_from_admin_to_university(UUID,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.app_add_application_message_from_admin_to_university(UUID,TEXT,TEXT,TEXT,TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.app_add_application_message_from_student(p_application_id uuid, p_content text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_app_student_id UUID;
    v_message_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    IF p_content IS NULL OR LENGTH(TRIM(p_content)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'empty_content');
    END IF;

    SELECT student_id INTO v_app_student_id
    FROM app.applications
    WHERE id = p_application_id;

    IF v_app_student_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    IF v_app_student_id <> v_user_id THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_owner');
    END IF;

    INSERT INTO app.application_messages (application_id, sender_role, audience, content)
    VALUES (p_application_id, 'student', 'admin_only', p_content)
    RETURNING id INTO v_message_id;

    UPDATE app.applications
    SET
        last_message_at = NOW(),
        updated_at = NOW()
    WHERE id = p_application_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'message_id', v_message_id
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.app_mark_application_messages_read_for_student(p_application_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_owner_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT student_id INTO v_owner_id
    FROM app.applications
    WHERE id = p_application_id;

    IF v_owner_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    IF v_owner_id <> v_user_id THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_owner');
    END IF;

    UPDATE app.applications
    SET last_student_read_at = NOW()
    WHERE id = p_application_id;

    UPDATE app.application_messages SET read_at = NOW()
    WHERE application_id = p_application_id AND read_at IS NULL AND sender_role = 'admin' AND audience = 'student';

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$function$;

CREATE OR REPLACE FUNCTION public.app_list_application_messages_for_university(p_application_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_university_id UUID;
    v_exists BOOLEAN;
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT
        raw_app_meta_data->>'role',
        (raw_app_meta_data->>'university_id')::UUID
    INTO v_role, v_university_id
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role IS DISTINCT FROM 'university' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_university');
    END IF;

    IF v_university_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'university_not_configured');
    END IF;

    SELECT EXISTS(
        SELECT 1
        FROM app.applications a
        JOIN app.programs p ON p.id = a.program_id
        WHERE a.id = p_application_id
          AND p.university_id = v_university_id
          AND a.sent_to_university IS TRUE
    ) INTO v_exists;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', m.id,
                'application_id', m.application_id,
                'sender_role', m.sender_role,
                'audience', m.audience,
                'content', m.content,
                'created_at', m.created_at,
                'type', m.type,
                'media_url', m.media_url,
                'media_mime', m.media_mime,
                'read_at', m.read_at
            )
            ORDER BY m.created_at ASC
        ),
        '[]'::JSONB
    )
    INTO v_result
    FROM app.application_messages m
    JOIN app.applications a ON a.id = m.application_id
    JOIN app.programs p ON p.id = a.program_id
    WHERE m.application_id = p_application_id
      AND p.university_id = v_university_id
          AND a.sent_to_university IS TRUE
      AND (m.audience = 'university' OR m.sender_role = 'university');

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'messages', v_result
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.app_list_application_messages_for_student(p_application_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN '[]'::JSONB;
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', m.id,
                'application_id', m.application_id,
                'sender_role', m.sender_role,
                'audience', m.audience,
                'content', m.content,
                'created_at', m.created_at,
                'type', m.type,
                'media_url', m.media_url,
                'media_mime', m.media_mime,
                'read_at', m.read_at
            )
            ORDER BY m.created_at ASC
        ),
        '[]'::JSONB
    )
    INTO v_result
    FROM app.application_messages m
    JOIN app.applications a ON a.id = m.application_id
    WHERE m.application_id = p_application_id
      AND a.student_id = v_user_id
      AND (m.sender_role = 'student' OR m.audience = 'student');

    RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION public.app_list_application_messages_for_admin(p_application_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_exists BOOLEAN;
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_app_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF COALESCE(v_role, '') NOT IN ('admin', 'super_admin') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
    END IF;

    SELECT EXISTS(SELECT 1 FROM app.applications a WHERE a.id = p_application_id)
    INTO v_exists;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', m.id,
                'application_id', m.application_id,
                'sender_role', m.sender_role,
                'audience', m.audience,
                'content', m.content,
                'created_at', m.created_at,
                'type', m.type,
                'media_url', m.media_url,
                'media_mime', m.media_mime,
                'read_at', m.read_at
            )
            ORDER BY m.created_at ASC
        ),
        '[]'::JSONB
    )
    INTO v_result
    FROM app.application_messages m
    WHERE m.application_id = p_application_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'messages', v_result
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.app_add_application_message_from_admin_to_student(p_application_id uuid, p_content text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_exists BOOLEAN;
    v_message_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_app_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF COALESCE(v_role, '') NOT IN ('admin', 'super_admin') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
    END IF;

    IF p_content IS NULL OR LENGTH(TRIM(p_content)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'empty_content');
    END IF;

    SELECT EXISTS(SELECT 1 FROM app.applications a WHERE a.id = p_application_id)
    INTO v_exists;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    INSERT INTO app.application_messages (application_id, sender_role, audience, content)
    VALUES (p_application_id, 'admin', 'student', p_content)
    RETURNING id INTO v_message_id;

    UPDATE app.applications
    SET
        last_message_at = NOW(),
        updated_at = NOW()
    WHERE id = p_application_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'message_id', v_message_id
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.app_add_application_message_from_admin_to_university(p_application_id uuid, p_content text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_exists BOOLEAN;
    v_message_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_app_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF COALESCE(v_role, '') NOT IN ('admin', 'super_admin') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
    END IF;

    IF p_content IS NULL OR LENGTH(TRIM(p_content)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'empty_content');
    END IF;

    SELECT EXISTS(SELECT 1 FROM app.applications a WHERE a.id = p_application_id)
    INTO v_exists;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    INSERT INTO app.application_messages (application_id, sender_role, audience, content)
    VALUES (p_application_id, 'admin', 'university', p_content)
    RETURNING id INTO v_message_id;

    UPDATE app.applications
    SET
        last_message_at = NOW(),
        updated_at = NOW()
    WHERE id = p_application_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'message_id', v_message_id
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.app_mark_application_messages_read_for_admin(p_application_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_exists BOOLEAN;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_app_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF COALESCE(v_role, '') NOT IN ('admin', 'super_admin') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
    END IF;

    SELECT EXISTS(SELECT 1 FROM app.applications a WHERE a.id = p_application_id)
    INTO v_exists;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    UPDATE app.applications
    SET last_admin_read_at = NOW()
    WHERE id = p_application_id;

    UPDATE app.application_messages SET read_at = NOW()
    WHERE application_id = p_application_id AND read_at IS NULL AND sender_role IN ('student','university') AND audience = 'admin_only';

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$function$;

CREATE OR REPLACE FUNCTION public.app_add_application_message_from_university(p_application_id uuid, p_content text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_university_id UUID;
    v_exists BOOLEAN;
    v_message_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT
        raw_app_meta_data->>'role',
        (raw_app_meta_data->>'university_id')::UUID
    INTO v_role, v_university_id
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role IS DISTINCT FROM 'university' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_university');
    END IF;

    IF v_university_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'university_not_configured');
    END IF;

    IF p_content IS NULL OR LENGTH(TRIM(p_content)) = 0 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'empty_content');
    END IF;

    SELECT EXISTS(
        SELECT 1
        FROM app.applications a
        JOIN app.programs p ON p.id = a.program_id
        WHERE a.id = p_application_id
          AND p.university_id = v_university_id
          AND a.sent_to_university IS TRUE
    ) INTO v_exists;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    INSERT INTO app.application_messages (application_id, sender_role, audience, content)
    VALUES (p_application_id, 'university', 'admin_only', p_content)
    RETURNING id INTO v_message_id;

    UPDATE app.applications
    SET
        last_message_at = NOW(),
        updated_at = NOW()
    WHERE id = p_application_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'message_id', v_message_id
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.app_mark_application_messages_read_for_university(p_application_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_university_id UUID;
    v_exists BOOLEAN;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT
        raw_app_meta_data->>'role',
        (raw_app_meta_data->>'university_id')::UUID
    INTO v_role, v_university_id
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role IS DISTINCT FROM 'university' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_university');
    END IF;

    IF v_university_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'university_not_configured');
    END IF;

    SELECT EXISTS(
        SELECT 1
        FROM app.applications a
        JOIN app.programs p ON p.id = a.program_id
        WHERE a.id = p_application_id
          AND p.university_id = v_university_id
          AND a.sent_to_university IS TRUE
    ) INTO v_exists;

    IF NOT v_exists THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
    END IF;

    UPDATE app.applications
    SET last_university_read_at = NOW()
    WHERE id = p_application_id;

    UPDATE app.application_messages SET read_at = NOW()
    WHERE application_id = p_application_id AND read_at IS NULL AND sender_role = 'admin' AND audience = 'university';

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$function$;

NOTIFY pgrst, 'reload schema';
