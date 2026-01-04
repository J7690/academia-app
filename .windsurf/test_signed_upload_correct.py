#!/usr/bin/env python3
"""Test upload avec signed URL - format correct."""

import requests
import json

PROJECT_REF = "thevdfcwlcqzdoybfvgs"
URL = f"https://{PROJECT_REF}.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
}


def main():
    print("=" * 60)
    print("TEST SIGNED UPLOAD URL - FORMAT CORRECT")
    print("=" * 60)

    test_path = "test_user/communities/test_community/test_file.txt"

    # 1. Obtenir la signed URL
    print("\n[1] Obtention signed upload URL")
    print("-" * 40)
    
    resp = requests.post(
        f"{URL}/storage/v1/object/upload/sign/community-media/{test_path}",
        headers=HEADERS,
        json={"upsert": "true"},
        timeout=30,
    )
    print(f"  HTTP {resp.status_code}")
    signed_data = resp.json()
    print(f"  Token obtenu: {signed_data.get('token', 'N/A')[:50]}...")

    if resp.status_code != 200:
        print(f"  Erreur: {signed_data}")
        return

    # 2. Construire l'URL d'upload correcte
    # Le format est: /storage/v1/object/community-media/path?token=xxx
    signed_url = signed_data.get("url", "")
    token = signed_data.get("token", "")
    
    # L'URL retournée est relative, on doit la compléter
    full_upload_url = f"{URL}/storage/v1/object/community-media/{test_path}?token={token}"
    
    print(f"\n[2] Upload vers: {full_upload_url[:80]}...")
    print("-" * 40)
    
    test_content = b"Test content uploaded via signed URL - SUCCESS!"
    
    # Essayer avec PUT
    resp = requests.put(
        full_upload_url,
        headers={"Content-Type": "text/plain"},
        data=test_content,
    )
    print(f"  PUT HTTP {resp.status_code}: {resp.text}")

    # Si PUT échoue, essayer POST
    if resp.status_code not in (200, 201):
        print("\n  Tentative avec POST...")
        resp = requests.post(
            full_upload_url,
            headers={"Content-Type": "text/plain"},
            data=test_content,
        )
        print(f"  POST HTTP {resp.status_code}: {resp.text}")

    # 3. Essayer avec l'URL exacte retournée par l'API
    print("\n[3] Upload avec URL exacte de l'API")
    print("-" * 40)
    
    exact_url = f"{URL}{signed_url}"
    print(f"  URL: {exact_url[:80]}...")
    
    resp = requests.put(
        exact_url,
        headers={"Content-Type": "text/plain"},
        data=test_content,
    )
    print(f"  PUT HTTP {resp.status_code}: {resp.text}")

    # 4. Vérifier si le fichier existe
    print("\n[4] Vérification du fichier")
    print("-" * 40)
    
    public_url = f"{URL}/storage/v1/object/public/community-media/{test_path}"
    resp = requests.head(public_url, timeout=10)
    print(f"  HEAD {public_url[:60]}...")
    print(f"  HTTP {resp.status_code}")

    if resp.status_code == 200:
        print(f"\n  ✅ Fichier accessible!")
    else:
        # Lister les fichiers dans le bucket
        print("\n[5] Liste des fichiers dans community-media")
        print("-" * 40)
        resp = requests.post(
            f"{URL}/storage/v1/object/list/community-media",
            headers=HEADERS,
            json={"prefix": "", "limit": 10},
            timeout=30,
        )
        print(f"  HTTP {resp.status_code}")
        print(f"  Fichiers: {json.dumps(resp.json(), indent=2)}")

    print("\n" + "=" * 60)


if __name__ == "__main__":
    main()
