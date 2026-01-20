#!/usr/bin/env python3
"""Test simple SELECT via RPC execute_sql avec Bearer explicite."""

import sys
import requests
import json

def test_select():
    url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/execute_sql"
    headers = {
        "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Prefer": "return=minimal",
    }
    sql = "SELECT 1 AS test"
    payload = {"sql_query": sql}
    r = requests.post(url, headers=headers, json=payload, timeout=10)
    print("SELECT simple via RPC (Bearer only):", r.status_code, r.text[:500])

if __name__ == "__main__":
    test_select()
