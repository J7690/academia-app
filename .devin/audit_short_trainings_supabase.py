#!/usr/bin/env python3
"""Audit Supabase pour le module formations courtes: tables, RPCs, données."""
import requests
import os
from supabase_auto_manager import SupabaseAutoManager

def q(m, sql):
    r = requests.post(f"{m.url}/rest/v1/rpc/execute_sql",
        headers=m.headers, json={"sql_query": sql}, timeout=30)
    try:
        data = r.json()
        return data if isinstance(data, list) else []
    except:
        return []

def section(t): print(f"\n{'='*60}\n  {t}\n{'='*60}")

def main():
    m = SupabaseAutoManager()
    log = []
    def p(msg):
        print(msg)
        log.append(msg)

    p("\n🔍 AUDIT — Module Formations Courtes (Short Trainings)\n")

    # 1. Tables
    section("1. TABLES short_training* (schema app)")
    tables = q(m,
        "SELECT table_name FROM information_schema.tables "
        "WHERE table_schema='app' AND table_name LIKE '%short_training%' ORDER BY table_name")
    p(f"  {len(tables)} tables:")
    for t in tables:
        tn = t.get('table_name','')
        count = q(m, f"SELECT COUNT(*) AS n FROM app.{tn}")
        n = count[0].get('n', '?') if count else '?'
        p(f"    app.{tn:45s} {n} lignes")

    # 2. Structure tables clés
    for table in ['short_trainings', 'short_training_sessions', 'short_training_registrations', 'short_training_messages']:
        section(f"2. Structure app.{table}")
        cols = q(m,
            f"SELECT column_name, udt_name, column_default FROM information_schema.columns "
            f"WHERE table_schema='app' AND table_name='{table}' ORDER BY ordinal_position")
        if cols:
            for c in cols:
                p(f"    {c.get('column_name',''):30s} {c.get('udt_name',''):15s} {c.get('column_default','') or ''}")
        else:
            p(f"    ❌ Table n'existe pas")

    # 3. RPCs short_training dans public
    section("3. RPCs short_training (public)")
    pub = q(m,
        "SELECT p.proname, pg_get_function_arguments(p.oid) AS args "
        "FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
        "WHERE n.nspname='public' AND p.proname LIKE '%short_training%' ORDER BY p.proname")
    p(f"  {len(pub)} RPCs:")
    for r in pub:
        p(f"    {r.get('proname','')}")

    # 4. RPCs short_training dans app
    section("4. RPCs short_training (app)")
    app_rpcs = q(m,
        "SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
        "WHERE n.nspname='app' AND p.proname LIKE '%short_training%' ORDER BY p.proname")
    p(f"  {len(app_rpcs)} RPCs:")
    for r in app_rpcs:
        p(f"    {r.get('proname','')}")

    # 5. Test accessibilité API REST
    section("5. TEST ACCESSIBILITÉ API REST")
    rpcs_to_test = [
        'app_admin_list_short_trainings',
        'app_admin_upsert_short_training',
        'app_admin_upsert_short_training_session',
        'app_admin_list_short_training_registrations',
        'app_list_public_short_training_sessions',
        'app_list_my_short_trainings',
        'app_register_short_training',
        'app_register_short_training_full',
        'app_list_short_training_messages_for_admin',
        'app_list_short_training_messages_for_student',
        'app_add_short_training_message_from_admin_to_student',
        'app_add_short_training_message_from_student',
    ]
    for rpc in rpcs_to_test:
        try:
            resp = requests.post(f"{m.url}/rest/v1/rpc/{rpc}",
                headers=m.headers, json={}, timeout=10)
            code = resp.status_code
            icon = "✅" if code in [200, 400] else "❌"
            label = "OK" if code == 200 else "AUTH" if code == 400 else "404"
            p(f"    {icon} {rpc} → {code} ({label})")
        except:
            p(f"    ❌ {rpc} → ERREUR")

    # 6. Données
    section("6. DONNÉES EXISTANTES")
    for table in ['short_trainings', 'short_training_sessions', 'short_training_registrations', 'short_training_messages']:
        try:
            count = q(m, f"SELECT COUNT(*) AS n FROM app.{table}")
            n = count[0].get('n', '?') if count else '?'
            p(f"    app.{table:40s} {n} lignes")
        except:
            p(f"    app.{table:40s} ❌")

    # 7. Paiements — tables existantes?
    section("7. TABLES PAIEMENT")
    pay_tables = q(m,
        "SELECT table_name FROM information_schema.tables "
        "WHERE table_schema='app' AND (table_name LIKE '%payment%' OR table_name LIKE '%paiement%' "
        "OR table_name LIKE '%transaction%' OR table_name LIKE '%ligdicash%') ORDER BY table_name")
    if pay_tables:
        for t in pay_tables:
            tn = t.get('table_name','')
            count = q(m, f"SELECT COUNT(*) AS n FROM app.{tn}")
            n = count[0].get('n', '?') if count else '?'
            p(f"    app.{tn:40s} {n} lignes")
    else:
        p("    Aucune table de paiement trouvée")

    # 8. RPCs paiement
    section("8. RPCs PAIEMENT")
    pay_rpcs = q(m,
        "SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
        "WHERE (n.nspname='public' OR n.nspname='app') "
        "AND (p.proname LIKE '%payment%' OR p.proname LIKE '%ligdicash%' OR p.proname LIKE '%paiement%') "
        "ORDER BY p.proname")
    if pay_rpcs:
        for r in pay_rpcs:
            p(f"    {r.get('proname','')}")
    else:
        p("    Aucune RPC de paiement trouvée")

    # VERDICT
    section("VERDICT")
    p("""
  MODULE FORMATIONS COURTES — État actuel:
  
  Flutter (COMPLET):
  - Admin: CRUD formations + sessions + inscriptions + messages (1045 lignes)
  - Étudiant: Catalogue + inscription détaillée + messages (716 lignes)
  - 4 providers: admin trainings, student trainings, admin messages, student messages
  
  À VÉRIFIER dans Supabase:
  - Tables short_training_* existent-elles?
  - RPCs accessibles via PostgREST?
  - Tables de paiement pour LigdiCash?
    """)

    p("✅ Audit terminé.\n")

    # Save log
    log_dir = r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\logs"
    os.makedirs(log_dir, exist_ok=True)
    with open(os.path.join(log_dir, "audit_short_trainings.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(log))
    p(f"📄 Log: {log_dir}/audit_short_trainings.txt")

if __name__ == "__main__":
    main()
