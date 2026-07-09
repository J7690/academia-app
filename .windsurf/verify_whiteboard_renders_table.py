import requests

supabase_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=" * 80)
print("VÉRIFICATION TABLE whiteboard_renders")
print("=" * 80)

# Check if table exists
sql_check = """
SELECT COUNT(*) as count
FROM app.whiteboard_renders
"""

resp = requests.post(supabase_url, headers=headers, json={"p_sql": sql_check}, timeout=30)
data = resp.json()

print(f"\nSTATUS: {resp.status_code}")
print(f"BODY: {resp.text}")

if data.get("ok") and data.get("rows"):
    print(f"✅ Table existe, {data['rows'][0]['count']} enregistrement(s)")
elif data.get("ok") and data.get("affected_rows") > 0:
    print(f"✅ Table existe, affected_rows: {data['affected_rows']}")
else:
    print(f"❌ Erreur")

# List all records
sql_list = """
SELECT id, project_id, status, video_url, created_at, completed_at
FROM app.whiteboard_renders
ORDER BY created_at DESC
LIMIT 10
"""

resp_list = requests.post(supabase_url, headers=headers, json={"p_sql": sql_list}, timeout=30)
data_list = resp_list.json()

print(f"\n--- Liste des jobs ---")
print(f"STATUS: {resp_list.status_code}")

if data_list.get("ok") and data_list.get("rows"):
    print(f"✅ {len(data_list['rows'])} job(s) trouvé(s):")
    for row in data_list["rows"]:
        print(f"  ID: {row['id']}")
        print(f"  Project ID: {row['project_id']}")
        print(f"  Status: {row['status']}")
        print(f"  Video URL: {row.get('video_url', 'N/A')}")
        print(f"  Created: {row['created_at']}")
        print(f"  Completed: {row.get('completed_at', 'N/A')}")
        print()
elif data_list.get("ok") and data_list.get("affected_rows") > 0:
    print(f"✅ {data_list['affected_rows']} job(s) trouvé(s) (affected_rows)")
else:
    print(f"❌ Aucun job trouvé")

print("\n" + "=" * 80)
