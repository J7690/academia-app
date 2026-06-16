"""
Create Kamatera server - explore API format then create
"""
import requests
import json
import time

API = "https://cloudcli.cloudwm.com"
CLIENT_ID = "54ae6bec54550d349e6181c51e2b925c"
SECRET_KEY = "cdf8f98e556dfe28243aa243104801a7"
HEADERS = {"AuthClientId": CLIENT_ID, "AuthSecret": SECRET_KEY, "Content-Type": "application/json"}

# Step 1: Understand the API structure
print("=" * 50)
print("Exploring /service/server options...")
r = requests.get(f"{API}/service/server", headers=HEADERS)
if r.status_code == 200:
    opts = r.json()
    print(f"  Type: {type(opts)}")
    if isinstance(opts, dict):
        for k, v in opts.items():
            vstr = json.dumps(v, ensure_ascii=False)[:200] if not isinstance(v, str) else v[:200]
            print(f"  {k}: {vstr}")

# Step 2: Get disk images via cloudcli
print("\n" + "=" * 50)
print("Getting disk images for EU...")
r2 = requests.get(f"{API}/service/server/hdlib", headers=HEADERS, params={"datacenter": "EU"})
print(f"  HTTP {r2.status_code}")
if r2.status_code == 200:
    imgs = r2.json()
    if isinstance(imgs, list):
        for img in imgs:
            s = str(img)
            if 'buntu' in s.lower():
                print(f"  {s[:150]}")
    elif isinstance(imgs, dict):
        for k, v in imgs.items():
            if 'buntu' in str(k).lower() or 'buntu' in str(v).lower():
                print(f"  {k}: {str(v)[:150]}")
else:
    print(f"  {r2.text[:200]}")

# Step 3: Get server options (capabilities)
print("\n" + "=" * 50)
print("Getting server capabilities for EU...")
r3 = requests.get(f"{API}/service/server/options", headers=HEADERS, params={"datacenter": "EU"})
print(f"  HTTP {r3.status_code}")
if r3.status_code == 200:
    data = r3.json()
    print(f"  Type: {type(data)}")
    if isinstance(data, dict):
        for k in list(data.keys())[:15]:
            val = data[k]
            vstr = str(val)[:200]
            print(f"  {k}: {vstr}")
elif r3.status_code != 200:
    print(f"  {r3.text[:200]}")

# Step 4: Try different creation approaches
print("\n" + "=" * 50)
print("Attempting server creation...")

# Approach A: direct string params matching cloudcli CLI format
payloads = [
    {
        "desc": "Format A: string-based",
        "body": {
            "name": "academia-livekit2",
            "password": "Wenden@Koote2026",
            "passwordValidate": "Wenden@Koote2026",
            "datacenter": "EU",
            "image": "ubuntu_server_22.04_64-bit",
            "cpu": "2B",
            "ram": 4096,
            "disk": "size=40",
            "dailybackup": "no",
            "managed": "no",
            "network": "name=wan,ip=auto",
            "quantity": 1,
            "billingcycle": "monthly",
            "poweronaftercreate": "yes",
        }
    },
    {
        "desc": "Format B: arrays for disk/network",
        "body": {
            "name": "academia-livekit2",
            "password": "Wenden@Koote2026",
            "passwordValidate": "Wenden@Koote2026",
            "datacenter": "EU",
            "image": "ubuntu_server_22.04_64-bit",
            "cpu": "2B",
            "ram": 4096,
            "disk": ["size=40"],
            "dailybackup": "no",
            "managed": "no",
            "network": ["name=wan,ip=auto"],
            "quantity": 1,
            "billingcycle": "monthly",
            "poweronaftercreate": "yes",
        }
    },
    {
        "desc": "Format C: minimal",
        "body": {
            "name": "academia-livekit2",
            "password": "Wenden@Koote2026",
            "passwordValidate": "Wenden@Koote2026",
            "datacenter": "EU",
            "image": "ubuntu_server_22.04_64-bit",
            "cpu": "2B",
            "ram": 4096,
            "disk": "size=40",
            "network": "name=wan,ip=auto",
            "billingcycle": "monthly",
        }
    },
]

for p in payloads:
    print(f"\n  Trying {p['desc']}...")
    r = requests.post(f"{API}/service/server", headers=HEADERS, json=p["body"])
    print(f"  HTTP {r.status_code}: {r.text[:300]}")
    if r.status_code == 200:
        print(f"  ✅ SUCCESS! Task: {r.json()}")
        break

print("\n🏁 Done.")
