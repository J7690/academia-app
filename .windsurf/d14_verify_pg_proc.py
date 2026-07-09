"""
MISSION D.14.1 - Vérification finale via pg_proc

Requête exacte demandée par l'utilisateur:
SELECT
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    pg_get_function_result(p.oid) AS returns
FROM pg_proc p
JOIN pg_namespace n
ON n.oid = p.pronamespace
WHERE p.proname ILIKE '%whiteboard%'
ORDER BY
    n.nspname,
    p.proname;
"""

import requests
import json

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
EXECUTE_DDL_URL = f"{SUPABASE_URL}/rest/v1/rpc/execute_ddl"
RPC_URL = f"{SUPABASE_URL}/rest/v1/rpc/_verify_whiteboard_functions"
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


def create_verify_function():
    ddl = """
    CREATE OR REPLACE FUNCTION public._verify_whiteboard_functions()
    RETURNS TABLE (
        schema_name text,
        function_name text,
        arguments text,
        returns text
    )
    LANGUAGE sql
    SECURITY DEFINER
    AS $$
        SELECT
            n.nspname::text AS schema_name,
            p.proname::text AS function_name,
            pg_get_function_identity_arguments(p.oid)::text AS arguments,
            pg_get_function_result(p.oid)::text AS returns
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE p.proname ILIKE '%whiteboard%'
        ORDER BY n.nspname, p.proname;
    $$;
    """
    return execute_ddl(ddl)


def drop_verify_function():
    ddl = "DROP FUNCTION IF EXISTS public._verify_whiteboard_functions();"
    return execute_ddl(ddl)


def query_pg_proc():
    resp = requests.post(RPC_URL, headers=HEADERS, timeout=30)
    try:
        return resp.json()
    except Exception:
        return {"status": resp.status_code, "text": resp.text}


def main():
    print("=" * 80)
    print("MISSION D.14.1 - VÉRIFICATION FINALE pg_proc")
    print("=" * 80)

    print("\n1. Création de la fonction de vérification temporaire...")
    result_create = create_verify_function()
    print(json.dumps(result_create, indent=2, ensure_ascii=False))

    print("\n2. Exécution de la requête de vérification...")
    raw_data = query_pg_proc()
    print("Réponse brute:")
    print(json.dumps(raw_data, indent=2, ensure_ascii=False)[:2000])

    if isinstance(raw_data, list):
        data = raw_data
    elif isinstance(raw_data, dict) and "result" in raw_data:
        data = raw_data["result"]
    elif isinstance(raw_data, dict) and len(raw_data) > 0:
        data = [raw_data]
    else:
        data = []

    print(f"\nNombre de fonctions trouvées: {len(data)}")

    print("\nListe complète:")
    print("-" * 80)
    for row in data:
        print(f"  {row['schema_name']}.{row['function_name']}")
        print(f"    args: ({row['arguments']})")
        print(f"    returns: {row['returns']}")
    print("-" * 80)

    print("\n3. Suppression de la fonction de vérification temporaire...")
    result_drop = drop_verify_function()
    print(json.dumps(result_drop, indent=2, ensure_ascii=False))

    # Sauvegarder
    output_file = ".windsurf/d14_pg_proc_final.json"
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    print(f"\nRésultat sauvegardé dans: {output_file}")

    # Vérification du total
    print("\n" + "=" * 80)
    if len(data) == 14:
        print(f"✅ TOTAL = {len(data)} (14 attendus)")
        print("OPÉRATION RÉUSSIE")
    else:
        print(f"❌ TOTAL = {len(data)} (14 attendus)")
        print("OPÉRATION ÉCHOUÉE")
    print("=" * 80)


if __name__ == "__main__":
    main()
