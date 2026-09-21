-- UNIQUEMENT dans une base locale jetable nommée academia_phase3_test*.
-- Ne jamais appliquer ce fichier de fixtures sur Supabase.
DO $$ BEGIN
 IF current_database() NOT LIKE 'academia_phase3_test%' THEN
   RAISE EXCEPTION 'Fixtures réservées à academia_phase3_test*';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon; END IF;
END $$;
CREATE SCHEMA auth;
CREATE SCHEMA app;
CREATE SCHEMA storage;
CREATE TABLE auth.users(id UUID PRIMARY KEY, raw_user_meta_data JSONB, raw_app_meta_data JSONB);
CREATE FUNCTION auth.uid() RETURNS UUID LANGUAGE sql STABLE AS $$
  SELECT NULLIF(current_setting('request.jwt.claim.sub', true),'')::UUID;
$$;
CREATE TABLE app.programs(id UUID PRIMARY KEY, university_id UUID);
CREATE TABLE app.applications(id UUID PRIMARY KEY, student_id UUID, program_id UUID,
 sent_to_university BOOLEAN DEFAULT TRUE, last_message_at TIMESTAMPTZ, updated_at TIMESTAMPTZ,
 last_admin_read_at TIMESTAMPTZ,last_student_read_at TIMESTAMPTZ,last_university_read_at TIMESTAMPTZ);
CREATE TABLE app.application_messages(id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 application_id UUID REFERENCES app.applications(id),sender_role TEXT,audience TEXT,content TEXT,
 created_at TIMESTAMPTZ DEFAULT now());
CREATE TABLE storage.buckets(id TEXT PRIMARY KEY,name TEXT,public BOOLEAN,file_size_limit BIGINT,allowed_mime_types TEXT[]);
CREATE TABLE storage.objects(id UUID DEFAULT gen_random_uuid(),bucket_id TEXT,name TEXT,metadata JSONB,UNIQUE(bucket_id,name));
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.application_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY student_select_own_application_messages ON app.application_messages FOR SELECT TO public USING (
 EXISTS (SELECT 1 FROM app.applications a WHERE a.id=application_id AND a.student_id=auth.uid()));
CREATE POLICY student_insert_own_application_messages ON app.application_messages FOR INSERT TO public WITH CHECK (
 EXISTS (SELECT 1 FROM app.applications a WHERE a.id=application_id AND a.student_id=auth.uid()) AND sender_role='student');
GRANT USAGE ON SCHEMA auth,app,storage TO authenticated,anon;
GRANT ALL ON ALL TABLES IN SCHEMA app,storage TO authenticated,anon;

INSERT INTO auth.users VALUES
 ('00000000-0000-0000-0000-000000000001','{"role":"student"}','{"role":"student"}'),
 ('00000000-0000-0000-0000-000000000002','{"role":"university","university_id":"10000000-0000-0000-0000-000000000001"}','{"role":"university","university_id":"10000000-0000-0000-0000-000000000001"}'),
 ('00000000-0000-0000-0000-000000000003','{"role":"admin"}','{"role":"admin"}'),
 ('00000000-0000-0000-0000-000000000004','{"role":"admin"}','{"role":"student"}'),
 ('00000000-0000-0000-0000-000000000005','{"role":"university","university_id":"10000000-0000-0000-0000-000000000002"}','{"role":"university","university_id":"10000000-0000-0000-0000-000000000002"}');
INSERT INTO app.programs VALUES('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001');
INSERT INTO app.applications(id,student_id,program_id) VALUES('30000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001');
