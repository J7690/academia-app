import requests

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

print("Testing narration_mode constraint...")

# Test with different values
test_values = ['none', 'auto', 'voice', 'userRecording', 'USER_RECORDING', 'manual']

for value in test_values:
    sql = f"""
    INSERT INTO app.whiteboard_projects (
      student_id,
      subject,
      status,
      renderer_id,
      theme_id,
      narration_mode,
      storyboard_json
    ) VALUES (
      'c63e9c1e-92d9-43f3-ab41-066ec3dc788b',
      'Test {value}',
      'draft',
      'scientific',
      'scientific',
      '{value}',
      '{{}}'::jsonb
    );
    """
    
    resp = requests.post(admin_url, headers=headers, json={"p_sql": sql}, timeout=30)
    print(f"\nValue: '{value}'")
    print(f"  STATUS: {resp.status_code}")
    if resp.status_code == 200:
        data = resp.json()
        if data.get('ok'):
            print(f"  ✅ SUCCESS")
        else:
            print(f"  ❌ ERROR: {resp.text}")
    else:
        print(f"  ❌ ERROR: {resp.text}")
