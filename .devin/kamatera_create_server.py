"""
Créer un serveur VPS Kamatera via API pour LiveKit
"""
import requests
import json
import time

CLIENT_ID = "54ae6bec54550d349e6181c51e2b925c"
SECRET = "cdf8f98e556dfe28243aa243104801a7"

# Try multiple API endpoints
API_URLS = [
    "https://cloudcli.cloudwm.com",
    "https://console.kamatera.com/service",
    "https://console.kamatera.com/svc",
]

HEADERS = {
    "AuthClientId": CLIENT_ID,
    "AuthSecret": SECRET,
    "Content-Type": "application/json",
    "Accept": "application/json",
}

for api_url in API_URLS:
    print(f"\n{'=' * 50}")
    print(f"Trying API: {api_url}")
    print(f"{'=' * 50}")
    
    # Test 1: with AuthClientId/AuthSecret headers
    r = requests.get(f"{api_url}/service/server", headers=HEADERS)
    print(f"  [Headers auth] /service/server → HTTP {r.status_code}: {r.text[:200]}")
    
    # Test 2: with Basic auth
    r2 = requests.get(f"{api_url}/service/server", auth=(CLIENT_ID, SECRET))
    print(f"  [Basic auth] /service/server → HTTP {r2.status_code}: {r2.text[:200]}")
    
    # Test 3: server info
    r3 = requests.get(f"{api_url}/server/info", headers=HEADERS)
    print(f"  [Headers auth] /server/info → HTTP {r3.status_code}: {r3.text[:200]}")

    # Test 4: list servers
    r4 = requests.post(f"{api_url}/service/server/info", headers=HEADERS, json={})
    print(f"  [POST] /service/server/info → HTTP {r4.status_code}: {r4.text[:200]}")

print("\n\nTrying Kamatera API v1 documented format...")
# Kamatera documented API
API_V1 = "https://console.kamatera.com/service"
h = {"AuthClientId": CLIENT_ID, "AuthSecret": SECRET}
endpoints = ["/queue", "/server", "/server/hdlib"]
for ep in endpoints:
    r = requests.get(f"{API_V1}{ep}", headers=h)
    print(f"  GET {ep} → HTTP {r.status_code}: {r.text[:150]}")
