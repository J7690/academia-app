#!/usr/bin/env python3
"""Audit COMPLET du système Concours — architecture globale Supabase.
Interroge:
1. TOUTES les tables prep_* avec colonnes, types, defaults, nullable
2. TOUTES les RPCs publiques prep (signatures + corps complet)
3. Toutes les FK entre tables prep
4. Tous les triggers sur tables prep
5. Tous les index sur tables prep
6. RLS policies sur tables prep
7. Row counts pour chaque table
8. Bucket storage prep-documents
9. Edge Functions répertoriées (supabase/functions/prep-*)
10. Qui appelle quoi: grep dans les Edge Functions pour trouver les RPCs appelées
"""

from __future__ import annotations
import json, os, re
from pathlib import Path
from datetime import datetime
from typing import Any, Dict, List
import requests
from supabase_auto_manager import SupabaseAutoManager


def run_sql(m: SupabaseAutoManager, label: str, sql: str, timeout: int = 180) -> Dict[str, Any]:
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    resp = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=timeout)
    try:
        data = resp.json()
    except Exception:
        return {"label": label, "http": resp.status_code, "ok": False, "raw": (resp.text or "")[:2000]}
    if isinstance(data, dict):
        rows = data.get("rows")
        return {"label": label, "ok": bool(data.get("ok")),
                "rows_count": len(rows) if isinstance(rows, list) else 0,
                "rows": rows if isinstance(rows, list) else [],
                "error": data.get("error")}
    if isinstance(data, list):
        return {"label": label, "ok": True, "rows_count": len(data), "rows": data, "error": None}
    return {"label": label, "ok": False, "rows": [], "rows_count": 0, "error": "unexpected"}


def scan_edge_functions() -> Dict[str, Any]:
    """Scan local Edge Functions for prep-* and extract which RPCs they call."""
    ef_dir = Path("supabase/functions")
    result = {}
    if not ef_dir.exists():
        return {"error": "supabase/functions not found"}
    
    for d in sorted(ef_dir.iterdir()):
        if not d.is_dir() or not d.name.startswith("prep-"):
            continue
        index_file = d / "index.ts"
        if not index_file.exists():
            result[d.name] = {"exists": True, "index_ts": False}
            continue
        
        content = index_file.read_text(encoding="utf-8", errors="replace")
        lines = len(content.splitlines())
        
        # Find all RPC calls
        rpc_calls = re.findall(r"\.rpc\(\s*['\"]([^'\"]+)['\"]", content)
        # Find all fetch calls to openrouter
        openrouter_calls = re.findall(r"fetch\(\s*['\"]([^'\"]*openrouter[^'\"]*)['\"]", content)
        # Find environment variables used
        env_vars = re.findall(r"Deno\.env\.get\(\s*['\"]([^'\"]+)['\"]", content)
        # Find model names
        models = re.findall(r"model:\s*['\"]([^'\"]+)['\"]", content)
        models += re.findall(r"EMBEDDING_MODEL\s*=\s*['\"]([^'\"]+)['\"]", content)
        
        result[d.name] = {
            "exists": True,
            "index_ts": True,
            "lines": lines,
            "rpc_calls": sorted(set(rpc_calls)),
            "openrouter_endpoints": sorted(set(openrouter_calls)),
            "env_vars": sorted(set(env_vars)),
            "models_used": sorted(set(models)),
        }
    
    return result


