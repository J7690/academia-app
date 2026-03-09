#!/usr/bin/env python3
"""Test rapide de la RPC app_student_unified_video_feed corrigée."""

import requests
import json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {
    "apikey": KEY,
    "Authorization": f"Bearer {KEY}",
    "Content-Type": "application/json",
}

def query(sql):
    r = requests.post(f"{URL}/rest/v1/rpc/execute_sql", headers=HEADERS, json={"sql_query": sql}, timeout=30)
    return r.json() if r.status_code == 200 else f"ERR {r.status_code}: {r.text[:500]}"

# Test: call the feed RPC directly via SQL (simulating service_role, not auth)
result = query("""
    SELECT app_student_unified_video_feed(NULL, 5)
""")

print("=== FEED RPC RESULT ===")
if isinstance(result, list) and result:
    data = result[0]
    if isinstance(data, dict):
        feed_result = list(data.values())[0] if data else data
        if isinstance(feed_result, str):
            try:
                feed_result = json.loads(feed_result)
            except:
                pass
        print(json.dumps(feed_result, indent=2, ensure_ascii=False, default=str)[:3000])
    else:
        print(json.dumps(data, indent=2, ensure_ascii=False, default=str)[:3000])
else:
    print(json.dumps(result, indent=2, ensure_ascii=False, default=str)[:3000])
