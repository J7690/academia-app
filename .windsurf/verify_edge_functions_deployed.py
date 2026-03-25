#!/usr/bin/env python3
"""Verify all 5 prep Edge Functions are deployed and responding."""
import requests

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"

functions = [
    "prep-tutor-chat",
    "prep-ingest-document",
    "prep-generate-questions",
    "prep-analyze-trends",
    "prep-grade-assignment",
]

print("=" * 50)
print("EDGE FUNCTIONS DEPLOYMENT VERIFICATION")
print("=" * 50)

all_ok = True
for fn in functions:
    try:
        resp = requests.options(f"{URL}/functions/v1/{fn}", timeout=10)
        status = resp.status_code
        ok = status == 200
        if not ok:
            all_ok = False
        print(f"  {'OK' if ok else 'FAIL'} {fn}: HTTP {status}")
    except Exception as e:
        all_ok = False
        print(f"  FAIL {fn}: {e}")

print(f"\n{'ALL 5 DEPLOYED' if all_ok else 'SOME FAILED'}")
