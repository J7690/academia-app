"""Read-only: inspect the exact renditions/status of the 2 most recent published
free_videos (the user's June 21 test) to confirm feed-exclusion root cause."""
import json
import requests

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {"apikey": KEY, "Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}
OUT = ".windsurf/diag_feed_output_v3.txt"

buf = []


def run(title, sql):
    buf.append("\n" + "=" * 90)
    buf.append(title)
    buf.append("=" * 90)
    try:
        r = requests.post(URL, headers=HEADERS, json={"p_sql": sql}, timeout=60)
        data = r.json()
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


# Asset status of the 8 most recent free_videos + ALL their renditions.
run(
    "ASSETS + RENDITIONS des 8 dernieres free_videos (jointure complete)",
    """
    SELECT row_to_json(t) AS r FROM (
      SELECT
        fv.id            AS free_video_id,
        fv.created_at    AS fv_created,
        fv.video_asset_id,
        va.status        AS asset_status,
        va.origin        AS asset_origin,
        (
          SELECT json_agg(json_build_object(
            'rendition_key', vr.rendition_key,
            'kind', vr.kind,
            'status', vr.status,
            'has_url', (vr.public_url_hint IS NOT NULL),
            'created_at', vr.created_at
          ) ORDER BY vr.created_at)
          FROM app.video_renditions vr
          WHERE vr.video_asset_id = fv.video_asset_id
        ) AS renditions,
        (
          SELECT count(*) FROM app.video_renditions vr
          WHERE vr.video_asset_id = fv.video_asset_id
            AND vr.status = 'ready' AND vr.public_url_hint IS NOT NULL
        ) AS ready_renditions
      FROM app.free_videos fv
      LEFT JOIN app.video_assets va ON va.id = fv.video_asset_id
      ORDER BY fv.created_at DESC
      LIMIT 8
    ) t
    """,
)

# Processing jobs for those assets (is the worker queue stuck?).
run(
    "VIDEO_PROCESSING_JOBS des 8 derniers assets",
    """
    SELECT row_to_json(t) AS r FROM (
      SELECT j.video_asset_id, j.job_type, j.status, j.attempts, j.created_at, j.updated_at, j.last_error
      FROM app.video_processing_jobs j
      WHERE j.video_asset_id IN (
        SELECT video_asset_id FROM app.free_videos ORDER BY created_at DESC LIMIT 8
      )
      ORDER BY j.created_at DESC
    ) t
    """,
)

# Global health: how many ready renditions exist vs assets, recent job backlog.
run(
    "SANTE GLOBALE: jobs par status (30 derniers jours)",
    """
    SELECT row_to_json(t) AS r FROM (
      SELECT status, count(*) AS n, max(created_at) AS latest
      FROM app.video_processing_jobs
      WHERE created_at > NOW() - INTERVAL '30 days'
      GROUP BY status ORDER BY n DESC
    ) t
    """,
)

with open(OUT, "w", encoding="utf-8") as f:
    f.write("\n".join(buf))
print(f"WROTE {len(buf)} lines to {OUT}")
