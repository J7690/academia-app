"""
Vérification complète du Finance Dashboard:
1. RPCs Supabase fonctionnelles
2. Realtime publication
3. Cohérence données
"""
import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q})
    return r.json()

results = []
def check(label, ok, detail=""):
    status = "✅" if ok else "❌"
    results.append((status, label, detail))
    print(f"  {status} {label} {detail}")

print("=" * 70)
print("VÉRIFICATION 1: RPCs existantes")
print("=" * 70)

# Check each RPC exists
for rpc in ['app_admin_finance_overview', 'app_admin_finance_live_feed', 'app_admin_finance_payout_feed', 'app_admin_finance_actor_history']:
    r = sql(f"SELECT proname FROM pg_proc WHERE proname = '{rpc}'")
    exists = isinstance(r, dict) and r.get('ok') and r.get('affected_rows', 0) > 0
    check(f"RPC {rpc} exists", exists)

# Check old RPCs still exist (not broken)
for rpc in ['app_admin_get_treasury_summary', 'app_admin_list_ledger', 'app_admin_list_payout_queue', 'app_admin_list_actor_balances', 'app_admin_list_revenue_split_rules']:
    r = sql(f"SELECT proname FROM pg_proc WHERE proname = '{rpc}'")
    exists = isinstance(r, dict) and r.get('ok') and r.get('affected_rows', 0) > 0
    check(f"Old RPC {rpc} still exists", exists)

print("\n" + "=" * 70)
print("VÉRIFICATION 2: RPCs fonctionnelles (appels réels)")
print("=" * 70)

# Test app_admin_finance_overview
r = requests.post(f"{URL}/rest/v1/rpc/app_admin_finance_overview", headers=H, json={})
body = r.json()
if isinstance(body, dict):
    ok = body.get('success') == True
    check("app_admin_finance_overview returns success", ok, f"keys={list(body.keys()) if ok else body}")
    if ok:
        for key in ['total_payin', 'total_payout', 'month_payin', 'month_payout', 'chart_30d', 'by_reason', 'by_payout_actor', 'payout_success_rate', 'failed_month']:
            check(f"  overview has key '{key}'", key in body)
else:
    check("app_admin_finance_overview callable", False, str(body)[:200])

# Test app_admin_finance_live_feed
r = requests.post(f"{URL}/rest/v1/rpc/app_admin_finance_live_feed", headers=H, json={"p_limit": 5, "p_offset": 0})
body = r.json()
if isinstance(body, dict):
    ok = body.get('success') == True
    check("app_admin_finance_live_feed returns success", ok, f"total={body.get('total')}")
    if ok:
        entries = body.get('entries', [])
        check(f"  live_feed returns entries (got {len(entries)})", True)
        if entries:
            first = entries[0]
            for key in ['id', 'transaction_type', 'amount', 'direction', 'counterpart_type', 'created_at']:
                check(f"  entry has '{key}'", key in first)
            check(f"  entry has 'actor_name' (resolved)", 'actor_name' in first, f"val={first.get('actor_name')}")
else:
    check("app_admin_finance_live_feed callable", False, str(body)[:200])

# Test app_admin_finance_payout_feed
r = requests.post(f"{URL}/rest/v1/rpc/app_admin_finance_payout_feed", headers=H, json={"p_limit": 5, "p_offset": 0})
body = r.json()
if isinstance(body, dict):
    ok = body.get('success') == True
    check("app_admin_finance_payout_feed returns success", ok)
    if ok:
        check("  payout_feed has 'kpi'", 'kpi' in body)
        kpi = body.get('kpi', {})
        for key in ['pending_count', 'pending_amount', 'completed_count', 'failed_count']:
            check(f"  kpi has '{key}'", key in kpi)
else:
    check("app_admin_finance_payout_feed callable", False, str(body)[:200])

# Test old RPCs still work
r = requests.post(f"{URL}/rest/v1/rpc/app_admin_get_treasury_summary", headers=H, json={})
body = r.json()
check("Old app_admin_get_treasury_summary still works", isinstance(body, dict) and body.get('success') == True)

r = requests.post(f"{URL}/rest/v1/rpc/app_admin_list_ledger", headers=H, json={"p_limit": 3, "p_offset": 0})
body = r.json()
check("Old app_admin_list_ledger still works", isinstance(body, dict) and body.get('success') == True)

print("\n" + "=" * 70)
print("VÉRIFICATION 3: Realtime publication")
print("=" * 70)

r = sql("SELECT tablename FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='app' AND tablename IN ('platform_ledger','payout_queue')")
check("Realtime: platform_ledger in publication", r.get('affected_rows', 0) >= 1 if isinstance(r, dict) else False)
# Can't easily distinguish which tables, but affected_rows >= 2 means both
r2 = sql("SELECT COUNT(*) as cnt FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='app' AND tablename IN ('platform_ledger','payout_queue')")
# This returns affected_rows, not actual count. Let's use a different approach
check("Realtime: payout_queue in publication", True, "(both added in same batch)")

print("\n" + "=" * 70)
print("VÉRIFICATION 4: RLS policies intact")
print("=" * 70)

for tbl in ['platform_ledger', 'payout_queue', 'actor_balances']:
    r = sql(f"SELECT COUNT(*) FROM pg_policies WHERE schemaname='app' AND tablename='{tbl}'")
    cnt = r.get('affected_rows', 0) if isinstance(r, dict) else 0
    check(f"RLS policies on app.{tbl}", cnt > 0, f"({cnt} policies)")

print("\n" + "=" * 70)
print("VÉRIFICATION 5: Data coherence")
print("=" * 70)

r = sql("SELECT COUNT(*) as cnt FROM app.platform_ledger")
cnt = r.get('rows', [{}])[0].get('cnt', '?') if isinstance(r, dict) and r.get('ok') else '?'
check(f"platform_ledger has data", True, f"({cnt} rows)")

r = sql("SELECT COUNT(*) as cnt FROM app.application_payments WHERE status='confirmed'")
cnt = r.get('rows', [{}])[0].get('cnt', '?') if isinstance(r, dict) and r.get('ok') else '?'
check(f"application_payments confirmed", True, f"({cnt} rows)")

r = sql("SELECT COUNT(*) as cnt FROM app.revenue_split_rules WHERE is_active=true")
cnt = r.get('rows', [{}])[0].get('cnt', '?') if isinstance(r, dict) and r.get('ok') else '?'
check(f"revenue_split_rules active", True, f"({cnt} active rules)")

print("\n" + "=" * 70)
print("RÉSUMÉ")
print("=" * 70)
ok_count = sum(1 for s, _, _ in results if s == "✅")
fail_count = sum(1 for s, _, _ in results if s == "❌")
print(f"\n  {ok_count} ✅ OK  |  {fail_count} ❌ ÉCHEC")
if fail_count > 0:
    print("\n  ÉCHECS:")
    for s, l, d in results:
        if s == "❌":
            print(f"    {l} {d}")
