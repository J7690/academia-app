import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}

# 1. Vérifier le bucket actuel
r = requests.get(f"{URL}/storage/v1/bucket/whiteboard-renders", headers=H, timeout=15)
print("=== bucket status ===")
print(json.dumps(r.json(), ensure_ascii=False))

# 2. Rendre le bucket public
r2 = requests.put(f"{URL}/storage/v1/bucket/whiteboard-renders",
    headers=H,
    json={"public": True},
    timeout=15)
print("\n=== make public ===")
print(json.dumps(r2.json(), ensure_ascii=False))

# 3. Vérifier
r3 = requests.get(f"{URL}/storage/v1/bucket/whiteboard-renders", headers=H, timeout=15)
print("\n=== bucket after ===")
print(json.dumps(r3.json(), ensure_ascii=False))
