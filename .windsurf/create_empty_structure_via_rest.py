#!/usr/bin/env python3
"""Crée une structure vide mais complète pour une nouvelle université via REST POST."""

import sys
import requests
import json

def create_empty_structure(university_id: str):
    url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/university_site_config"
    headers = {
        "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
        "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Prefer": "return=minimal",
        "Accept-Profile": "app",
    }
    payload = {
        "university_id": university_id,
        "hero_title": None,
        "hero_subtitle": None,
        "hero_primary_color": None,
        "hero_secondary_color": None,
        "hero_poster_media_id": None,
    }
    r = requests.post(url, headers=headers, json=payload, timeout=10)
    print("POST university_site_config via REST:", r.status_code, r.text[:500])

    url_check = f"https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/university_site_config?university_id=eq.{university_id}"
    r_check = requests.get(url_check, headers=headers, timeout=10)
    print("Vérification university_site_config via REST:", r_check.status_code, r_check.text[:500])

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python .windsurf/create_empty_structure_via_rest.py <UNIVERSITY_ID>")
        sys.exit(1)
    create_empty_structure(sys.argv[1])
