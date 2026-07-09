import requests

supabase_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=" * 80)
print("RÉCUPÉRATION DÉTAILS JOB VIA FETCH")
print("=" * 80)

# Try using FETCH instead of SELECT
sql = """
DO $$
DECLARE
    job_record RECORD;
BEGIN
    FOR job_record IN 
        SELECT id, project_id, status, video_url, duration_ms, error_message, created_at, started_at, completed_at
        FROM app.whiteboard_renders
        WHERE id = 'fd9e3969-be64-45a9-8e95-00606ac51446'
    LOOP
        RAISE NOTICE 'ID: %', job_record.id;
        RAISE NOTICE 'Project ID: %', job_record.project_id;
        RAISE NOTICE 'Status: %', job_record.status;
        RAISE NOTICE 'Video URL: %', job_record.video_url;
        RAISE NOTICE 'Duration: %', job_record.duration_ms;
        RAISE NOTICE 'Error: %', job_record.error_message;
        RAISE NOTICE 'Created: %', job_record.created_at;
        RAISE NOTICE 'Started: %', job_record.started_at;
        RAISE NOTICE 'Completed: %', job_record.completed_at;
    END LOOP;
END $$;
"""

resp = requests.post(supabase_url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()

print(f"\nSTATUS: {resp.status_code}")
print(f"BODY: {resp.text}")

print("\n" + "=" * 80)
