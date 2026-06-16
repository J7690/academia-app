#!/usr/bin/env python3
"""Cartographie des relations entre tables (enseignants/étudiants/TD/prépa/orientation/lives/assignments/submissions)"""
import requests
import json
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    
    print("\n" + "="*60)
    print("  PHASE 4 — CARTOGRAPHIE DES RELATIONS")
    print("="*60 + "\n")
    
    # Tables clés à analyser
    key_tables = [
        'profiles',
        'td_teachers',
        'td_teacher_profiles',
        'td_students',
        'td_student_profiles',
        'td_enrollments',
        'td_local_groups',
        'td_local_group_members',
        'td_assignments',
        'td_assignment_submissions',
        'td_sessions',
        'td_session_occurrences',
        'prep_assignments',
        'prep_assignment_submissions',
        'prep_live_sessions',
        'prep_live_participants',
        'online_courses',
        'online_course_enrollments',
        'online_course_instructors',
        'online_course_live_sessions',
        'online_course_live_session_participants',
    ]
    
    print("ANALYSE DES CLÉS ÉTRANGÈRES:\n")
    
    for table in key_tables:
        # Vérifier si la table existe
        sql_check = f"""
        SELECT COUNT(*) as count
        FROM information_schema.tables
        WHERE table_schema = 'app' AND table_name = '{table}'
        """
        
        result_check = m.execute_sql_auto(sql_check)
        
        if result_check.get('success') and result_check.get('data'):
            count = result_check['data'][0].get('count', 0)
            if count == 0:
                continue  # Table n'existe pas
        
        # Récupérer les clés étrangères
        sql = f"""
        SELECT
            tc.table_name,
            tc.constraint_name,
            kcu.column_name,
            ccu.table_name AS foreign_table_name,
            ccu.column_name AS foreign_column_name
        FROM information_schema.table_constraints AS tc
        JOIN information_schema.key_column_usage AS kcu
            ON tc.constraint_name = kcu.constraint_name
            AND tc.table_schema = kcu.table_schema
        JOIN information_schema.constraint_column_usage AS ccu
            ON ccu.constraint_name = tc.constraint_name
            AND ccu.table_schema = tc.table_schema
        WHERE tc.constraint_type = 'FOREIGN KEY'
        AND tc.table_schema = 'app'
        AND tc.table_name = '{table}'
        """
        
        result = m.execute_sql_auto(sql)
        
        if result.get('success'):
            fks = result.get('data', [])
            if fks:
                print(f"\n{'='*60}")
                print(f"  TABLE: {table}")
                print(f"{'='*60}")
                
                for fk in fks:
                    col = fk.get('column_name', '?')
                    ref_table = fk.get('foreign_table_name', '?')
                    ref_col = fk.get('foreign_column_name', '?')
                    
                    print(f"  {col} → {ref_table}.{ref_col}")
            else:
                # Pas de FK, mais la table existe
                pass
    
    print("\n" + "="*60)
    print("  GRAPHE LOGIQUE MÉTIER")
    print("="*60 + "\n")
    
    # Afficher un graphe simplifié basé sur les relations connues
    print("ENSEIGNANTS → ÉTUDIANTS:")
    print("  td_teachers → td_enrollments (teacher_id)")
    print("  td_teacher_profiles → profiles (user_id)")
    print("  td_local_groups → td_teachers (teacher_id)")
    print()
    
    print("ÉTUDIANTS → TD:")
    print("  td_students → td_enrollments (student_id)")
    print("  td_student_profiles → profiles (user_id)")
    print("  td_enrollments → td_programs (program_id)")
    print("  td_assignments → td_enrollments (enrollment_id)")
    print("  td_assignment_submissions → td_assignments (assignment_id)")
    print("  td_assignment_submissions → td_students (student_id)")
    print()
    
    print("ENSEIGNANTS → PRÉPA CONCOURS:")
    print("  prep_assignments → profiles (teacher_id)")
    print("  prep_assignment_submissions → prep_assignments (assignment_id)")
    print("  prep_assignment_submissions → profiles (student_id)")
    print("  prep_live_sessions → profiles (teacher_id)")
    print("  prep_live_participants → prep_live_sessions (session_id)")
    print("  prep_live_participants → profiles (student_id)")
    print()
    
    print("ENSEIGNANTS → COURS EN LIGNE:")
    print("  online_courses → profiles (instructor_id)")
    print("  online_course_enrollments → online_courses (course_id)")
    print("  online_course_enrollments → profiles (student_id)")
    print("  online_course_instructors → online_courses (course_id)")
    print("  online_course_instructors → profiles (instructor_id)")
    print("  online_course_live_sessions → online_courses (course_id)")
    print("  online_course_live_session_participants → online_course_live_sessions (session_id)")
    print("  online_course_live_session_participants → profiles (user_id)")
    
    print("\n✅ Cartographie des relations terminée.\n")

if __name__ == "__main__":
    main()
