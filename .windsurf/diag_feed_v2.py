"""Read-only diagnostic v2: feed visibility. Writes full output to a file to
avoid terminal truncation. SELECT / pg_get_functiondef only => safe."""
import json
import requests

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {"apikey": KEY, "Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}
OUT_PATH = ".windsurf/diag_feed_output.txt"

_buf = []


def w(line=""):
    _buf.append(str(line))


def run_sql(sql):
    try:
        r = requests.post(URL, headers=HEADERS, json={"p_sql": sql}, timeout=60)
        data = r.json()
    except Exception as e:  # noqa: BLE001
        return None, f"REQUEST/JSON ERROR: {e}"
    if isinstance(data, dict) and data.get("ok"):
        return data.get("rows") or [], None
    return None, f"RPC ERROR: {json.dumps(data, ensure_ascii=False)[:1500]}"


def section(title):
    w("\n" + "=" * 90)
    w(title)
    w("=" * 90)


def dump_def(title, proname):
    section(f"DEFINITION: {title}  ({proname})")
    rows, err = run_sql(
        "SELECT n.nspname AS schema, pg_get_functiondef(p.oid) AS definition "
        "FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace "
        f"WHERE p.proname = '{proname}' LIMIT 5"
    )
    if err:
        w(err)
        return
    if not rows:
        w("(function not found)")
        return
    for row in rows:
        w(f"-- schema: {row.get('schema')}")
        w(row.get("definition", row))


def dump_rows(title, sql):
    section(title)
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


# 1) THE feed filter (most important).
dump_def("Feed unifié (FILTRE de visibilité)", "app_student_unified_video_feed")

# 2) Where does free_videos actually live? (table/view/schema)
dump_rows(
    "LOCALISATION de free_videos (pg_class)",
    """
    SELECT row_to_json(t) AS r FROM (
      SELECT n.nspname AS schema, c.relname, c.relkind
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE c.relname IN ('free_videos','challenge_participations','video_assets','video_renditions')
      ORDER BY n.nspname, c.relname
    ) t
    """,
)

# 3) Columns of free_videos (try both schemas via pg_attribute).
dump_rows(
    "COLONNES free_videos",
    """
    SELECT row_to_json(t) AS r FROM (
      SELECT n.nspname AS schema, a.attname AS column, format_type(a.atttypid, a.atttypmod) AS type
      FROM pg_attribute a
      JOIN pg_class c ON c.oid = a.attrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE c.relname = 'free_videos' AND a.attnum > 0 AND NOT a.attisdropped
      ORDER BY n.nspname, a.attnum
    ) t
    """,
)

# 4) Did publishes persist? counts + most recent rows.
dump_rows("COUNT app.free_videos", "SELECT row_to_json(t) AS r FROM (SELECT count(*) AS n FROM app.free_videos) t")
dump_rows(
    "DERNIÈRES free_videos (8)",
    "SELECT row_to_json(t) AS r FROM (SELECT * FROM app.free_videos ORDER BY created_at DESC LIMIT 8) t",
)

# 5) Recent video_assets (correct column = owner_user_id).
dump_rows(
    "DERNIERS video_assets (8)",
    """
    SELECT row_to_json(t) AS r FROM (
      SELECT id, status, origin, owner_user_id, canonical_type, has_audio, created_at
      FROM app.video_assets ORDER BY created_at DESC LIMIT 8
    ) t
    """,
)

# 6) Renditions of those recent assets.
dump_rows(
    "RENDITIONS des derniers assets",
    """
    SELECT row_to_json(t) AS r FROM (
      SELECT vr.video_asset_id, vr.rendition_key, vr.kind, vr.status, vr.public_url_hint, vr.created_at
      FROM app.video_renditions vr
      WHERE vr.video_asset_id IN (SELECT id FROM app.video_assets ORDER BY created_at DESC LIMIT 8)
      ORDER BY vr.created_at DESC
    ) t
    """,
)

with open(OUT_PATH, "w", encoding="utf-8") as f:
    f.write("\n".join(_buf))

print(f"WROTE {len(_buf)} lines to {OUT_PATH}")
