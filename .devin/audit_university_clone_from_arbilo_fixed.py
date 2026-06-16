#!/usr/bin/env python3
"""Audit du clonage de mini-site & offres depuis Arbilo vers une nouvelle université (version REST)."""

import sys
import requests
import json

TEMPLATE_SLUG = "universite-arbilo"
TEMPLATE_ID = "caa0d821-45e4-4148-86a4-bf16c7fc3bb1"

HEADERS = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Accept": "application/json",
    "Prefer": "return=minimal",
    "Accept-Profile": "app",
}

def count_table(table: str, university_id: str) -> int:
    url = f"https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/{table}?select=count&university_id=eq.{university_id}"
    r = requests.get(url, headers=HEADERS, timeout=10)
    if r.status_code != 200:
        return 0
    # Prefer: return=representation pour count
    url_count = f"https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/{table}?select=id&university_id=eq.{university_id}"
    r2 = requests.get(url_count, headers={**HEADERS, "Prefer": "return=representation"}, timeout=10)
    if r2.status_code != 200:
        return 0
    try:
        return len(r2.json())
    except:
        return 0

def count_programs(university_id: str) -> int:
    url = f"https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/programs?select=id&university_id=eq.{university_id}"
    r = requests.get(url, headers={**HEADERS, "Prefer": "return=representation"}, timeout=10)
    if r.status_code != 200:
        return 0
    try:
        return len(r.json())
    except:
        return 0

def count_courses(university_id: str) -> int:
    url = f"https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/courses?select=id"
    r = requests.get(url, headers={**HEADERS, "Prefer": "return=representation"}, timeout=10)
    if r.status_code != 200:
        return 0
    try:
        courses = r.json()
        # Filtrer par programmes liés à l'université
        prog_ids_url = f"https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/programs?select=id&university_id=eq.{university_id}"
        prog_resp = requests.get(prog_ids_url, headers={**HEADERS, "Prefer": "return=representation"}, timeout=10)
        if prog_resp.status_code != 200:
            return 0
        prog_ids = {p["id"] for p in prog_resp.json()}
        return sum(1 for c in courses if c.get("program_id") in prog_ids)
    except:
        return 0

def main(argv):
    if len(argv) < 2:
        print("Usage: python .windsurf/audit_university_clone_from_arbilo_fixed.py <TARGET_UNIVERSITY_ID>")
        return 1
    target_id = argv[1]

    print(f"=== Audit clonage Arbilo -> {target_id} ===")
    print("\nCompteurs Arbilo (template):")
    arbilo_counts = {
        "blocks": count_table("university_site_blocks", TEMPLATE_ID),
        "media": count_table("university_media", TEMPLATE_ID),
        "banners": count_table("university_site_banners", TEMPLATE_ID),
        "events": count_table("university_events", TEMPLATE_ID),
        "news": count_table("university_news", TEMPLATE_ID),
        "staff": count_table("university_staff", TEMPLATE_ID),
        "programs": count_programs(TEMPLATE_ID),
        "courses": count_courses(TEMPLATE_ID),
    }
    for k, v in arbilo_counts.items():
        print(f"- {k}: {v}")

    print("\nCompteurs université cible:")
    target_counts = {
        "blocks": count_table("university_site_blocks", target_id),
        "media": count_table("university_media", target_id),
        "banners": count_table("university_site_banners", target_id),
        "events": count_table("university_events", target_id),
        "news": count_table("university_news", target_id),
        "staff": count_table("university_staff", target_id),
        "programs": count_programs(target_id),
        "courses": count_courses(target_id),
    }
    for k, v in target_counts.items():
        print(f"- {k}: {v}")

    print("\nDelta (Arbilo - cible):")
    missing_any = False
    for k in arbilo_counts:
        delta = arbilo_counts[k] - target_counts.get(k, 0)
        if delta > 0:
            missing_any = True
            print(f"- {k}: la cible a {target_counts.get(k, 0)}, Arbilo en a {arbilo_counts[k]} → il manque {delta} élément(s).")
    if not missing_any:
        print("Tous les compteurs sont >= à ceux de la cible ; le clonage semble complet au niveau des volumes.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
