#!/usr/bin/env python3
"""MISSION D31.1 — Audit des durées storyboard existants (lecture seule)."""
import requests
import json
import time

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}


def execute_sql(sql):
    sql = sql.strip().rstrip(';')
    for attempt in range(3):
        try:
            resp = requests.post(admin_url, headers=headers, json={"p_sql": sql}, timeout=60)
            resp.raise_for_status()
            return resp.json()
        except Exception:
            if attempt == 2:
                raise
            time.sleep(2)


# Récupérer 5 projets avec storyboard non vide, les plus récents
query_projects = """
SELECT id, subject, created_at, storyboard_json
FROM app.whiteboard_projects
WHERE storyboard_json IS NOT NULL
ORDER BY created_at DESC
LIMIT 5
"""

result = execute_sql(query_projects)
rows = result.get('rows', result.get('data', []))

analysis = []
for row in rows:
    project_id = row['id'] if isinstance(row, dict) else row[0]
    subject = row['subject'] if isinstance(row, dict) else row[1]
    created_at = row['created_at'] if isinstance(row, dict) else row[2]
    sb = row['storyboard_json'] if isinstance(row, dict) else row[3]
    if isinstance(sb, str):
        sb = json.loads(sb)
    scenes = sb.get('scenes', []) if isinstance(sb, dict) else []
    durations = [s.get('duration_ms') for s in scenes if isinstance(s, dict)]
    analysis.append({
        'project_id': project_id,
        'subject': subject,
        'created_at': created_at,
        'num_scenes': len(scenes),
        'durations_ms': durations,
        'total_duration_ms': sum(d for d in durations if isinstance(d, (int, float))),
        'unique_durations': sorted(set(d for d in durations if isinstance(d, (int, float)))),
    })

outfile = r"C:\Users\fasop\AndroidStudioProjects\academia\.windsurf\MISSION_D31_1_duration_audit_output.json"
with open(outfile, "w", encoding="utf-8") as f:
    json.dump(analysis, f, indent=2, ensure_ascii=False)
print(f"Saved {outfile}")
print(json.dumps(analysis, indent=2, ensure_ascii=False))
