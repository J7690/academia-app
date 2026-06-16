#!/usr/bin/env python3
"""Déploie le système de crédits Academia : tables + RPCs + seed data."""

import requests
import json
import re

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

HEADERS = {
    "apikey": SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}

def execute_ddl(sql):
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/execute_ddl",
        headers=HEADERS,
        json={"ddl_query": sql},
        timeout=30,
    )
    return r.status_code, r.text[:500]

def split_sql(sql_text):
    """Split SQL respecting $$ blocks."""
    statements = []
    current = ""
    in_dollar = False
    
    for line in sql_text.split("\n"):
        stripped = line.strip()
        if stripped.startswith("--") and not in_dollar:
            continue
        if not stripped and not in_dollar:
            continue
            
        current += line + "\n"
        
        # Track $$ blocks
        count = line.count("$$")
        if count % 2 == 1:
            in_dollar = not in_dollar
            
        if not in_dollar and current.rstrip().endswith(";"):
            stmt = current.strip()
            if stmt and stmt != ";":
                statements.append(stmt)
            current = ""
    
    if current.strip():
        statements.append(current.strip())
    
    return statements

def deploy_file(filepath, label):
    print(f"\n{'='*60}")
    print(f"Deploying: {label}")
    print(f"File: {filepath}")
    print(f"{'='*60}")
    
    with open(filepath, "r", encoding="utf-8") as f:
        sql_content = f.read()
    
    statements = split_sql(sql_content)
    print(f"Found {len(statements)} statements")
    
    success_count = 0
    error_count = 0
    
    for i, stmt in enumerate(statements):
        # Show first 80 chars
        preview = stmt.replace("\n", " ")[:80]
        status, resp = execute_ddl(stmt)
        
        if status == 200:
            success_count += 1
            print(f"  ✅ [{i+1}/{len(statements)}] {preview}...")
        else:
            # Check if it's a "already exists" type error
            if "already exists" in resp or "duplicate" in resp.lower():
                success_count += 1
                print(f"  ⚠️ [{i+1}/{len(statements)}] Already exists (OK): {preview[:60]}...")
            else:
                error_count += 1
                print(f"  ❌ [{i+1}/{len(statements)}] Error {status}: {resp[:200]}")
                print(f"     Statement: {preview[:100]}...")
    
    print(f"\nResult: {success_count} OK, {error_count} errors")
    return error_count == 0

def verify():
    print(f"\n{'='*60}")
    print("VERIFICATION POST-DEPLOIEMENT")
    print(f"{'='*60}")
    
    # Check tables
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/execute_sql",
        headers=HEADERS,
        json={"sql_query": """
            SELECT table_name FROM information_schema.tables 
            WHERE table_schema = 'app' 
            AND table_name IN ('student_credits','credit_transactions','credit_packs','ai_action_prices','credit_reservations')
            ORDER BY table_name
        """},
        timeout=15,
    )
    if r.status_code == 200:
        tables = [row.get("table_name") for row in r.json()]
        expected = ["ai_action_prices", "credit_packs", "credit_reservations", "credit_transactions", "student_credits"]
        for t in expected:
            status = "✅" if t in tables else "❌"
            print(f"  Table app.{t}: {status}")
    
    # Check RPCs
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/execute_sql",
        headers=HEADERS,
        json={"sql_query": """
            SELECT routine_name FROM information_schema.routines 
            WHERE routine_schema = 'public' AND routine_name LIKE 'app_student_%credit%'
            ORDER BY routine_name
        """},
        timeout=15,
    )
    if r.status_code == 200:
        rpcs = [row.get("routine_name") for row in r.json()]
        print(f"\n  Credit RPCs found: {len(rpcs)}")
        for rpc in rpcs:
            print(f"    ✅ {rpc}")
    
    # Check seed data
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/execute_sql",
        headers=HEADERS,
        json={"sql_query": "SELECT code, name, credits, price_xof FROM app.credit_packs ORDER BY sort_order"},
        timeout=15,
    )
    if r.status_code == 200:
        packs = r.json()
        print(f"\n  Credit packs: {len(packs)}")
        for p in packs:
            print(f"    💎 {p.get('name')}: {p.get('credits')} crédits → {p.get('price_xof')} XOF")
    
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/execute_sql",
        headers=HEADERS,
        json={"sql_query": "SELECT action_code, label, cost_credits FROM app.ai_action_prices ORDER BY cost_credits"},
        timeout=15,
    )
    if r.status_code == 200:
        prices = r.json()
        print(f"\n  AI action prices: {len(prices)}")
        for p in prices:
            print(f"    🤖 {p.get('action_code')}: {p.get('cost_credits')} crédits — {p.get('label')}")

def main():
    ok1 = deploy_file("sql_changes/change_20260407_credits_system_tables.sql", "Tables + Seed Data")
    ok2 = deploy_file("sql_changes/change_20260407_credits_system_rpcs.sql", "RPCs")
    
    verify()
    
    print(f"\n{'='*60}")
    if ok1 and ok2:
        print("✅ DÉPLOIEMENT TERMINÉ AVEC SUCCÈS")
    else:
        print("⚠️ DÉPLOIEMENT TERMINÉ AVEC DES ERREURS")
    print(f"{'='*60}")

if __name__ == "__main__":
    main()
