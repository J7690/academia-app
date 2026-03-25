#!/usr/bin/env python3
"""Phase 2 TD Audit: existing AI chat infrastructure, td_ai_config, Edge Functions."""
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
print("PHASE 2 TD AUDIT -- IA Tuteur TD")
print("=" * 60)

# 1. td_ai_config (existing AI config for TD)
print("\n[1] td_ai_config:")
ok1, r1 = sql("SELECT config_key, LEFT(config_value, 80) AS preview FROM app.td_ai_config", "td_ai_config")
for c in r1: print(f"    {c.get('config_key')}: {c.get('preview')}")

# 2. td_ai_conversations / td_ai_messages
print("\n[2] TD AI conversations:")
ok2a, r2a = sql("SELECT COUNT(*) AS cnt FROM app.td_ai_conversations", "conversations")
ok2b, r2b = sql("SELECT COUNT(*) AS cnt FROM app.td_ai_messages", "messages")
print(f"    conversations: {r2a[0].get('cnt',0) if r2a else '?'}")
print(f"    messages: {r2b[0].get('cnt',0) if r2b else '?'}")

# 3. td_ai_conversations columns
print("\n[3] td_ai_conversations columns:")
ok3, r3 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='td_ai_conversations' ORDER BY ordinal_position", "cols")
for c in r3: print(f"    {c['column_name']}: {c['data_type']}")

# 4. td_ai_messages columns
print("\n[4] td_ai_messages columns:")
ok4, r4 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='td_ai_messages' ORDER BY ordinal_position", "cols")
for c in r4: print(f"    {c['column_name']}: {c['data_type']}")

# 5. Existing RPCs for AI chat in TD
print("\n[5] TD AI RPCs:")
ok5, r5 = sql("SELECT routine_name FROM information_schema.routines WHERE routine_name LIKE '%td_ai%' OR routine_name LIKE '%td%conversation%' OR routine_name LIKE '%td%message%' ORDER BY routine_name", "TD AI RPCs")
for r in r5: print(f"    {r.get('routine_name')}")

# 6. prep-tutor-chat Edge Function (will be reused)
print("\n[6] Edge Function prep-tutor-chat:")
try:
    resp = requests.options(f"{URL}/functions/v1/prep-tutor-chat", timeout=10)
    print(f"    HTTP {resp.status_code}")
except: print("    ERROR")

# 7. Existing prep_ai_service.dart (Flutter service for AI chat)
print("\n[7] Check: prep_ai_service exists in Flutter for reference")
print("    (verified in Flutter audit above)")

out = Path(__file__).parent / "logs" / "audit_td_phase2.json"
with open(out, "w", encoding="utf-8") as f:
    json.dump({"td_ai_config": r1, "conversations": r2a, "messages": r2b, "ai_rpcs": r5}, f, indent=2, ensure_ascii=False)
print(f"\nAudit saved: {out}")
