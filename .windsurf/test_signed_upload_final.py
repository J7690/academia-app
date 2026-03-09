#!/usr/bin/env python3
"""Test upload avec signed URL - avec authorization header."""

import requests
import json

PROJECT_REF = "thevdfcwlcqzdoybfvgs"
URL = f"https://{PROJECT_REF}.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMwNTY1NjAsImV4cCI6MjA3ODYzMjU2MH0.VHxR2Z8JUjJLJYMqjpLBLK8sS8pNMMKNBNZvHYVVPzE"

HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
}


def main():
    print("=" * 60)
    print("TEST SIGNED UPLOAD - AVEC AUTH HEADER")
    print("=" * 60)

    test_path = "test_user/communities/test_community/final_test.txt"

    # 1. Obtenir la signed URL avec upsert=true
    print("\n[1] Obtention signed upload URL")
    print("-" * 40)
    
    resp = requests.post(
        f"{URL}/storage/v1/object/upload/sign/community-media/{test_path}",
        headers=HEADERS,
        json={"upsert": True},
        timeout=30,
    )
    print(f"  HTTP {resp.status_code}")
    signed_data = resp.json()
    
    if resp.status_code != 200:
        print(f"  Erreur: {signed_data}")
        return

    signed_url = signed_data.get("url", "")
    token = signed_data.get("token", "")
    print(f"  URL relative: {signed_url[:60]}...")

    # 2. Upload avec l'URL signée et les headers appropriés
    print("\n[2] Upload avec signed URL + auth headers")
    print("-" * 40)
    
    # L'URL signée doit être utilisée avec le préfixe /storage/v1
    full_url = f"{URL}/storage/v1{signed_url.replace('/object/upload/sign/', '/object/')}"
    print(f"  URL construite: {full_url[:70]}...")
    
    test_content = b"Test content - final upload test!"
    
    resp = requests.put(
        full_url,
        headers={
            "apikey": ANON_KEY,
            "Authorization": f"Bearer {token}",
            "Content-Type": "text/plain",
        },
        data=test_content,
    )
    print(f"  PUT HTTP {resp.status_code}: {resp.text}")

    # 3. Essayer avec le format d'URL direct
    if resp.status_code not in (200, 201):
        print("\n[3] Essai format alternatif")
        print("-" * 40)
        
        # Format: POST /storage/v1/object/bucket/path avec token dans query
        alt_url = f"{URL}/storage/v1/object/community-media/{test_path}"
        
        resp = requests.post(
            alt_url,
            headers={
                "apikey": SERVICE_KEY,
                "Authorization": f"Bearer {SERVICE_KEY}",
                "Content-Type": "text/plain",
                "x-upsert": "true",
            },
            data=test_content,
        )
        print(f"  POST avec service_role: HTTP {resp.status_code}")
        print(f"  Réponse: {resp.text}")

    # 4. Vérifier le fichier
    print("\n[4] Vérification")
    print("-" * 40)
    
    resp = requests.post(
        f"{URL}/storage/v1/object/list/community-media",
        headers=HEADERS,
        json={"prefix": "test_user/communities/test_community/", "limit": 10},
        timeout=30,
    )
    print(f"  Fichiers: {json.dumps(resp.json(), indent=2)}")

    print("\n" + "=" * 60)


if __name__ == "__main__":
    main()
