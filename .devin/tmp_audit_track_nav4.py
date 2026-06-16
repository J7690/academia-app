#!/usr/bin/env python3
"""Audit forensique app_track_navigation_event - Details fonctions v4 (queries plus simples)"""
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

# 1. Function args and return type (simple query)
results.append(rpc_sql("ARGS app_track_navigation_event", """
SELECT routine_name, routine_schema, data_type as return_type
FROM information_schema.routines
WHERE routine_schema = 'app' AND routine_name = 'app_track_navigation_event'
"""))
time.sleep(1)

# 2. Function parameters
results.append(rpc_sql("PARAMETERS app_track_navigation_event", """
SELECT parameter_name, data_type, parameter_mode
FROM information_schema.parameters
WHERE specific_schema = 'app'
  AND specific_name IN (
    SELECT specific_name FROM information_schema.routines
    WHERE routine_schema = 'app' AND routine_name = 'app_track_navigation_event'
  )
ORDER BY ordinal_position
"""))
time.sleep(1)

# 3. What table does it insert into? Check by searching INSERT in its body
results.append(rpc_sql("SOURCE app_track_navigation_event (pg_proc)", """
SELECT prosrc FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'app' AND p.proname = 'app_track_navigation_event'
"""))
time.sleep(1)

# 4. Table with screen_name column - which one?
results.append(rpc_sql("TABLE WITH screen_name", """
SELECT c.table_schema, c.table_name, c.column_name, c.data_type
FROM information_schema.columns c
JOIN information_schema.tables t ON t.table_schema = c.table_schema AND t.table_name = c.table_name
WHERE c.table_schema IN ('app','public')
  AND c.column_name = 'screen_name'
  AND t.table_type = 'BASE TABLE'
"""))
time.sleep(1)

# 5. Tables in app with event/screen/activity names
results.append(rpc_sql("APP TABLES event/screen/activity names", """
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'app' AND table_type = 'BASE TABLE'
  AND (table_name LIKE '%event%' OR table_name LIKE '%screen%' OR table_name LIKE '%activity%')
ORDER BY table_name
"""))
time.sleep(1)

# 6. Columns of that table with screen_name
results.append(rpc_sql("COLUMNS of screen_name table", """
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'app'
  AND table_name = (
    SELECT table_name FROM information_schema.columns
    WHERE table_schema = 'app' AND column_name = 'screen_name' LIMIT 1
  )
ORDER BY ordinal_position
"""))
time.sleep(1)

# 7. Count rows in that table
results.append(rpc_sql("COUNT screen_name table", """
SELECT COUNT(*) as cnt FROM app.navigation_events
"""))
time.sleep(1)

# 8. public.app_track_user_activity parameters
results.append(rpc_sql("PARAMETERS public.app_track_user_activity", """
SELECT parameter_name, data_type, parameter_mode
FROM information_schema.parameters
WHERE specific_schema = 'public'
  AND specific_name IN (
    SELECT specific_name FROM information_schema.routines
    WHERE routine_schema = 'public' AND routine_name = 'app_track_user_activity'
  )
ORDER BY ordinal_position
"""))
time.sleep(1)

# 9. What does public.app_track_user_activity do?
results.append(rpc_sql("SOURCE public.app_track_user_activity", """
SELECT prosrc FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'app_track_user_activity'
"""))

with open('audit_track_navigation_details2.json','w',encoding='utf-8') as f:
    json.dump(results, f, indent=2, ensure_ascii=False)
print('OK')
