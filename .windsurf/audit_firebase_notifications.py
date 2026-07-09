import requests
import json
from datetime import datetime

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

print("=" * 80)
print("AUDIT SYSTÈME DE NOTIFICATIONS FIREBASE")
print("=" * 80)
print(f"Date: {datetime.now().isoformat()}")
print("=" * 80)

# ========================================
# 1. AUDIT DES TABLES DE NOTIFICATION
# ========================================
print("\n" + "=" * 80)
print("1. AUDIT DES TABLES DE NOTIFICATION")
print("=" * 80)

tables_to_audit = [
    "user_device_tokens",
    "notification_events",
    "user_notification_state"
]

for table in tables_to_audit:
    print(f"\n--- Table: app.{table} ---")
    
    # Vérifier si la table existe
    sql_check = f"""
    SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'app' 
        AND table_name = '{table}'
    );
    """
    resp = requests.post(admin_url, headers=headers, json={"p_sql": sql_check}, timeout=30)
    if resp.status_code == 200:
        exists = resp.json().get('data', [[False]])[0][0]
        print(f"  Existe: {exists}")
        
        if exists:
            # Lister les colonnes
            sql_columns = f"""
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns
            WHERE table_schema = 'app' AND table_name = '{table}'
            ORDER BY ordinal_position;
            """
            resp_cols = requests.post(admin_url, headers=headers, json={"p_sql": sql_columns}, timeout=30)
            if resp_cols.status_code == 200:
                columns = resp_cols.json().get('data', [])
                print(f"  Colonnes ({len(columns)}):")
                for col in columns:
                    print(f"    - {col[0]}: {col[1]} (nullable: {col[2]}, default: {col[3]})")
            
            # Compter les enregistrements
            sql_count = f"SELECT COUNT(*) FROM app.{table};"
            resp_count = requests.post(admin_url, headers=headers, json={"p_sql": sql_count}, timeout=30)
            if resp_count.status_code == 200:
                count = resp_count.json().get('data', [[0]])[0][0]
                print(f"  Nombre d'enregistrements: {count}")
            
            # Pour notification_events: analyser les événements par domaine
            if table == "notification_events":
                sql_events = """
                SELECT 
                    domain,
                    event_type,
                    COUNT(*) as count,
                    MIN(created_at) as first_event,
                    MAX(created_at) as last_event
                FROM app.notification_events
                GROUP BY domain, event_type
                ORDER BY count DESC
                LIMIT 20;
                """
                resp_events = requests.post(admin_url, headers=headers, json={"p_sql": sql_events}, timeout=30)
                if resp_events.status_code == 200:
                    events = resp_events.json().get('data', [])
                    print(f"  Événements par domaine/type (top 20):")
                    for event in events:
                        print(f"    - {event[0]}/{event[1]}: {event[2]} événements (de {event[3]} à {event[4]})")
                
                # Événements non traités
                sql_pending = """
                SELECT COUNT(*) FROM app.notification_events 
                WHERE processed_at IS NULL;
                """
                resp_pending = requests.post(admin_url, headers=headers, json={"p_sql": sql_pending}, timeout=30)
                if resp_pending.status_code == 200:
                    pending = resp_pending.json().get('data', [[0]])[0][0]
                    print(f"  Événements en attente (processed_at IS NULL): {pending}")
            
            # Pour user_device_tokens: analyser par plateforme
            if table == "user_device_tokens":
                sql_platforms = """
                SELECT 
                    platform,
                    COUNT(*) as count,
                    COUNT(DISTINCT user_id) as unique_users
                FROM app.user_device_tokens
                WHERE is_active = true
                GROUP BY platform;
                """
                resp_platforms = requests.post(admin_url, headers=headers, json={"p_sql": sql_platforms}, timeout=30)
                if resp_platforms.status_code == 200:
                    platforms = resp_platforms.json().get('data', [])
                    print(f"  Tokens actifs par plateforme:")
                    for plat in platforms:
                        print(f"    - {plat[0]}: {plat[1]} tokens ({plat[2]} utilisateurs)")
                
                # Tokens inactifs
                sql_inactive = """
                SELECT COUNT(*) FROM app.user_device_tokens 
                WHERE is_active = false;
                """
                resp_inactive = requests.post(admin_url, headers=headers, json={"p_sql": sql_inactive}, timeout=30)
                if resp_inactive.status_code == 200:
                    inactive = resp_inactive.json().get('data', [[0]])[0][0]
                    print(f"  Tokens inactifs: {inactive}")
    else:
        print(f"  Erreur vérification existence: {resp.text}")

# ========================================
# 2. AUDIT DES RPCs DE NOTIFICATION
# ========================================
print("\n" + "=" * 80)
print("2. AUDIT DES RPCs DE NOTIFICATION")
print("=" * 80)

rpcs_to_audit = [
    "app_register_device_token",
    "app_unregister_device_token"
]