def main() -> int:
    m = SupabaseAutoManager()
    audit: Dict[str, Any] = {"timestamp": datetime.utcnow().isoformat() + "Z"}

    # ─── 1. ALL prep tables with columns ────────────────────────────
    print("[1/10] Tables prep_* colonnes...")
    audit["tables_columns"] = run_sql(m, "tables_columns", """
        SELECT c.table_name, c.column_name, c.ordinal_position,
               c.data_type, c.udt_name, c.is_nullable, c.column_default
        FROM information_schema.columns c
        WHERE c.table_schema = 'app' AND c.table_name LIKE 'prep_%'
        ORDER BY c.table_name, c.ordinal_position
    """)

    # ─── 2. ALL prep RPCs signatures ────────────────────────────────
    print("[2/10] RPCs prep signatures...")
    audit["rpcs_signatures"] = run_sql(m, "rpcs_signatures", """
        SELECT p.proname AS name,
               pg_get_function_arguments(p.oid) AS args,
               pg_get_function_result(p.oid) AS returns
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname LIKE '%prep%'
        ORDER BY p.proname
    """)

    # ─── 3. FK constraints ──────────────────────────────────────────
    print("[3/10] FK constraints...")
    audit["fk_constraints"] = run_sql(m, "fk_constraints", """
        SELECT tc.table_name, tc.constraint_name, kcu.column_name,
               ccu.table_name AS fk_table, ccu.column_name AS fk_column
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
            ON tc.constraint_name = kcu.constraint_name AND tc.table_schema = kcu.table_schema
        JOIN information_schema.constraint_column_usage ccu
            ON ccu.constraint_name = tc.constraint_name AND ccu.table_schema = tc.table_schema
        WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_schema = 'app'
          AND tc.table_name LIKE 'prep_%'
        ORDER BY tc.table_name
    """)

    # ─── 4. Triggers ────────────────────────────────────────────────
    print("[4/10] Triggers...")
    audit["triggers"] = run_sql(m, "triggers", """
        SELECT trigger_name, event_manipulation, event_object_table,
               action_statement, action_timing
        FROM information_schema.triggers
        WHERE event_object_schema = 'app'
          AND event_object_table LIKE 'prep_%'
        ORDER BY event_object_table, trigger_name
    """)

    # ─── 5. Indexes ─────────────────────────────────────────────────
    print("[5/10] Indexes...")
    audit["indexes"] = run_sql(m, "indexes", """
        SELECT schemaname, tablename, indexname, indexdef
        FROM pg_indexes
        WHERE schemaname = 'app' AND tablename LIKE 'prep_%'
        ORDER BY tablename, indexname
    """)

    # ─── 6. RLS policies ───────────────────────────────────────────
    print("[6/10] RLS policies...")
    audit["rls_policies"] = run_sql(m, "rls_policies", """
        SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
        FROM pg_policies
        WHERE schemaname = 'app' AND tablename LIKE 'prep_%'
        ORDER BY tablename, policyname
    """)

    # ─── 7. Row counts ─────────────────────────────────────────────
    print("[7/10] Row counts...")
    audit["row_counts"] = run_sql(m, "row_counts", """
        SELECT 'prep_subjects' AS tbl, count(*) AS cnt FROM app.prep_subjects
        UNION ALL SELECT 'prep_questions', count(*) FROM app.prep_questions
        UNION ALL SELECT 'prep_question_choices', count(*) FROM app.prep_question_choices
        UNION ALL SELECT 'prep_source_documents', count(*) FROM app.prep_source_documents
        UNION ALL SELECT 'prep_doc_chunks', count(*) FROM app.prep_doc_chunks
        UNION ALL SELECT 'prep_ai_generations', count(*) FROM app.prep_ai_generations
        UNION ALL SELECT 'prep_attempts', count(*) FROM app.prep_attempts
        UNION ALL SELECT 'prep_student_progress', count(*) FROM app.prep_student_progress
        UNION ALL SELECT 'prep_ai_usage_logs', count(*) FROM app.prep_ai_usage_logs
        UNION ALL SELECT 'prep_ai_conversations', count(*) FROM app.prep_ai_conversations
        UNION ALL SELECT 'prep_student_weaknesses', count(*) FROM app.prep_student_weaknesses
        ORDER BY tbl
    """)

    # ─── 8. Storage buckets ─────────────────────────────────────────
    print("[8/10] Storage buckets...")
    audit["storage_buckets"] = run_sql(m, "storage_buckets", """
        SELECT id, name, public, file_size_limit, allowed_mime_types
        FROM storage.buckets
        WHERE name LIKE '%prep%' OR name LIKE '%concours%'
        ORDER BY name
    """)

    # ─── 9. Edge Functions scan ─────────────────────────────────────
    print("[9/10] Edge Functions scan...")
    audit["edge_functions"] = scan_edge_functions()

    # ─── 10. RPCs full definitions (the import/RAG ones) ────────────
    print("[10/10] RPCs critiques (import + RAG)...")
    audit["rpcs_critical_defs"] = run_sql(m, "rpcs_critical_defs", """
        SELECT p.proname AS name,
               pg_get_function_arguments(p.oid) AS args,
               pg_get_functiondef(p.oid) AS definition
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
          AND p.proname IN (
              'app_admin_prep_import_questions_json',
              'app_admin_prep_import_text_bulk',
              'app_prep_get_rag_chunks',
              'app_prep_semantic_search',
              'app_prep_get_quiz_questions',
              'app_prep_get_adaptive_quiz'
          )
        ORDER BY p.proname
    """)

    # Save
    log_dir = Path(".windsurf/logs")
    log_dir.mkdir(parents=True, exist_ok=True)
    out_path = log_dir / "audit_concours_full.json"
    out_path.write_text(json.dumps(audit, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"\n[OK] Saved {out_path.as_posix()}")
    print("\n=== RÉSUMÉ ===")
    for k, v in audit.items():
        if k == "timestamp":
            continue
        if isinstance(v, dict) and "rows_count" in v:
            err = f" ERROR={v['error']}" if v.get('error') else ""
            print(f"  {k}: {v['rows_count']} lignes{err}")
        elif isinstance(v, dict) and k == "edge_functions":
            print(f"  {k}: {len(v)} Edge Functions")
            for ef_name, ef_data in v.items():
                if isinstance(ef_data, dict) and ef_data.get("exists"):
                    rpcs = ef_data.get("rpc_calls", [])
                    models = ef_data.get("models_used", [])
                    print(f"    {ef_name}: {ef_data.get('lines',0)} lignes, RPCs={rpcs}, models={models}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
