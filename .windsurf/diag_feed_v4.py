"""Read-only: compare renditions of NEW (June21, invisible) vs OLD (June20,
visible) assets. Uses SELECT * (proven working pattern)."""
import json
import requests

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {"apikey": KEY, "Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}
OUT = ".windsurf/diag_feed_output_v4.txt"

NEW1 = "3d99f815-d930-442a-a30f-bdf1984b8cc0"  # free_video 2026-06-21 15:16 (test)
NEW2 = "c6f1ceb6-d276-4e39-b59f-ebdaee927fe6"  # free_video 2026-06-21 15:14 (test)
OLD = "ddff2f54-ebe3-44c9-816d-b8345fe0321e"   # free_video 2026-06-20 (visible in feed per logs)
IDS = f"'{NEW1}','{NEW2}','{OLD}'"

buf = []


def run(title, sql):
    buf.append("\n" + "=" * 90)
    buf.append(title)
    buf.append("=" * 90)
    try:
        data = requests.post(URL, headers=HEADERS, json={"p_sql": sql}, timeout=60).json()
    except Exception as e:  # noqa: BLE001
        buf.append(f"REQUEST/JSON ERROR: {e}")
        return
    if not (isinstance(data, dict) and data.get("ok")):
        buf.append(f"RPC ERROR: {json.dumps(data, ensure_ascii=False)[:1500]}")
        return
    rows = data.get("rows") or []
    if not rows:
        buf.append("(0 rows)")
        return
    for row in rows:
        val = row.get("r") if isinstance(row, dict) and "r" in row else row
        buf.append(json.dumps(val, indent=2, ensure_ascii=False, default=str))


run("VIDEO_ASSETS (NEW1, NEW2, OLD)",
    f"SELECT row_to_json(t) AS r FROM (SELECT * FROM app.video_assets WHERE id IN ({IDS})) t")

run("VIDEO_RENDITIONS (NEW1, NEW2, OLD)",
    f"SELECT row_to_json(t) AS r FROM (SELECT * FROM app.video_renditions WHERE video_asset_id IN ({IDS}) ORDER BY video_asset_id, created_at) t")

run("VIDEO_SOURCES (NEW1, NEW2, OLD)",
    f"SELECT row_to_json(t) AS r FROM (SELECT * FROM app.video_sources WHERE video_asset_id IN ({IDS})) t")

run("VIDEO_PROCESSING_JOBS (NEW1, NEW2, OLD)",
    f"SELECT row_to_json(t) AS r FROM (SELECT * FROM app.video_processing_jobs WHERE video_asset_id IN ({IDS})) t")

with open(OUT, "w", encoding="utf-8") as f:
    f.write("\n".join(buf))
print(f"WROTE {len(buf)} lines to {OUT}")
