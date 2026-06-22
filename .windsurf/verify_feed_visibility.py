"""Verify the instant-visibility fix using ONLY plain COUNT(*)/JOIN queries
(admin_execute_sql returns empty for GROUP BY / correlated-scalar / row_to_json,
but plain COUNT(*) and simple JOINs work). Output -> verify_feed_visibility_output.txt
"""
import json
import requests

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {"apikey": KEY, "Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}
OUT = []


def w(line=""):
    OUT.append(str(line))
    print(line)


def run_sql(sql):
    try:
        r = requests.post(URL, headers=HEADERS, json={"p_sql": sql}, timeout=90)
        data = r.json()
    except Exception as e:  # noqa: BLE001
        return None, f"ERROR: {e}"
    if isinstance(data, dict) and data.get("ok"):
        return data.get("rows") or [], None
    return None, f"RPC ERROR: {json.dumps(data, ensure_ascii=False)[:800]}"


def count(label, sql):
    rows, err = run_sql(sql)
    if err:
        w(f"{label}: {err}")
    else:
        w(f"{label}: {json.dumps(rows, ensure_ascii=False)}")


BASE = ("FROM app.free_videos fv "
        "WHERE fv.is_active = TRUE AND fv.is_deleted = FALSE AND fv.video_asset_id IS NOT NULL "
        "AND COALESCE(fv.moderation_status,'published') NOT IN ('blocked_ai','rejected')")

w("=" * 80)
w("VERIFICATION INSTANT VISIBILITY (free_videos)")
w("=" * 80)

count("A. Total free_videos publiables", f"SELECT COUNT(*) AS n {BASE}")

count(
    "B. VISIBLES avant fix (>=1 rendition ready)",
    "SELECT COUNT(DISTINCT fv.id) AS n "
    "FROM app.free_videos fv "
    "JOIN app.video_renditions vr ON vr.video_asset_id = fv.video_asset_id "
    "  AND vr.status='ready' AND vr.public_url_hint IS NOT NULL "
    "WHERE fv.is_active = TRUE AND fv.is_deleted = FALSE AND fv.video_asset_id IS NOT NULL "
    "AND COALESCE(fv.moderation_status,'published') NOT IN ('blocked_ai','rejected')",
)

count(
    "C. NOUVELLEMENT visibles (pas de rendition ready MAIS source ingeree)",
    "SELECT COUNT(DISTINCT fv.id) AS n "
    "FROM app.free_videos fv "
    "JOIN app.video_sources vs ON vs.video_asset_id = fv.video_asset_id "
    "  AND vs.ingested_at IS NOT NULL AND vs.storage_bucket IS NOT NULL AND vs.storage_path IS NOT NULL "
    "LEFT JOIN app.video_renditions vr ON vr.video_asset_id = fv.video_asset_id "
    "  AND vr.status='ready' AND vr.public_url_hint IS NOT NULL "
    "WHERE fv.is_active = TRUE AND fv.is_deleted = FALSE AND fv.video_asset_id IS NOT NULL "
    "AND COALESCE(fv.moderation_status,'published') NOT IN ('blocked_ai','rejected') "
    "AND vr.id IS NULL",
)

count(
    "D. ENCORE invisibles (ni rendition ready ni source ingeree)",
    "SELECT COUNT(DISTINCT fv.id) AS n "
    "FROM app.free_videos fv "
    "LEFT JOIN app.video_sources vs ON vs.video_asset_id = fv.video_asset_id "
    "  AND vs.ingested_at IS NOT NULL AND vs.storage_bucket IS NOT NULL AND vs.storage_path IS NOT NULL "
    "LEFT JOIN app.video_renditions vr ON vr.video_asset_id = fv.video_asset_id "
    "  AND vr.status='ready' AND vr.public_url_hint IS NOT NULL "
    "WHERE fv.is_active = TRUE AND fv.is_deleted = FALSE AND fv.video_asset_id IS NOT NULL "
    "AND COALESCE(fv.moderation_status,'published') NOT IN ('blocked_ai','rejected') "
    "AND vr.id IS NULL AND vs.id IS NULL",
)

with open("verify_feed_visibility_output.txt", "w", encoding="utf-8") as f:
    f.write("\n".join(OUT))
w("\nDONE -> verify_feed_visibility_output.txt")
