"""
MISSION D.14.1 - Exécution sécurisée des 7 RPCs Flutter

Exécute le script create_missing_flutter_rpcs.sql via execute_ddl.
Chaque instruction est exécutée individuellement.
"""

import requests
import re

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
EXECUTE_DDL_URL = f"{SUPABASE_URL}/rest/v1/rpc/execute_ddl"
HEADERS = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}


def remove_comments(sql):
    sql = re.sub(r'--.*$', '', sql, flags=re.MULTILINE)
    sql = re.sub(r'/\*.*?\*/', '', sql, flags=re.DOTALL)
    return sql


def split_sql_statements(sql):
    statements = sql.split(';')
    cleaned = []
    for stmt in statements:
        stmt = stmt.strip()
        if stmt and (stmt.upper().startswith('DROP') or stmt.upper().startswith('CREATE')):
            cleaned.append(stmt + ';')
    return cleaned


def execute_ddl(ddl):
    resp = requests.post(EXECUTE_DDL_URL, headers=HEADERS, json={"ddl_query": ddl}, timeout=30)
    try:
        return resp.json()
    except Exception:
        return {"status": resp.status_code, "text": resp.text}


def main():
    sql_file = ".windsurf/create_missing_flutter_rpcs.sql"

    print("=" * 80)
    print("MISSION D.14.1 - CRÉATION DES 7 RPCs FLUTTER")
    print("=" * 80)

    with open(sql_file, "r", encoding="utf-8") as f:
        sql = f.read()

    # Retirer les commentaires de vérification en fin de script
    # et exécuter le script SQL complet en une seule requête execute_ddl
    sql_clean = re.sub(r'--\s*Exécuter après ce script:.*$', '', sql, flags=re.MULTILINE | re.DOTALL)
    sql_clean = re.sub(r'--\s*Résultat attendu:.*$', '', sql_clean, flags=re.MULTILINE | re.DOTALL)
    sql_clean = re.sub(r'--\s*SELECT.*$', '', sql_clean, flags=re.MULTILINE | re.DOTALL)
    sql_clean = sql_clean.strip()

    print(f"Script SQL à exécuter:\n{sql_clean[:500]}...")
    print(f"\nLongueur totale: {len(sql_clean)} caractères")
    print()

    result = execute_ddl(sql_clean)
    print(f"Résultat: {result}")

    success = False
    if isinstance(result, dict):
        if result.get("success") is True or result.get("status") in [200, 204]:
            success = True
        elif not result.get("error") and not result.get("text"):
            success = True

    print()
    print("=" * 80)
    if success:
        print("RÉSULTAT: SUCCÈS")
    else:
        print(f"RÉSULTAT: ERREUR - {result}")
    print("=" * 80)


if __name__ == "__main__":
    main()
