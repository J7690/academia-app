import requests

supabase_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=" * 80)
print("VÉRIFICATION DÉTAILLÉE JOB WHITEBOARD")
print("=" * 80)

sql = """
SELECT id, project_id, status, video_url, duration_ms, error_message, created_at, started_at, completed_at
FROM app.whiteboard_renders
WHERE id = 'fd9e3969-be64-45a9-8e95-00606ac51446'
"""

resp = requests.post(supabase_url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()

print(f"\nSTATUS: {resp.status_code}")
print(f"BODY: {resp.text}")

if data.get("ok") and data.get("rows"):
    print("\n✅ Job trouvé:")
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
        
        video_url = row.get('video_url')
        if video_url:
            print(f"\n--- Test URL Storage ---")
            print(f"URL: {video_url}")
            
            storage_headers = {
                "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
                "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
            }
            
            try:
                storage_resp = requests.head(video_url, headers=storage_headers, timeout=10)
                print(f"Status: {storage_resp.status_code}")
                print(f"Content-Type: {storage_resp.headers.get('Content-Type', 'N/A')}")
                print(f"Content-Length: {storage_resp.headers.get('Content-Length', 'N/A')} bytes")
                
                if storage_resp.status_code == 200:
                    print("✅ MP4 accessible via Storage")
                else:
                    print(f"❌ Erreur HTTP {storage_resp.status_code}")
                    print(f"Response: {storage_resp.text[:200]}")
            except Exception as e:
                print(f"❌ Erreur: {e}")
else:
    print(f"\n❌ Job non trouvé")

print("\n" + "=" * 80)
