"""
MISSION D.13 - PHASE 5: Exécuter cleanup_whiteboard_duplicates.sql

Exécute chaque instruction DROP FUNCTION du fichier SQL via execute_ddl.
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
    # Supprimer les commentaires sur une ligne
    sql = re.sub(r'--.*$', '', sql, flags=re.MULTILINE)
    # Supprimer les commentaires multi-lignes
    sql = re.sub(r'/\*.*?\*/', '', sql, flags=re.DOTALL)
    return sql


def split_sql_statements(sql):
    # Séparer par point-virgule
    statements = sql.split(';')
    # Nettoyer
    cleaned = []
    for stmt in statements:
        stmt = stmt.strip()
        if stmt and stmt.upper().startswith('DROP'):
            cleaned.append(stmt + ';')
    return cleaned


def execute_ddl(ddl):
    resp = requests.post(EXECUTE_DDL_URL, headers=HEADERS, json={"ddl_query": ddl}, timeout=30)
    try:
        return resp.json()
    except Exception:
        return {"status": resp.status_code, "text": resp.text}


def main():
    sql_file = ".windsurf/cleanup_whiteboard_duplicates.sql"

    print("=" * 80)
    print("MISSION D.13 - PHASE 5: EXÉCUTION DU NETTOYAGE")
    print("=" * 80)

    with open(sql_file, "r", encoding="utf-8") as f:
        sql = f.read()

    sql_no_comments = remove_comments(sql)
    statements = split_sql_statements(sql_no_comments)

    print(f"Nombre d'instructions DROP trouvées: {len(statements)}")
    print()

    success_count = 0
    error_count = 0

    for i, stmt in enumerate(statements, 1):
        # Extraire le nom de la fonction pour l'affichage
        match = re.search(r'DROP FUNCTION IF EXISTS\s+(\S+)', stmt, re.IGNORECASE)
        name = match.group(1) if match else f"instruction_{i}"

        print(f"[{i}/{len(statements)}] {name}")
        result = execute_ddl(stmt)
        print(f"  Résultat: {result}")

        # Considérer comme succès si pas d'erreur explicite
        if isinstance(result, dict) and (result.get("success") is True or result.get("status") in [200, 204]):
            success_count += 1
        elif isinstance(result, dict) and not result.get("error") and not result.get("text"):
            success_count += 1
        else:
            error_count += 1

    print()
    print("=" * 80)
    print(f"RÉSULTAT: {success_count} succès, {error_count} erreurs")
    print("=" * 80)


if __name__ == "__main__":
    main()
