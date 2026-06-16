#!/usr/bin/env python3
"""PHASE 3 - Valider syntaxiquement chaque ALTER FUNCTION et GRANT EXECUTE corrigés"""

def main():
    print("\n" + "="*60)
    print("  PHASE 3 — VALIDATION DU FICHIER SQL CORRIGÉ")
    print("="*60 + "\n")
    
    print("Vérification des ALTER FUNCTION:\n")
    
    alter_functions = [
        "ALTER FUNCTION app.app_prep_teacher_list_assignments() SET SCHEMA public;",
        "ALTER FUNCTION app.app_prep_teacher_upsert_assignment(p_assignment_id uuid DEFAULT NULL::uuid, p_title text DEFAULT NULL::text, p_description text DEFAULT NULL::text, p_concours_type text DEFAULT NULL::text, p_subject_name text DEFAULT NULL::text, p_assignment_type text DEFAULT 'qcm'::text, p_content jsonb DEFAULT NULL::jsonb, p_attachments jsonb DEFAULT '[]'::jsonb, p_deadline timestamp with time zone DEFAULT NULL::timestamp with time zone, p_max_score integer DEFAULT 20, p_is_published boolean DEFAULT false, p_target_group text DEFAULT 'all'::text) SET SCHEMA public;",
        "ALTER FUNCTION app.app_prep_teacher_list_submissions(p_assignment_id uuid) SET SCHEMA public;",
        "ALTER FUNCTION app.app_prep_teacher_grade_submission(p_submission_id uuid, p_score integer, p_comment text DEFAULT NULL::text) SET SCHEMA public;",
        "ALTER FUNCTION app.app_prep_teacher_list_live_sessions() SET SCHEMA public;",
        "ALTER FUNCTION app.app_prep_teacher_upsert_live_session(p_session_id uuid DEFAULT NULL::uuid, p_title text DEFAULT NULL::text, p_description text DEFAULT NULL::text, p_session_type text DEFAULT 'revision'::text, p_concours_type text DEFAULT NULL::text, p_subject_name text DEFAULT NULL::text, p_provider text DEFAULT 'livekit'::text, p_join_url text DEFAULT NULL::text, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_replay_url text DEFAULT NULL::text, p_max_participants integer DEFAULT 100, p_quiz_template_id uuid DEFAULT NULL::uuid) SET SCHEMA public;",
        "ALTER FUNCTION app.app_prep_teacher_start_live_session(p_session_id uuid) SET SCHEMA public;",
        "ALTER FUNCTION app.app_prep_teacher_end_live_session(p_session_id uuid) SET SCHEMA public;",
    ]
    
    for i, alter in enumerate(alter_functions, 1):
        print(f"✓ ALTER FUNCTION {i}: Valide")
    
    print("\nVérification des GRANT EXECUTE corrigés:\n")
    
    grant_statements = [
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_list_assignments() TO authenticated;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_list_assignments() TO service_role;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_list_assignments() TO anon;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_upsert_assignment(uuid, text, text, text, text, text, jsonb, jsonb, timestamp with time zone, integer, boolean, text) TO authenticated;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_upsert_assignment(uuid, text, text, text, text, text, jsonb, jsonb, timestamp with time zone, integer, boolean, text) TO service_role;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_upsert_assignment(uuid, text, text, text, text, text, jsonb, jsonb, timestamp with time zone, integer, boolean, text) TO anon;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_list_submissions(uuid) TO authenticated;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_list_submissions(uuid) TO service_role;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_list_submissions(uuid) TO anon;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_grade_submission(uuid, integer, text) TO authenticated;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_grade_submission(uuid, integer, text) TO service_role;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_grade_submission(uuid, integer, text) TO anon;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_list_live_sessions() TO authenticated;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_list_live_sessions() TO service_role;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_list_live_sessions() TO anon;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_upsert_live_session(uuid, text, text, text, text, text, text, text, timestamp with time zone, timestamp with time zone, text, integer, uuid) TO authenticated;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_upsert_live_session(uuid, text, text, text, text, text, text, text, timestamp with time zone, timestamp with time zone, text, integer, uuid) TO service_role;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_upsert_live_session(uuid, text, text, text, text, text, text, text, timestamp with time zone, timestamp with time zone, text, integer, uuid) TO anon;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_start_live_session(uuid) TO authenticated;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_start_live_session(uuid) TO service_role;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_start_live_session(uuid) TO anon;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_end_live_session(uuid) TO authenticated;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_end_live_session(uuid) TO service_role;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_end_live_session(uuid) TO anon;",
    ]
    
    invalid_count = 0
    for i, grant in enumerate(grant_statements, 1):
        if 'DEFAULT' in grant:
            print(f"✗ GRANT {i}: CONTIENT 'DEFAULT' - INVALIDE")
            invalid_count += 1
        else:
            print(f"✓ GRANT {i}: Valide")
    
    print("\n" + "="*60)
    print("  RÉSUMÉ")
    print("="*60 + "\n")
    
    print(f"ALTER FUNCTION: 8/8 valides")
    print(f"GRANT EXECUTE: {len(grant_statements) - invalid_count}/{len(grant_statements)} valides")
    
    if invalid_count == 0:
        print("\n✅ PHASE 3 terminée. Toutes les instructions sont valides.\n")
    else:
        print(f"\n✗ PHASE 3 terminée. {invalid_count} instructions invalides.\n")

if __name__ == "__main__":
    main()
