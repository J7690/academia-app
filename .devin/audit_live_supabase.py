"""
Audit Live Supabase — Tables, RPCs, Edge Functions, données
"""
import requests
import json

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "count=exact",
}

def query_table(table, schema="public"):
    """Query a table and get count + sample"""
    h = dict(HEADERS)
    if schema != "public":
        h["Accept-Profile"] = schema
    r = requests.get(
        f"{SUPABASE_URL}/rest/v1/{table}?select=*&limit=3",
        headers=h,
    )
    count_header = r.headers.get("Content-Range", "")
    total = "?"
    if "/" in count_header:
        total = count_header.split("/")[-1]
    return r.status_code, total, r.json() if r.status_code == 200 else r.text[:200]

def test_rpc(rpc_name, params=None):
    """Test if an RPC exists and returns data"""
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/{rpc_name}",
        headers=HEADERS,
        json=params or {},
    )
    return r.status_code, r.text[:300] if r.status_code != 200 else str(r.json())[:300]

def test_edge_function(name):
    """Test if an edge function responds"""
    r = requests.post(
        f"{SUPABASE_URL}/functions/v1/{name}",
        headers=HEADERS,
        json={},
    )
    return r.status_code, r.text[:200]

# ═══════════════════════════════════════════════════════════════
print("=" * 60)
print("AUDIT LIVE — Tables")
print("=" * 60)

# Tables in public schema
public_tables = [
    "prep_live_sessions",
    "prep_live_session_participants",
    "online_course_live_sessions",
    "online_course_live_session_participants",
]

for t in public_tables:
    status, count, data = query_table(t, "public")
    if status == 200:
        print(f"  ✅ {t} (public): {count} rows")
        if isinstance(data, list) and data:
            cols = list(data[0].keys())
            print(f"     Colonnes: {', '.join(cols[:15])}")
    elif status == 404:
        print(f"  ❌ {t} (public): TABLE NON TROUVÉE")
    else:
        print(f"  ⚠️  {t} (public): HTTP {status}")

# Tables in app schema
app_tables = [
    "challenge_game_live_sessions",
    "challenge_live_sessions",
    "live_sessions",
]

for t in app_tables:
    status, count, data = query_table(t, "app")
    if status == 200:
        print(f"  ✅ {t} (app): {count} rows")
        if isinstance(data, list) and data:
            cols = list(data[0].keys())
            print(f"     Colonnes: {', '.join(cols[:15])}")
    elif status == 404 or status == 406:
        print(f"  ❌ {t} (app): TABLE NON TROUVÉE")
    else:
        print(f"  ⚠️  {t} (app): HTTP {status} — {data}")

# ═══════════════════════════════════════════════════════════════
print("\n" + "=" * 60)
print("AUDIT LIVE — RPCs")
print("=" * 60)

rpcs = [
    ("app_student_list_my_online_course_live_sessions", None),
    ("app_prep_student_list_live_sessions", None),
    ("app_prep_student_join_live_session", {"p_session_id": "00000000-0000-0000-0000-000000000000"}),
    ("app_register_online_course_live_session_participant", {"p_session_id": "00000000-0000-0000-0000-000000000000", "p_user_id": "00000000-0000-0000-0000-000000000000"}),
    ("app_admin_create_live_session", None),
    ("app_instructor_list_my_live_sessions", None),
    ("app_list_live_sessions", None),
]

for rpc_name, params in rpcs:
    status, result = test_rpc(rpc_name, params)
    if status == 200:
        print(f"  ✅ {rpc_name}: OK — {result[:100]}")
    elif status == 404:
        print(f"  ❌ {rpc_name}: RPC NON TROUVÉE")
    else:
        print(f"  ⚠️  {rpc_name}: HTTP {status} — {result[:100]}")

# ═══════════════════════════════════════════════════════════════
print("\n" + "=" * 60)
print("AUDIT LIVE — Edge Functions")
print("=" * 60)

edge_functions = ["livekit-token", "livekit-recording"]

for fn in edge_functions:
    status, result = test_edge_function(fn)
    if status in (200, 400, 401):
        print(f"  ✅ {fn}: DEPLOYED (HTTP {status})")
    elif status == 404:
        print(f"  ❌ {fn}: NON DÉPLOYÉE")
    else:
        print(f"  ⚠️  {fn}: HTTP {status} — {result[:100]}")

# ═══════════════════════════════════════════════════════════════
print("\n" + "=" * 60)
print("AUDIT LIVE — Secrets LiveKit")
print("=" * 60)

# Test livekit-token with a dummy session to see if LiveKit is configured
r = requests.post(
    f"{SUPABASE_URL}/functions/v1/livekit-token",
    headers={
        "apikey": SERVICE_KEY,
        "Authorization": f"Bearer {SERVICE_KEY}",
        "Content-Type": "application/json",
    },
    json={"session_id": "test-dummy-session"},
)
print(f"  livekit-token response (dummy): HTTP {r.status_code}")
try:
    data = r.json()
    print(f"  → {json.dumps(data, ensure_ascii=False)[:300]}")
except:
    print(f"  → {r.text[:300]}")

print("\n🏁 Audit live terminé.")
