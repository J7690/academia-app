#!/usr/bin/env python3
"""Crée les policies RLS pour community-media via l'API Management de Supabase."""

import requests
import json

# Configuration Supabase
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
    print("DIAGNOSTIC ET SOLUTION POUR community-media")
    print("=" * 60)

    # 1. Vérifier les détails du bucket
    print("\n[1] Détails du bucket community-media")
    print("-" * 40)
    resp = requests.get(f"{URL}/storage/v1/bucket/community-media", headers=HEADERS)
    print(f"  HTTP {resp.status_code}")
    bucket_info = resp.json()
    print(f"  Bucket: {json.dumps(bucket_info, indent=2)}")

    # 2. Tester un upload direct avec le service_role key
    print("\n[2] Test upload avec service_role key")
    print("-" * 40)
    test_content = b"Test file content for community-media"
    test_path = "test/test_upload.txt"
    
    resp = requests.post(
        f"{URL}/storage/v1/object/community-media/{test_path}",
        headers={
            "apikey": SERVICE_KEY,
            "Authorization": f"Bearer {SERVICE_KEY}",
            "Content-Type": "text/plain",
        },
        data=test_content,
    )
    print(f"  HTTP {resp.status_code}")
    print(f"  Résultat: {resp.text}")

    # 3. Supprimer le fichier test
    if resp.status_code in (200, 201):
        print("\n[3] Suppression du fichier test")
        print("-" * 40)
        resp = requests.delete(
            f"{URL}/storage/v1/object/community-media/{test_path}",
            headers=HEADERS,
        )
        print(f"  HTTP {resp.status_code}")
        print(f"  Résultat: {resp.text}")

    # 4. Générer le SQL à exécuter manuellement dans le Dashboard
    print("\n" + "=" * 60)
    print("SQL À EXÉCUTER DANS LE DASHBOARD SUPABASE")
    print("(SQL Editor > New Query > Exécuter)")
    print("=" * 60)
    
    sql = """
-- Policies RLS pour le bucket community-media
-- À exécuter dans le SQL Editor du Dashboard Supabase

-- 1. Policy SELECT (lecture publique)
CREATE POLICY IF NOT EXISTS public_read_community_media
ON storage.objects
AS PERMISSIVE
FOR SELECT
TO anon, authenticated
USING (bucket_id = 'community-media');

-- 2. Policy INSERT (écriture pour authenticated)
CREATE POLICY IF NOT EXISTS authenticated_write_community_media_insert
ON storage.objects
AS PERMISSIVE
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'community-media');

-- 3. Policy UPDATE (mise à jour pour authenticated)
CREATE POLICY IF NOT EXISTS authenticated_write_community_media_update
ON storage.objects
AS PERMISSIVE
FOR UPDATE
TO authenticated
USING (bucket_id = 'community-media')
WITH CHECK (bucket_id = 'community-media');

-- 4. Policy DELETE (suppression pour authenticated)
CREATE POLICY IF NOT EXISTS authenticated_write_community_media_delete
ON storage.objects
AS PERMISSIVE
FOR DELETE
TO authenticated
USING (bucket_id = 'community-media');
"""
    print(sql)

    print("\n" + "=" * 60)
    print("ALTERNATIVE: Configurer via le Dashboard Storage")
    print("=" * 60)
    print("""
1. Aller sur https://supabase.com/dashboard/project/{}/storage/buckets
2. Cliquer sur le bucket 'community-media'
3. Aller dans l'onglet 'Policies'
4. Ajouter les policies suivantes:
   - SELECT: Allow public read (anon, authenticated)
   - INSERT: Allow authenticated users to upload
   - UPDATE: Allow authenticated users to update
   - DELETE: Allow authenticated users to delete
""".format(PROJECT_REF))


if __name__ == "__main__":
    main()
