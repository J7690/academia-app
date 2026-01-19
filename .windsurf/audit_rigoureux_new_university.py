#!/usr/bin/env python3
"""
Audit rigoureux d’une nouvelle université vs Arbilo.
Pour chaque table liée au mini-site et aux offres, on lance un SQL précis :
- COUNT(*) pour savoir s’il y a des lignes
- Si > 0, on affiche les 3 premières lignes (sans tronquer les UUIDs)
- Si = 0, on affiche "(vide)"
Tables auditées : university_site_config, university_site_blocks, university_media,
university_site_banners, university_events, university_news, university_staff,
programs, courses.
"""

import sys
import requests
import json

HEADERS = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Accept": "application/json",
    "Prefer": "return=minimal",
    "Accept-Profile": "app",
}

def count_rows(table: str, university_id: str) -> int:
    """Compte les lignes pour une table et un university_id donnés."""
    url = f"https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/{table}?select=count&university_id=eq.{university_id}"
    r = requests.get(url, headers=HEADERS, timeout=10)
    if r.status_code != 200:
        return -1
    # Supabase ne renvoie pas directement count ; on utilise une requête RPC pour count exact
    return -1  # on utilisera RPC pour le vrai count

def rpc_count(table: str, university_id: str) -> int:
    """Compte les lignes via RPC execute_sql."""
    url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/execute_sql"
    headers = {
        "apikey": HEADERS["apikey"],
        "Authorization": HEADERS["Authorization"],
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Prefer": "return=minimal",
    }
    sql = f"SELECT COUNT(*) AS cnt FROM app.{table} WHERE university_id = '{university_id}'::UUID"
    payload = {"sql_query": sql}
    r = requests.post(url, headers=headers, json=payload, timeout=10)
    if r.status_code != 200:
        return -1
    try:
        data = r.json()
        if isinstance(data, list) and data:
            return int(data[0].get("cnt", 0))
        return -1
    except:
        return -1

def sample_rows(table: str, university_id: str, limit: int = 3):
    """Retourne jusqu’à limit lignes pour une table."""
    url = f"https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/{table}?select=*&university_id=eq.{university_id}&order=created_at&limit={limit}"
    r = requests.get(url, headers=HEADERS, timeout=10)
    if r.status_code != 200:
        return None
    try:
        return r.json()
    except:
        return None

def audit_university(name: str, university_id: str):
    print(f"\n=== AUDIT : {name} ({university_id}) ===")
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
        cnt = rpc_count(t, university_id)
        print(f"\n--- {t} ---")
        if cnt < 0:
            print("Erreur de comptage")
        elif cnt == 0:
            print("(vide)")
        else:
            print(f"{cnt} ligne(s)")
            rows = sample_rows(t, university_id, limit=3)
            if rows is None:
                print("Erreur de récupération")
            else:
                for i, row in enumerate(rows, 1):
                    print(f"[{i}] {json.dumps(row, ensure_ascii=False, separators=(',', ':'))}")

def main():
    if len(sys.argv) < 2:
        print("Usage: python .windsurf/audit_rigoureux_new_university.py <UNIVERSITY_ID>")
        sys.exit(1)
    target_id = sys.argv[1]
    template_id = "caa0d821-45e4-4148-86a4-bf16c7fc3bb1"  # Arbilo
    audit_university("Arbilo (template)", template_id)
    audit_university("Nouvelle université", target_id)

if __name__ == "__main__":
    main()
