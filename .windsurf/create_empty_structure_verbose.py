#!/usr/bin/env python3
"""Crée une structure vide mais complète pour une nouvelle université, avec debug."""

import sys
import requests
import json

HEADERS = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
    "Accept": "application/json",
    "Prefer": "return=minimal",
    "Accept-Profile": "app",
}

def create_empty_config(university_id: str):
    url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/university_site_config"
    payload = {
        "university_id": university_id,
        "hero_title": None,
        "hero_subtitle": None,
        "hero_primary_color": None,
        "hero_secondary_color": None,
        "hero_poster_media_id": None,
    }
    r = requests.post(url, headers=HEADERS, json=payload, timeout=10)
    print("POST university_site_config:", r.status_code, r.text[:200])

def main():
    if len(sys.argv) < 2:
        print("Usage: python .windsurf/create_empty_structure_verbose.py <UNIVERSITY_ID>")
        sys.exit(1)
    create_empty_config(sys.argv[1])

if __name__ == "__main__":
    main()
