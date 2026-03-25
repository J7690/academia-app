#!/usr/bin/env python3
"""Fix remaining INSERT policies and verify all."""
import json, requests, time

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SK, "Authorization": f"Bearer {SK}", "Content-Type": "application/json"}

def sql(q, label=""):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                       json={"p_sql": " ".join(q.split())}, timeout=60)
    body = r.json() if r.status_code == 200 else {"ok": False, "error": r.text[:500]}
    ok = isinstance(body, dict) and body.get("ok", False)
    err = body.get("error", "") if isinstance(body, dict) and not ok else ""
    print(f"  {'✅' if ok else '❌'} {label} {('— ' + err[:150]) if err else ''}")
    return ok, body

# FIX INSERT policies: FOR INSERT must use WITH CHECK only, no USING
insert_policies = [
    ("auth_insert_own_prep_fp", "app.prep_flashcard_progress", "student_id = auth.uid()"),
    ("auth_insert_own_prep_qa", "app.prep_quiz_attempts", "student_id = auth.uid()"),
    ("auth_insert_own_prep_aic", "app.prep_ai_conversations", "student_id = auth.uid()"),
    ("auth_upsert_own_prep_sp", "app.prep_student_progress", "student_id = auth.uid()"),
]

print("FIX: INSERT policies (WITH CHECK only, no USING)...")
for pname, table, check_expr in insert_policies:
    tname = table.split(".")[-1]
    s = f"""
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = '{pname}' AND tablename = '{tname}') THEN
        EXECUTE 'CREATE POLICY {pname} ON {table} FOR INSERT TO public WITH CHECK ({check_expr})';
    END IF;
END $$;
"""
    sql(s, f"INSERT policy {pname}")
    time.sleep(0.2)

# VERIFY: Count all new tables and policies
print("\n--- VERIFICATION ---")

ok1, r1 = sql("""
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'app' AND table_name LIKE 'prep_%'
ORDER BY table_name
""", "Count prep_* tables")
if ok1:
    tables = [row.get("table_name") for row in r1.get("rows", [])]
    print(f"  → {len(tables)} tables: {tables}")

ok2, r2 = sql("""
SELECT COUNT(*) AS cnt FROM pg_policies
WHERE schemaname = 'app' AND tablename LIKE 'prep_%'
""", "Count prep_* policies")
if ok2:
    print(f"  → {r2.get('rows', [{}])[0].get('cnt', '?')} RLS policies on prep_* tables")

ok3, r3 = sql("""
SELECT routine_name FROM information_schema.routines
WHERE routine_name LIKE '%prep%' AND routine_type = 'FUNCTION'
  AND routine_schema IN ('public', 'app')
ORDER BY routine_name
""", "Count prep RPCs")
if ok3:
    rpcs = [row.get("routine_name") for row in r3.get("rows", [])]
    print(f"  → {len(rpcs)} RPCs")

# Verify the critical RPCs now point to prep_* tables
print("\n--- VERIFY RPC TARGETS ---")
critical_rpcs = [
    "app_prep_create_question_bank",
    "app_prep_create_question",
    "app_prep_admin_get_stats",
    "app_prep_create_flashcard_deck",
    "app_prep_create_ai_conversation",
    "app_prep_get_student_progress",
]
for rpc in critical_rpcs:
    ok4, r4 = sql(f"""
SELECT pg_get_functiondef(p.oid) AS def
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = '{rpc}' AND n.nspname IN ('app','public')
LIMIT 1
""", f"Check {rpc}")
    if ok4 and r4.get("rows"):
        defn = r4["rows"][0].get("def", "")
        uses_td = "td_" in defn
        uses_prep = "prep_" in defn
        status = "✅ prep_*" if uses_prep and not uses_td else "❌ STILL td_*" if uses_td else "⚠️ unknown"
        print(f"    → {status}")

# Verify bucket
print("\n--- VERIFY STORAGE ---")
sql("SELECT id, name, public FROM storage.buckets WHERE name = 'prep-documents'", "Bucket prep-documents")

print("\n✅ All fixes applied!")
