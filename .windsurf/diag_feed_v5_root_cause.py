"""Read-only root-cause confirmation for INSTANT feed visibility.

Goal: prove that the feed gate (video_url IS NOT NULL == has a 'ready' rendition)
is the bottleneck, and gather everything needed to choose the SAFEST fix:
  - definition of app_videoasset_register_uploaded_source (when is the file usable?)
  - distinct video_assets.status values + counts
  - how many published free_videos are CURRENTLY invisible (no ready rendition)
  - whether any 'original' rendition exists at all (transcode-video success proof)
  - triggers on app.video_sources / app.video_assets
  - is the 'video-assets' bucket public? (source URL must be publicly playable)
  - video_sources columns (storage_bucket / storage_path / ingested_at gating)

All statements are SELECT / pg_get_functiondef => read-only, safe.
Output is written to diag_feed_v5_output.txt to avoid console truncation.
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


def section(title):
    w("\n" + "=" * 90)
    w(title)
    w("=" * 90)


def dump_def(label, proname):
    section(f"DEFINITION: {label}  ({proname})")
    rows, err = run_sql(
        "SELECT pg_get_functiondef(p.oid) AS definition "
        "FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace "
        f"WHERE p.proname = '{proname}' ORDER BY n.nspname LIMIT 5"
    )
    if err:
        w(err)
        return
    if not rows:
        w("(function not found)")
        return
    for row in rows:
        w(row.get("definition", row))
        w("-" * 40)


def dump_rows(label, sql):
    section(label)
    rows, err = run_sql(sql)
    if err:
        w(err)
        return
    if not rows:
        w("(0 rows)")
        return
    for row in rows:
        val = row.get("r") if isinstance(row, dict) and "r" in row else row
        w(json.dumps(val, indent=2, ensure_ascii=False, default=str))


# 1) Registration RPC: understand WHEN the source becomes usable (gating)
dump_def("Enregistrement source uploadée", "app_videoasset_register_uploaded_source")

# 2) Distinct asset statuses (what status right after register, before transcode?)
dump_rows(
    "video_assets.status — valeurs distinctes + counts",
    """
    SELECT row_to_json(t) AS r FROM (
      SELECT status, COUNT(*) AS n
      FROM app.video_assets
      GROUP BY status
      ORDER BY n DESC
    ) t
    """,
)

# 3) How many published free_videos are CURRENTLY invisible (no ready rendition)?
dump_rows(
    "free_videos PUBLIÉES mais INVISIBLES (aucune rendition ready) — preuve du gate",
    """
    SELECT row_to_json(t) AS r FROM (
      SELECT COUNT(*) AS invisible_published
      FROM app.free_videos fv
      WHERE fv.is_active = TRUE
        AND fv.is_deleted = FALSE
        AND fv.video_asset_id IS NOT NULL
        AND COALESCE(fv.moderation_status,'published') NOT IN ('blocked_ai','rejected')
        AND NOT EXISTS (
          SELECT 1 FROM app.video_renditions vr
          WHERE vr.video_asset_id = fv.video_asset_id
            AND vr.status = 'ready'
            AND vr.public_url_hint IS NOT NULL
        )
    ) t
    """,
)

# 4) Does ANY 'original' rendition exist? (transcode-video success proof)
dump_rows(
    "Renditions par rendition_key (existe-t-il 'original' ?)",
    """
    SELECT row_to_json(t) AS r FROM (
      SELECT rendition_key, COUNT(*) AS n
      FROM app.video_renditions
      GROUP BY rendition_key
      ORDER BY n DESC
    ) t
    """,
)

# 5) Triggers on the ingestion tables
dump_rows(
    "Triggers sur app.video_sources et app.video_assets",
    """
    SELECT row_to_json(t) AS r FROM (
      SELECT event_object_table, trigger_name, action_timing, event_manipulation
      FROM information_schema.triggers
      WHERE event_object_schema='app'
        AND event_object_table IN ('video_sources','video_assets')
      ORDER BY event_object_table, trigger_name
    ) t
    """,
)

# 6) Is the 'video-assets' bucket public? (source URL must be playable)
dump_rows(
    "storage.buckets video-assets (public ?)",
    """
    SELECT row_to_json(t) AS r FROM (
      SELECT id, name, public
      FROM storage.buckets
      WHERE id = 'video-assets'
    ) t
    """,
)

# 7) video_sources columns (confirm storage_bucket / storage_path / ingested_at)
dump_rows(
    "COLONNES app.video_sources",
    """
    SELECT row_to_json(t) AS r FROM (
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns
      WHERE table_schema='app' AND table_name='video_sources'
      ORDER BY ordinal_position
    ) t
    """,
)

with open("diag_feed_v5_output.txt", "w", encoding="utf-8") as f:
    f.write("\n".join(OUT))

w("\n\nDONE -> diag_feed_v5_output.txt")
