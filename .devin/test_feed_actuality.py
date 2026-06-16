#!/usr/bin/env python3
"""Test the prep-feed-actuality Edge Function."""
import json, requests
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()
url = f"{m.url}/functions/v1/prep-feed-actuality"

# Use service_role key for auth
headers = {
    "Authorization": f"Bearer {m.service_key}",
    "apikey": m.service_key,
    "Content-Type": "application/json",
}

print(f"Calling {url}...")
resp = requests.post(url, headers=headers, json={}, timeout=120)
print(f"Status: {resp.status_code}")

try:
    d = resp.json()
    print(json.dumps(d, ensure_ascii=False, indent=2)[:3000])
except Exception as e:
    print(f"Error parsing response: {e}")
    print(resp.text[:2000])
