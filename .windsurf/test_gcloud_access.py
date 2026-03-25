"""
Test Google Cloud access using the service account key.
No gcloud CLI needed — uses REST APIs directly via PyJWT + requests.
"""
import json
import time
import jwt
import requests

# --- Load service account key ---
KEY_PATH = r"C:\Users\fasop\AndroidStudioProjects\academia\academia_app\secrets\google-cloud-key.json"
with open(KEY_PATH, "r") as f:
    sa_key = json.load(f)

PROJECT_ID = sa_key["project_id"]
CLIENT_EMAIL = sa_key["client_email"]
PRIVATE_KEY = sa_key["private_key"]
TOKEN_URI = sa_key["token_uri"]

print(f"=== Google Cloud Access Test ===")
print(f"Project ID : {PROJECT_ID}")
print(f"Service Account: {CLIENT_EMAIL}")
print()

# --- Step 1: Generate OAuth2 access token via JWT ---
print("[1] Generating OAuth2 access token...")
now = int(time.time())
payload = {
    "iss": CLIENT_EMAIL,
    "sub": CLIENT_EMAIL,
    "aud": TOKEN_URI,
    "iat": now,
    "exp": now + 3600,
    "scope": "https://www.googleapis.com/auth/cloud-platform"
}

signed_jwt = jwt.encode(payload, PRIVATE_KEY, algorithm="RS256")

token_resp = requests.post(TOKEN_URI, data={
    "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
    "assertion": signed_jwt
})

if token_resp.status_code != 200:
    print(f"  FAIL: Could not get access token. Status={token_resp.status_code}")
    print(f"  Response: {token_resp.text}")
    exit(1)

access_token = token_resp.json()["access_token"]
print(f"  OK: Access token obtained (expires in {token_resp.json().get('expires_in', '?')}s)")
print()

headers = {"Authorization": f"Bearer {access_token}"}

# --- Step 2: Test Cloud Resource Manager — Get project info ---
print("[2] Testing Cloud Resource Manager (project info)...")
url = f"https://cloudresourcemanager.googleapis.com/v1/projects/{PROJECT_ID}"
resp = requests.get(url, headers=headers)
if resp.status_code == 200:
    data = resp.json()
    print(f"  OK: Project name='{data.get('name')}', number={data.get('projectNumber')}, state={data.get('lifecycleState')}")
else:
    print(f"  Status {resp.status_code}: {resp.text[:200]}")
print()

# --- Step 3: Test IAM — List service account's permissions on the project ---
print("[3] Testing IAM permissions on project...")
url = f"https://cloudresourcemanager.googleapis.com/v1/projects/{PROJECT_ID}:testIamPermissions"
test_perms = [
    "compute.instances.list",
    "compute.instances.create",
    "compute.instances.delete",
    "run.services.list",
    "run.services.create",
    "run.services.delete",
    "container.clusters.list",
    "container.clusters.create",
    "storage.buckets.list",
    "storage.buckets.create",
    "iam.serviceAccounts.list",
    "artifactregistry.repositories.list",
    "cloudbuild.builds.create",
    "resourcemanager.projects.get",
]
resp = requests.post(url, headers=headers, json={"permissions": test_perms})
if resp.status_code == 200:
    granted = resp.json().get("permissions", [])
    print(f"  Granted {len(granted)}/{len(test_perms)} permissions:")
    for p in test_perms:
        status = "YES" if p in granted else "NO"
        print(f"    [{status}] {p}")
else:
    print(f"  Status {resp.status_code}: {resp.text[:200]}")
print()

# --- Step 4: Test Compute Engine API — List instances ---
print("[4] Testing Compute Engine API (list instances)...")
url = f"https://compute.googleapis.com/compute/v1/projects/{PROJECT_ID}/aggregated/instances"
resp = requests.get(url, headers=headers)
if resp.status_code == 200:
    items = resp.json().get("items", {})
    instance_count = sum(len(zone_data.get("instances", [])) for zone_data in items.values())
    print(f"  OK: {instance_count} instance(s) found across all zones")
elif resp.status_code == 403:
    print(f"  FORBIDDEN: Compute Engine API not enabled or no permission")
    print(f"  Detail: {resp.text[:200]}")
else:
    print(f"  Status {resp.status_code}: {resp.text[:200]}")
print()

# --- Step 5: Test Cloud Run API — List services ---
print("[5] Testing Cloud Run API (list services)...")
url = f"https://run.googleapis.com/v2/projects/{PROJECT_ID}/locations/-/services"
resp = requests.get(url, headers=headers)
if resp.status_code == 200:
    services = resp.json().get("services", [])
    print(f"  OK: {len(services)} Cloud Run service(s)")
    for svc in services:
        print(f"    - {svc.get('name', '?')} | URI: {svc.get('uri', '?')}")
elif resp.status_code == 403:
    print(f"  FORBIDDEN: Cloud Run API not enabled or no permission")
else:
    print(f"  Status {resp.status_code}: {resp.text[:200]}")
print()

# --- Step 6: Test Artifact Registry API — List repositories ---
print("[6] Testing Artifact Registry (list repos)...")
url = f"https://artifactregistry.googleapis.com/v1/projects/{PROJECT_ID}/locations/-/repositories"
resp = requests.get(url, headers=headers)
if resp.status_code == 200:
    repos = resp.json().get("repositories", [])
    print(f"  OK: {len(repos)} repository(ies)")
    for r in repos:
        print(f"    - {r.get('name', '?')} | format={r.get('format', '?')}")
else:
    print(f"  Status {resp.status_code}: {resp.text[:200]}")
print()

# --- Step 7: Test Cloud Storage — List buckets ---
print("[7] Testing Cloud Storage (list buckets)...")
url = f"https://storage.googleapis.com/storage/v1/b?project={PROJECT_ID}"
resp = requests.get(url, headers=headers)
if resp.status_code == 200:
    buckets = resp.json().get("items", [])
    print(f"  OK: {len(buckets)} bucket(s)")
    for b in buckets:
        print(f"    - {b.get('name', '?')} | location={b.get('location', '?')}")
else:
    print(f"  Status {resp.status_code}: {resp.text[:200]}")
print()

# --- Step 8: Test enabled APIs ---
print("[8] Listing enabled APIs on project...")
url = f"https://serviceusage.googleapis.com/v1/projects/{PROJECT_ID}/services?filter=state:ENABLED&pageSize=50"
resp = requests.get(url, headers=headers)
if resp.status_code == 200:
    services = resp.json().get("services", [])
    print(f"  OK: {len(services)} API(s) enabled")
    for s in services:
        name = s.get("config", {}).get("name", s.get("name", "?"))
        title = s.get("config", {}).get("title", "")
        print(f"    - {name} ({title})")
else:
    print(f"  Status {resp.status_code}: {resp.text[:200]}")
print()

print("=== Test complete ===")
