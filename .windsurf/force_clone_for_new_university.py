#!/usr/bin/env python3
"""
Clonage manuel pour une nouvelle université.
Utilisation: python .windsurf/force_clone_for_new_university.py <UNIVERSITY_ID>
"""

import sys
import requests
import json

def clone_university(target_university_id: str):
    url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/app_admin_clone_university_from_template"
    headers = {
        "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
        "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Prefer": "return=minimal",
        "Accept-Profile": "public",
    }
    payload = {
        "p_template_slug": "universite-arbilo",
        "p_target_university_id": target_university_id,
    }
    try:
        r = requests.post(url, headers=headers, json=payload, timeout=15)
        print("Status:", r.status_code)
        print("Body:", r.text[:800])
    except Exception as e:
        print("Exception:", e)

def main(argv):
    if len(argv) < 2:
        print("Usage: python .windsurf/force_clone_for_new_university.py <UNIVERSITY_ID>")
        return 1
    clone_university(argv[1])
    return 0

if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
