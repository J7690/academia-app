import requests

supabase_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=" * 80)
print("PROJETS WHITEBOARD EXISTANTS")
print("=" * 80)

sql = """
SELECT id, student_id, subject, status, renderer_id, theme_id, narration_mode, created_at
FROM app.whiteboard_projects
ORDER BY created_at DESC
LIMIT 5;
"""

resp = requests.post(supabase_url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()

print(f"\nSTATUS: {resp.status_code}")

if data.get("ok") and data.get("rows"):
    print(f"✅ {len(data['rows'])} projet(s) trouvé(s):")
    for row in data["rows"]:
        print(f"  ID: {row['id']}")
        print(f"  Student ID: {row['student_id']}")
        print(f"  Subject: {row['subject']}")
        print(f"  Status: {row['status']}")
        print(f"  Renderer ID: {row.get('renderer_id', 'N/A')}")
        print(f"  Theme ID: {row.get('theme_id', 'N/A')}")
        print(f"  Narration Mode: {row.get('narration_mode', 'N/A')}")
        print(f"  Created: {row['created_at']}")
        print()
elif data.get("ok") and data.get("affected_rows") > 0:
    print(f"✅ {data['affected_rows']} projet(s) trouvé(s) (affected_rows)")
else:
    print(f"❌ Aucun projet trouvé")

print("\n" + "=" * 80)
