#!/usr/bin/env python3
"""Phase D Audit: Edge Functions availability, existing IA services."""
import requests
URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
print("=== PHASE D AUDIT ===")
for fn in ["prep-tutor-chat", "prep-generate-questions", "prep-generate-psychotech"]:
    try:
        r = requests.options(f"{URL}/functions/v1/{fn}", timeout=10)
        print(f"  {fn}: HTTP {r.status_code}")
    except Exception as e:
        print(f"  {fn}: ERROR {e}")
