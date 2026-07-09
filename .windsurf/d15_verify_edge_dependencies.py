"""
MISSION D.15.1 - Vérification des dépendances de l'Edge Function

Vérifie que les RPCs non-whiteboard utilisées par whiteboard-generate-storyboard
existent dans pg_proc.
"""

import requests
import json

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
EXECUTE_DDL_URL = f"{SUPABASE_URL}/rest/v1/rpc/execute_ddl"
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


def query_pg_proc():
    ddl = """
    SELECT
        n.nspname AS schema_name,
        p.proname AS function_name
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE p.proname IN (
        'app_student_reserve_credits',
        'app_student_refund_credits',
        'app_student_confirm_credits',
        'admin_execute_sql'
    )
    ORDER BY n.nspname, p.proname;
    """
    resp = requests.post(EXECUTE_DDL_URL, headers=HEADERS, json={"ddl_query": ddl}, timeout=30)
    try:
        return resp.json()
    except Exception:
        return {"status": resp.status_code, "text": resp.text}


def main():
    print("=" * 80)
    print("MISSION D.15.1 - VÉRIFICATION DES DÉPENDANCES EDGE FUNCTION")
    print("=" * 80)

    expected = {
        'app_student_reserve_credits',
        'app_student_refund_credits',
        'app_student_confirm_credits',
        'admin_execute_sql',
    }

    data = query_pg_proc()
    print("\nDépendances de whiteboard-generate-storyboard:")
    if isinstance(data, list):
        found = {row['function_name'] for row in data}
        for name in sorted(expected):
            status = "✅" if name in found else "❌"
            print(f"  {status} {name}")
        if found == expected:
            print("\n✅ Toutes les dépendances existent.")
        else:
            print("\n❌ Certaines dépendances sont manquantes.")
    else:
        print("Erreur:")
        print(json.dumps(data, indent=2, ensure_ascii=False))

    print("=" * 80)


if __name__ == "__main__":
    main()
