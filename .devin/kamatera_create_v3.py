"""
Create new Kamatera server - try multiple API formats
"""
import requests
import json
import time

API = "https://cloudcli.cloudwm.com"
CLIENT_ID = "54ae6bec54550d349e6181c51e2b925c"
SECRET_KEY = "cdf8f98e556dfe28243aa243104801a7"
HEADERS = {"AuthClientId": CLIENT_ID, "AuthSecret": SECRET_KEY, "Content-Type": "application/json"}

# Step 0: Check current servers
print("=" * 50)
print("Current servers:")
r = requests.post(f"{API}/service/server/info", headers=HEADERS, json={})
print(f"  HTTP {r.status_code}: {r.text[:500]}")

# Step 0b: Check queue for pending tasks
API_V1 = "https://console.kamatera.com/service"
H1 = {"AuthClientId": CLIENT_ID, "AuthSecret": SECRET_KEY}
r_q = requests.get(f"{API_V1}/queue", headers=H1)
print(f"\nQueue: {r_q.text[:500]}")

# Step 1: Get available disk images for EU datacenter
print("\n" + "=" * 50)
print("Getting available OS images for EU datacenter...")
r_img = requests.get(f"{API_V1}/server/hdlib", headers=H1, params={"datacenter": "EU"})
print(f"  HTTP {r_img.status_code}")
if r_img.status_code == 200:
    images = r_img.json()
    # Find Ubuntu images
    if isinstance(images, dict):
        for key, val in images.items():
            if 'ubuntu' in str(key).lower() or 'ubuntu' in str(val).lower():
                print(f"  {key}: {str(val)[:100]}")
    elif isinstance(images, list):
        for img in images:
            s = str(img)
            if 'ubuntu' in s.lower():
                print(f"  {s[:120]}")
else:
    print(f"  {r_img.text[:300]}")

# Step 2: Get server options to understand the correct format
print("\n" + "=" * 50)
print("Getting server creation options...")
r_opts = requests.get(f"{API}/service/server", headers=HEADERS)
print(f"  HTTP {r_opts.status_code}")
if r_opts.status_code == 200:
    opts = r_opts.json()
    # Show datacenter options
    dcs = opts.get("datacenters", {})
    print(f"  Datacenters: {list(dcs.keys())[:10]}")
    # Show CPU options
    cpus = opts.get("cpu", {})
    print(f"  CPU types: {list(cpus.keys())[:10]}")
    # Show images
    images = opts.get("images", {})
    if images:
        for k in list(images.keys())[:5]:
            print(f"  Image: {k}")

# Step 3: Try creating with the v1 API
print("\n" + "=" * 50)
print("Creating server via console API...")

# Format based on Kamatera docs
create_body = {
    "name": "academia-livekit",
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

r1 = requests.post(f"{API_V1}/server", headers={**H1, "Content-Type": "application/json"}, json=create_body)
print(f"  V1 API: HTTP {r1.status_code}: {r1.text[:300]}")

# Step 4: If V1 fails, try cloudcli with different formats
if r1.status_code != 200:
    print("\n  Trying cloudcli format 1...")
    body2 = {
        "name": "academia-livekit",
        "password": "Wenden@Koote2026",
        "passwordValidate": "Wenden@Koote2026",
        "datacenter": "EU",
        "image": "ubuntu_server_22.04_64-bit",
        "cpu": "2B",
        "ram": "4096",
        "disk": "size=40",
        "dailybackup": "no",
        "managed": "no",
        "network": "name=wan,ip=auto",
        "quantity": "1",
        "billingcycle": "monthly",
        "poweronaftercreate": "yes",
    }
    r2 = requests.post(f"{API}/service/server", headers=HEADERS, json=body2)
    print(f"  cloudcli format 1: HTTP {r2.status_code}: {r2.text[:300]}")

    if r2.status_code != 200:
        print("\n  Trying cloudcli format 2 (arrays)...")
        body3 = {
            "name": "academia-livekit",
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
        r3 = requests.post(f"{API}/service/server", headers=HEADERS, json=body3)
        print(f"  cloudcli format 2: HTTP {r3.status_code}: {r3.text[:300]}")

        if r3.status_code != 200:
            print("\n  Trying cloudcli format 3 (separate fields)...")
            body4 = {
                "name": "academia-livekit",
                "password": "Wenden@Koote2026",
                "passwordValidate": "Wenden@Koote2026",
                "datacenter": "EU",
                "image": "ubuntu_server_22.04_64-bit",
                "cpu": "2B",
                "ram": 4096,
                "disk_size_0": 40,
                "dailybackup": "no",
                "managed": "no",
                "network_name_0": "wan",
                "network_ip_0": "auto",
                "quantity": 1,
                "billingcycle": "monthly",
                "poweronaftercreate": "yes",
            }
            r4 = requests.post(f"{API}/service/server", headers=HEADERS, json=body4)
            print(f"  cloudcli format 3: HTTP {r4.status_code}: {r4.text[:300]}")

print("\n🏁 Done.")
