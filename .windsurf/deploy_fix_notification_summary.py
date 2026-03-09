#!/usr/bin/env python3
"""Phase 8B — Fix app_get_notification_summary: quand last_seen IS NULL, has_new doit être TRUE si du contenu existe."""
import json, requests
from supabase_auto_manager import SupabaseAutoManager

def run_admin_sql(m, label, sql):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=60)
    d = r.json() if r.text else {}
    ok = r.status_code == 200 and isinstance(d, dict) and d.get("ok") is True
    print(f"{'✅' if ok else '❌'} {label}")
    if not ok:
        print(f"   {json.dumps(d, ensure_ascii=False, default=str)[:500]}")
    return ok

m = SupabaseAutoManager()
print("Phase 8B — Fix notification summary\n")

# Read the current SQL from file and fix the NULL logic
# The fix: replace all "IF v_last_seen IS NULL THEN v_has_new := FALSE;"
# with "IF v_last_seen IS NULL THEN v_has_new := (v_max_updated > TO_TIMESTAMP(0));"
# This means: if user never saw domain AND there's content, it's new.

with open("supabase_notifications.sql", "r", encoding="utf-8") as f:
    original = f.read()

# Apply the fix
fixed = original.replace(
    "IF v_last_seen IS NULL THEN\n            v_has_new := FALSE;",
    "IF v_last_seen IS NULL THEN\n            v_has_new := (v_max_updated > TO_TIMESTAMP(0));"
).replace(
    "IF v_last_seen IS NULL THEN\n            v_has_new := FALSE;\n            v_new_count := 0;",
    "IF v_last_seen IS NULL THEN\n            v_has_new := (v_max_updated > TO_TIMESTAMP(0));\n            IF v_has_new THEN v_new_count := 1; ELSE v_new_count := 0; END IF;"
).replace(
    "IF v_last_seen IS NULL THEN\n            v_has_new := FALSE;\n        ELSE",
    "IF v_last_seen IS NULL THEN\n            v_has_new := (v_max_updated > TO_TIMESTAMP(0));\n        ELSE"
)

# Extract just the CREATE OR REPLACE FUNCTION app_get_notification_summary block
start = fixed.find("CREATE OR REPLACE FUNCTION app_get_notification_summary")
end = fixed.find("GRANT EXECUTE ON FUNCTION app_get_notification_summary", start)
if start == -1 or end == -1:
    print("❌ Could not find function boundaries in SQL file")
    exit(1)

# Include up to the semicolon after the $$ block
func_sql = fixed[start:end].strip()
if not func_sql.endswith("$$;"):
    # Find the $$ ending
    dollar_end = func_sql.rfind("$$;")
    if dollar_end > 0:
        func_sql = func_sql[:dollar_end + 3]

print(f"Function SQL length: {len(func_sql)} chars")
print(f"Contains 'v_max_updated > TO_TIMESTAMP(0)': {'✅' if 'v_max_updated > TO_TIMESTAMP(0)' in func_sql else '❌'}")

# Count how many times the fix pattern appears (should be > 0)
fix_count = func_sql.count("v_max_updated > TO_TIMESTAMP(0)")
print(f"Fix pattern count: {fix_count}")

if fix_count == 0:
    print("❌ Fix not applied correctly!")
    exit(1)

ok = run_admin_sql(m, "Deploy fixed app_get_notification_summary", func_sql)

if ok:
    print("\n✅ Fix deployed successfully!")
else:
    print("\n⚠️ Deploy failed")
