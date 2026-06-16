#!/usr/bin/env python3
"""Audit forensique app_track_navigation_event - Details fonctions et tables"""
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

# 1. Details of app.app_track_navigation_event
results.append(rpc_sql("DETAILS app.app_track_navigation_event", """
SELECT p.proname as function_name,
       n.nspname as schema,
       pg_get_functiondef(p.oid) as definition,
       pg_get_function_arguments(p.oid) as arguments,
       pg_get_function_result(p.oid) as return_type
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'app' AND p.proname = 'app_track_navigation_event'
"""))
time.sleep(1)

# 2. Details of public.app_track_user_activity
results.append(rpc_sql("DETAILS public.app_track_user_activity", """
SELECT p.proname as function_name,
       n.nspname as schema,
       pg_get_functiondef(p.oid) as definition,
       pg_get_function_arguments(p.oid) as arguments,
       pg_get_function_result(p.oid) as return_type
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'app_track_user_activity'
"""))
time.sleep(1)

# 3. GRANT on app.app_track_navigation_event
results.append(rpc_sql("GRANT app.app_track_navigation_event", """
SELECT grantee, privilege_type
FROM information_schema.role_routine_grants
WHERE routine_schema = 'app' AND routine_name = 'app_track_navigation_event'
"""))
time.sleep(1)

# 4. GRANT on public.app_track_user_activity
results.append(rpc_sql("GRANT public.app_track_user_activity", """
SELECT grantee, privilege_type
FROM information_schema.role_routine_grants
WHERE routine_schema = 'public' AND routine_name = 'app_track_user_activity'
"""))
time.sleep(1)

# 5. Tables with screen/navigation columns - DETAILED
results.append(rpc_sql("DETAILED COLUMNS screen/navigation", """
SELECT table_schema, table_name, column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema IN ('app','public')
  AND (column_name LIKE '%screen_name%' OR column_name LIKE '%navigation%'
       OR column_name LIKE '%session_id%' OR column_name LIKE '%duration_seconds%'
       OR column_name LIKE '%tab_index%' OR column_name LIKE '%tab_name%')
ORDER BY table_schema, table_name, ordinal_position
"""))
time.sleep(1)

# 6. All tables in app schema that might store navigation events
results.append(rpc_sql("APP SCHEMA TABLES (all)", """
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'app' AND table_type = 'BASE TABLE'
ORDER BY table_name
"""))
time.sleep(1)

# 7. Search for any table with 'event' or 'screen' in app schema
results.append(rpc_sql("APP TABLES event/screen/activity", """
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'app' AND table_type = 'BASE TABLE'
  AND (table_name LIKE '%event%' OR table_name LIKE '%screen%' OR table_name LIKE '%activity%')
ORDER BY table_name
"""))
time.sleep(1)

# 8. Check admin_user_action_logs structure (has action, might be related)
results.append(rpc_sql("admin_user_action_logs columns", """
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'admin_user_action_logs'
ORDER BY ordinal_position
"""))
time.sleep(1)

# 9. Check if there are any recent entries in potential analytics tables
results.append(rpc_sql("COUNT admin_user_action_logs", "SELECT COUNT(*) as cnt FROM app.admin_user_action_logs"))
time.sleep(1)

# 10. Look for any table that might store navigation data by checking column patterns
results.append(rpc_sql("TABLES WITH screen_name COLUMN", """
SELECT c.table_schema, c.table_name, c.data_type
FROM information_schema.columns c
JOIN information_schema.tables t ON t.table_schema = c.table_schema AND t.table_name = c.table_name
WHERE c.table_schema IN ('app','public')
  AND c.column_name = 'screen_name'
  AND t.table_type = 'BASE TABLE'
"""))
time.sleep(1)

# 11. Check if function app_track_navigation_event has security definer/invoker
results.append(rpc_sql("SECURITY app.app_track_navigation_event", """
SELECT p.proname, p.prosecdef, p.proowner::regrole as owner
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'app' AND p.proname = 'app_track_navigation_event'
"""))

with open('audit_track_navigation_details.json','w',encoding='utf-8') as f:
    json.dump(results, f, indent=2, ensure_ascii=False)
print('OK')
