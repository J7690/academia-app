#!/usr/bin/env python3
"""Analyse des écrans étudiant vs backend - basé sur l'audit Flutter précédent"""
import json

def main():
    print("\n" + "="*60)
    print("  PHASE 7 — INVENTAIRE ÉCRANS ÉTUDIANT VS BACKEND")
    print("="*60 + "\n")
    
    # Basé sur les fichiers Flutter analysés et les RPCs Supabase trouvées
    
    student_screens = [
        {
            "écran": "TdHomeTab",
            "provider": "TdHomeProvider",
            "rpc_appelée": "app_td_student_create_request, app_td_student_list_subjects",
            "table_utilisée": "td_student_requests, td_programs",
            "existe_rpc": "✅ OUI (public)",
            "existe_tables": "✅ OUI (app)",
            "statut": "COMPLET"
        },
        {
            "écran": "TdQuizTab",
            "provider": "TdQuizProvider",
            "rpc_appelée": "app_td_student_list_subjects, app_td_student_get_quiz_questions",
            "table_utilisée": "td_questions, td_quiz_templates",
            "existe_rpc": "✅ OUI (public)",
            "existe_tables": "✅ OUI (app)",
            "statut": "COMPLET"
        },
        {
            "écran": "TdExercisesTab",
            "provider": "TdExercisesProvider",
            "rpc_appelée": "app_td_student_list_exercises, app_td_student_submit_exercise",
            "table_utilisée": "td_assignments, td_assignment_submissions",
            "existe_rpc": "✅ OUI (public)",
            "existe_tables": "✅ OUI (app)",
            "statut": "COMPLET"
        },
        {
            "écran": "TdLocalGroupsTab",
            "provider": "TdLocalGroupsProvider",
            "rpc_appelée": "app_td_student_list_local_groups, app_td_student_join_group",
            "table_utilisée": "td_local_groups, td_local_group_members",
            "existe_rpc": "✅ OUI (public)",
            "existe_tables": "✅ OUI (app)",
            "statut": "COMPLET"
        },
        {
            "écran": "PrepQuizTab",
            "provider": "PrepQuizProvider",
            "rpc_appelée": "app_prep_get_adaptive_quiz, app_prep_save_quiz_attempt",
            "table_utilisée": "prep_questions, prep_quiz_attempts",
            "existe_rpc": "✅ OUI (public)",
            "existe_tables": "✅ OUI (app)",
            "statut": "COMPLET"
        },
        {
            "écran": "PrepExercisesTab",
            "provider": "PrepExercisesProvider",
            "rpc_appelée": "app_prep_student_list_assignments, app_prep_student_submit_assignment",
            "table_utilisée": "prep_assignments, prep_assignment_submissions",
            "existe_rpc": "✅ OUI (public)",
            "existe_tables": "✅ OUI (app)",
            "statut": "COMPLET"
        },
        {
            "écran": "PrepLivesTab",
            "provider": "PrepLivesProvider",
            "rpc_appelée": "app_prep_student_list_live_sessions, app_prep_student_join_live_session",
            "table_utilisée": "prep_live_sessions, prep_live_participants",
            "existe_rpc": "⚠️ PARTIEL (list OK, join NON)",
            "existe_tables": "✅ OUI (app)",
            "statut": "PARTIEL (join_live_session manquante)"
        },
        {
            "écran": "PrepPsychotechTab",
            "provider": "PrepPsychotechProvider",
            "rpc_appelée": "app_prep_get_psychotech_profile, app_prep_save_psychotech_result",
            "table_utilisée": "prep_psychotech_profiles, prep_psychotech_results",
            "existe_rpc": "✅ OUI (public)",
            "existe_tables": "✅ OUI (app)",
            "statut": "COMPLET"
        },
        {
            "écran": "OrientationScreen",
            "provider": "OrientationProvider",
            "rpc_appelée": "app_student_get_orientation_results",
            "table_utilisée": "orientation_results",
            "existe_rpc": "❌ NON (non trouvée)",
            "existe_tables": "❌ NON (non trouvée)",
            "statut": "INEXISTANT"
        },
        {
            "écran": "StudentOnlineCoursesScreen",
            "provider": "StudentOnlineCoursesProvider",
            "rpc_appelée": "app_student_list_my_online_courses, app_student_enroll_online_course",
            "table_utilisée": "online_courses, online_course_enrollments",
            "existe_rpc": "✅ OUI (public)",
            "existe_tables": "✅ OUI (app)",
            "statut": "COMPLET"
        },
    ]
    
    print("TABLEAU DE COMPARAISON:\n")
    print(f"{'Écran':<35} {'RPC':<40} {'Tables':<30} {'Statut':<20}")
    print("-" * 125)
    
    for screen in student_screens:
        name = screen["écran"]
        rpc = screen["rpc_appelée"][:35] + "..." if len(screen["rpc_appelée"]) > 35 else screen["rpc_appelée"]
        tables = screen["table_utilisée"][:25] + "..." if len(screen["table_utilisée"]) > 25 else screen["table_utilisée"]
        status = screen["statut"]
        
        print(f"{name:<35} {rpc:<40} {tables:<30} {status:<20}")
    
    print("\n" + "="*60)
    print("  RÉSUMÉ PHASE 7")
    print("="*60 + "\n")
    
    complete = sum(1 for s in student_screens if s["statut"] == "COMPLET")
    partial = sum(1 for s in student_screens if s["statut"] == "PARTIEL")
    inexistant = sum(1 for s in student_screens if s["statut"] == "INEXISTANT")
    
    print(f"  Écrans complets: {complete}")
    print(f"  Écrans partiels: {partial}")
    print(f"  Écrans inexistants: {inexistant}")
    print(f"  Total: {len(student_screens)}")
    
    print("\n  PROBLÈMES IDENTIFIÉS:")
    print("  - PrepLivesTab: app_prep_student_join_live_session n'existe PAS dans public")
    print("  - OrientationScreen: RPCs et tables orientation non trouvées")
    
    print("\n✅ Inventaire des écrans étudiant terminé.\n")

if __name__ == "__main__":
    main()
