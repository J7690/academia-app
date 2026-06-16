#!/usr/bin/env python3
"""Compare Flutter RPCs vs Supabase RPCs - identify mismatches."""
import json, requests
from pathlib import Path
from collections import defaultdict

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SK, "Authorization": f"Bearer {SK}", "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                       json={"p_sql": " ".join(q.split())}, timeout=60)
    body = r.json() if r.status_code == 200 else {"ok": False}
    if isinstance(body, dict) and body.get("ok"):
        return body.get("rows", [])
    return []

# Load Flutter audit
flutter_data = json.loads((Path(__file__).parent / "logs" / "audit_global_flutter.json").read_text(encoding="utf-8"))
flutter_rpcs = set(flutter_data.get("rpc_calls", {}).keys())

# Get all Supabase RPCs
supabase_rpcs_rows = sql("SELECT routine_name FROM information_schema.routines WHERE routine_schema IN ('app','public') AND routine_type = 'FUNCTION' AND routine_name LIKE 'app_%' ORDER BY routine_name")
supabase_rpcs = set(r["routine_name"] for r in supabase_rpcs_rows)

print("=" * 70)
print("COMPARAISON FLUTTER <-> SUPABASE")
print("=" * 70)

# 1. RPCs called in Flutter but NOT in Supabase
missing_in_supabase = flutter_rpcs - supabase_rpcs
print(f"\n[1] RPCs appelees dans Flutter MAIS ABSENTES de Supabase ({len(missing_in_supabase)}):")
for rpc in sorted(missing_in_supabase):
    files = flutter_data["rpc_calls"].get(rpc, [])
    print(f"  !! {rpc}")
    for f in files[:2]:
        print(f"     -> {f}")

# 2. RPCs in Supabase but NOT called in Flutter
unused_in_flutter = supabase_rpcs - flutter_rpcs
print(f"\n[2] RPCs dans Supabase MAIS NON APPELEES dans Flutter ({len(unused_in_flutter)}):")
# Group by prefix
unused_groups = defaultdict(list)
for rpc in sorted(unused_in_flutter):
    parts = rpc.split("_")
    prefix = "_".join(parts[:3]) if len(parts) >= 3 else rpc
    unused_groups[prefix].append(rpc)
for prefix, rpcs in sorted(unused_groups.items()):
    print(f"  {prefix}*:")
    for r in rpcs:
        print(f"    - {r}")

# 3. RPCs in BOTH (connected)
connected = flutter_rpcs & supabase_rpcs
print(f"\n[3] RPCs CONNECTEES Flutter <-> Supabase ({len(connected)}):")
# Group
connected_groups = defaultdict(int)
for rpc in connected:
    if "admin" in rpc and "prep" in rpc: cat = "ADMIN_PREP"
    elif "admin" in rpc: cat = "ADMIN"
    elif "prep_teacher" in rpc: cat = "TEACHER_CONCOURS"
    elif "ci_" in rpc: cat = "TEACHER_TD"
    elif "prep_student" in rpc: cat = "STUDENT_PREP"
    elif "prep_" in rpc: cat = "PREP"
    elif "td_" in rpc: cat = "TD"
    elif "student" in rpc: cat = "STUDENT"
    elif "community" in rpc: cat = "COMMUNITY"
    elif "marketplace" in rpc: cat = "MARKETPLACE"
    elif "university" in rpc or "uni_" in rpc: cat = "UNIVERSITY"
    elif "commercial" in rpc: cat = "COMMERCIAL"
    elif "bobodo" in rpc: cat = "BOBODO"
    else: cat = "OTHER"
    connected_groups[cat] += 1

for cat, cnt in sorted(connected_groups.items(), key=lambda x: -x[1]):
    print(f"  {cat:25s} {cnt} RPCs connectees")

# 4. Edge Functions
print(f"\n[4] EDGE FUNCTIONS:")
flutter_edge = set(flutter_data.get("edge_fn_calls", {}).keys())
all_edge = {"prep-tutor-chat", "prep-ingest-document", "prep-generate-questions",
            "prep-analyze-trends", "prep-grade-assignment", "bobodo-chat",
            "send-push-notifications", "admin-create-teacher-account",
            "admin-promote-user-role", "admin-create-merchant-account"}

for fn in sorted(all_edge):
    in_flutter = fn in flutter_edge
    try:
        resp = requests.options(f"{URL}/functions/v1/{fn}", timeout=10)
        deployed = resp.status_code in (200, 204)
    except:
        deployed = False
    status = "OK" if in_flutter and deployed else "FLUTTER_ONLY" if in_flutter else "DEPLOYED_ONLY" if deployed else "MISSING"
    print(f"  {fn:40s} Flutter={'YES' if in_flutter else 'NO ':3s}  Deployed={'YES' if deployed else 'NO ':3s}  -> {status}")

# 5. Summary
print(f"\n{'='*70}")
print("RESUME GLOBAL")
print(f"{'='*70}")
print(f"  RPCs dans Flutter:         {len(flutter_rpcs)}")
print(f"  RPCs dans Supabase:        {len(supabase_rpcs)}")
print(f"  RPCs CONNECTEES (OK):      {len(connected)}")
print(f"  RPCs MANQUANTES Supabase:  {len(missing_in_supabase)}")
print(f"  RPCs NON UTILISEES Flutter:{len(unused_in_flutter)}")
print(f"  Edge Functions Flutter:    {len(flutter_edge)}")
print(f"  Edge Functions deployed:   {sum(1 for fn in all_edge if fn in flutter_edge)}")

out = Path(__file__).parent / "logs" / "audit_global_comparison.json"
with open(out, "w", encoding="utf-8") as f:
    json.dump({
        "flutter_rpcs": len(flutter_rpcs),
        "supabase_rpcs": len(supabase_rpcs),
        "connected": len(connected),
        "missing_in_supabase": sorted(missing_in_supabase),
        "unused_in_flutter": sorted(unused_in_flutter),
        "connected_by_category": dict(connected_groups),
    }, f, indent=2, ensure_ascii=False)
print(f"\nComparison saved: {out}")
