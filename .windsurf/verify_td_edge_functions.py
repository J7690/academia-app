#!/usr/bin/env python3
import requests
URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
for fn in ["td-tutor-chat", "td-ingest-document", "prep-tutor-chat", "prep-ingest-document"]:
    try:
        r = requests.options(f"{URL}/functions/v1/{fn}", timeout=10)
        print(f"  {fn:30s} HTTP {r.status_code}")
    except: print(f"  {fn:30s} TIMEOUT")
