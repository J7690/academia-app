#!/usr/bin/env python3
"""Phase 8C/8D — Audit complet push notifications chain."""
import json, requests
from supabase_auto_manager import SupabaseAutoManager

def sql(m, label, q):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": q.strip()}, timeout=30)
    d = r.json() if r.text else {}
    rows = d.get("rows", []) if isinstance(d, dict) else []
    if not isinstance(rows, list): rows = []
    print(f"\n-- {label} --")
    for row in rows[:15]:
        display = {}
        for k, v in row.items():
            sv = str(v) if v is not None else "NULL"
            display[k] = sv[:400] if len(sv) > 400 else sv
        print(f"  {json.dumps(display, ensure_ascii=False)}")
    if not rows: print("  (0 rows)")
    return rows

m = SupabaseAutoManager()
print("="*60)
print("AUDIT PUSH NOTIFICATIONS — CHAÎNE COMPLÈTE")
print("="*60)

# 1. Triggers qui insèrent dans notification_events
sql(m, "1. TRIGGERS qui appellent app_queue_notification_event",
    """SELECT t.trigger_name, t.event_object_table, t.event_manipulation,
              LEFT(t.action_statement, 80) AS action
       FROM information_schema.triggers t
       WHERE t.event_object_schema = 'app'
       AND t.action_statement LIKE '%notify%'
       ORDER BY t.event_object_table""")

# 2. Vérifier si un trigger insère aussi dans un webhook ou appelle une Edge Function
sql(m, "2. Triggers qui appellent net.http ou pg_net (pour push externe)",
    """SELECT t.trigger_name, t.event_object_table, t.action_statement
       FROM information_schema.triggers t
       WHERE t.event_object_schema = 'app'
       AND (t.action_statement LIKE '%net.http%' OR t.action_statement LIKE '%pg_net%'
            OR t.action_statement LIKE '%http%')""")

# 3. Vérifier s'il y a un trigger sur notification_events qui envoie les push
sql(m, "3. Triggers sur app.notification_events",
    """SELECT t.trigger_name, t.event_manipulation, t.action_statement
       FROM information_schema.triggers t
       WHERE t.event_object_schema = 'app'
       AND t.event_object_table = 'notification_events'""")

# 4. Chercher les fonctions qui envoient des push (pg_net, http_post)
sql(m, "4. Fonctions contenant 'pg_net' ou 'http' ou 'push'",
    """SELECT p.proname, n.nspname
       FROM pg_catalog.pg_proc p
       JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
       WHERE (p.proname LIKE '%push%' OR p.proname LIKE '%send_notif%'
              OR p.proname LIKE '%fcm%' OR p.proname LIKE '%webhook%')
       ORDER BY p.proname""")

# 5. Vérifier si pg_net extension est installée
sql(m, "5. Extension pg_net installée?",
    """SELECT extname, extversion FROM pg_extension WHERE extname = 'pg_net'""")

# 6. Vérifier les database webhooks (supabase)
sql(m, "6. Supabase database webhooks (net._http_response)",
    """SELECT EXISTS(
         SELECT 1 FROM information_schema.tables
         WHERE table_schema = 'net' AND table_name = '_http_response'
       ) AS net_schema_exists""")

# 7. Source de app_queue_notification_event (vérifie si elle appelle un push)
sql(m, "7. Source app_queue_notification_event",
    """SELECT pg_get_functiondef(p.oid) AS src
       FROM pg_catalog.pg_proc p
       JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
       WHERE p.proname = 'app_queue_notification_event'""")

# 8. Vérifier supabase Edge Functions disponibles
print("\n-- 8. Edge Function send-push-notifications --")
ef_url = f"{m.url}/functions/v1/send-push-notifications"
try:
    r = requests.options(ef_url, headers={
        "apikey": m.service_key,
        "Authorization": f"Bearer {m.service_key}",
    }, timeout=10)
    print(f"  OPTIONS HTTP {r.status_code}")
except Exception as e:
    print(f"  Error: {e}")

# 9. Vérifier user_device_tokens — combien d'appareils enregistrés
sql(m, "9. user_device_tokens stats",
    """SELECT platform, COUNT(*) as cnt
       FROM app.user_device_tokens
       GROUP BY platform
       ORDER BY cnt DESC""")

# 10. Source de app_register_device_token
sql(m, "10. Source app_register_device_token",
    """SELECT LEFT(pg_get_functiondef(p.oid), 1500) AS src
       FROM pg_catalog.pg_proc p
       JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
       WHERE n.nspname = 'public' AND p.proname = 'app_register_device_token'""")

# 11. Vérifier FCM_SERVICE_ACCOUNT_JSON dans Edge Functions secrets
# (Cannot check from SQL, but we note it)
print("\n-- 11. FCM_SERVICE_ACCOUNT_JSON --")
print("  Cannot verify from SQL. Check Supabase dashboard > Edge Functions > Secrets.")

# 12. Vérifier si notification_events a un trigger qui appelle send-push-notifications
sql(m, "12. ALL triggers on ALL tables that might call push",
    """SELECT t.trigger_name, t.event_object_table,
              t.action_statement
       FROM information_schema.triggers t
       WHERE t.event_object_schema = 'app'
       AND t.action_statement LIKE '%push%'""")

# 13. Vérifier supabase database webhooks
sql(m, "13. Database webhooks (supabase_functions.hooks)",
    """SELECT EXISTS(
         SELECT 1 FROM information_schema.tables
         WHERE table_schema = 'supabase_functions' AND table_name = 'hooks'
       ) AS hooks_table_exists""")

# 14. If hooks table exists, check its content
sql(m, "14. Supabase hooks content",
    """SELECT id, hook_table_id, hook_name, enabled, events,
              LEFT(request_url::text, 100) AS url
       FROM supabase_functions.hooks
       ORDER BY hook_name
       LIMIT 20""")

print(f"\n{'='*60}")
print("AUDIT PUSH NOTIFICATIONS TERMINÉ")
print(f"{'='*60}")
