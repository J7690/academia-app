import requests
import json

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

headers = {
    "apikey": SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
    "Content-Type": "application/json",
    "Accept-Profile": "app"
}

# Get a real student
r = requests.get(f"{SUPABASE_URL}/rest/v1/students?select=id,full_name&limit=3",
                 headers=headers)
print("Students:", r.text[:500])

# Get existing bobodo sessions
r2 = requests.get(f"{SUPABASE_URL}/rest/v1/bobodo_sessions?select=id,student_id,title&limit=3&order=created_at.desc",
                  headers=headers)
print("\nSessions:", r2.text[:500])

# Try to create a session with a real student_id 
# Using student_id from existing session
r3 = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/app_create_bobodo_session",
                   headers=headers,
                   json={"p_title": "Vocal Pilot", "p_student_id": "6745c7ad-732b-47d0-b5b8-06d6dcf286ff"})
print(f"\nCreate session: {r3.status_code} {r3.text[:500]}")

# Try calling edge function with a real session
if r2.status_code == 200:
    sessions = r2.json()
    if sessions:
        real_session_id = sessions[0]["id"]
        print(f"\nUsing real session_id: {real_session_id}")
        r4 = requests.post(f"{SUPABASE_URL}/functions/v1/bobodo-chat",
                           headers={
                               "apikey": SERVICE_ROLE_KEY,
                               "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
                               "Content-Type": "application/json"
                           },
                           json={"session_id": real_session_id, "message": "Bonjour Bobodo"})
        print(f"Edge function: {r4.status_code} {r4.text[:500]}")
