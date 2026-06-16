#!/usr/bin/env python3
"""Generate a test notification event for the TECNO user to validate push end-to-end."""
import json, requests
from supabase_auto_manager import SupabaseAutoManager

def q(m, label, sql):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=30)
    d = r.json() if r.text else {}
    ok = r.status_code == 200 and isinstance(d, dict) and d.get("ok") is True
    print(f"{'✅' if ok else '❌'} {label}")
    if not ok:
        print(json.dumps(d, ensure_ascii=False, default=str)[:500])
    return ok

m = SupabaseAutoManager()

# TECNO user ID (from fresh token)
tecno_user = "9c09d123-286c-414c-8b52-b70054290924"

# Insert a test notification event
q(m, "Insert test push event", f"""
INSERT INTO app.notification_events (user_id, domain, event_type, payload)
VALUES (
  '{tecno_user}',
  'student_announcements',
  'test',
  '{{"title": "Test Push Academia", "urgency": "normal"}}'::jsonb
)
""")

print("\n⏳ Le cron va traiter cet event dans ~1 minute.")
print("   Si le push fonctionne, tu recevras une notification sur le TECNO.")
print("   Ferme l'app maintenant (swipe away) et attends!")
