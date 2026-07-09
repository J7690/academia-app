"""
MISSION D.13 - PHASE 2: Interroger pg_proc

Crée une fonction temporaire d'audit dans public pour retourner le résultat
de la requête pg_proc, puis l'appelle via RPC et supprime la fonction.

PRINCIPE: PostgreSQL = source de vérité.
"""

import requests
import json

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
EXECUTE_DDL_URL = f"{SUPABASE_URL}/rest/v1/rpc/execute_ddl"
RPC_URL = f"{SUPABASE_URL}/rest/v1/rpc/_audit_whiteboard_functions"
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


def create_audit_function():
    ddl = """
    CREATE OR REPLACE FUNCTION public._audit_whiteboard_functions()
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
        WHERE p.proname ILIKE '%whiteboard%'
           OR p.proname IN (
               'app_student_reserve_credits',
               'app_student_refund_credits',
               'app_student_confirm_credits',
               'admin_execute_sql'
           )
        ORDER BY n.nspname, p.proname;
    $$;
    """
    return execute_ddl(ddl)


def drop_audit_function():
    ddl = "DROP FUNCTION IF EXISTS public._audit_whiteboard_functions();"
    return execute_ddl(ddl)


def query_pg_proc():
    resp = requests.post(RPC_URL, headers=HEADERS, timeout=30)
    try:
        return resp.json()
    except Exception:
        return {"status": resp.status_code, "text": resp.text}


def main():
    print("=" * 80)
    print("MISSION D.13 - PHASE 2: INTERROGATION pg_proc")
    print("=" * 80)

    print("\n1. Création de la fonction d'audit temporaire...")
    result_create = create_audit_function()
    print(json.dumps(result_create, indent=2, ensure_ascii=False))

    print("\n2. Appel de la fonction d'audit...")
    raw_data = query_pg_proc()
    print("Réponse brute:")
    print(json.dumps(raw_data, indent=2, ensure_ascii=False)[:1000])

    # Normaliser le format de réponse
    if isinstance(raw_data, list):
        data = raw_data
    elif isinstance(raw_data, dict) and "result" in raw_data:
        data = raw_data["result"]
    elif isinstance(raw_data, dict) and len(raw_data) > 0:
        # Peut-être une seule ligne retournée comme dict
        data = [raw_data]
    else:
        data = []

    print(f"\nNombre de fonctions trouvées: {len(data)}")
    print("\nPremières fonctions:")
    for row in data[:10]:
        print(f"  {row['nspname']}.{row['proname']}({row['signature']})")

    print("\n3. Suppression de la fonction d'audit temporaire...")
    result_drop = drop_audit_function()
    print(json.dumps(result_drop, indent=2, ensure_ascii=False))

    # Sauvegarder le résultat
    import sys
    output_file = sys.argv[1] if len(sys.argv) > 1 else ".windsurf/d13_pg_proc_after.json"
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    print(f"\nRésultat sauvegardé dans: {output_file}")

    print("=" * 80)


if __name__ == "__main__":
    main()
