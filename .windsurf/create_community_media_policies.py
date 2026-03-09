#!/usr/bin/env python3
"""Crée les policies RLS manquantes pour le bucket community-media."""

import requests
import json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
}


def execute_sql(sql: str) -> dict:
    """Exécute du SQL via la RPC admin_execute_sql."""
    resp = requests.post(
        f"{URL}/rest/v1/rpc/admin_execute_sql",
        headers=HEADERS,
        json={"p_sql": sql},
        timeout=30,
    )
    print(f"  HTTP {resp.status_code}")
    try:
        return resp.json()
    except:
        return {"raw": resp.text}


def main():
    print("=" * 60)
    print("CRÉATION DES POLICIES RLS POUR community-media")
    print("=" * 60)

    # 1. Policy SELECT (lecture publique)
    print("\n[1] Création policy SELECT (public_read_community_media)")
    print("-" * 40)
    sql = """
    CREATE POLICY public_read_community_media
    ON storage.objects
    AS PERMISSIVE
    FOR SELECT
    TO anon, authenticated
    USING (bucket_id = 'community-media');
    """
    result = execute_sql(sql)
    print(f"  Résultat: {json.dumps(result, indent=2, ensure_ascii=False)}")

    # 2. Policy INSERT (écriture pour authenticated)
    print("\n[2] Création policy INSERT (authenticated_write_community_media_insert)")
    print("-" * 40)
    sql = """
    CREATE POLICY authenticated_write_community_media_insert
    ON storage.objects
    AS PERMISSIVE
    FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'community-media');
    """
    result = execute_sql(sql)
    print(f"  Résultat: {json.dumps(result, indent=2, ensure_ascii=False)}")

    # 3. Policy UPDATE (mise à jour pour authenticated)
    print("\n[3] Création policy UPDATE (authenticated_write_community_media_update)")
    print("-" * 40)
    sql = """
    CREATE POLICY authenticated_write_community_media_update
    ON storage.objects
    AS PERMISSIVE
    FOR UPDATE
    TO authenticated
    USING (bucket_id = 'community-media')
    WITH CHECK (bucket_id = 'community-media');
    """
    result = execute_sql(sql)
    print(f"  Résultat: {json.dumps(result, indent=2, ensure_ascii=False)}")

    # 4. Policy DELETE (suppression pour authenticated)
    print("\n[4] Création policy DELETE (authenticated_write_community_media_delete)")
    print("-" * 40)
    sql = """
    CREATE POLICY authenticated_write_community_media_delete
    ON storage.objects
    AS PERMISSIVE
    FOR DELETE
    TO authenticated
    USING (bucket_id = 'community-media');
    """
    result = execute_sql(sql)
    print(f"  Résultat: {json.dumps(result, indent=2, ensure_ascii=False)}")

    # 5. Vérification finale
    print("\n[5] VÉRIFICATION - Policies pour community-media")
    print("-" * 40)
    sql = """
    SELECT polname, polcmd 
    FROM pg_policy 
    WHERE polrelid = 'storage.objects'::regclass
      AND polname LIKE '%community%'
    """
    resp = requests.post(
        f"{URL}/rest/v1/rpc/execute_sql",
        headers=HEADERS,
        json={"sql_query": sql},
        timeout=30,
    )
    print(f"  HTTP {resp.status_code}")
    print(f"  Résultat: {json.dumps(resp.json(), indent=2, ensure_ascii=False)}")

    print("\n" + "=" * 60)
    print("FIN DE LA CRÉATION DES POLICIES")
    print("=" * 60)


if __name__ == "__main__":
    main()
