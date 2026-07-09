import requests
import json

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

def execute_sql(sql):
    resp = requests.post(admin_url, headers=headers, json={"p_sql": sql}, timeout=30)
    return resp.json()

print("=" * 80)
print("VÉRIFICATION DU DÉPLOIEMENT WHITEBOARD")
print("=" * 80)

# 1. Vérifier le schéma app
print("\n1. Vérification du schéma app...")
sql1 = "SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'app';"
result1 = execute_sql(sql1)
schema_exists = len(result1.get('data', [])) > 0
print(f"   Schéma app existe : {'✅' if schema_exists else '❌'}")

# 2. Vérifier les tables
print("\n2. Vérification des tables...")
tables = ['whiteboard_projects', 'whiteboard_renders', 'whiteboard_ai_generations']
for table in tables:
    sql = f"""
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'app' AND table_name = '{table}';
    """
    result = execute_sql(sql)
    exists = len(result.get('data', [])) > 0
    print(f"   Table app.{table} : {'✅' if exists else '❌'}")

# 3. Vérifier les indexes
print("\n3. Vérification des indexes...")
indexes = [
    'idx_whiteboard_projects_student_id',
    'idx_whiteboard_projects_status',
    'idx_whiteboard_projects_created_at',
    'idx_whiteboard_renders_project_id',
    'idx_whiteboard_renders_status',
    'idx_whiteboard_renders_created_at',
    'idx_whiteboard_ai_generations_created_by',
    'idx_whiteboard_ai_generations_status',
    'idx_whiteboard_ai_generations_created_at'
]
for index in indexes:
    sql = f"""
    SELECT indexname
    FROM pg_indexes
    WHERE schemaname = 'app' AND indexname = '{index}';
    """
    result = execute_sql(sql)
    exists = len(result.get('data', [])) > 0
    print(f"   Index {index} : {'✅' if exists else '❌'}")

# 4. Vérifier les RLS policies
print("\n4. Vérification des RLS policies...")
policies = [
    ('whiteboard_projects', 'Students can view own projects'),
    ('whiteboard_projects', 'Students can insert own projects'),
    ('whiteboard_projects', 'Students can update own projects'),
    ('whiteboard_projects', 'Students can delete own projects'),
    ('whiteboard_projects', 'Service role can do everything'),
    ('whiteboard_renders', 'Students can view own renders'),
    ('whiteboard_renders', 'Service role can do everything'),
    ('whiteboard_ai_generations', 'Students can view own generations'),
    ('whiteboard_ai_generations', 'Admins can view all generations'),
    ('whiteboard_ai_generations', 'Service role can insert generations')
]
for table, policy in policies:
    sql = f"""
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'app' AND tablename = '{table}' AND policyname = '{policy}';
    """
    result = execute_sql(sql)
    exists = len(result.get('data', [])) > 0
    print(f"   Policy {policy} on {table} : {'✅' if exists else '❌'}")

# 5. Vérifier les triggers
print("\n5. Vérification des triggers...")
triggers = [
    ('whiteboard_projects', 'whiteboard_projects_updated_at_trigger'),
    ('whiteboard_ai_generations', 'whiteboard_ai_generations_updated_at_trigger')
]
for table, trigger in triggers:
    sql = f"""
    SELECT trigger_name
    FROM information_schema.triggers
    WHERE trigger_schema = 'app' AND event_object_table = '{table}' AND trigger_name = '{trigger}';
    """
    result = execute_sql(sql)
    exists = len(result.get('data', [])) > 0
    print(f"   Trigger {trigger} on {table} : {'✅' if exists else '❌'}")

# 6. Vérifier les RPCs worker (public schema)
print("\n6. Vérification des RPCs worker (public schema)...")
worker_rpcs = [
    'whiteboard_fetch_queued_jobs',
    'whiteboard_mark_processing',
    'whiteboard_mark_done',
    'whiteboard_mark_failed',
    'whiteboard_get_any_student_id'
]
for rpc in worker_rpcs:
    sql = f"""
    SELECT proname
    FROM pg_proc
    WHERE pronamespace::regnamespace = 'public' AND proname = '{rpc}';
    """
    result = execute_sql(sql)
    exists = len(result.get('data', [])) > 0
    print(f"   RPC public.{rpc} : {'✅' if exists else '❌'}")

# 7. Vérifier les RPCs editor (app schema)
print("\n7. Vérification des RPCs editor (app schema)...")
editor_rpcs = [
    'whiteboard_get_project',
    'whiteboard_update_project',
    'whiteboard_list_projects',
    'whiteboard_delete_project',
    'whiteboard_create_project'
]
for rpc in editor_rpcs:
    sql = f"""
    SELECT proname
    FROM pg_proc
    WHERE pronamespace::regnamespace = 'app' AND proname = '{rpc}';
    """
    result = execute_sql(sql)
    exists = len(result.get('data', [])) > 0
    print(f"   RPC app.{rpc} : {'✅' if exists else '❌'}")

# 8. Vérifier les RPCs wrapper (public schema)
print("\n8. Vérification des RPCs wrapper (public schema)...")
wrapper_rpcs = [
    'whiteboard_create_project',
    'whiteboard_list_projects'
]
for rpc in wrapper_rpcs:
    sql = f"""
    SELECT proname, pg_get_function_identity_arguments(oid) as signature
    FROM pg_proc
    WHERE pronamespace::regnamespace = 'public' AND proname = '{rpc}';
    """
    result = execute_sql(sql)
    exists = len(result.get('data', [])) > 0
    if exists:
        sig = result['data'][0][1]
        print(f"   RPC public.{rpc} : ✅ (signature: {sig})")
    else:
        print(f"   RPC public.{rpc} : ❌")

# 9. Vérifier les doublons (PGRST203)
print("\n9. Vérification des doublons (PGRST203)...")
sql = """
SELECT
    proname,
    pg_get_function_identity_arguments(oid) as signature,
    pronamespace::regnamespace as schema
FROM pg_proc
WHERE proname = 'whiteboard_create_project'
ORDER BY schema, proname;
"""
result = execute_sql(sql)
functions = result.get('data', [])
print(f"   Nombre de fonctions whiteboard_create_project : {len(functions)}")
if len(functions) > 1:
    print("   ❌ DOUBLON DÉTECTÉ (PGRST203) :")
    for func in functions:
        print(f"      - {func[2]}.{func[0]}({func[1]})")
elif len(functions) == 1:
    print("   ✅ Une seule fonction (pas de doublon)")
else:
    print("   ❌ Aucune fonction trouvée")

print("\n" + "=" * 80)
print("VÉRIFICATION TERMINÉE")
print("=" * 80)
