#!/usr/bin/env python3
"""Dump complet de la structure Arbilo (tables clés) pour comprendre ce qui est requis."""

import requests
import json

HEADERS = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Accept": "application/json",
    "Prefer": "return=minimal",
    "Accept-Profile": "app",
}

TEMPLATE_ID = "caa0d821-45e4-4148-86a4-bf16c7fc3bb1"

def dump_table(table_name: str, university_id: str):
    url = f"https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/{table_name}?select=*&university_id=eq.{university_id}&order=created_at"
    r = requests.get(url, headers=HEADERS, timeout=10)
    print(f"\n--- {table_name} (university_id={university_id}) ---")
    if r.status_code != 200:
        print(f"Erreur {r.status_code}: {r.text[:200]}")
        return
    data = r.json()
    if not data:
        print("(vide)")
    else:
        for i, row in enumerate(data[:5]):  # max 5 lignes pour lisibilité
            print(f"[{i+1}] {json.dumps(row, ensure_ascii=False, separators=(',', ':'))}")
        if len(data) > 5:
            print(f"... ({len(data)} lignes au total)")

def main():
    print(f"=== DUMP STRUCTURE ARBILO ({TEMPLATE_ID}) ===")
    tables = [
        "university_site_config",
        "university_site_blocks",
        "university_media",
        "university_site_banners",
        "university_events",
        "university_news",
        "university_staff",
        "programs",
        "courses",
    ]
    for t in tables:
        dump_table(t, TEMPLATE_ID)

if __name__ == "__main__":
    main()
