"""Inspect app.video_renditions real columns + constraints to fix the silent
upsert failure in transcode-video. Uses single-row aggregates (no GROUP BY,
no row_to_json) which admin_execute_sql returns correctly.
Output -> inspect_renditions_schema_output.txt
"""
import json
import requests

RPC_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {"apikey": KEY, "Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}
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
w("SCHEMA app.video_renditions")
w("=" * 80)

w("\n1. Colonnes (ordonnees):")
rows, err = run_sql(
    "SELECT string_agg(attname, ', ' ORDER BY attnum) AS cols "
    "FROM pg_attribute "
    "WHERE attrelid = 'app.video_renditions'::regclass AND attnum > 0 AND NOT attisdropped"
)
w("   " + (err or json.dumps(rows, ensure_ascii=False)))

w("\n2. Existence colonne file_size_bytes:")
rows, err = run_sql(
    "SELECT COUNT(*) AS n FROM pg_attribute "
    "WHERE attrelid = 'app.video_renditions'::regclass "
    "AND attname = 'file_size_bytes' AND NOT attisdropped"
)
w("   " + (err or json.dumps(rows, ensure_ascii=False)))

w("\n3. Contraintes (pour ON CONFLICT video_asset_id,rendition_key):")
rows, err = run_sql(
    "SELECT string_agg(conname || ' => ' || pg_get_constraintdef(oid), '  |  ') AS cons "
    "FROM pg_constraint WHERE conrelid = 'app.video_renditions'::regclass"
)
w("   " + (err or json.dumps(rows, ensure_ascii=False)))

w("\n4. Index uniques:")
rows, err = run_sql(
    "SELECT string_agg(indexdef, '  |  ') AS idx "
    "FROM pg_indexes WHERE schemaname='app' AND tablename='video_renditions'"
)
w("   " + (err or json.dumps(rows, ensure_ascii=False)))

with open("inspect_renditions_schema_output.txt", "w", encoding="utf-8") as f:
    f.write("\n".join(OUT))
w("\nDONE -> inspect_renditions_schema_output.txt")
