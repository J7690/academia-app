#!/usr/bin/env python3
"""Audit: list ALL notification triggers, their source tables, trigger functions, and what they notify."""
import json, requests
from supabase_auto_manager import SupabaseAutoManager

def q(m, label, sql):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=60)
    d = r.json() if r.text else {}
    ok = r.status_code == 200 and isinstance(d, dict) and d.get("ok") is True
    rows = d.get('rows', []) if isinstance(d, dict) else []
    if not isinstance(rows, list): rows = []
    print(f"\n{'✅' if ok else '❌'} {label}")
    if not ok:
        print(f"  ERROR: {json.dumps(d, ensure_ascii=False, default=str)[:600]}")
    for row in (rows or [])[:60]:
        print(f"  {json.dumps(row, ensure_ascii=False, default=str)[:500]}")
    if ok and not rows: print("  (0 rows)")
    return rows

m = SupabaseAutoManager()
print("=" * 70)
print("AUDIT — TOUTES LES FONCTIONNALITÉS AVEC NOTIFICATIONS")
print("=" * 70)

# 1. All notification triggers with their source table and function
q(m, "1. ALL notification triggers (table → function)", """
SELECT t.trigger_name, t.event_object_table AS source_table,
       t.event_manipulation AS event_type,
       REPLACE(REPLACE(t.action_statement, 'EXECUTE FUNCTION ', ''), '()', '') AS trigger_function
FROM information_schema.triggers t
WHERE t.event_object_schema = 'app'
AND (t.action_statement LIKE '%notify%' OR t.action_statement LIKE '%notification%')
ORDER BY t.event_object_table, t.trigger_name
""")

# 2. All trigger functions source — extract domain from app_queue_notification_event calls
q(m, "2. Trigger functions → notification domains", """
SELECT p.proname AS function_name,
       regexp_matches(pg_get_functiondef(p.oid), 'app_queue_notification_event\\([^,]+,\\s*''([^'']+)''', 'g') AS domain_match
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname IN ('public', 'app')
AND pg_get_functiondef(p.oid) LIKE '%app_queue_notification_event%'
ORDER BY p.proname
""")

# 3. All domains used in notification_events
q(m, "3. ALL domains in notification_events (historical)", """
SELECT domain, event_type, COUNT(*) AS event_count
FROM app.notification_events
GROUP BY domain, event_type
ORDER BY domain, event_type
""")

# 4. Edge Function buildFcmMessage — all supported domains
print(f"\n{'='*70}")
print("4. Domains gérés dans Edge Function buildFcmMessage")
print("   (extrait du code source send-push-notifications/index.ts)")

# 5. Android config
q(m, "5. minSdkVersion from Flutter", """
SELECT 1 AS info
""")

# 6. Active tokens stats by platform
q(m, "6. Token stats", """
SELECT platform, is_active, COUNT(*) AS cnt,
       MIN(updated_at) AS oldest_update,
       MAX(updated_at) AS newest_update
FROM app.user_device_tokens
GROUP BY platform, is_active
ORDER BY platform, is_active DESC
""")

print(f"\n{'='*70}")
print("AUDIT TERMINÉ")
print(f"{'='*70}")
