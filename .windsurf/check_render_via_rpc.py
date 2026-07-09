import requests

supabase_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/whiteboard_get_project"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=" * 80)
print("TEST RPC whiteboard_get_project")
print("=" * 80)

# Test with a project ID
project_id = "00000000-0000-0000-0000-000000000000"

resp = requests.post(supabase_url, headers=headers, json={"p_project_id": project_id}, timeout=30)

print(f"\nSTATUS: {resp.status_code}")
print(f"BODY: {resp.text}")

if resp.status_code == 200:
    data = resp.json()
    print("✅ RPC fonctionnelle")
    print(f"Response: {data}")
else:
    print("❌ Erreur RPC")

print("\n" + "=" * 80)
