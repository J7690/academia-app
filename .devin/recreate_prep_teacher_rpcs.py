#!/usr/bin/env python3
"""PHASE 2 - Recréation des RPCs dans public (DROP app, CREATE public)"""
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    
    print("\n" + "="*60)
    print("  PHASE 2 — RECÉATION DES RPCs DANS PUBLIC")
    print("="*60 + "\n")
    
    # Définitions SQL des RPCs (extraites de la sauvegarde)
    rpcs_sql = [
        {
            'name': 'app_prep_teacher_list_assignments',
            'args': '',
            'body': """CREATE OR REPLACE FUNCTION public.app_prep_teacher_list_assignments()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'app'
AS $function$ DECLARE v_result JSONB; BEGIN SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at DESC), '[]'::jsonb) INTO v_result FROM ( SELECT a.*, (SELECT COUNT(*) FROM app.prep_assignment_submissions s WHERE s.assignment_id = a.id) AS submission_count, (SELECT COUNT(*) FROM app.prep_assignment_submissions s WHERE s.assignment_id = a.id AND s.status = 'graded') AS graded_count FROM app.prep_assignments a WHERE a.teacher_id = auth.uid() ) t; RETURN v_result; END; $function$"""
        },
        {
            'name': 'app_prep_teacher_upsert_assignment',
            'args': 'p_assignment_id uuid DEFAULT NULL::uuid, p_title text DEFAULT NULL::text, p_description text DEFAULT NULL::text, p_concours_type text DEFAULT NULL::text, p_subject_name text DEFAULT NULL::text, p_assignment_type text DEFAULT \'qcm\'::text, p_content jsonb DEFAULT NULL::jsonb, p_attachments jsonb DEFAULT \'[]\'::jsonb, p_deadline timestamp with time zone DEFAULT NULL::timestamp with time zone, p_max_score integer DEFAULT 20, p_is_published boolean DEFAULT false, p_target_group text DEFAULT \'all\'::text',
            'body': """CREATE OR REPLACE FUNCTION public.app_prep_teacher_upsert_assignment(p_assignment_id uuid DEFAULT NULL::uuid, p_title text DEFAULT NULL::text, p_description text DEFAULT NULL::text, p_concours_type text DEFAULT NULL::text, p_subject_name text DEFAULT NULL::text, p_assignment_type text DEFAULT 'qcm'::text, p_content jsonb DEFAULT NULL::jsonb, p_attachments jsonb DEFAULT '[]'::jsonb, p_deadline timestamp with time zone DEFAULT NULL::timestamp with time zone, p_max_score integer DEFAULT 20, p_is_published boolean DEFAULT false, p_target_group text DEFAULT 'all'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'app'
AS $function$ DECLARE v_id UUID; BEGIN IF p_assignment_id IS NOT NULL THEN UPDATE app.prep_assignments SET title = COALESCE(p_title, title), description = COALESCE(p_description, description), concours_type = COALESCE(p_concours_type, concours_type), subject_name = COALESCE(p_subject_name, subject_name), assignment_type = COALESCE(p_assignment_type, assignment_type), content = COALESCE(p_content, content), attachments = COALESCE(p_attachments, attachments), deadline = COALESCE(p_deadline, deadline), max_score = COALESCE(p_max_score, max_score), is_published = COALESCE(p_is_published, is_published), target_group = COALESCE(p_target_group, target_group), updated_at = now() WHERE id = p_assignment_id AND teacher_id = auth.uid() RETURNING id INTO v_id; ELSE INSERT INTO app.prep_assignments (teacher_id, title, description, concours_type, subject_name, assignment_type, content, attachments, deadline, max_score, is_published, target_group) VALUES (auth.uid(), p_title, p_description, p_concours_type, p_subject_name, p_assignment_type, p_content, p_attachments, p_deadline, p_max_score, p_is_published, p_target_group) RETURNING id INTO v_id; END IF; RETURN jsonb_build_object('success', true, 'id', v_id); END; $function$"""
        },
        {
            'name': 'app_prep_teacher_list_submissions',
            'args': 'p_assignment_id uuid',
            'body': """CREATE OR REPLACE FUNCTION public.app_prep_teacher_list_submissions(p_assignment_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'app'
AS $function$ DECLARE v_result JSONB; BEGIN IF NOT EXISTS (SELECT 1 FROM app.prep_assignments WHERE id = p_assignment_id AND teacher_id = auth.uid()) THEN RETURN jsonb_build_object('success', false, 'error', 'not_owner'); END IF; SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.submitted_at DESC), '[]'::jsonb) INTO v_result FROM ( SELECT s.*, st.full_name AS student_name FROM app.prep_assignment_submissions s LEFT JOIN app.students st ON st.id = s.student_id WHERE s.assignment_id = p_assignment_id ) t; RETURN jsonb_build_object('success', true, 'submissions', v_result); END; $function$"""
        },
        {
            'name': 'app_prep_teacher_grade_submission',
            'args': 'p_submission_id uuid, p_score integer, p_comment text DEFAULT NULL::text',
            'body': """CREATE OR REPLACE FUNCTION public.app_prep_teacher_grade_submission(p_submission_id uuid, p_score integer, p_comment text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'app'
AS $function$ BEGIN UPDATE app.prep_assignment_submissions SET teacher_score = p_score, teacher_comment = p_comment, teacher_graded_at = now(), status = 'graded' WHERE id = p_submission_id AND EXISTS (SELECT 1 FROM app.prep_assignments a WHERE a.id = assignment_id AND a.teacher_id = auth.uid()); RETURN jsonb_build_object('success', true); END; $function$"""
        },
        {
            'name': 'app_prep_teacher_list_live_sessions',
            'args': '',
            'body': """CREATE OR REPLACE FUNCTION public.app_prep_teacher_list_live_sessions()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'app'
AS $function$ DECLARE v_result JSONB; BEGIN SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.start_at DESC), '[]'::jsonb) INTO v_result FROM (SELECT s.*, (SELECT COUNT(*) FROM app.prep_live_participants p WHERE p.session_id=s.id) AS participant_count FROM app.prep_live_sessions s WHERE s.teacher_id=auth.uid()) t; RETURN v_result; END; $function$"""
        },
        {
            'name': 'app_prep_teacher_upsert_live_session',
            'args': 'p_session_id uuid DEFAULT NULL::uuid, p_title text DEFAULT NULL::text, p_description text DEFAULT NULL::text, p_session_type text DEFAULT \'revision\'::text, p_concours_type text DEFAULT NULL::text, p_subject_name text DEFAULT NULL::text, p_provider text DEFAULT \'livekit\'::text, p_join_url text DEFAULT NULL::text, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_replay_url text DEFAULT NULL::text, p_max_participants integer DEFAULT 100, p_quiz_template_id uuid DEFAULT NULL::uuid',
            'body': """CREATE OR REPLACE FUNCTION public.app_prep_teacher_upsert_live_session(p_session_id uuid DEFAULT NULL::uuid, p_title text DEFAULT NULL::text, p_description text DEFAULT NULL::text, p_session_type text DEFAULT 'revision'::text, p_concours_type text DEFAULT NULL::text, p_subject_name text DEFAULT NULL::text, p_provider text DEFAULT 'livekit'::text, p_join_url text DEFAULT NULL::text, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_replay_url text DEFAULT NULL::text, p_max_participants integer DEFAULT 100, p_quiz_template_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'app'
AS $function$ DECLARE v_id UUID; BEGIN IF p_session_id IS NOT NULL THEN UPDATE app.prep_live_sessions SET title = COALESCE(p_title, title), description = COALESCE(p_description, description), session_type = COALESCE(p_session_type, session_type), concours_type = COALESCE(p_concours_type, concours_type), subject_name = COALESCE(p_subject_name, subject_name), provider = COALESCE(p_provider, provider), join_url = COALESCE(p_join_url, join_url), start_at = COALESCE(p_start_at, start_at), end_at = COALESCE(p_end_at, end_at), replay_url = COALESCE(p_replay_url, replay_url), max_participants = COALESCE(p_max_participants, max_participants), quiz_template_id = COALESCE(p_quiz_template_id, quiz_template_id), updated_at = now() WHERE id = p_session_id AND teacher_id = auth.uid() RETURNING id INTO v_id; ELSE INSERT INTO app.prep_live_sessions (teacher_id, title, description, session_type, concours_type, subject_name, provider, join_url, start_at, end_at, replay_url, max_participants, quiz_template_id) VALUES (auth.uid(), p_title, p_description, p_session_type, p_concours_type, p_subject_name, p_provider, p_join_url, p_start_at, p_end_at, p_replay_url, p_max_participants, p_quiz_template_id) RETURNING id INTO v_id; END IF; RETURN jsonb_build_object('success', true, 'id', v_id); END; $function$"""
        },
        {
            'name': 'app_prep_teacher_start_live_session',
            'args': 'p_session_id uuid',
            'body': """CREATE OR REPLACE FUNCTION public.app_prep_teacher_start_live_session(p_session_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'app'
AS $function$ BEGIN UPDATE app.prep_live_sessions SET status = 'live', started_at = now() WHERE id = p_session_id AND teacher_id = auth.uid(); RETURN jsonb_build_object('success', true); END; $function$"""
        },
        {
            'name': 'app_prep_teacher_end_live_session',
            'args': 'p_session_id uuid',
            'body': """CREATE OR REPLACE FUNCTION public.app_prep_teacher_end_live_session(p_session_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'app'
AS $function$ BEGIN UPDATE app.prep_live_sessions SET status = 'ended', ended_at = now() WHERE id = p_session_id AND teacher_id = auth.uid(); RETURN jsonb_build_object('success', true); END; $function$"""
        },
    ]
    
    for rpc in rpcs_sql:
        name = rpc['name']
        print(f"Recréation de {name}...")
        
        # DROP dans app
        sql_drop = f"DROP FUNCTION IF EXISTS app.{name}({rpc['args']}) CASCADE"
        result_drop = m.execute_sql_auto(sql_drop)
        
        if result_drop.get('success'):
            print(f"  ✓ Dropped from app")
        else:
            print(f"  ✗ Drop error: {result_drop.get('error')}")
        
        # CREATE dans public
        sql_create = rpc['body']
        result_create = m.execute_sql_auto(sql_create)
        
        if result_create.get('success'):
            print(f"  ✓ Created in public")
        else:
            print(f"  ✗ Create error: {result_create.get('error')}")
    
    print("\n✅ PHASE 2 terminée.\n")

if __name__ == "__main__":
    main()