for rpc in rpcs_to_audit:
    print(f"\n--- RPC: {rpc} ---")
    
    # Vérifier si la RPC existe
    sql_check = f"""
    SELECT EXISTS (
        SELECT FROM pg_proc 
        WHERE proname = '{rpc.replace('app_', '')}'
        AND pronamespace::regnamespace = 'public'
    );
    """
    resp = requests.post(admin_url, headers=headers, json={"p_sql": sql_check}, timeout=30)
    if resp.status_code == 200:
        exists = resp.json().get('data', [[False]])[0][0]
        print(f"  Existe dans schema public: {exists}")
        
        # Chercher dans app aussi
        sql_check_app = f"""
        SELECT EXISTS (
            SELECT FROM pg_proc 
            WHERE proname = '{rpc.replace('app_', '')}'
            AND pronamespace::regnamespace = 'app'
        );
        """
        resp_app = requests.post(admin_url, headers=headers, json={"p_sql": sql_check_app}, timeout=30)
        if resp_app.status_code == 200:
            exists_app = resp_app.json().get('data', [[False]])[0][0]
            print(f"  Existe dans schema app: {exists_app}")
        
        if exists or exists_app:
            # Obtenir la signature
            schema = 'app' if exists_app else 'public'
            sql_sig = f"""
            SELECT pg_get_function_identity_arguments(oid)
            FROM pg_proc
            WHERE proname = '{rpc.replace('app_', '')}'
            AND pronamespace::regnamespace = '{schema}';
            """
            resp_sig = requests.post(admin_url, headers=headers, json={"p_sql": sql_sig}, timeout=30)
            if resp_sig.status_code == 200:
                sig = resp_sig.json().get('data', [[]])[0][0]
                print(f"  Signature: {sig}")
                print(f"  Schéma: {schema}")
    else:
        print(f"  Erreur: {resp.text}")

# ========================================
# 3. RECHERCHE DE TOUTES LES RPCs CONTENANT "token" ou "notification"
# ========================================
print("\n" + "=" * 80)
print("3. RECHERCHE DE TOUTES LES RPCs CONTENANT 'token' OU 'notification'")
print("=" * 80)

sql_search = """
SELECT 
    proname,
    pronamespace::regnamespace as schema,
    pg_get_function_identity_arguments(oid) as signature
FROM pg_proc
WHERE pronamespace::regnamespace NOT IN ('pg_catalog', 'information_schema')
AND (proname LIKE '%token%' OR proname LIKE '%notification%')
ORDER BY schema, proname;
"""

resp_search = requests.post(admin_url, headers=headers, json={"p_sql": sql_search}, timeout=30)
if resp_search.status_code == 200:
    funcs = resp_search.json().get('data', [])
    print(f"\nFonctions trouvées: {len(funcs)}")
    for func in funcs:
        print(f"  - {func[1]}.{func[0]}({func[2]})")
else:
    print(f"Erreur: {resp_search.text}")

# ========================================
# 4. ANALYSE DU FLUX D'ENVOI PAR ACTION
# ========================================
print("\n" + "=" * 80)
print("4. ANALYSE DU FLUX D'ENVOI PAR ACTION")
print("=" * 80)

# Chercher les triggers qui insèrent dans notification_events
sql_triggers = """
SELECT 
    trigger_name,
    event_object_table,
    action_statement,
    event_manipulation
FROM information_schema.triggers
WHERE action_statement LIKE '%notification_events%'
ORDER BY event_object_table, trigger_name;
"""

resp_triggers = requests.post(admin_url, headers=headers, json={"p_sql": sql_triggers}, timeout=30)
if resp_triggers.status_code == 200:
    triggers = resp_triggers.json().get('data', [])
    print(f"\nTriggers insérant dans notification_events: {len(triggers)}")
    for trig in triggers:
        print(f"  - {trig[0]} sur {trig[1]} ({trig[3]})")
        print(f"    Action: {trig[2][:100]}...")
else:
    print(f"Erreur: {resp_triggers.text}")

# Chercher les fonctions qui insèrent dans notification_events
sql_functions = """
SELECT 
    proname,
    pronamespace::regnamespace as schema,
    pg_get_functiondef(oid) as definition
FROM pg_proc
WHERE pg_get_functiondef(oid) LIKE '%notification_events%'
AND pronamespace::regnamespace NOT IN ('pg_catalog', 'information_schema')
ORDER BY schema, proname
LIMIT 30;
"""

resp_functions = requests.post(admin_url, headers=headers, json={"p_sql": sql_functions}, timeout=30)
if resp_functions.status_code == 200:
    funcs = resp_functions.json().get('data', [])
    print(f"\nFonctions insérant dans notification_events (top 30): {len(funcs)}")
    for func in funcs:
        print(f"  - {func[1]}.{func[0]}")
else:
    print(f"Erreur: {resp_functions.text}")

print("\n" + "=" * 80)
print("FIN DE L'AUDIT")
print("=" * 80)
