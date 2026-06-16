#!/usr/bin/env python3
"""Audit forensique app_track_navigation_event - Recherche Supabase (v2)"""
import requests, json, time
url='https://thevdfcwlcqzdoybfvgs.supabase.co'
key='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h={'apikey':key,'Authorization':f'Bearer {key}','Content-Type':'application/json'}

def rpc_sql(label, sql):
    try:
        r=requests.post(f'{url}/rest/v1/rpc/admin_execute_sql',headers=h,json={'p_sql':sql},timeout=30)
        data=r.json()
        return {'label': label, 'ok': data.get('ok'), 'mode': data.get('mode'), 'rows': data.get('rows'), 'affected': data.get('affected_rows')}
    except Exception as e:
        return {'label': label, 'error': str(e)}

results=[]

# 1. Exact search app_track_navigation_event
results.append(rpc_sql("EXACT app_track_navigation_event public", "SELECT routine_name, routine_schema, routine_type FROM information_schema.routines WHERE routine_schema='public' AND routine_name='app_track_navigation_event'"))
time.sleep(1)
results.append(rpc_sql("EXACT app_track_navigation_event app", "SELECT routine_name, routine_schema, routine_type FROM information_schema.routines WHERE routine_schema='app' AND routine_name='app_track_navigation_event'"))
time.sleep(1)

# 2. Broader search for track-related functions
results.append(rpc_sql("ALL track functions", "SELECT routine_schema, routine_name, routine_type FROM information_schema.routines WHERE routine_name LIKE '%track%' ORDER BY routine_schema, routine_name"))
time.sleep(1)

# 3. Broader search for analytics/navigation/event functions
results.append(rpc_sql("ALL analytics/navigation/event functions", """
SELECT routine_schema, routine_name, routine_type
FROM information_schema.routines
WHERE routine_name LIKE '%navigation%' OR routine_name LIKE '%analytics%'
   OR routine_name LIKE '%event%' OR routine_name LIKE '%telemetry%'
   OR routine_name LIKE '%metrics%' OR routine_name LIKE '%usage%'
   OR routine_name LIKE '%screen%' OR routine_name LIKE '%activity%'
ORDER BY routine_schema, routine_name
"""))
time.sleep(1)

# 4. Tables analytics
results.append(rpc_sql("TABLES analytics/navigation/tracking", """
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema IN ('app','public')
  AND (table_name LIKE '%navigation%' OR table_name LIKE '%analytics%'
       OR table_name LIKE '%tracking%' OR table_name LIKE '%telemetry%'
       OR table_name LIKE '%metrics%' OR table_name LIKE '%events%'
       OR table_name LIKE '%activity%' OR table_name LIKE '%usage%'
       OR table_name LIKE '%screen%' OR table_name LIKE '%log%')
  AND table_type = 'BASE TABLE'
ORDER BY table_schema, table_name
"""))
time.sleep(1)

# 5. Specific tables
results.append(rpc_sql("SPECIFIC tables navigation/screen", """
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema IN ('app','public')
  AND table_name IN ('navigation_events','screen_views','user_activity','analytics_events','tracking_events','screen_logs')
"""))
time.sleep(1)

# 6. Cron jobs
results.append(rpc_sql("CRON jobs", "SELECT jobid, jobname, schedule, command FROM cron.job"))
time.sleep(1)

# 7. Triggers
results.append(rpc_sql("TRIGGERS analytics", """
SELECT trigger_name, event_object_table, action_statement
FROM information_schema.triggers
WHERE trigger_schema IN ('app','public')
  AND (trigger_name LIKE '%navigation%' OR trigger_name LIKE '%analytics%'
       OR trigger_name LIKE '%tracking%' OR trigger_name LIKE '%event%')
"""))
time.sleep(1)

# 8. Views
results.append(rpc_sql("VIEWS analytics", """
SELECT table_schema, table_name
FROM information_schema.views
WHERE table_schema IN ('app','public')
  AND (table_name LIKE '%navigation%' OR table_name LIKE '%analytics%'
       OR table_name LIKE '%tracking%' OR table_name LIKE '%usage%')
"""))
time.sleep(1)

# 9. RLS policies
results.append(rpc_sql("RLS policies analytics", """
SELECT schemaname, tablename, policyname, cmd
FROM pg_policies
WHERE schemaname IN ('app','public')
  AND (tablename LIKE '%navigation%' OR tablename LIKE '%analytics%'
       OR tablename LIKE '%tracking%' OR tablename LIKE '%event%')
"""))
time.sleep(1)

# 10. Check if table with navigation_events columns exists
results.append(rpc_sql("COLUMNS matching navigation/screen", """
SELECT table_schema, table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema IN ('app','public')
  AND (column_name LIKE '%screen_name%' OR column_name LIKE '%navigation%'
       OR column_name LIKE '%session_id%' OR column_name LIKE '%duration_seconds%'
       OR column_name LIKE '%tab_index%' OR column_name LIKE '%tab_name%')
ORDER BY table_schema, table_name, column_name
"""))

with open('audit_track_navigation_results2.json','w',encoding='utf-8') as f:
    json.dump(results, f, indent=2, ensure_ascii=False)
print('OK')
