\set ON_ERROR_STOP on
-- Tests synthétiques exclusivement locaux, jamais sur Supabase.
DO $$ BEGIN
 IF current_database() NOT LIKE 'academia_phase3_test%' THEN
  RAISE EXCEPTION 'Tests réservés à academia_phase3_test*';
 END IF;
END $$;
SET ROLE authenticated;
DO $$
DECLARE
 a UUID := '30000000-0000-0000-0000-000000000001';
 student TEXT := '00000000-0000-0000-0000-000000000001';
 university TEXT := '00000000-0000-0000-0000-000000000002';
 admin TEXT := '00000000-0000-0000-0000-000000000003';
 outsider TEXT := '00000000-0000-0000-0000-000000000004';
 other_uni TEXT := '00000000-0000-0000-0000-000000000005';
 path_student TEXT := a::TEXT||'/student/'||student||'/test.wav';
 path_uni TEXT := a::TEXT||'/university/'||university||'/test.mp4';
 path_admin TEXT := a::TEXT||'/university/'||admin||'/test.jpg';
 path_admin_student TEXT := a::TEXT||'/student/'||admin||'/test.jpg';
 v JSONB; v_again JSONB; n INT;
BEGIN
 PERFORM set_config('request.jwt.claim.sub',student,true);
 v:=public.app_add_application_message_from_student(a,'Ancien client étudiant');
 ASSERT (v->>'success')::BOOLEAN, 'legacy student';
 INSERT INTO storage.objects(bucket_id,name,metadata) VALUES ('application-media',path_student,'{"mimetype":"audio/wav","size":100}');
 v:=public.app_add_application_message_from_student(a,'Vocal','audio',path_student,'audio/wav');
 ASSERT (v->>'success')::BOOLEAN,'student audio';
 v_again:=public.app_add_application_message_from_student(a,'Vocal','audio',path_student,'audio/wav');
 ASSERT v->>'message_id'=v_again->>'message_id','idempotent retry';
 DELETE FROM storage.objects WHERE bucket_id='application-media' AND name=path_student;
 GET DIAGNOSTICS n=ROW_COUNT; ASSERT n=0,'linked media cannot be removed';
 BEGIN
  INSERT INTO storage.objects(bucket_id,name,metadata) VALUES('application-media',a::TEXT||'/university/'||student||'/evil.wav','{}');
  RAISE EXCEPTION 'Student upload to university succeeded';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  INSERT INTO app.application_messages(application_id,sender_role,audience,content) VALUES(a,'student','university','forged');
  RAISE EXCEPTION 'Direct message insert succeeded';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;

 PERFORM set_config('request.jwt.claim.sub',university,true);
 ASSERT (public.app_add_application_message_from_university(a,'Ancien client université')->>'success')::BOOLEAN,'legacy university';
 ASSERT NOT app.application_media_access(path_student,'read'),'university cannot read student';
 INSERT INTO storage.objects(bucket_id,name,metadata) VALUES ('application-media',path_uni,'{"mimetype":"video/mp4","size":100}');
 ASSERT (public.app_add_application_message_from_university(a,'Vidéo','video',path_uni,'video/mp4')->>'success')::BOOLEAN,'university video';
 v:=public.app_list_application_messages_for_university(a);
 ASSERT jsonb_array_length(v->'messages')=2,'university sees only its channel';

 PERFORM set_config('request.jwt.claim.sub',admin,true);
 ASSERT app.application_media_access(path_student,'read') AND app.application_media_access(path_uni,'read'),'admin reads both';
 ASSERT (public.app_add_application_message_from_admin_to_student(a,'Ancien client admin étudiant')->>'success')::BOOLEAN,'legacy admin student';
 ASSERT (public.app_add_application_message_from_admin_to_university(a,'Ancien client admin université')->>'success')::BOOLEAN,'legacy admin university';
 INSERT INTO storage.objects(bucket_id,name,metadata) VALUES ('application-media',path_admin,'{"mimetype":"image/jpeg","size":100}');
 ASSERT (public.app_add_application_message_from_admin_to_university(a,'Image','image',path_admin,'image/jpeg')->>'success')::BOOLEAN,'admin image to university';
 INSERT INTO storage.objects(bucket_id,name,metadata) VALUES ('application-media',path_admin_student,'{"mimetype":"image/jpeg","size":100}');
 ASSERT (public.app_add_application_message_from_admin_to_student(a,'Image','image',path_admin_student,'image/jpeg')->>'success')::BOOLEAN,'admin image to student';
 v:=public.app_add_application_message_from_admin_to_student(a,'Wrong','image',path_admin,'image/jpeg');
 ASSERT NOT (v->>'success')::BOOLEAN,'cross channel attach denied';
 PERFORM public.app_mark_application_messages_read_for_admin(a);
 v:=public.app_list_application_messages_for_admin(a);
 ASSERT jsonb_array_length(v->'messages')=8,'admin lists all';
 ASSERT (SELECT count(*) FROM jsonb_array_elements(v->'messages') m WHERE m->>'sender_role' IN ('student','university') AND m->>'read_at' IS NOT NULL)=4,'admin receipt';

 PERFORM set_config('request.jwt.claim.sub',student,true);
 ASSERT NOT app.application_media_access(path_uni,'read') AND NOT app.application_media_access(path_admin,'read'),'student cannot read university channel';
 SELECT count(*) INTO n FROM storage.objects WHERE bucket_id='application-media';
 ASSERT n=2,'student storage RLS';
 SELECT count(*) INTO n FROM app.application_messages;
 ASSERT n=4,'student table RLS excludes university despite old permissive policy';
 v:=public.app_list_application_messages_for_student(a);
 ASSERT jsonb_array_length(v)=4,'student old response remains array';
 PERFORM public.app_mark_application_messages_read_for_student(a);
 PERFORM set_config('request.jwt.claim.sub',admin,true);
 v:=public.app_list_application_messages_for_admin(a);
 ASSERT (SELECT count(*) FROM jsonb_array_elements(v->'messages') m WHERE m->>'sender_role'='admin' AND m->>'audience'='student' AND m->>'read_at' IS NOT NULL)=2,'student receipt';
 ASSERT (SELECT count(*) FROM jsonb_array_elements(v->'messages') m WHERE m->>'sender_role'='admin' AND m->>'audience'='university' AND m->>'read_at' IS NOT NULL)=0,'student cannot mark university read';
 PERFORM set_config('request.jwt.claim.sub',university,true);
 PERFORM public.app_mark_application_messages_read_for_university(a);
 PERFORM set_config('request.jwt.claim.sub',outsider,true);
 ASSERT NOT app.application_media_access(path_student,'read'),'other student cannot read';
 ASSERT NOT (public.app_add_application_message_from_admin_to_student(a,'spoof')->>'success')::BOOLEAN,'user_metadata cannot grant admin';
 ASSERT NOT (public.app_list_application_messages_for_admin(a)->>'success')::BOOLEAN,'spoofed admin list denied';
 PERFORM set_config('request.jwt.claim.sub',other_uni,true);
 ASSERT NOT (public.app_add_application_message_from_university(a,'spoof')->>'success')::BOOLEAN,'other university rejected';
 ASSERT NOT app.application_media_access(path_uni,'read'),'other university no storage read';
 PERFORM set_config('request.jwt.claim.sub','',true);
 ASSERT NOT app.application_media_access(path_student,'read'),'no auth no media';
 RAISE NOTICE 'PASS: legacy RPCs, four media sends, retry, role spoofing, audience isolation, receipts, storage RLS';
END $$;
RESET ROLE;
-- Même une policy permissive globale ajoutée accidentellement ne doit pas ouvrir le bucket.
CREATE POLICY test_broad_read ON storage.objects FOR SELECT TO public USING(TRUE);
SET ROLE anon;
SELECT set_config('request.jwt.claim.sub','',false);
DO $$ BEGIN
 ASSERT (SELECT count(*) FROM storage.objects WHERE bucket_id='application-media')=0,'anonymous restrictive guard';
 RAISE NOTICE 'PASS: anonymous storage access denied with broad permissive policy';
END $$;
RESET ROLE;
DROP POLICY test_broad_read ON storage.objects;
