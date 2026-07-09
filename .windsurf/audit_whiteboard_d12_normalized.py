"""
MISSION D.12 - Audit normalisé des objets whiteboard Supabase.

PRINCIPE: PostgreSQL = source de vérité.
Ce script ne fait PAS d'appels RPC pour récupérer des données SELECT.
Il génère les requêtes SQL à exécuter MANUELLEMENT dans le SQL Editor Supabase.

Les anciens scripts qui utilisaient admin_execute_sql pour des SELECT produisaient
des faux négatifs car admin_execute_sql ne retourne pas les résultats SELECT.
"""

import textwrap
from datetime import datetime


def print_audit_header():
    print("=" * 80)
    print("MISSION D.12 - AUDIT NORMALISÉ WHITEBOARD")
    print("Date:", datetime.now().isoformat())
    print("Source de vérité: PostgreSQL (pg_proc, pg_class, pg_trigger, pg_policies)")
    print("Méthode: Exécuter les requêtes ci-dessous dans le SQL Editor Supabase")
    print("=" * 80)
    print()


def print_proof_block(url, project, sql, source, label):
    print(f"--- PREUVE: {label} ---")
    print(f"URL Supabase: {url}")
    print(f"Projet: {project}")
    print(f"Source: {source}")
    print(f"SQL exact exécuté:")
    print(textwrap.indent(sql.strip(), "    "))
    print()


def main():
    SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
    PROJECT_REF = "thevdfcwlcqzdoybfvgs"

    print_audit_header()

    # Requête 1: fonctions whiteboard dans pg_proc
    sql_functions = """
    SELECT
        n.nspname,
        p.proname,
        pg_get_function_identity_arguments(p.oid) AS signature
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE p.proname ILIKE '%whiteboard%'
    ORDER BY n.nspname, p.proname;
    """
    print_proof_block(
        SUPABASE_URL,
        PROJECT_REF,
        sql_functions,
        "pg_proc",
        "FONCTIONS WHITEBOARD",
    )

    # Requête 2: tables whiteboard
    sql_tables = """
    SELECT
        schemaname,
        relname
    FROM pg_stat_user_tables
    WHERE relname ILIKE '%whiteboard%'
    ORDER BY schemaname, relname;
    """
    print_proof_block(
        SUPABASE_URL,
        PROJECT_REF,
        sql_tables,
        "pg_stat_user_tables",
        "TABLES WHITEBOARD",
    )

    # Requête 3: triggers whiteboard
    sql_triggers = """
    SELECT
        n.nspname,
        c.relname,
        t.tgname
    FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE NOT t.tgisinternal
    AND (
        c.relname ILIKE '%whiteboard%'
        OR t.tgname ILIKE '%whiteboard%'
    )
    ORDER BY n.nspname, c.relname, t.tgname;
    """
    print_proof_block(
        SUPABASE_URL,
        PROJECT_REF,
        sql_triggers,
        "pg_trigger",
        "TRIGGERS WHITEBOARD",
    )

    # Requête 4: policies whiteboard
    sql_policies = """
    SELECT
        schemaname,
        tablename,
        policyname
    FROM pg_policies
    WHERE tablename ILIKE '%whiteboard%'
    ORDER BY schemaname, tablename, policyname;
    """
    print_proof_block(
        SUPABASE_URL,
        PROJECT_REF,
        sql_policies,
        "pg_policies",
        "POLICIES RLS WHITEBOARD",
    )

    # Requête 5: détail complet des fonctions pour comparaison de signatures
    sql_signatures = """
    SELECT
        n.nspname AS schema,
        p.proname AS function_name,
        pg_get_function_arguments(p.oid) AS arguments,
        pg_get_function_result(p.oid) AS return_type
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE p.proname ILIKE '%whiteboard%'
    ORDER BY n.nspname, p.proname;
    """
    print_proof_block(
        SUPABASE_URL,
        PROJECT_REF,
        sql_signatures,
        "pg_proc",
        "SIGNATURES DÉTAILLÉES WHITEBOARD",
    )

    print("=" * 80)
    print("INSTRUCTIONS:")
    print("1. Copier chaque requête SQL ci-dessus")
    print("2. Coller dans le SQL Editor Supabase")
    print("3. Exécuter et capturer le résultat")
    print("4. Documenter: nombre de lignes, premières lignes, source")
    print("5. Comparer avec les contrats Flutter dans .windsurf/flutter_rpc_contracts.md")
    print("=" * 80)


if __name__ == "__main__":
    main()
