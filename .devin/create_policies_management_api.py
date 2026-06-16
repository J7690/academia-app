#!/usr/bin/env python3
"""Utilise l'API Supabase Management pour exécuter du SQL avec privilèges postgres."""

import requests
import json

PROJECT_REF = "thevdfcwlcqzdoybfvgs"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

# API Management Supabase
MANAGEMENT_API = "https://api.supabase.com"

def main():
    print("=" * 60)
    print("CRÉATION POLICIES VIA SUPABASE MANAGEMENT API")
    print("=" * 60)

    # L'API Management nécessite un access token personnel
    # Essayons d'abord de voir si on peut utiliser le service_role key
    # pour accéder à des fonctionnalités admin supplémentaires

    print("\n[1] Test API Management")
    print("-" * 40)
    
    # Essayer d'accéder à l'API de gestion du projet
    headers = {
        "Authorization": f"Bearer {SERVICE_KEY}",
        "Content-Type": "application/json",
    }
    
    resp = requests.get(
        f"{MANAGEMENT_API}/v1/projects/{PROJECT_REF}",
        headers=headers,
        timeout=30,
    )
    print(f"  HTTP {resp.status_code}")
    if resp.status_code == 401:
        print("  L'API Management nécessite un access token personnel")
    else:
        print(f"  Réponse: {resp.text[:200]}")

    # Approche alternative: utiliser l'endpoint SQL de l'API REST
    print("\n[2] Test endpoint SQL direct")
    print("-" * 40)
    
    # Certains projets Supabase ont un endpoint /sql
    url = f"https://{PROJECT_REF}.supabase.co/rest/v1/"
    headers = {
        "apikey": SERVICE_KEY,
        "Authorization": f"Bearer {SERVICE_KEY}",
        "Content-Type": "application/json",
    }
    
    # Lister les fonctions RPC disponibles
    resp = requests.get(url, headers=headers, timeout=30)
    print(f"  HTTP {resp.status_code}")

    # Essayer d'utiliser une fonction système si elle existe
    print("\n[3] Recherche de fonctions système")
    print("-" * 40)
    
    sql = """
    SELECT proname, pronamespace::regnamespace as schema
    FROM pg_proc 
    WHERE proname IN ('exec_sql', 'run_sql', 'execute_command', 'pg_execute')
    OR (pronamespace::regnamespace::text = 'extensions' AND proname LIKE '%sql%')
    """
    
    resp = requests.post(
        f"https://{PROJECT_REF}.supabase.co/rest/v1/rpc/execute_sql",
        headers=headers,
        json={"sql_query": sql},
        timeout=30,
    )
    print(f"  HTTP {resp.status_code}")
    print(f"  Fonctions: {json.dumps(resp.json(), indent=2)}")

    # Vérifier si supabase_functions schema existe
    print("\n[4] Vérification schémas système")
    print("-" * 40)
    
    sql = "SELECT nspname FROM pg_namespace WHERE nspname LIKE '%supabase%' OR nspname = 'extensions'"
    resp = requests.post(
        f"https://{PROJECT_REF}.supabase.co/rest/v1/rpc/execute_sql",
        headers=headers,
        json={"sql_query": sql},
        timeout=30,
    )
    print(f"  Schémas: {json.dumps(resp.json(), indent=2)}")

    # Dernière tentative: vérifier les rôles disponibles
    print("\n[5] Vérification des rôles")
    print("-" * 40)
    
    sql = "SELECT current_user, current_role, session_user"
    resp = requests.post(
        f"https://{PROJECT_REF}.supabase.co/rest/v1/rpc/execute_sql",
        headers=headers,
        json={"sql_query": sql},
        timeout=30,
    )
    print(f"  Rôles: {json.dumps(resp.json(), indent=2)}")

    # Vérifier qui est le owner de storage.objects
    print("\n[6] Owner de storage.objects")
    print("-" * 40)
    
    sql = """
    SELECT tableowner 
    FROM pg_tables 
    WHERE schemaname = 'storage' AND tablename = 'objects'
    """
    resp = requests.post(
        f"https://{PROJECT_REF}.supabase.co/rest/v1/rpc/execute_sql",
        headers=headers,
        json={"sql_query": sql},
        timeout=30,
    )
    print(f"  Owner: {json.dumps(resp.json(), indent=2)}")

    print("\n" + "=" * 60)


if __name__ == "__main__":
    main()
