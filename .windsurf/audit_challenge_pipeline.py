#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Audit CIBLE du pipeline video Challenge (LECTURE SEULE).
Verifie: tables video, distribution des statuts renditions/jobs,
sessions d'upload, signature reelle de app_videoasset_register_uploaded_source."""
import requests
import json

BASE = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {"apikey": KEY, "Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}


def _call(rpc, sql):
    return requests.post(f"{BASE}/{rpc}", headers=HEADERS, json={"p_sql": sql.strip()}, timeout=40)


def run(label, sql):
    print(f"\n--- {label} ---")
    for rpc in ("execute_sql", "admin_execute_sql"):
        try:
            r = _call(rpc, sql)
            data = r.json()
        except Exception as e:
            print(f"  [{rpc}] ERROR {e}")
            continue
        rows = data.get("rows") if isinstance(data, dict) else None
        if rows is not None:
            print(f"  [{rpc}] {len(rows)} rows:")
            for row in rows:
                print(f"    {row}")
            return
        # No rows key: print raw once for the last attempt
        if rpc == "admin_execute_sql":
            print(f"  [{rpc}] raw: {json.dumps(data, ensure_ascii=False)[:1500]}")


print("=" * 80)
print("AUDIT PIPELINE VIDEO CHALLENGE - LECTURE SEULE")
print("=" * 80)

run("1. Tables video presentes", """
SELECT tablename FROM pg_tables
WHERE schemaname='app' AND tablename IN
('video_assets','video_sources','video_renditions','video_processing_jobs','upload_sessions')
ORDER BY tablename""")

run("2. Compteurs globaux", """
SELECT
 (SELECT COUNT(*) FROM app.video_assets) AS assets,
 (SELECT COUNT(*) FROM app.video_sources) AS sources,
 (SELECT COUNT(*) FROM app.video_renditions) AS renditions,
 (SELECT COUNT(*) FROM app.video_processing_jobs) AS jobs""")

run("3. video_assets par statut", """
SELECT status, COUNT(*) FROM app.video_assets GROUP BY status ORDER BY 2 DESC""")

run("4. video_renditions par (rendition_key, status)", """
SELECT rendition_key, status, COUNT(*)
FROM app.video_renditions GROUP BY rendition_key, status ORDER BY 1,2""")

run("5. video_processing_jobs par (job_type, status)", """
SELECT job_type, status, COUNT(*)
FROM app.video_processing_jobs GROUP BY job_type, status ORDER BY 3 DESC""")

run("6. Jobs en attente les plus anciens (worker actif ?)", """
SELECT id, status, created_at, updated_at
FROM app.video_processing_jobs
WHERE status IN ('queued','pending','processing')
ORDER BY created_at ASC LIMIT 10""")

run("7. upload_sessions par statut", """
SELECT status, COUNT(*) FROM app.upload_sessions GROUP BY status ORDER BY 2 DESC""")

run("8. upload_sessions recentes", """
SELECT id, status, file_size, uploaded_bytes, created_at, expires_at
FROM app.upload_sessions ORDER BY created_at DESC LIMIT 8""")

run("9. SIGNATURE REELLE app_videoasset_register_uploaded_source", """
SELECT n.nspname AS schema, p.proname, pg_get_function_arguments(p.oid) AS args
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE p.proname='app_videoasset_register_uploaded_source'""")

run("10. SIGNATURE app_videoasset_create_upload_intent", """
SELECT n.nspname AS schema, p.proname, pg_get_function_arguments(p.oid) AS args
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE p.proname='app_videoasset_create_upload_intent'""")

run("11. Derniers video_assets (origin/status)", """
SELECT id, origin, status, created_at
FROM app.video_assets ORDER BY created_at DESC LIMIT 8""")

run("12. Colonnes de video_assets (verifier poster_url)", """
SELECT column_name FROM information_schema.columns
WHERE table_schema='app' AND table_name='video_assets' ORDER BY ordinal_position""")

run("13. Triggers sur video_sources / video_assets (enqueue jobs ?)", """
SELECT event_object_table, trigger_name, action_timing, event_manipulation
FROM information_schema.triggers
WHERE trigger_schema='app'
AND event_object_table IN ('video_sources','video_assets','video_processing_jobs')
ORDER BY event_object_table, trigger_name""")

run("14. Existe-t-il des jobs transcode_resolution ?", """
SELECT job_type, COUNT(*) FROM app.video_processing_jobs
WHERE job_type='transcode_resolution' GROUP BY job_type""")

run("15. Causes d'echec worker (derniers errors)", """
SELECT job_type, status, LEFT(COALESCE(error,''),160) AS err, COUNT(*) AS n
FROM app.video_processing_jobs
WHERE status='failed'
GROUP BY job_type, status, LEFT(COALESCE(error,''),160)
ORDER BY n DESC LIMIT 12""")

run("16. Delai moyen source->ready (perf pipeline serveur)", """
SELECT job_type,
 ROUND(AVG(EXTRACT(EPOCH FROM (updated_at-created_at)))::numeric,1) AS avg_sec,
 ROUND(MAX(EXTRACT(EPOCH FROM (updated_at-created_at)))::numeric,1) AS max_sec
FROM app.video_processing_jobs
WHERE status='done' GROUP BY job_type ORDER BY avg_sec DESC""")

print("\n" + "=" * 80)
print("FIN AUDIT")
print("=" * 80)
