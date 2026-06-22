"""Apply + verify the INSTANT feed visibility fix via admin_execute_sql.

1) Applies sql_changes/change_20260622_feed_instant_visibility.sql
   (CREATE OR REPLACE app_student_unified_video_feed with source-URL fallback).
2) Verifies:
   - the new function body actually contains the video_sources fallback;
   - how many published free_videos were PREVIOUSLY invisible (no ready
     rendition) but now resolve a video_url via the uploaded source;
   - a preview of url resolution (rendition vs source) for recent videos.

DDL is idempotent (CREATE OR REPLACE). Output -> apply_feed_instant_visibility_output.txt
"""
import json
import os
import requests

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {"apikey": KEY, "Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}

HERE = os.path.dirname(os.path.abspath(__file__))
SQL_FILE = os.path.join(HERE, "sql_changes", "change_20260622_feed_instant_visibility.sql")
OUT = []


def w(line=""):
    OUT.append(str(line))
    print(line)


def run_sql(sql):
    try:
        r = requests.post(URL, headers=HEADERS, json={"p_sql": sql}, timeout=90)
    except Exception as e:  # noqa: BLE001
        return None, f"REQUEST ERROR: {e}"
    try:
        data = r.json()
    except Exception as e:  # noqa: BLE001
        return None, f"JSON ERROR: {e} | raw={r.text[:500]}"
    if isinstance(data, dict) and data.get("ok"):
        return data.get("rows") or [], None
    return None, f"RPC ERROR: {json.dumps(data, ensure_ascii=False)[:1500]}"


def section(title):
    w("\n" + "=" * 90)
    w(title)
    w("=" * 90)


# --- 1) APPLY -----------------------------------------------------------------
section("APPLY: CREATE OR REPLACE app_student_unified_video_feed")
with open(SQL_FILE, "r", encoding="utf-8") as f:
    ddl = f.read()
rows, err = run_sql(ddl)
if err:
    w("FAILED: " + err)
    with open(os.path.join(HERE, "apply_feed_instant_visibility_output.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(OUT))
    raise SystemExit(1)
w("OK (function replaced)")

# --- 2) Confirm the new body contains the source fallback --------------------
section("VERIF 1: la nouvelle definition contient bien le fallback video_sources")
rows, err = run_sql(
    "SELECT (position('app.video_sources vs' IN pg_get_functiondef(p.oid)) > 0)::text AS has_fallback "
    "FROM pg_proc p WHERE p.proname = 'app_student_unified_video_feed' LIMIT 1"
)
w(err or json.dumps(rows, ensure_ascii=False))

# --- 3) Videos newly revealed (published, no ready rendition, but source ok) -
section("VERIF 2: free_videos publiees SANS rendition ready mais AVEC source uploadee")
rows, err = run_sql(
    """
    SELECT row_to_json(t) AS r FROM (
      SELECT COUNT(*) AS newly_visible
      FROM app.free_videos fv
      WHERE fv.is_active = TRUE
        AND fv.is_deleted = FALSE
        AND fv.video_asset_id IS NOT NULL
        AND COALESCE(fv.moderation_status,'published') NOT IN ('blocked_ai','rejected')
        AND NOT EXISTS (
          SELECT 1 FROM app.video_renditions vr
          WHERE vr.video_asset_id = fv.video_asset_id
            AND vr.status = 'ready' AND vr.public_url_hint IS NOT NULL
        )
        AND EXISTS (
          SELECT 1 FROM app.video_sources vs
          WHERE vs.video_asset_id = fv.video_asset_id
            AND vs.ingested_at IS NOT NULL
            AND vs.storage_bucket IS NOT NULL AND vs.storage_path IS NOT NULL
        )
    ) t
    """
)
w(err or "\n".join(json.dumps(r.get("r", r), ensure_ascii=False) for r in rows))

# --- 4) Resolution preview for the 6 most recent free_videos ------------------
section("VERIF 3: resolution video_url (rendition vs source) - 6 dernieres free_videos")
rows, err = run_sql(
    """
    SELECT row_to_json(t) AS r FROM (
      SELECT
        fv.id,
        fv.created_at,
        (
          SELECT vr.rendition_key
          FROM app.video_renditions vr
          WHERE vr.video_asset_id = fv.video_asset_id
            AND vr.status='ready' AND vr.public_url_hint IS NOT NULL
          ORDER BY vr.created_at DESC LIMIT 1
        ) AS ready_rendition,
        (
          SELECT vs.ingested_at IS NOT NULL
          FROM app.video_sources vs
          WHERE vs.video_asset_id = fv.video_asset_id
          ORDER BY vs.created_at DESC LIMIT 1
        ) AS source_ingested,
        (
          COALESCE(
            (SELECT vr.public_url_hint FROM app.video_renditions vr
             WHERE vr.video_asset_id=fv.video_asset_id AND vr.status='ready'
               AND vr.public_url_hint IS NOT NULL
             ORDER BY vr.created_at DESC LIMIT 1),
            (SELECT 'https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/public/'
                    || vs.storage_bucket || '/' || vs.storage_path
             FROM app.video_sources vs
             WHERE vs.video_asset_id=fv.video_asset_id AND vs.ingested_at IS NOT NULL
               AND vs.storage_bucket IS NOT NULL AND vs.storage_path IS NOT NULL
             ORDER BY vs.created_at DESC LIMIT 1)
          ) IS NOT NULL
        ) AS resolves_video_url
      FROM app.free_videos fv
      WHERE fv.is_active = TRUE AND fv.is_deleted = FALSE AND fv.video_asset_id IS NOT NULL
      ORDER BY fv.created_at DESC
      LIMIT 6
    ) t
    """
)
if err:
    w(err)
else:
    for r in rows:
        w(json.dumps(r.get("r", r), indent=2, ensure_ascii=False, default=str))

with open(os.path.join(HERE, "apply_feed_instant_visibility_output.txt"), "w", encoding="utf-8") as f:
    f.write("\n".join(OUT))

w("\n\nDONE -> apply_feed_instant_visibility_output.txt")
