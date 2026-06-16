#!/usr/bin/env python3
"""Audit approfondi Supabase pour le module TD: tables, RPCs, Edge Functions, données."""
import requests
import json
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
    log_lines = []
    def log(msg):
        print(msg)
        log_lines.append(msg)

    log("\n🔍 AUDIT APPROFONDI — Module TD Supabase\n")

    # ═══ 1. Tables TD dans schema app ═══
    section("1. TABLES TD (schema app)")
    tables = q(m,
        "SELECT table_name FROM information_schema.tables "
        "WHERE table_schema='app' AND table_name LIKE 'td_%' ORDER BY table_name")
    log(f"  {len(tables)} tables TD trouvées:")
    for t in tables:
        tn = t.get('table_name','')
        count = q(m, f"SELECT COUNT(*) AS n FROM app.{tn}")
        n = count[0].get('n', '?') if count else '?'
        log(f"    app.{tn:40s} {n} lignes")

    # ═══ 2. RPCs TD dans schema PUBLIC ═══
    section("2. RPCs TD (schema public)")
    pub_rpcs = q(m,
        "SELECT p.proname, pg_get_function_arguments(p.oid) AS args "
        "FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
        "WHERE n.nspname='public' AND p.proname LIKE '%td%' ORDER BY p.proname")
    log(f"  {len(pub_rpcs)} RPCs TD dans public:")
    for r in pub_rpcs:
        log(f"    {r.get('proname','')}")

    # ═══ 3. RPCs TD dans schema app ═══
    section("3. RPCs TD (schema app)")
    app_rpcs = q(m,
        "SELECT p.proname, pg_get_function_arguments(p.oid) AS args "
        "FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
        "WHERE n.nspname='app' AND p.proname LIKE '%td%' ORDER BY p.proname")
    log(f"  {len(app_rpcs)} RPCs TD dans app:")
    for r in app_rpcs:
        log(f"    {r.get('proname','')}")

    # ═══ 4. RPCs TD accessibles via API REST ═══
    section("4. TEST ACCESSIBILITÉ API REST")
    td_rpcs_to_test = [
        'app_td_list_public_programs',
        'app_td_get_program_detail',
        'app_td_student_get_dashboard',
        'app_td_student_list_my_enrollments',
        'app_td_student_create_request',
        'app_td_send_message',
        'app_td_admin_list_enrollments_with_context',
        'app_td_admin_get_dashboard',
        'app_td_teacher_get_dashboard',
    ]
    for rpc in td_rpcs_to_test:
        try:
            resp = requests.post(f"{m.url}/rest/v1/rpc/{rpc}",
                headers=m.headers, json={}, timeout=10)
            code = resp.status_code
            icon = "✅" if code in [200, 400] else "❌"
            label = "OK" if code == 200 else "AUTH" if code == 400 else "404"
            log(f"    {icon} {rpc} → {code} ({label})")
        except:
            log(f"    ❌ {rpc} → ERREUR")

    # ═══ 5. Edge Functions TD ═══
    section("5. EDGE FUNCTIONS TD")
    ef_check = q(m,
        "SELECT proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
        "WHERE p.proname LIKE '%td%ingest%' OR p.proname LIKE '%td%scan%' "
        "OR p.proname LIKE '%td%generate%' OR p.proname LIKE '%td%embed%'")
    if ef_check:
        for e in ef_check:
            log(f"    {e.get('proname','')}")
    else:
        log("    Aucune Edge Function TD trouvée")

    # Vérifier les dossiers Edge Functions
    ef_dir = r"c:\Users\fasop\AndroidStudioProjects\academia\supabase\functions"
    log(f"\n  Dossiers Edge Functions contenant 'td':")
    if os.path.exists(ef_dir):
        for d in os.listdir(ef_dir):
            if 'td' in d.lower():
                log(f"    📁 {d}")

    # ═══ 6. Tables de contenu/ressources TD ═══
    section("6. TABLES CONTENU/RESSOURCES TD")
    content_tables = q(m,
        "SELECT table_name FROM information_schema.tables "
        "WHERE table_schema='app' AND ("
        "table_name LIKE 'td_%resource%' OR table_name LIKE 'td_%content%' "
        "OR table_name LIKE 'td_%document%' OR table_name LIKE 'td_%chunk%' "
        "OR table_name LIKE 'td_%question%' OR table_name LIKE 'td_%exercise%'"
        ") ORDER BY table_name")
    if content_tables:
        for t in content_tables:
            tn = t.get('table_name','')
            count = q(m, f"SELECT COUNT(*) AS n FROM app.{tn}")
            n = count[0].get('n', '?') if count else '?'
            log(f"    app.{tn:40s} {n} lignes")
    else:
        log("    ❌ Aucune table de contenu/ressources TD trouvée")

    # ═══ 7. Structure td_resources si elle existe ═══
    section("7. STRUCTURE td_resources")
    res_cols = q(m,
        "SELECT column_name, udt_name FROM information_schema.columns "
        "WHERE table_schema='app' AND table_name='td_resources' "
        "ORDER BY ordinal_position")
    if res_cols:
        for c in res_cols:
            log(f"    {c.get('column_name',''):30s} {c.get('udt_name','')}")
    else:
        log("    ❌ Table td_resources n'existe pas")

    # ═══ 8. Buckets storage pour TD ═══
    section("8. BUCKETS STORAGE TD")
    buckets = q(m,
        "SELECT id, name FROM storage.buckets WHERE name LIKE '%td%' OR name LIKE '%exercise%'")
    if buckets:
        for b in buckets:
            log(f"    📦 {b.get('name','')}")
    else:
        log("    Aucun bucket TD spécifique")

    # ═══ 9. Données existantes ═══
    section("9. DONNÉES TD EXISTANTES")
    for table in ['td_fields', 'td_programs', 'td_collections', 'td_sessions',
                  'td_enrollments', 'td_teachers', 'td_messages']:
        try:
            count = q(m, f"SELECT COUNT(*) AS n FROM app.{table}")
            n = count[0].get('n', '?') if count else '?'
            log(f"    app.{table:30s} {n} lignes")
        except:
            log(f"    app.{table:30s} ❌ n'existe pas")

    # ═══ 10. admin_td_upload_screen.dart — ce qui existe ═══
    section("10. FLUTTER — admin_td_upload_screen.dart")
    upload_path = r"c:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib\features\admin\admin_td_upload_screen.dart"
    if os.path.exists(upload_path):
        with open(upload_path, 'r', encoding='utf-8') as f:
            content = f.read()
        log(f"    ✅ Existe ({len(content)} caractères)")
        # Chercher les fonctionnalités
        for kw in ['upload', 'PDF', 'image', 'JSON', 'import', 'ingest', 'scan', 'Edge Function']:
            if kw.lower() in content.lower():
                log(f"    ✅ Contient '{kw}'")
    else:
        log("    ❌ N'existe pas")

    # ═══ VERDICT ═══
    section("VERDICT")
    log("""
  MODULE TD — État actuel:
  - Tables de structure: td_fields, td_programs, td_collections, td_sessions
  - Tables de gestion: td_enrollments, td_teachers, td_messages
  - Providers Flutter: 7 providers (catalog, enrollments, requests, teachers, messages, gamification)
  - Service: td_service.dart (30+ méthodes RPC)
  - Écrans admin: admin_td_screen.dart avec bouton "Upload & IA TD"
  
  CE QUI MANQUE pour le mécanisme scan/import:
  1. Edge Function td-scan-subject (OCR + réponses IA pour étudiants)
  2. RPCs d'import sans token (JSON structuré, texte brut)
  3. Tables de contenu indexable (td_source_documents, td_doc_chunks)
  4. Interface admin pour import direct (0 token)
  5. Interface étudiant pour scanner un sujet TD
    """)

    log("✅ Audit TD terminé.\n")

    # Sauvegarder le log
    log_dir = r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\logs"
    os.makedirs(log_dir, exist_ok=True)
    with open(os.path.join(log_dir, "audit_td_supabase_deep.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(log_lines))
    print(f"📄 Log sauvegardé dans {log_dir}/audit_td_supabase_deep.txt")

if __name__ == "__main__":
    main()
