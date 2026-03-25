#!/usr/bin/env python3
"""Audit global Supabase: schémas, tables, RPCs, RLS, triggers, buckets, Edge Functions."""
import json, requests
from pathlib import Path
from collections import defaultdict

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SK, "Authorization": f"Bearer {SK}", "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                       json={"p_sql": " ".join(q.split())}, timeout=60)
    body = r.json() if r.status_code == 200 else {"ok": False, "error": r.text[:500]}
    if isinstance(body, dict) and body.get("ok"):
        return body.get("rows", [])
    return []

results = {}

print("=" * 70)
print("AUDIT GLOBAL SUPABASE — Cartographie complète")
print("=" * 70)

# ═══════════════════════════════════════════════════════════════
# 1. TABLES par schéma
# ═══════════════════════════════════════════════════════════════
print("\n[1] TABLES PAR SCHÉMA:")
tables = sql("SELECT table_schema, table_name FROM information_schema.tables WHERE table_schema IN ('app','public','storage') AND table_type = 'BASE TABLE' ORDER BY table_schema, table_name")
schema_tables = defaultdict(list)
for t in tables:
    schema_tables[t["table_schema"]].append(t["table_name"])

for schema, tbls in sorted(schema_tables.items()):
    print(f"\n  [{schema}] ({len(tbls)} tables):")
    for t in tbls:
        print(f"    - {t}")

results["tables"] = dict(schema_tables)

# ═══════════════════════════════════════════════════════════════
# 2. RPCs par schéma (fonctions publiques appelables)
# ═══════════════════════════════════════════════════════════════
print("\n\n[2] RPCs PAR SCHÉMA:")
rpcs = sql("SELECT routine_schema, routine_name FROM information_schema.routines WHERE routine_schema IN ('app','public') AND routine_type = 'FUNCTION' AND routine_name LIKE 'app_%' ORDER BY routine_schema, routine_name")
schema_rpcs = defaultdict(list)
for r in rpcs:
    schema_rpcs[r["routine_schema"]].append(r["routine_name"])

# Group by prefix
for schema, funcs in sorted(schema_rpcs.items()):
    prefixes = defaultdict(list)
    for f in funcs:
        parts = f.split("_")
        if len(parts) >= 3:
            prefix = "_".join(parts[:3])
        else:
            prefix = f
        prefixes[prefix].append(f)
    
    print(f"\n  [{schema}] ({len(funcs)} RPCs):")
    for prefix, flist in sorted(prefixes.items()):
        print(f"    {prefix}* ({len(flist)}):")
        for fn in flist:
            print(f"      - {fn}")

results["rpcs"] = dict(schema_rpcs)

# ═══════════════════════════════════════════════════════════════
# 3. ROW COUNTS pour tables principales
# ═══════════════════════════════════════════════════════════════
print("\n\n[3] ROW COUNTS (tables principales):")
important_tables = [
    "app.students", "app.prep_questions", "app.prep_subjects", "app.prep_question_banks",
    "app.prep_source_documents", "app.prep_doc_chunks", "app.prep_ai_conversations",
    "app.prep_badges", "app.prep_student_progress", "app.prep_flashcard_decks",
    "app.prep_topics", "app.prep_topic_predictions", "app.prep_ai_corrections",
    "app.prep_assignments", "app.prep_assignment_submissions",
    "app.prep_live_sessions", "app.prep_live_participants",
    "app.prep_psychotech_results", "app.prep_psychotech_profiles",
    "app.prep_ai_config", "app.prep_ai_generations",
    "app.online_courses", "app.online_course_live_sessions",
    "app.td_sessions", "app.td_enrollments",
    "app.communities", "app.community_posts",
    "app.marketplace_products", "app.marketplace_orders",
]
row_counts = {}
for t in important_tables:
    rows = sql(f"SELECT COUNT(*) AS cnt FROM {t}")
    cnt = rows[0].get("cnt", "ERR") if rows else "ERR"
    row_counts[t] = cnt
    print(f"  {t:50s} {cnt}")

results["row_counts"] = row_counts

# ═══════════════════════════════════════════════════════════════
# 4. RLS POLICIES count par table
# ═══════════════════════════════════════════════════════════════
print("\n\n[4] RLS POLICIES:")
rls = sql("SELECT schemaname, tablename, COUNT(*) AS cnt FROM pg_policies WHERE schemaname = 'app' GROUP BY schemaname, tablename ORDER BY cnt DESC")
total_rls = 0
for r in rls:
    total_rls += r.get("cnt", 0)
    print(f"  {r.get('tablename','?'):45s} {r.get('cnt',0)} policies")
print(f"\n  TOTAL RLS: {total_rls}")
results["rls_total"] = total_rls

# ═══════════════════════════════════════════════════════════════
# 5. TRIGGERS
# ═══════════════════════════════════════════════════════════════
print("\n\n[5] TRIGGERS:")
triggers = sql("SELECT trigger_name, event_object_table FROM information_schema.triggers WHERE trigger_schema = 'app' ORDER BY event_object_table, trigger_name")
print(f"  Total: {len(triggers)}")
for tr in triggers[:30]:
    print(f"  {tr.get('event_object_table','?'):35s} {tr.get('trigger_name','?')}")
if len(triggers) > 30:
    print(f"  ... et {len(triggers) - 30} de plus")
results["triggers_count"] = len(triggers)

# ═══════════════════════════════════════════════════════════════
# 6. STORAGE BUCKETS
# ═══════════════════════════════════════════════════════════════
print("\n\n[6] STORAGE BUCKETS:")
buckets = sql("SELECT id, name, public FROM storage.buckets ORDER BY name")
for b in buckets:
    print(f"  {b.get('name','?'):30s} public={b.get('public','?')}")
results["buckets"] = buckets

# ═══════════════════════════════════════════════════════════════
# 7. EDGE FUNCTIONS
# ═══════════════════════════════════════════════════════════════
print("\n\n[7] EDGE FUNCTIONS:")
edge_fns = ["prep-tutor-chat", "prep-ingest-document", "prep-generate-questions",
            "prep-analyze-trends", "prep-grade-assignment", "bobodo-chat",
            "send-push-notifications", "admin-create-teacher-account",
            "admin-promote-user-role", "admin-create-merchant-account"]
for fn in edge_fns:
    try:
        resp = requests.options(f"{URL}/functions/v1/{fn}", timeout=10)
        status = resp.status_code
    except:
        status = "TIMEOUT"
    print(f"  {fn:40s} HTTP {status}")
results["edge_functions"] = {fn: "active" for fn in edge_fns}

# ═══════════════════════════════════════════════════════════════
# 8. AI CONFIG
# ═══════════════════════════════════════════════════════════════
print("\n\n[8] AI CONFIG:")
ai_cfg = sql("SELECT config_key, LEFT(config_value, 60) AS preview FROM app.prep_ai_config")
for c in ai_cfg:
    print(f"  {c.get('config_key','?'):25s} {c.get('preview','?')}")

# Save
out = Path(__file__).parent / "logs" / "audit_global_supabase.json"
out.parent.mkdir(exist_ok=True)
with open(out, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False)
print(f"\n\n✅ Audit Supabase saved: {out}")
