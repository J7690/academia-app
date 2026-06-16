#!/usr/bin/env python3
"""Crée une structure vide mais complète pour une nouvelle université via RPC execute_sql direct (headers corrigés)."""

import sys
import requests
import json

def create_empty_structure(university_id: str):
    url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/execute_sql"
    headers = {
        "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
        "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Prefer": "return=minimal",
    }
    sql = f"""
    INSERT INTO app.university_site_config (university_id, hero_title, hero_subtitle, hero_primary_color, hero_secondary_color, hero_poster_media_id)
    VALUES ('{university_id}'::UUID, NULL, NULL, NULL, NULL, NULL)
    ON CONFLICT (university_id) DO NOTHING;
    """
    payload = {"sql_query": sql}
    r = requests.post(url, headers=headers, json=payload, timeout=10)
    print("INSERT university_site_config via RPC:", r.status_code, r.text[:500])

    sql_check = f"""
    SELECT * FROM app.university_site_config WHERE university_id = '{university_id}'::UUID;
    """
    payload_check = {"sql_query": sql_check}
    r_check = requests.post(url, headers=headers, json=payload_check, timeout=10)
    print("Vérification university_site_config via RPC:", r_check.status_code, r_check.text[:500])

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python .windsurf/create_empty_structure_direct_rpc_fixed.py <UNIVERSITY_ID>")
        sys.exit(1)
    create_empty_structure(sys.argv[1])
