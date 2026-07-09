import requests

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

print("Finding students in database...")

# Try different schemas
schemas = ['app', 'public', 'auth']

for schema in schemas:
    sql = f"SELECT id, email FROM {schema}.students LIMIT 5;"
    resp = requests.post(admin_url, headers=headers, json={"p_sql": sql}, timeout=30)
    print(f"Schema {schema}: STATUS {resp.status_code}")
    if resp.status_code == 200:
        data = resp.json()
        students = data.get('data', [])
        print(f"  Found {len(students)} students")
        if students:
            for student in students:
                print(f"    - ID: {student['id']}, Email: {student.get('email', 'N/A')}")
            break
    else:
        print(f"  Error: {resp.text}")
