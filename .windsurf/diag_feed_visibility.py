"""Read-only diagnostic: why freshly published videos don't appear in the feed.

Dumps the server-side definitions of the feed + free-video RPCs and inspects the
most recent rows actually persisted, so we can tell PERSISTENCE vs FILTERING.
All statements are SELECT / pg_get_functiondef => read-only, safe.
"""
import json
import requests

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {"apikey": KEY, "Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}


def run_sql(sql):
    try:
        r = requests.post(URL, headers=HEADERS, json={"p_sql": sql}, timeout=60)
    except Exception as e:  # noqa: BLE001
        return None, f"REQUEST ERROR: {e}"
    try:
        data = r.json()
    except Exception as e:  # noqa: BLE001
        return None, f"JSON ERROR: {e} | raw={r.text[:500]}"
    if isinstance(data, dict) and data.get("ok"):
        return data.get("rows") or [], None
    return None, f"RPC ERROR: {json.dumps(data, ensure_ascii=False)[:1000]}"


def dump_def(label, proname):
    print(f"\n{'='*80}\nDEFINITION: {label}  ({proname})\n{'='*80}")
    rows, err = run_sql(
        "SELECT pg_get_functiondef(p.oid) AS definition "
        "FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace "
        f"WHERE p.proname = '{proname}' ORDER BY n.nspname LIMIT 5"
    )
    if err:
        print(err)
        return
    if not rows:
        print("(function not found)")
        return
    for row in rows:
        print(row.get("definition", row))
        print("-" * 40)


def dump_rows(label, sql):
    print(f"\n{'='*80}\n{label}\n{'='*80}")
    rows, err = run_sql(sql)
    if err:
        print(err)
        return
    if not rows:
        print("(0 rows)")
        return
    for row in rows:
        # Most queries below select a single json column named 'r'.
        val = row.get("r") if isinstance(row, dict) and "r" in row else row
        print(json.dumps(val, indent=2, ensure_ascii=False, default=str))


# --- 1) Server-side filters --------------------------------------------------
dump_def("Feed unifié (filtre de visibilité)", "app_student_unified_video_feed")
dump_def("Création free video", "app_student_create_free_video")
dump_def("Set free video main renditions", "app_student_set_free_video_main_renditions")

# --- 2) Schema of free_videos / video_assets --------------------------------
dump_rows(
    "COLONNES app.free_videos",
    """
    SELECT row_to_json(t) AS r FROM (
      SELECT column_name, data_type, column_default, is_nullable
      FROM information_schema.columns
      WHERE table_schema='app' AND table_name='free_videos'
      ORDER BY ordinal_position
    ) t
    """,
)

# --- 3) Did the publishes actually persist? ---------------------------------
dump_rows(
    "DERNIÈRES app.free_videos (8) — persistance + status + asset",
    """
    SELECT row_to_json(t) AS r FROM (
      SELECT fv.*
      FROM app.free_videos fv
      ORDER BY fv.created_at DESC
      LIMIT 8
    ) t
    """,
)

dump_rows(
    "DERNIERS app.video_assets (8) — status réel après transcode",
    """
    SELECT row_to_json(t) AS r FROM (
      SELECT va.id, va.status, va.origin, va.owner_id, va.created_at
      FROM app.video_assets va
      ORDER BY va.created_at DESC
      LIMIT 8
    ) t
    """,
)

dump_rows(
    "RENDITIONS des 8 derniers video_assets",
    """
    SELECT row_to_json(t) AS r FROM (
      SELECT vr.video_asset_id, vr.rendition_key, vr.status, vr.created_at
      FROM app.video_renditions vr
      WHERE vr.video_asset_id IN (
        SELECT id FROM app.video_assets ORDER BY created_at DESC LIMIT 8
      )
      ORDER BY vr.created_at DESC
    ) t
    """,
)

print("\n\nDONE.")
