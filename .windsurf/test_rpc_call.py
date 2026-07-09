import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/whiteboard_create_project"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

print("Testing RPC call to whiteboard_create_project...")

# Get a student ID first
student_sql = "SELECT id FROM app.students LIMIT 1;"
admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
resp = requests.post(admin_url, headers=headers, json={"p_sql": student_sql}, timeout=30)
print("Get student ID STATUS:", resp.status_code)
if resp.status_code == 200:
    data = resp.json()
    students = data.get('data', [])
    if students:
        student_id = students[0]['id']
        print(f"Using student_id: {student_id}")
        
        # Test the RPC
        params = {
            "p_student_id": student_id,
            "p_subject": "Test subject",
            "p_renderer_id": "scientific",
            "p_theme_id": "scientific",
            "p_narration_mode": "none",
            "p_storyboard_json": None
        }
        
        resp = requests.post(url, headers=headers, json=params, timeout=30)
        print("RPC call STATUS:", resp.status_code)
        print("RPC call RESPONSE:", resp.text)
    else:
        print("No students found")
else:
    print("Error getting student ID:", resp.text)
