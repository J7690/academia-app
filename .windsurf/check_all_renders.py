import requests

supabase_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=" * 80)
print("TOUS LES RENDERS WHITEBOARD")
print("=" * 80)

sql = """
SELECT id, project_id, status, video_url, duration_ms, error_message, created_at, started_at, completed_at
FROM app.whiteboard_renders
ORDER BY created_at DESC;
"""

resp = requests.post(supabase_url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()

print(f"\nSTATUS: {resp.status_code}")
print(f"BODY: {resp.text}")

if data.get("ok") and data.get("rows"):
    print(f"✅ {len(data['rows'])} renderer(s) trouvé(s):")
    for row in data["rows"]:
        print(f"  ID: {row['id']}")
        print(f"  Project ID: {row['project_id']}")
        print(f"  Status: {row['status']}")
        print(f"  Video URL: {row.get('video_url', 'N/A')}")
        print(f"  Duration: {row.get('duration_ms', 'N/A')} ms")
        print(f"  Error: {row.get('error_message', 'N/A')}")
        print(f"  Created: {row['created_at']}")
        print(f"  Started: {row.get('started_at', 'N/A')}")
        print(f"  Completed: {row.get('completed_at', 'N/A')}")
        print()
elif data.get("ok") and data.get("affected_rows") > 0:
    print(f"✅ {data['affected_rows']} renderer(s) trouvé(s) (affected_rows)")
else:
    print(f"❌ Aucun renderer trouvé")

print("\n" + "=" * 80)
