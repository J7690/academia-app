"""
Récupérer les infos du serveur academia-livekit créé sur Kamatera
"""
import requests
import json

API_URL = "https://console.kamatera.com/service"
CLIENT_ID = "54ae6bec54550d349e6181c51e2b925c"
SECRET = "cdf8f98e556dfe28243aa243104801a7"
HEADERS = {"AuthClientId": CLIENT_ID, "AuthSecret": SECRET}

# 1. Get queue details (creation task)
print("=" * 50)
print("Queue (tâches)")
print("=" * 50)
r = requests.get(f"{API_URL}/queue", headers=HEADERS)
if r.status_code == 200:
    tasks = r.json()
    for t in tasks:
        print(json.dumps(t, indent=2, ensure_ascii=False))
else:
    print(f"HTTP {r.status_code}: {r.text[:300]}")

# 2. List all servers
print("\n" + "=" * 50)
print("Serveurs")
print("=" * 50)

# Try the cloudcli API which worked
API2 = "https://cloudcli.cloudwm.com"
HEADERS2 = {"AuthClientId": CLIENT_ID, "AuthSecret": SECRET, "Content-Type": "application/json"}

r2 = requests.post(f"{API2}/service/server/info", headers=HEADERS2, json={"name": "academia-livekit"})
print(f"  POST /service/server/info → HTTP {r2.status_code}")
print(f"  {r2.text[:500]}")

# 3. List all servers (no filter)
r3 = requests.get(f"{API_URL}/server/info", headers=HEADERS)
print(f"\n  GET /server/info → HTTP {r3.status_code}")
if r3.status_code == 200:
    servers = r3.json()
    if isinstance(servers, list):
        for s in servers:
            print(json.dumps(s, indent=2, ensure_ascii=False))
    elif isinstance(servers, dict):
        print(json.dumps(servers, indent=2, ensure_ascii=False)[:1000])
else:
    print(f"  {r3.text[:300]}")

# 4. Try to get specific server details
r4 = requests.get(f"{API_URL}/server/info", headers=HEADERS, params={"name": "academia-livekit"})
print(f"\n  GET /server/info?name=academia-livekit → HTTP {r4.status_code}")
print(f"  {r4.text[:500]}")
