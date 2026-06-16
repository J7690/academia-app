"""
Wait for Kamatera server creation and get IP address
"""
import requests
import json
import time

API = "https://cloudcli.cloudwm.com"
API_V1 = "https://console.kamatera.com/service"
CLIENT_ID = "54ae6bec54550d349e6181c51e2b925c"
SECRET_KEY = "cdf8f98e556dfe28243aa243104801a7"
HEADERS = {"AuthClientId": CLIENT_ID, "AuthSecret": SECRET_KEY, "Content-Type": "application/json"}
H1 = {"AuthClientId": CLIENT_ID, "AuthSecret": SECRET_KEY}

TASK_ID = "154905791"

# Poll queue status
print("Waiting for server creation task to complete...")
for i in range(30):
    r = requests.get(f"{API_V1}/queue", headers=H1)
    if r.status_code == 200:
        tasks = r.json()
        for t in tasks:
            if str(t.get("id")) == TASK_ID:
                status = t.get("status", "unknown")
                desc = t.get("description", "")
                log = t.get("log", "")
                print(f"  [{i*10}s] Task {TASK_ID}: status={status} desc={desc}")
                if log:
                    print(f"    Log: {str(log)[:200]}")
                if status == "complete":
                    print("  ✅ Task completed!")
                    # Get server details
                    break
                elif status == "error":
                    print(f"  ❌ Task failed!")
                    print(f"    Full task: {json.dumps(t, indent=2)[:500]}")
                    exit(1)
        else:
            time.sleep(10)
            continue
        break
    else:
        print(f"  Queue error: {r.status_code}")
        time.sleep(10)
else:
    print("  ⏰ Timeout after 300s, checking server anyway...")

# Get server info
print("\n" + "=" * 50)
print("Getting server info...")

# Try listing servers
r = requests.post(f"{API}/service/server/info", headers=HEADERS, json={})
print(f"  server/info: HTTP {r.status_code}")
if r.status_code == 200:
    servers = r.json()
    print(f"  Servers: {json.dumps(servers, indent=2)[:1000]}")
else:
    print(f"  Error: {r.text[:300]}")

# Try listing via names
r2 = requests.post(f"{API}/service/server/info", headers=HEADERS, json={"name": "academia-livekit2"})
print(f"\n  server/info by name: HTTP {r2.status_code}")
if r2.status_code == 200:
    print(f"  {json.dumps(r2.json(), indent=2)[:1000]}")
else:
    print(f"  {r2.text[:300]}")

# Also try via V1 API
r3 = requests.get(f"{API_V1}/servers", headers=H1)
print(f"\n  V1 /servers: HTTP {r3.status_code}")
if r3.status_code == 200:
    print(f"  {json.dumps(r3.json(), indent=2)[:1000]}")
else:
    print(f"  {r3.text[:300]}")

# Get task details
r4 = requests.get(f"{API_V1}/queue/{TASK_ID}", headers=H1)
print(f"\n  Task details: HTTP {r4.status_code}")
if r4.status_code == 200:
    print(f"  {json.dumps(r4.json(), indent=2)[:1000]}")
else:
    print(f"  {r4.text[:300]}")

print("\n🏁 Done.")
