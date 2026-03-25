#!/usr/bin/env python3
"""Deploy the prep concours unification SQL in segments."""
import json, requests, time, re
from pathlib import Path

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SK, "Authorization": f"Bearer {SK}", "Content-Type": "application/json"}

def exec_sql(sql_text: str, label: str = "") -> dict:
    """Execute SQL via admin_execute_sql RPC."""
    clean = " ".join(sql_text.split())
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                       json={"p_sql": clean}, timeout=60)
    body = r.json() if r.status_code == 200 else {"ok": False, "error": r.text[:500]}
    ok = isinstance(body, dict) and body.get("ok", False)
    status = "✅" if ok else "❌"
    err = body.get("error", "") if not ok else ""
    print(f"  {status} {label} {'— ' + err if err else ''}")
    return body

def split_statements(sql_text: str):
    """Split SQL file into individual statements, respecting $$ blocks."""
    statements = []
    current = []
    in_dollar = False
    
    for line in sql_text.split("\n"):
        stripped = line.strip()
        if stripped.startswith("--") and not in_dollar:
            continue
        if stripped == "":
            continue
        
        # Count $$ occurrences
        dollar_count = line.count("$$")
        if dollar_count % 2 == 1:
            in_dollar = not in_dollar
        
        current.append(line)
        
        if not in_dollar and stripped.endswith(";"):
            stmt = "\n".join(current).strip()
            if stmt and not stmt.startswith("--"):
                statements.append(stmt)
            current = []
    
    # Remaining
    if current:
        stmt = "\n".join(current).strip()
        if stmt and not stmt.startswith("--"):
            statements.append(stmt)
    
    return statements

def main():
    sql_file = Path(__file__).parent / "sql_changes" / "change_20260315_unify_prep_concours.sql"
    sql_text = sql_file.read_text(encoding="utf-8")
    
    stmts = split_statements(sql_text)
    print(f"Deploying {len(stmts)} SQL statements...\n")
    
    ok_count = 0
    err_count = 0
    errors = []
    
    for i, stmt in enumerate(stmts, 1):
        # Extract a label from the statement
        label = ""
        if "CREATE TABLE" in stmt.upper():
            m = re.search(r"CREATE TABLE.*?(\w+\.\w+)", stmt, re.IGNORECASE)
            label = f"CREATE TABLE {m.group(1)}" if m else "CREATE TABLE"
        elif "CREATE OR REPLACE FUNCTION" in stmt.upper():
            m = re.search(r"FUNCTION\s+(\S+)\(", stmt, re.IGNORECASE)
            label = f"FUNCTION {m.group(1)}" if m else "FUNCTION"
        elif "CREATE POLICY" in stmt.upper():
            m = re.search(r"POLICY.*?(\w+)\s+ON\s+(\S+)", stmt, re.IGNORECASE)
            label = f"POLICY {m.group(1)} ON {m.group(2)}" if m else "POLICY"
        elif "ALTER TABLE" in stmt.upper():
            m = re.search(r"ALTER TABLE\s+(\S+)", stmt, re.IGNORECASE)
            label = f"ALTER {m.group(1)}" if m else "ALTER"
        elif "INSERT INTO" in stmt.upper():
            m = re.search(r"INSERT INTO\s+(\S+)", stmt, re.IGNORECASE)
            label = f"INSERT {m.group(1)}" if m else "INSERT"
        elif "DO $$" in stmt:
            label = "DO $$ block"
        else:
            label = stmt[:60].replace("\n", " ")
        
        result = exec_sql(stmt, f"[{i}/{len(stmts)}] {label}")
        
        if isinstance(result, dict) and result.get("ok"):
            ok_count += 1
        else:
            err_count += 1
            err_msg = result.get("error", "") if isinstance(result, dict) else str(result)
            errors.append({"index": i, "label": label, "error": err_msg})
        
        time.sleep(0.3)
    
    print(f"\n{'='*60}")
    print(f"Résultat: {ok_count}/{len(stmts)} OK, {err_count} erreurs")
    
    if errors:
        print("\nErreurs:")
        for e in errors:
            print(f"  [{e['index']}] {e['label']}: {e['error'][:200]}")
    
    # Save results
    out = Path(__file__).parent / "logs" / "deploy_prep_unify_result.json"
    with open(out, "w", encoding="utf-8") as f:
        json.dump({"ok": ok_count, "errors": errors, "total": len(stmts)}, f, indent=2, ensure_ascii=False)
    print(f"\nSauvegardé: {out}")

if __name__ == "__main__":
    main()
