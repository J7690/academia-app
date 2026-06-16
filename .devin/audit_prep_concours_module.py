#!/usr/bin/env python3
"""Audit exhaustif du module Préparation Concours — Tables, RPCs, RLS, données."""

from __future__ import annotations
import json
import requests
from datetime import datetime

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}

def sql(query: str) -> dict:
    try:
        clean = " ".join(query.split())  # collapse whitespace to single line
        r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql",
                          headers=HEADERS, json={"p_sql": clean}, timeout=30)
        if r.status_code == 200:
            body = r.json()
            if isinstance(body, dict) and body.get("ok"):
                return {"ok": True, "rows": body.get("rows", []), "mode": body.get("mode")}
            return {"ok": False, "error": str(body)}
        return {"ok": False, "error": f"HTTP {r.status_code}: {r.text[:500]}"}
    except Exception as e:
        return {"ok": False, "error": str(e)}

def main():
    results = {}
    print("=" * 70)
    print("AUDIT MODULE PRÉPARATION CONCOURS — Supabase")
    print(f"Date: {datetime.now().isoformat()}")
    print("=" * 70)

    # 1. Tables prep dans schema app
    print("\n[1] Tables contenant 'prep' dans schema app...")
    q1 = sql("""
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE table_schema = 'app'
          AND table_name LIKE '%prep%'
        ORDER BY table_name
    """)
    print(json.dumps(q1, indent=2, ensure_ascii=False))
    results["prep_tables"] = q1

    # 2. Toutes les tables contenant 'question', 'quiz', 'flashcard', 'exam', 'badge', 'ai_' dans schema app
    print("\n[2] Tables associées (question, quiz, flashcard, exam, badge, ai_)...")
    q2 = sql("""
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE table_schema = 'app'
          AND (
            table_name LIKE '%question%'
            OR table_name LIKE '%quiz%'
            OR table_name LIKE '%flashcard%'
            OR table_name LIKE '%exam%'
            OR table_name LIKE '%badge%'
            OR table_name LIKE '%ai_%'
            OR table_name LIKE '%entitlement%'
            OR table_name LIKE '%source_document%'
            OR table_name LIKE '%ai_generation%'
            OR table_name LIKE '%concours%'
          )
        ORDER BY table_name
    """)
    print(json.dumps(q2, indent=2, ensure_ascii=False))
    results["related_tables"] = q2

    # 3. RPCs contenant 'prep' 
    print("\n[3] RPCs contenant 'prep'...")
    q3 = sql("""
        SELECT routine_schema, routine_name, 
               data_type AS return_type
        FROM information_schema.routines
        WHERE routine_type = 'FUNCTION'
          AND routine_name LIKE '%prep%'
        ORDER BY routine_name
    """)
    print(json.dumps(q3, indent=2, ensure_ascii=False))
    results["prep_rpcs"] = q3

    # 4. Colonnes des tables prep
    print("\n[4] Colonnes des tables prep...")
    # Get table names first
    if q1.get("ok") and isinstance(q1.get("rows"), list):
        for row in q1["rows"]:
            tname = row.get("table_name")
            if not tname:
                continue
            print(f"\n  --- Colonnes de app.{tname} ---")
            qc = sql(f"""
                SELECT column_name, data_type, is_nullable, column_default
                FROM information_schema.columns
                WHERE table_schema = 'app' AND table_name = '{tname}'
                ORDER BY ordinal_position
            """)
            print(json.dumps(qc, indent=2, ensure_ascii=False))
            results[f"columns_{tname}"] = qc

    # 5. RLS policies sur les tables prep
    print("\n[5] Politiques RLS sur les tables prep...")
    q5 = sql("""
        SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
        FROM pg_policies
        WHERE schemaname = 'app'
          AND (
            tablename LIKE '%prep%'
            OR tablename LIKE '%question%'
            OR tablename LIKE '%quiz%'
            OR tablename LIKE '%flashcard%'
            OR tablename LIKE '%exam_paper%'
            OR tablename LIKE '%badge%'
            OR tablename LIKE '%ai_conversation%'
            OR tablename LIKE '%ai_message%'
            OR tablename LIKE '%entitlement%'
            OR tablename LIKE '%source_document%'
            OR tablename LIKE '%ai_generation%'
          )
        ORDER BY tablename, policyname
    """)
    print(json.dumps(q5, indent=2, ensure_ascii=False))
    results["rls_policies"] = q5

    # 6. Row counts for prep tables
    print("\n[6] Nombre de lignes dans les tables prep...")
    if q1.get("ok") and isinstance(q1.get("rows"), list):
        for row in q1["rows"]:
            tname = row.get("table_name")
            if not tname:
                continue
            qr = sql(f"SELECT COUNT(*) AS cnt FROM app.{tname}")
            cnt = qr.get('rows', [{}])[0].get('cnt', '?') if qr.get('ok') else 'ERR'
            print(f"  app.{tname}: {cnt}")
            results[f"count_{tname}"] = qr

    # 7. Edge Functions liées
    print("\n[7] Edge Function prep-tutor-chat — vérification...")
    try:
        r = requests.options(f"{URL}/functions/v1/prep-tutor-chat", timeout=10)
        print(f"  HTTP {r.status_code}")
        results["edge_function_prep_tutor"] = {"status": r.status_code}
    except Exception as e:
        print(f"  Erreur: {e}")
        results["edge_function_prep_tutor"] = {"error": str(e)}

    # 8. Signatures des RPCs prep (paramètres)
    print("\n[8] Paramètres des RPCs prep...")
    q8 = sql("""
        SELECT p.specific_name, p.parameter_name, p.data_type, p.parameter_mode
        FROM information_schema.parameters p
        JOIN information_schema.routines r ON r.specific_name = p.specific_name
        WHERE r.routine_name LIKE '%prep%'
          AND p.parameter_name IS NOT NULL
        ORDER BY r.routine_name, p.ordinal_position
    """)
    print(json.dumps(q8, indent=2, ensure_ascii=False))
    results["rpc_parameters"] = q8

    # 9. Triggers sur tables prep
    print("\n[9] Triggers sur tables prep...")
    q9 = sql("""
        SELECT trigger_schema, trigger_name, event_manipulation, 
               event_object_schema, event_object_table, action_statement
        FROM information_schema.triggers
        WHERE event_object_schema = 'app'
          AND (
            event_object_table LIKE '%prep%'
            OR event_object_table LIKE '%question%'
            OR event_object_table LIKE '%quiz%'
            OR event_object_table LIKE '%flashcard%'
            OR event_object_table LIKE '%badge%'
          )
        ORDER BY event_object_table, trigger_name
    """)
    print(json.dumps(q9, indent=2, ensure_ascii=False))
    results["triggers"] = q9

    # 10. Storage buckets liés
    print("\n[10] Buckets Storage liés aux concours...")
    q10 = sql("""
        SELECT id, name, public, file_size_limit, allowed_mime_types
        FROM storage.buckets
        WHERE name LIKE '%prep%' OR name LIKE '%concours%' OR name LIKE '%exam%'
        ORDER BY name
    """)
    print(json.dumps(q10, indent=2, ensure_ascii=False))
    results["storage_buckets"] = q10

    # Save full results
    out_path = __import__('pathlib').Path(__file__).parent / "logs" / "audit_prep_concours_module.json"
    out_path.parent.mkdir(exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2, ensure_ascii=False, default=str)
    print(f"\n✅ Résultats sauvegardés: {out_path}")

if __name__ == "__main__":
    main()
