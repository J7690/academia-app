#!/usr/bin/env python3
import requests
URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
for fn in ["td-tutor-chat", "td-ingest-document", "td-generate-exercises"]:
    try:
        r = requests.options(f"{URL}/functions/v1/{fn}", timeout=10)
        print(f"  {fn}: HTTP {r.status_code}")
    except Exception as e:
        print(f"  {fn}: ERROR {e}")
