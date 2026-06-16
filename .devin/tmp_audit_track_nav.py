#!/usr/bin/env python3
"""Audit forensique app_track_navigation_event - Recherche Supabase"""
import requests, json
url='https://thevdfcwlcqzdoybfvgs.supabase.co'
key='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h={'apikey':key,'Authorization':f'Bearer {key}','Content-Type':'application/json'}

def rpc_sql(sql):
    r=requests.post(f'{url}/rest/v1/rpc/admin_execute_sql',headers=h,json={'p_sql':sql},timeout=30)
    return r.json()

lines=[]
lines.append("=== AUDIT FORENSIQUE app_track_navigation_event ===\n")

# PHASE 3 — Recherche fonctions Supabase (tous schemas)
lines.append("--- PHASE 3: FONCTIONS SUPABASE ---")
for schema in ['public','app','auth']:
    res=rpc_sql(f"""
    SELECT routine_name, routine_type, data_type,
           pg_get_function_identity_arguments(p.oid) as args
    FROM information_schema.routines r
    JOIN pg_proc p ON p.proname = r.routine_name
    JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = r.routine_schema
    WHERE r.routine_schema = '{schema}'
      AND (r.routine_name LIKE '%track%' OR r.routine_name LIKE '%navigation%'
           OR r.routine_name LIKE '%analytics%' OR r.routine_name LIKE '%event%'
           OR r.routine_name LIKE '%telemetry%' OR r.routine_name LIKE '%metrics%'
           OR r.routine_name LIKE '%usage%' OR r.routine_name LIKE '%screen%'
           OR r.routine_name LIKE '%page_view%' OR r.routine_name LIKE '%activity%')
    ORDER BY r.routine_name
    """)
    lines.append(f"\nSchema {schema}:")
    lines.append(json.dumps(res, indent=2))

# Also search for app_track_navigation_event specifically
lines.append("\n--- RECHERCHE EXACTE app_track_navigation_event ---")
for schema in ['public','app','auth','extensions']:
    res=rpc_sql(f"""
    SELECT routine_name, routine_schema, routine_type
    FROM information_schema.routines
    WHERE routine_schema = '{schema}'
      AND routine_name = 'app_track_navigation_event'
    """)
    lines.append(f"Schema {schema}: {json.dumps(res)}")

# PHASE 5 — Tables analytics
lines.append("\n\n--- PHASE 5: TABLES ANALYTICS ---")
res=rpc_sql("""
SELECT table_schema, table_name,
       (SELECT COUNT(*) FROM information_schema.columns
        WHERE table_schema = c.table_schema AND table_name = c.table_name) as col_count
FROM information_schema.tables c
WHERE table_schema IN ('app','public')
  AND (table_name LIKE '%navigation%' OR table_name LIKE '%analytics%'
       OR table_name LIKE '%tracking%' OR table_name LIKE '%telemetry%'
       OR table_name LIKE '%metrics%' OR table_name LIKE '%events%'
       OR table_name LIKE '%activity%' OR table_name LIKE '%usage%'
       OR table_name LIKE '%screen%' OR table_name LIKE '%log%')
  AND table_type = 'BASE TABLE'
ORDER BY table_schema, table_name
""")
lines.append(json.dumps(res, indent=2))

# Check if navigation_events or similar exists
lines.append("\n--- TABLES SPECIFIQUES navigation/screen ---")
res=rpc_sql("""
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema IN ('app','public')
  AND table_name IN ('navigation_events','screen_views','user_activity','analytics_events','tracking_events')
""")
lines.append(json.dumps(res, indent=2))

# PHASE 6 — Dependances (triggers, cron, views)
lines.append("\n\n--- PHASE 6: DEPENDANCES ---")

# Triggers
res=rpc_sql("""
SELECT trigger_name, event_manipulation, event_object_table, action_statement
FROM information_schema.triggers
WHERE trigger_schema IN ('app','public')
  AND (trigger_name LIKE '%navigation%' OR trigger_name LIKE '%analytics%'
       OR trigger_name LIKE '%tracking%' OR trigger_name LIKE '%event%')
""")
lines.append("Triggers:")
lines.append(json.dumps(res, indent=2))

# Cron jobs related
res=rpc_sql("""
SELECT jobid, jobname, schedule, command
FROM cron.job
WHERE jobname LIKE '%track%' OR jobname LIKE '%analytics%'
   OR jobname LIKE '%navigation%' OR command LIKE '%track%'
   OR command LIKE '%navigation%' OR command LIKE '%analytics%'
""")
lines.append("\nCron jobs:")
lines.append(json.dumps(res, indent=2))

# Views
res=rpc_sql("""
SELECT table_schema, table_name
FROM information_schema.views
WHERE table_schema IN ('app','public')
  AND (table_name LIKE '%navigation%' OR table_name LIKE '%analytics%'
       OR table_name LIKE '%tracking%' OR table_name LIKE '%usage%')
""")
lines.append("\nViews:")
lines.append(json.dumps(res, indent=2))

# Edge functions (if any table)
res=rpc_sql("""
SELECT schema_name, function_name
FROM net._http_response
LIMIT 0
""")
lines.append("\nEdge functions (net extension):")
lines.append(json.dumps(res, indent=2))

# Check RLS policies related to analytics
lines.append("\n--- RLS POLICIES ANALYTICS ---")
res=rpc_sql("""
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE schemaname IN ('app','public')
  AND (tablename LIKE '%navigation%' OR tablename LIKE '%analytics%'
       OR tablename LIKE '%tracking%' OR tablename LIKE '%event%')
""")
lines.append(json.dumps(res, indent=2))

# Also check for app_track_navigation_event in all function names (broader)
lines.append("\n\n--- BROADER SEARCH: ALL FUNCTIONS WITH 'track' ---")
res=rpc_sql("""
SELECT routine_schema, routine_name, routine_type
FROM information_schema.routines
WHERE routine_name LIKE '%track%'
ORDER BY routine_schema, routine_name
""")
lines.append(json.dumps(res, indent=2))

# Check migration history (if available)
lines.append("\n\n--- SCHEMA MIGRATIONS (supabase_migrations) ---")
res=rpc_sql("""
SELECT name, executed_at
FROM supabase_migrations.schema_migrations
WHERE name LIKE '%track%' OR name LIKE '%navigation%' OR name LIKE '%analytics%'
ORDER BY executed_at DESC
""")
lines.append(json.dumps(res, indent=2))

with open('audit_track_navigation_results.txt','w',encoding='utf-8') as f:
    f.write('\n'.join(lines))
print('OK')
