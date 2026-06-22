"""Verify the freshly deployed transcode-video Edge Function actually works
(no more owner_id 400/404) and now creates the 'original' rendition.

Calls the function on an existing asset (idempotent upsert), then confirms via
admin_execute_sql that an 'original' rendition exists. Output -> verify_transcode_deploy_output.txt
"""
import json
import requests

PROJECT = "thevdfcwlcqzdoybfvgs"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

FUNC_URL = f"https://{PROJECT}.supabase.co/functions/v1/transcode-video"
RPC_URL = f"https://{PROJECT}.supabase.co/rest/v1/rpc/admin_execute_sql"
HEADERS = {"apikey": KEY, "Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}

# Existing asset (from diag_feed_output_v4.txt) that has an uploaded source.
TEST_ASSET = "c6f1ceb6-d276-4e39-b59f-ebdaee927fe6"
OUT = []


def w(line=""):
    OUT.append(str(line))
    print(line)


def run_sql(sql):
    try:
        r = requests.post(RPC_URL, headers=HEADERS, json={"p_sql": sql}, timeout=60)
        data = r.json()
    except Exception as e:  # noqa: BLE001
        return None, f"ERROR: {e}"
    if isinstance(data, dict) and data.get("ok"):
        return data.get("rows") or [], None
    return None, f"RPC ERROR: {json.dumps(data, ensure_ascii=False)[:800]}"


w("=" * 80)
w("VERIF DEPLOY transcode-video")
w("=" * 80)

# 1) Call the function on a real asset
w(f"\n1. POST {FUNC_URL}  (video_asset_id={TEST_ASSET})")
try:
    resp = requests.post(FUNC_URL, headers=HEADERS, json={"video_asset_id": TEST_ASSET}, timeout=60)
    w(f"   HTTP {resp.status_code}")
    w(f"   BODY: {resp.text[:900]}")
except Exception as e:  # noqa: BLE001
    w(f"   REQUEST ERROR: {e}")

# 2) Confirm an 'original' rendition now exists for this asset
w("\n2. Verif rendition 'original' pour l'asset de test")
rows, err = run_sql(
    "SELECT COUNT(*) AS n FROM app.video_renditions "
    f"WHERE video_asset_id = '{TEST_ASSET}' AND rendition_key = 'original'"
)
w("   " + (err or json.dumps(rows, ensure_ascii=False)))

# 3) Global count of 'original' renditions (was 0 before the fix)
w("\n3. Nombre total de renditions 'original' en base")
rows, err = run_sql(
    "SELECT COUNT(*) AS n FROM app.video_renditions WHERE rendition_key = 'original'"
)
w("   " + (err or json.dumps(rows, ensure_ascii=False)))

with open("verify_transcode_deploy_output.txt", "w", encoding="utf-8") as f:
    f.write("\n".join(OUT))
w("\nDONE -> verify_transcode_deploy_output.txt")
