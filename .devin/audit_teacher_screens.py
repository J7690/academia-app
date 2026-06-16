#!/usr/bin/env python3
"""Analyse des écrans enseignant vs backend - basé sur l'audit Flutter précédent"""
import json

def main():
    print("\n" + "="*60)
    print("  PHASE 6 — INVENTAIRE ÉCRANS ENSEIGNANT VS BACKEND")
    print("="*60 + "\n")
    
    # Basé sur les fichiers Flutter analysés et les RPCs Supabase trouvées
    
    teacher_screens = [
        {
            "écran": "TeacherTdAssignmentsScreen",
            "provider": "TeacherTdAssignmentsProvider",
            "rpc_appelée": "app_td_teacher_get_dashboard",
            "table_utilisée": "td_assignments, td_sessions, td_enrollments",
            "existe_rpc": "✅ OUI (public)",
            "existe_tables": "✅ OUI (app)",
            "statut": "COMPLET"
        },
        {
            "écran": "TeacherTdExercisesScreen",
            "provider": "TeacherTdAssignmentsProvider",
            "rpc_appelée": "app_td_teacher_list_exercises, app_td_teacher_create_exercise",
            "table_utilisée": "td_assignments, td_questions",
            "existe_rpc": "✅ OUI (public)",
            "existe_tables": "✅ OUI (app)",
            "statut": "COMPLET"
        },
        {
            "écran": "TeacherTdLocalGroupsScreen",
            "provider": "TeacherTdAssignmentsProvider",
            "rpc_appelée": "app_td_teacher_list_local_groups",
            "table_utilisée": "td_local_groups, td_local_group_members",
            "existe_rpc": "✅ OUI (public)",
            "existe_tables": "✅ OUI (app)",
            "statut": "COMPLET"
        },
        {
            "écran": "TeacherTdResourcesScreen",
            "provider": "TeacherTdAssignmentsProvider",
            "rpc_appelée": "app_td_teacher_list_resources, app_td_teacher_add_resource",
            "table_utilisée": "td_resources",
            "existe_rpc": "✅ OUI (public)",
            "existe_tables": "✅ OUI (app)",
            "statut": "COMPLET"
        },
        {
            "écran": "TeacherPrepAssignmentsScreen",
            "provider": "TeacherPrepAssignmentsProvider",
            "rpc_appelée": "app_prep_teacher_list_assignments, app_prep_teacher_upsert_assignment",
            "table_utilisée": "prep_assignments, prep_assignment_submissions",
            "existe_rpc": "❌ NON (seulement dans app, pas dans public)",
            "existe_tables": "✅ OUI (app)",
            "statut": "PARTIEL (tables OK, RPC pas accessibles)"
        },
        {
            "écran": "TeacherPrepLiveSessionsScreen",
            "provider": "TeacherPrepLiveSessionsProvider",
            "rpc_appelée": "app_prep_teacher_list_live_sessions, app_prep_teacher_upsert_live_session",
            "table_utilisée": "prep_live_sessions, prep_live_participants",
            "existe_rpc": "❌ NON (seulement dans app, pas dans public)",
            "existe_tables": "✅ OUI (app)",
            "statut": "PARTIEL (tables OK, RPC pas accessibles)"
        },
        {
            "écran": "InstructorDashboardScreen",
            "provider": "InstructorOnlineCoursesProvider",
            "rpc_appelée": "app_ci_list_my_online_courses",
            "table_utilisée": "online_courses, online_course_instructors",
            "existe_rpc": "✅ OUI (public)",
            "existe_tables": "✅ OUI (app)",
            "statut": "COMPLET"
        },
        {
            "écran": "InstructorCourseForumScreen",
            "provider": "InstructorOnlineCourseForumProvider",
            "rpc_appelée": "app_ci_list_online_course_forum_threads, app_ci_add_online_course_forum_message",
            "table_utilisée": "online_course_forum_threads, online_course_forum_messages",
            "existe_rpc": "✅ OUI (public)",
            "existe_tables": "✅ OUI (app)",
            "statut": "COMPLET"
        },
        {
            "écran": "InstructorRevenueTab",
            "provider": "InstructorOnlineCoursesProvider",
            "rpc_appelée": "app_instructor_get_my_balance, app_instructor_request_payout",
            "table_utilisée": "actor_balances",
            "existe_rpc": "✅ OUI (public)",
            "existe_tables": "✅ OUI (app)",
            "statut": "COMPLET"
        },
    ]
    
    print("TABLEAU DE COMPARAISON:\n")
    print(f"{'Écran':<35} {'RPC':<40} {'Tables':<30} {'Statut':<20}")
    print("-" * 125)
    
    for screen in teacher_screens:
        name = screen["écran"]
        rpc = screen["rpc_appelée"][:35] + "..." if len(screen["rpc_appelée"]) > 35 else screen["rpc_appelée"]
        tables = screen["table_utilisée"][:25] + "..." if len(screen["table_utilisée"]) > 25 else screen["table_utilisée"]
        status = screen["statut"]
        
        print(f"{name:<35} {rpc:<40} {tables:<30} {status:<20}")
    
    print("\n" + "="*60)
    print("  RÉSUMÉ PHASE 6")
    print("="*60 + "\n")
    
    complete = sum(1 for s in teacher_screens if s["statut"] == "COMPLET")
    partial = sum(1 for s in teacher_screens if s["statut"] == "PARTIEL")
    inexistant = sum(1 for s in teacher_screens if s["statut"] == "INEXISTANT")
    
    print(f"  Écrans complets: {complete}")
    print(f"  Écrans partiels: {partial}")
    print(f"  Écrans inexistants: {inexistant}")
    print(f"  Total: {len(teacher_screens)}")
    
    print("\n  PROBLÈMES IDENTIFIÉS:")
    print("  - TeacherPrepAssignmentsScreen: RPCs app_prep_teacher_* existent dans app mais PAS dans public")
    print("  - TeacherPrepLiveSessionsScreen: RPCs app_prep_teacher_* existent dans app mais PAS dans public")
    print("  → Les tables existent mais les RPCs ne sont pas accessibles via PostgREST")
    
    print("\n✅ Inventaire des écrans enseignant terminé.\n")

if __name__ == "__main__":
    main()
