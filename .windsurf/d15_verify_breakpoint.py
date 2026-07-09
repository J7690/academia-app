"""
MISSION D.15 - Vérification du point de rupture

Vérifie que whiteboard_create_project n'existe plus dans pg_proc.
"""

import requests
import json

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
EXECUTE_DDL_URL = f"{SUPABASE_URL}/rest/v1/rpc/execute_ddl"
RPC_URL = f"{SUPABASE_URL}/rest/v1/rpc/_check_whiteboard_create_project"
HEADERS = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}


def execute_ddl(ddl):
    resp = requests.post(EXECUTE_DDL_URL, headers=HEADERS, json={"ddl_query": ddl}, timeout=30)
    try:
        return resp.json()
    except Exception:
        return {"status": resp.status_code, "text": resp.text}


def create_check_function():
    ddl = """
    CREATE OR REPLACE FUNCTION public._check_whiteboard_create_project()
    RETURNS TABLE (
        nspname text,
        proname text,
        signature text
    )
    LANGUAGE sql
    SECURITY DEFINER
    AS $$
        SELECT
            n.nspname::text,
            p.proname::text,
            pg_get_function_identity_arguments(p.oid)::text
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE p.proname = 'whiteboard_create_project'
        ORDER BY n.nspname, p.proname;
    $$;
    """
    return execute_ddl(ddl)


def drop_check_function():
    ddl = "DROP FUNCTION IF EXISTS public._check_whiteboard_create_project();"
    return execute_ddl(ddl)


def query():
    resp = requests.post(RPC_URL, headers=HEADERS, timeout=30)
    try:
        return resp.json()
    except Exception:
        return {"status": resp.status_code, "text": resp.text}


def main():
    print("=" * 80)
    print("MISSION D.15 - VÉRIFICATION DU POINT DE RUPTURE")
    print("=" * 80)
    print("\nRecherche de whiteboard_create_project dans pg_proc...")

    create_check_function()
    data = query()
    drop_check_function()

    print("\nRéponse brute:")
    print(json.dumps(data, indent=2, ensure_ascii=False))

    if isinstance(data, list):
        count = len(data)
    else:
        count = 0

    print(f"\nNombre de fonctions whiteboard_create_project trouvées: {count}")

    if count == 0:
        print("\n✅ CONFIRMATION: whiteboard_create_project n'existe PLUS dans pg_proc.")
        print("L'appel dans l'Edge Function whiteboard-generate-storyboard ligne 451")
        print("produira nécessairement une erreur PGRST201.")
    else:
        print("\n⚠️ whiteboard_create_project existe encore.")

    print("=" * 80)


if __name__ == "__main__":
    main()
