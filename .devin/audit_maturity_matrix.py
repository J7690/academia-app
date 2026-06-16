#!/usr/bin/env python3
"""Matrice de maturité des modules (TD/Prépa/Orientation/Lives/Exercices/Correction/Suivi)"""
import json

def main():
    print("\n" + "="*60)
    print("  PHASE 8 — MATRICE DE MATURITÉ")
    print("="*60 + "\n")
    
    # Matrice de maturité basée sur les audits précédents
    modules = [
        {
            "module": "TD",
            "flutter_ui": "COMPLET",
            "provider": "COMPLET",
            "rpc": "COMPLET (app_td_teacher_*, app_td_student_*)",
            "tables": "COMPLET (td_*)",
            "rls": "COMPLET",
            "données": "COMPLET (questions, assignments, sessions)",
            "statut": "COMPLET"
        },
        {
            "module": "Prépa Concours",
            "flutter_ui": "COMPLET",
            "provider": "COMPLET",
            "rpc": "PARTIEL (app_prep_teacher_* dans app, PAS dans public)",
            "tables": "COMPLET (prep_*)",
            "rls": "COMPLET",
            "données": "COMPLET (questions, assignments, lives)",
            "statut": "PARTIEL (RPC teacher non accessibles)"
        },
        {
            "module": "Orientation",
            "flutter_ui": "INEXISTANT",
            "provider": "INEXISTANT",
            "rpc": "INEXISTANT",
            "tables": "INEXISTANT",
            "rls": "INEXISTANT",
            "données": "INEXISTANT",
            "statut": "INEXISTANT"
        },
        {
            "module": "Lives (TD)",
            "flutter_ui": "COMPLET",
            "provider": "COMPLET",
            "rpc": "COMPLET (app_td_teacher_*, app_td_student_*)",
            "tables": "COMPLET (td_sessions, td_session_occurrences)",
            "rls": "COMPLET",
            "données": "COMPLET",
            "statut": "COMPLET"
        },
        {
            "module": "Lives (Prépa)",
            "flutter_ui": "COMPLET",
            "provider": "COMPLET",
            "rpc": "PARTIEL (app_prep_teacher_* dans app, PAS dans public)",
            "tables": "COMPLET (prep_live_sessions, prep_live_participants)",
            "rls": "COMPLET",
            "données": "COMPLET",
            "statut": "PARTIEL (RPC teacher non accessibles)"
        },
        {
            "module": "Exercices (TD)",
            "flutter_ui": "COMPLET",
            "provider": "COMPLET",
            "rpc": "COMPLET (app_td_teacher_*, app_td_student_*)",
            "tables": "COMPLET (td_assignments, td_assignment_submissions)",
            "rls": "COMPLET",
            "données": "COMPLET",
            "statut": "COMPLET"
        },
        {
            "module": "Exercices (Prépa)",
            "flutter_ui": "COMPLET",
            "provider": "COMPLET",
            "rpc": "PARTIEL (app_prep_teacher_* dans app, PAS dans public)",
            "tables": "COMPLET (prep_assignments, prep_assignment_submissions)",
            "rls": "COMPLET",
            "données": "COMPLET",
            "statut": "PARTIEL (RPC teacher non accessibles)"
        },
        {
            "module": "Correction (TD)",
            "flutter_ui": "COMPLET",
            "provider": "COMPLET",
            "rpc": "COMPLET (app_td_teacher_grade_exercise, td-scan-subject Edge Function)",
            "tables": "COMPLET (td_assignment_submissions, td_scan_logs)",
            "rls": "COMPLET",
            "données": "COMPLET",
            "statut": "COMPLET"
        },
        {
            "module": "Correction (Prépa)",
            "flutter_ui": "COMPLET",
            "provider": "COMPLET",
            "rpc": "PARTIEL (app_prep_teacher_grade_submission dans app, PAS dans public)",
            "tables": "COMPLET (prep_assignment_submissions)",
            "rls": "COMPLET",
            "données": "COMPLET",
            "statut": "PARTIEL (RPC teacher non accessible)"
        },
        {
            "module": "Suivi étudiant (TD)",
            "flutter_ui": "COMPLET",
            "provider": "COMPLET",
            "rpc": "COMPLET (app_td_teacher_list_students, app_td_student_get_progress)",
            "tables": "COMPLET (td_student_progress, td_student_profiles)",
            "rls": "COMPLET",
            "données": "COMPLET",
            "statut": "COMPLET"
        },
        {
            "module": "Suivi étudiant (Prépa)",
            "flutter_ui": "COMPLET",
            "provider": "COMPLET",
            "rpc": "COMPLET (app_prep_get_student_progress, app_prep_get_weakness_analysis)",
            "tables": "COMPLET (prep_student_progress, prep_student_weaknesses)",
            "rls": "COMPLET",
            "données": "COMPLET",
            "statut": "COMPLET"
        },
        {
            "module": "Cours en ligne",
            "flutter_ui": "COMPLET",
            "provider": "COMPLET",
            "rpc": "COMPLET (app_ci_*, app_student_*)",
            "tables": "COMPLET (online_courses, online_course_enrollments)",
            "rls": "COMPLET",
            "données": "COMPLET",
            "statut": "COMPLET"
        },
    ]
    
    print("MATRICE DE MATURITÉ:\n")
    print(f"{'Module':<20} {'UI':<10} {'Provider':<10} {'RPC':<15} {'Tables':<10} {'RLS':<10} {'Données':<10} {'Statut':<20}")
    print("-" * 105)
    
    for module in modules:
        name = module["module"]
        ui = module["flutter_ui"]
        provider = module["provider"]
        rpc = module["rpc"][:12] + "..." if len(module["rpc"]) > 12 else module["rpc"]
        tables = module["tables"]
        rls = module["rls"]
        data = module["données"]
        status = module["statut"]
        
        print(f"{name:<20} {ui:<10} {provider:<10} {rpc:<15} {tables:<10} {rls:<10} {data:<10} {status:<20}")
    
    print("\n" + "="*60)
    print("  RÉSUMÉ PHASE 8")
    print("="*60 + "\n")
    
    complete = sum(1 for m in modules if m["statut"] == "COMPLET")
    partial = sum(1 for m in modules if m["statut"] == "PARTIEL")
    inexistant = sum(1 for m in modules if m["statut"] == "INEXISTANT")
    
    print(f"  Modules complets: {complete}")
    print(f"  Modules partiels: {partial}")
    print(f"  Modules inexistants: {inexistant}")
    print(f"  Total: {len(modules)}")
    
    print("\n  OBSERVATIONS:")
    print("  - TD: 100% complet (tous les composants opérationnels)")
    print("  - Prépa Concours: 80% complet (tables OK, RPC teacher non accessibles via PostgREST)")
    print("  - Orientation: 0% (module non implémenté)")
    print("  - Cours en ligne: 100% complet")
    
    print("\n  PROBLÈME PRINCIPAL:")
    print("  - Les RPCs app_prep_teacher_* existent dans le schéma app mais PAS dans public")
    print("  - Conséquence: Flutter ne peut pas appeler ces RPCs via PostgREST")
    print("  - Solution nécessaire: Déplacer les RPCs app_prep_teacher_* dans le schéma public")
    
    print("\n✅ Matrice de maturité terminée.\n")

if __name__ == "__main__":
    main()
