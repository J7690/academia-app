#!/usr/bin/env python3
"""Audit des données communautés pour la refonte WhatsApp-like."""

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


def execute_sql(sql: str) -> dict:
    resp = requests.post(
        f"{URL}/rest/v1/rpc/execute_sql",
        headers=HEADERS,
        json={"sql_query": sql},
        timeout=60,
    )
    return resp.json()


def main():
    print("=" * 70)
    print("AUDIT COMMUNAUTÉS - DONNÉES POUR INTERFACE WHATSAPP")
    print("=" * 70)

    # 1. Structure de la table community_posts (messages)
    print("\n[1] STRUCTURE TABLE community_posts")
    print("-" * 50)
    result = execute_sql("""
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_name = 'community_posts'
        ORDER BY ordinal_position
    """)
    print(json.dumps(result, indent=2, ensure_ascii=False))

    # 2. Exemple de données community_posts
    print("\n[2] EXEMPLE DONNÉES community_posts")
    print("-" * 50)
    result = execute_sql("""
        SELECT id, community_id, user_id, type, content, media_url, 
               created_at, updated_at
        FROM community_posts
        ORDER BY created_at DESC
        LIMIT 3
    """)
    print(json.dumps(result, indent=2, ensure_ascii=False))

    # 3. Structure de la table communities
    print("\n[3] STRUCTURE TABLE communities")
    print("-" * 50)
    result = execute_sql("""
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_name = 'communities'
        ORDER BY ordinal_position
    """)
    print(json.dumps(result, indent=2, ensure_ascii=False))

    # 4. RPCs disponibles pour les communautés
    print("\n[4] RPCs COMMUNAUTÉS DISPONIBLES")
    print("-" * 50)
    result = execute_sql("""
        SELECT proname as rpc_name
        FROM pg_proc
        WHERE pronamespace = 'public'::regnamespace
        AND proname LIKE '%community%' OR proname LIKE '%chat%'
        ORDER BY proname
    """)
    print(json.dumps(result, indent=2, ensure_ascii=False))

    # 5. Vérifier la RPC app_student_list_my_chats
    print("\n[5] SIGNATURE RPC app_student_list_my_chats")
    print("-" * 50)
    result = execute_sql("""
        SELECT pg_get_functiondef(oid) as definition
        FROM pg_proc
        WHERE proname = 'app_student_list_my_chats'
        LIMIT 1
    """)
    if result and isinstance(result, list) and len(result) > 0:
        definition = result[0].get('definition', '')
        # Afficher les 80 premières lignes
        lines = definition.split('\n')[:80]
        print('\n'.join(lines))
    else:
        print("RPC non trouvée")

    # 6. Vérifier la RPC app_student_list_community_posts
    print("\n[6] SIGNATURE RPC app_student_list_community_posts")
    print("-" * 50)
    result = execute_sql("""
        SELECT pg_get_functiondef(oid) as definition
        FROM pg_proc
        WHERE proname = 'app_student_list_community_posts'
        LIMIT 1
    """)
    if result and isinstance(result, list) and len(result) > 0:
        definition = result[0].get('definition', '')
        lines = definition.split('\n')[:60]
        print('\n'.join(lines))
    else:
        print("RPC non trouvée")

    # 7. Vérifier les champs retournés par app_student_list_my_chats
    print("\n[7] DONNÉES RETOURNÉES PAR app_student_list_my_chats")
    print("-" * 50)
    # Simuler un appel (sans user_id réel)
    result = execute_sql("""
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_name = 'community_members'
        ORDER BY ordinal_position
    """)
    print("Structure community_members:")
    print(json.dumps(result, indent=2, ensure_ascii=False))

    # 8. Vérifier si on a des statuts de lecture
    print("\n[8] STATUTS DE LECTURE / NON-LUS")
    print("-" * 50)
    result = execute_sql("""
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_name IN ('community_members', 'community_posts')
        AND column_name LIKE '%read%' OR column_name LIKE '%seen%' 
        OR column_name LIKE '%last%'
    """)
    print(json.dumps(result, indent=2, ensure_ascii=False))

    print("\n" + "=" * 70)
    print("FIN AUDIT")
    print("=" * 70)


if __name__ == "__main__":
    main()
