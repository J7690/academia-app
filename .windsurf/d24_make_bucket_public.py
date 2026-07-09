import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}

# Rendre le bucket public
r = requests.patch(
    f"{URL}/storage/v1/bucket/whiteboard-renders",
    headers=H,
    json={"public": True},
    timeout=15
)
print("PATCH status:", r.status_code)
print(r.text[:500])

# Vérifier
r2 = requests.get(f"{URL}/storage/v1/bucket/whiteboard-renders", headers=H, timeout=10)
print("\nGET bucket:", r2.status_code)
print(r2.json().get("public"))

# Tester l'URL directement
test_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/public/whiteboard-renders/renders/c7dce841-bab1-412c-b8a7-9bf7f41762c7/3f2e47e426b546438f635eb27574bd57.mp4"
r3 = requests.head(test_url, timeout=10)
print("\nURL test status:", r3.status_code)
print("content-type:", r3.headers.get("content-type"))
