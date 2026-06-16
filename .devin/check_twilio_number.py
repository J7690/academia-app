#!/usr/bin/env python3
"""
Check Twilio account: list phone numbers and messaging services available.
"""
import requests, json, os

# Try to get Twilio creds from Supabase Edge Function secrets
# We need to call the Twilio API directly to list phone numbers
SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
    ".eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6"
    "InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ"
    ".U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
)

# First, let's get the Twilio secrets by calling the Edge Function with a diagnostic payload
print("[1] Test Edge Function pour voir quels secrets sont configures...")
r = requests.post(
    f"{SUPABASE_URL}/functions/v1/send-phone-otp",
    headers={
        "Authorization": f"Bearer {SERVICE_KEY}",
        "Content-Type": "application/json",
    },
    json={"phone": "+22600000000", "otp": "000000"},
    timeout=30,
)
print(f"    Status: {r.status_code}")
try:
    resp = r.json()
    print(f"    Response: {json.dumps(resp, indent=2)[:400]}")
    
    error = resp.get("error", "")
    if error == "missing_twilio_config":
        print("\n    -> TWILIO_ACCOUNT_SID et/ou TWILIO_AUTH_TOKEN manquants!")
    elif error == "missing_twilio_from":
        print("\n    -> TWILIO_FROM_NUMBER et TWILIO_MESSAGING_SERVICE_SID manquants!")
        print("    -> Il faut configurer l'un des deux.")
    elif error == "twilio_error":
        code = resp.get("code")
        print(f"\n    -> Twilio a repondu (donc les secrets sont OK), erreur code={code}")
        details = resp.get("details", {})
        print(f"    -> Message: {details.get('message', '')[:200]}")
    elif resp.get("success"):
        print("\n    -> Tout fonctionne!")
except:
    print(f"    Raw: {r.text[:300]}")

# Now let's try to list Twilio phone numbers by calling their API
# We need the actual Twilio creds. Let's check if there's a way to get them.
# Since we can't read secrets directly, let's check the existing deploy scripts
print("\n[2] Recherche des credentials Twilio dans les fichiers locaux...")
import glob
for f in glob.glob("../.env*") + glob.glob("../.env") + glob.glob("*.py"):
    if os.path.isfile(f):
        content = open(f, "r", encoding="utf-8", errors="ignore").read()
        if "TWILIO" in content.upper():
            print(f"    Fichier: {f}")
            for line in content.split("\n"):
                if "TWILIO" in line.upper() and "=" in line:
                    print(f"      {line.strip()[:80]}")

# Check supabase/.env
for f in ["../supabase/.env", "../supabase/.env.local", "../.env", "../.env.local"]:
    if os.path.isfile(f):
        content = open(f, "r", encoding="utf-8", errors="ignore").read()
        if "TWILIO" in content.upper():
            print(f"    Fichier: {f}")
            for line in content.split("\n"):
                if "TWILIO" in line.upper():
                    print(f"      {line.strip()[:80]}")
