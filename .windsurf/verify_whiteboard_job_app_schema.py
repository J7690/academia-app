import requests

supabase_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/whiteboard_renders"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
}

print("=" * 80)
print("VÉRIFICATION JOB WHITEBOARD VIA REST API (schéma app)")
print("=" * 80)

# Query specific job with schema header
job_id = "fd9e3969-be64-45a9-8e95-00606ac51446"
headers_with_schema = headers.copy()
headers_with_schema["Prefer"] = "return=representation"

resp = requests.get(f"{supabase_url}?id=eq.{job_id}", headers=headers_with_schema, timeout=30)

print(f"\nSTATUS: {resp.status_code}")
data = resp.json()

if resp.status_code == 200 and data:
    print("✅ Job trouvé:")
    for row in data:
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
            
            try:
                storage_resp = requests.head(video_url, headers=headers, timeout=10)
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
    print(f"❌ Job non trouvé")
    print(f"Response: {data}")

# Also query all jobs to see what's in the table
print("\n--- Tous les jobs ---")
resp_all = requests.get(f"{supabase_url}?order=created_at.desc&limit=5", headers=headers_with_schema, timeout=30)
print(f"STATUS: {resp_all.status_code}")
data_all = resp_all.json()

if resp_all.status_code == 200 and data_all:
    print(f"✅ {len(data_all)} job(s) trouvé(s):")
    for row in data_all:
        print(f"  ID: {row['id']}")
        print(f"  Status: {row['status']}")
        print(f"  Video URL: {row.get('video_url', 'N/A')}")
        print(f"  Created: {row['created_at']}")
        print()

print("\n" + "=" * 80)
