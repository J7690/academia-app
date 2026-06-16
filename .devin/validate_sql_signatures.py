#!/usr/bin/env python3
"""PHASE 1 - Analyser chaque ALTER FUNCTION et confirmer la signature exacte"""
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    
    print("\n" + "="*60)
    print("  PHASE 1 — VALIDATION DES SIGNATURES ALTER FUNCTION")
    print("="*60 + "\n")
    
    target_rpcs = [
        'app_prep_teacher_list_assignments',
        'app_prep_teacher_upsert_assignment',
        'app_prep_teacher_list_submissions',
        'app_prep_teacher_grade_submission',
        'app_prep_teacher_list_live_sessions',
        'app_prep_teacher_upsert_live_session',
        'app_prep_teacher_start_live_session',
        'app_prep_teacher_end_live_session',
    ]
    
    validation_results = []
    
    for rpc_name in target_rpcs:
        print(f"\n{rpc_name}:")
        
        # Récupérer la signature exacte depuis pg_proc
        sql = f"""
        SELECT
            pg_get_function_arguments(p.oid) AS args
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'app' AND p.proname = '{rpc_name}'
        """
        
        result = m.execute_sql_auto(sql)
        
        if result.get('success') and result.get('data'):
            db_args = result['data'][0].get('args', '')
            print(f"  Signature DB: {db_args}")
            
            # Signatures attendues dans le fichier SQL
            expected_signatures = {
                'app_prep_teacher_list_assignments': '',
                'app_prep_teacher_upsert_assignment': 'p_assignment_id uuid DEFAULT NULL::uuid, p_title text DEFAULT NULL::text, p_description text DEFAULT NULL::text, p_concours_type text DEFAULT NULL::text, p_subject_name text DEFAULT NULL::text, p_assignment_type text DEFAULT \'qcm\'::text, p_content jsonb DEFAULT NULL::jsonb, p_attachments jsonb DEFAULT \'[]\'::jsonb, p_deadline timestamp with time zone DEFAULT NULL::timestamp with time zone, p_max_score integer DEFAULT 20, p_is_published boolean DEFAULT false, p_target_group text DEFAULT \'all\'::text',
                'app_prep_teacher_list_submissions': 'p_assignment_id uuid',
                'app_prep_teacher_grade_submission': 'p_submission_id uuid, p_score integer, p_comment text DEFAULT NULL::text',
                'app_prep_teacher_list_live_sessions': '',
                'app_prep_teacher_upsert_live_session': 'p_session_id uuid DEFAULT NULL::uuid, p_title text DEFAULT NULL::text, p_description text DEFAULT NULL::text, p_session_type text DEFAULT \'revision\'::text, p_concours_type text DEFAULT NULL::text, p_subject_name text DEFAULT NULL::text, p_provider text DEFAULT \'livekit\'::text, p_join_url text DEFAULT NULL::text, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_replay_url text DEFAULT NULL::text, p_max_participants integer DEFAULT 100, p_quiz_template_id uuid DEFAULT NULL::uuid',
                'app_prep_teacher_start_live_session': 'p_session_id uuid',
                'app_prep_teacher_end_live_session': 'p_session_id uuid',
            }
            
            expected = expected_signatures.get(rpc_name, '')
            print(f"  Signature SQL: {expected}")
            
            # Comparer
            if db_args == expected:
                print(f"  ✓ Signature correspond")
                validation_results.append({'name': rpc_name, 'valid': True, 'error': None})
            else:
                print(f"  ✗ Signature ne correspond pas")
                validation_results.append({'name': rpc_name, 'valid': False, 'error': f"DB: '{db_args}' vs SQL: '{expected}'"})
        else:
            print(f"  ✗ Erreur récupération signature: {result.get('error')}")
            validation_results.append({'name': rpc_name, 'valid': False, 'error': result.get('error')})
    
    # Sauvegarder les résultats
    import json
    with open('C:\\Users\\fasop\\AndroidStudioProjects\\academia\\.windsurf\\logs\\sql_validation_phase1.json', 'w', encoding='utf-8') as f:
        json.dump(validation_results, f, indent=2, ensure_ascii=False)
    
    print("\n✅ PHASE 1 terminée.\n")

if __name__ == "__main__":
    main()
