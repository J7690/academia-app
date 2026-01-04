#!/usr/bin/env python3
"""Crée une fonction helper pour ajouter des policies storage, puis l'utilise."""

import requests
import json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
}


def execute_sql(sql: str, rpc_name: str = "admin_execute_sql") -> dict:
    """Exécute du SQL via RPC."""
    param_name = "p_sql" if rpc_name == "admin_execute_sql" else "sql_query"
    resp = requests.post(
        f"{URL}/rest/v1/rpc/{rpc_name}",
        headers=HEADERS,
        json={param_name: sql},
        timeout=60,
    )
    print(f"  HTTP {resp.status_code}")
    try:
        return resp.json()
    except:
        return {"raw": resp.text}


def main():
    print("=" * 60)
    print("CRÉATION DES POLICIES VIA FONCTION HELPER")
    print("=" * 60)

    # Essayer de créer les policies via une approche différente
    # En utilisant la fonction postgres pour créer des policies
    
    # D'abord, vérifier si on peut utiliser l'API Management de Supabase
    # pour créer les policies directement
    
    print("\n[1] Tentative via API REST directe (PostgREST)")
    print("-" * 40)
    
    # Essayer d'insérer directement dans pg_policy n'est pas possible
    # car c'est une vue système
    
    # Approche alternative: utiliser la fonction storage.create_policy si elle existe
    sql_check = """
    SELECT proname, pronargs 
    FROM pg_proc 
    WHERE pronamespace = 'storage'::regnamespace 
    AND proname LIKE '%policy%'
    """
    result = execute_sql(sql_check, "execute_sql")
    print(f"  Fonctions storage liées aux policies: {json.dumps(result, indent=2)}")

    # Vérifier les extensions disponibles
    print("\n[2] Vérification des extensions")
    print("-" * 40)
    sql_ext = "SELECT extname FROM pg_extension ORDER BY extname"
    result = execute_sql(sql_ext, "execute_sql")
    print(f"  Extensions: {json.dumps(result, indent=2)}")

    # Essayer d'utiliser la fonction fuite_rls_policies si elle existe
    print("\n[3] Vérification des fonctions admin disponibles")
    print("-" * 40)
    sql_funcs = """
    SELECT proname 
    FROM pg_proc 
    WHERE proname LIKE '%admin%' OR proname LIKE '%policy%'
    ORDER BY proname
    LIMIT 20
    """
    result = execute_sql(sql_funcs, "execute_sql")
    print(f"  Fonctions admin: {json.dumps(result, indent=2)}")

    print("\n" + "=" * 60)
    print("SOLUTION RECOMMANDÉE")
    print("=" * 60)
    print("""
Les policies RLS sur storage.objects ne peuvent pas être créées
via RPC car la table appartient à supabase_storage_admin.

SOLUTION: Créer les policies via le Dashboard Supabase

1. Ouvrir: https://supabase.com/dashboard/project/thevdfcwlcqzdoybfvgs/storage/buckets
2. Cliquer sur 'community-media'
3. Aller dans l'onglet 'Policies'
4. Cliquer 'New Policy' et créer:

   a) Policy SELECT:
      - Name: public_read_community_media
      - Operation: SELECT
      - Target roles: anon, authenticated
      - USING expression: bucket_id = 'community-media'

   b) Policy INSERT:
      - Name: authenticated_write_community_media_insert
      - Operation: INSERT
      - Target roles: authenticated
      - WITH CHECK expression: bucket_id = 'community-media'

   c) Policy UPDATE:
      - Name: authenticated_write_community_media_update
      - Operation: UPDATE
      - Target roles: authenticated
      - USING expression: bucket_id = 'community-media'
      - WITH CHECK expression: bucket_id = 'community-media'

   d) Policy DELETE:
      - Name: authenticated_write_community_media_delete
      - Operation: DELETE
      - Target roles: authenticated
      - USING expression: bucket_id = 'community-media'

OU utiliser le SQL Editor avec le rôle postgres:
https://supabase.com/dashboard/project/thevdfcwlcqzdoybfvgs/sql/new
""")


if __name__ == "__main__":
    main()
