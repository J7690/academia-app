#!/usr/bin/env python3
"""Liste toutes les universités pour récupérer les IDs."""

import requests
import json

def main():
    url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/universities?select=id,name,slug,is_active&order=created_at.desc"
    headers = {
        "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
        "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
        "Accept": "application/json",
        "Prefer": "return=minimal",
        "Accept-Profile": "app",
    }
    try:
        r = requests.get(url, headers=headers, timeout=10)
        print("Status:", r.status_code)
        data = r.json()
        for u in data:
            print(f"{u['id']} | {u['name']} | {u['slug']} | actif={u['is_active']}")
    except Exception as e:
        print("Exception:", e)

if __name__ == "__main__":
    main()
