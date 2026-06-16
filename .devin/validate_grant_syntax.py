#!/usr/bin/env python3
"""PHASE 2 - Analyser chaque GRANT EXECUTE et confirmer la validité syntaxique"""

def main():
    print("\n" + "="*60)
    print("  PHASE 2 — VALIDATION DE LA SYNTAXE GRANT EXECUTE")
    print("="*60 + "\n")
    
    print("Règle PostgreSQL pour GRANT EXECUTE:")
    print("  - Les arguments dans GRANT EXECUTE doivent inclure SEULEMENT les types de données")
    print("  - Les valeurs DEFAULT ne doivent PAS être incluses")
    print("  - Syntaxe correcte: GRANT EXECUTE ON FUNCTION func_name(arg_type, arg_type) TO role;")
    print("  - Syntaxe incorrecte: GRANT EXECUTE ON FUNCTION func_name(arg_name arg_type DEFAULT value) TO role;")
    print()
    
    print("Analyse du fichier SQL:\n")
    
    # Lignes GRANT du fichier SQL
    grant_lines = [
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_list_assignments() TO authenticated;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_list_assignments() TO service_role;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_list_assignments() TO anon;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_upsert_assignment(p_assignment_id uuid DEFAULT NULL::uuid, p_title text DEFAULT NULL::text, p_description text DEFAULT NULL::text, p_concours_type text DEFAULT NULL::text, p_subject_name text DEFAULT NULL::text, p_assignment_type text DEFAULT 'qcm'::text, p_content jsonb DEFAULT NULL::jsonb, p_attachments jsonb DEFAULT '[]'::jsonb, p_deadline timestamp with time zone DEFAULT NULL::timestamp with time zone, p_max_score integer DEFAULT 20, p_is_published boolean DEFAULT false, p_target_group text DEFAULT 'all'::text) TO authenticated;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_upsert_assignment(p_assignment_id uuid DEFAULT NULL::uuid, p_title text DEFAULT NULL::text, p_description text DEFAULT NULL::text, p_concours_type text DEFAULT NULL::text, p_subject_name text DEFAULT NULL::text, p_assignment_type text DEFAULT 'qcm'::text, p_content jsonb DEFAULT NULL::jsonb, p_attachments jsonb DEFAULT '[]'::jsonb, p_deadline timestamp with time zone DEFAULT NULL::timestamp with time zone, p_max_score integer DEFAULT 20, p_is_published boolean DEFAULT false, p_target_group text DEFAULT 'all'::text) TO service_role;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_upsert_assignment(p_assignment_id uuid DEFAULT NULL::uuid, p_title text DEFAULT NULL::text, p_description text DEFAULT NULL::text, p_concours_type text DEFAULT NULL::text, p_subject_name text DEFAULT NULL::text, p_assignment_type text DEFAULT 'qcm'::text, p_content jsonb DEFAULT NULL::jsonb, p_attachments jsonb DEFAULT '[]'::jsonb, p_deadline timestamp with time zone DEFAULT NULL::timestamp with time zone, p_max_score integer DEFAULT 20, p_is_published boolean DEFAULT false, p_target_group text DEFAULT 'all'::text) TO anon;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_list_submissions(p_assignment_id uuid) TO authenticated;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_list_submissions(p_assignment_id uuid) TO service_role;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_list_submissions(p_assignment_id uuid) TO anon;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_grade_submission(p_submission_id uuid, p_score integer, p_comment text DEFAULT NULL::text) TO authenticated;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_grade_submission(p_submission_id uuid, p_score integer, p_comment text DEFAULT NULL::text) TO service_role;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_grade_submission(p_submission_id uuid, p_score integer, p_comment text DEFAULT NULL::text) TO anon;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_list_live_sessions() TO authenticated;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_list_live_sessions() TO service_role;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_list_live_sessions() TO anon;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_upsert_live_session(p_session_id uuid DEFAULT NULL::uuid, p_title text DEFAULT NULL::text, p_description text DEFAULT NULL::text, p_session_type text DEFAULT 'revision'::text, p_concours_type text DEFAULT NULL::text, p_subject_name text DEFAULT NULL::text, p_provider text DEFAULT 'livekit'::text, p_join_url text DEFAULT NULL::text, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_replay_url text DEFAULT NULL::text, p_max_participants integer DEFAULT 100, p_quiz_template_id uuid DEFAULT NULL::uuid) TO authenticated;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_upsert_live_session(p_session_id uuid DEFAULT NULL::uuid, p_title text DEFAULT NULL::text, p_description text DEFAULT NULL::text, p_session_type text DEFAULT 'revision'::text, p_concours_type text DEFAULT NULL::text, p_subject_name text DEFAULT NULL::text, p_provider text DEFAULT 'livekit'::text, p_join_url text DEFAULT NULL::text, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_replay_url text DEFAULT NULL::text, p_max_participants integer DEFAULT 100, p_quiz_template_id uuid DEFAULT NULL::uuid) TO service_role;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_upsert_live_session(p_session_id uuid DEFAULT NULL::uuid, p_title text DEFAULT NULL::text, p_description text DEFAULT NULL::text, p_session_type text DEFAULT 'revision'::text, p_concours_type text DEFAULT NULL::text, p_subject_name text DEFAULT NULL::text, p_provider text DEFAULT 'livekit'::text, p_join_url text DEFAULT NULL::text, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_replay_url text DEFAULT NULL::text, p_max_participants integer DEFAULT 100, p_quiz_template_id uuid DEFAULT NULL::uuid) TO anon;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_start_live_session(p_session_id uuid) TO authenticated;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_start_live_session(p_session_id uuid) TO service_role;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_start_live_session(p_session_id uuid) TO anon;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_end_live_session(p_session_id uuid) TO authenticated;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_end_live_session(p_session_id uuid) TO service_role;",
        "GRANT EXECUTE ON FUNCTION public.app_prep_teacher_end_live_session(p_session_id uuid) TO anon;",
    ]
    
    invalid_lines = []
    
    for i, line in enumerate(grant_lines, 1):
        if 'DEFAULT' in line:
            print(f"✗ Ligne {i}: CONTIENT 'DEFAULT' - INVALIDE")
            print(f"  {line}")
            invalid_lines.append(line)
        else:
            print(f"✓ Ligne {i}: Valide")
    
    print("\n" + "="*60)
    print("  RÉSUMÉ")
    print("="*60 + "\n")
    
    print(f"Total lignes GRANT: {len(grant_lines)}")
    print(f"Lignes valides: {len(grant_lines) - len(invalid_lines)}")
    print(f"Lignes invalides: {len(invalid_lines)}")
    
    if invalid_lines:
        print("\n✅ PHASE 2 terminée. Lignes invalides détectées.\n")
    else:
        print("\n✅ PHASE 2 terminée. Toutes les lignes sont valides.\n")

if __name__ == "__main__":
    main()
