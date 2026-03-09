#!/usr/bin/env python3
"""Applique automatiquement les scripts SQL des modules étudiants (offres, candidatures,
 cours, Bobodo) dans la base Supabase du projet Academia.

Ce script respecte l'infrastructure .windsurf existante en réutilisant
SupabaseCredentials / SupabaseAuditor pour se connecter directement à PostgreSQL.

Utilisation (à lancer depuis la racine du projet ou n'importe où) :

    python .windsurf/apply_academia_student_schema.py

Prérequis :
- Les identifiants Supabase doivent déjà être initialisés via supabase_credentials.py
- Le paquet psycopg2 doit être installé ("pip install psycopg2-binary" si nécessaire)
"""

from pathlib import Path
from typing import List

from supabase_credentials import get_supabase_auditor


SQL_FILES: List[str] = [
    "supabase_student_offers.sql",
    "supabase_student_applications.sql",
    "supabase_student_courses.sql",
    "supabase_bobodo.sql",
]


def apply_sql_script(script_path: Path) -> bool:
    """Exécute l'ensemble d'un script SQL via la connexion PostgreSQL directe."""
    auditor = get_supabase_auditor()

    # Initialiser la connexion si nécessaire
    if auditor.connection is None:
        auditor.initialize()

    if auditor.connection is None:
        print("❌ Impossible d'initialiser la connexion PostgreSQL (vérifie psycopg2 et tes identifiants).")
        return False

    try:
        sql = script_path.read_text(encoding="utf-8")
    except Exception as e:  # lecture fichier
        print(f"❌ Impossible de lire {script_path.name}: {e}")
        return False

    print(f"\n=== Application du script SQL : {script_path.name} ===")

    try:
        cursor = auditor.connection.cursor()
        cursor.execute(sql)
        auditor.connection.commit()
        cursor.close()
        print(f"✅ Script {script_path.name} exécuté avec succès")
        return True
    except Exception as e:
        auditor.connection.rollback()
        print(f"❌ Erreur lors de l'exécution de {script_path.name}: {e}")
        return False


def main() -> int:
    winds_dir = Path(__file__).parent

    print("🤖 Application automatique du schéma Academia (modules étudiants + Bobodo)")
    print("=" * 72)

    all_ok = True

    for filename in SQL_FILES:
        script_path = winds_dir / filename
        if not script_path.exists():
            print(f"❌ Fichier introuvable dans .windsurf : {filename}")
            all_ok = False
            continue

        if not apply_sql_script(script_path):
            all_ok = False

    # Fermer proprement l'auditor
    auditor = get_supabase_auditor()
    auditor.close()

    print("\n" + "=" * 72)
    if all_ok:
        print("🎉 Tous les scripts SQL Academia ont été appliqués correctement.")
        print("   Les RPC app_* et les tables app.* devraient maintenant exister.")
        return 0
    else:
        print("⚠️ Certains scripts n'ont pas pu être exécutés. Consulte les messages ci-dessus.")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
