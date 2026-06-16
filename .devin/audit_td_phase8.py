#!/usr/bin/env python3
"""Phase 8 TD Audit: notification_events table, existing triggers pattern, workflow RPCs."""
import json, requests
from pathlib import Path

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SK, "Authorization": f"Bearer {SK}", "Content-Type": "application/json"}

def sql(q, label=""):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                       json={"p_sql": " ".join(q.split())}, timeout=30)
    body = r.json() if r.status_code == 200 else {"ok": False}
    ok = isinstance(body, dict) and body.get("ok", False)
    rows = body.get("rows", []) if ok else []
    print(f"  {'OK' if ok else 'ERR'} {label}")
    return ok, rows

print("=" * 60)
print("PHASE 8 TD AUDIT -- Notifications + workflow")
print("=" * 60)

# 1. notification_events table columns
print("\n[1] notification_events columns:")
ok1, r1 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='notification_events' ORDER BY ordinal_position", "cols")
for c in r1: print(f"    {c['column_name']}: {c['data_type']}")

# 2. Existing notification trigger pattern (sample)
print("\n[2] Sample existing trigger on td tables:")
ok2, r2 = sql("SELECT trigger_name, event_object_table FROM information_schema.triggers WHERE trigger_schema='app' AND event_object_table LIKE 'td_%' ORDER BY trigger_name LIMIT 5", "td triggers")
for t in r2: print(f"    {t.get('event_object_table')}: {t.get('trigger_name')}")

# 3. Existing notify functions pattern
print("\n[3] Existing app_notify_* functions (sample):")
ok3, r3 = sql("SELECT routine_name FROM information_schema.routines WHERE routine_name LIKE 'app_notify_%' AND routine_schema IN ('app','public') ORDER BY routine_name LIMIT 10", "notify funcs")
for r in r3: print(f"    {r.get('routine_name')}")

# 4. app_queue_notification_event exists?
print("\n[4] app_queue_notification_event:")
ok4, r4 = sql("SELECT routine_name FROM information_schema.routines WHERE routine_name = 'app_queue_notification_event'", "queue func")
print(f"    {'EXISTS' if r4 else 'MISSING'}")

# 5. Existing triggers on local group tables
print("\n[5] Triggers on td_local_groups:")
ok5, r5 = sql("SELECT trigger_name FROM information_schema.triggers WHERE trigger_schema='app' AND event_object_table IN ('td_local_groups','td_local_group_members','td_physical_sessions')", "group triggers")
for t in r5: print(f"    {t.get('trigger_name')}")
if not r5: print("    (aucun trigger)")

# 6. RPCs for completing workflow (session done, rate teacher)
print("\n[6] Missing workflow RPCs:")
for rpc in ["app_td_student_rate_session", "app_td_teacher_complete_session"]:
    ok, r = sql(f"SELECT routine_name FROM information_schema.routines WHERE routine_name = '{rpc}'", rpc)
    print(f"    {rpc}: {'EXISTS' if r else 'TO CREATE'}")

out = Path(__file__).parent / "logs" / "audit_td_phase8.json"
with open(out, "w", encoding="utf-8") as f:
    json.dump({"notif_cols": r1, "queue_exists": bool(r4)}, f, indent=2)
print(f"\nAudit saved: {out}")
