#!/usr/bin/env python3
import requests
import json

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
}

PROJECT_ID = "3993bb85-1818-407b-810e-4bcfe1b983fa"

url = f"{SUPABASE_URL}/rest/v1/app/whiteboard_renders?project_id=eq.{PROJECT_ID}&select=id,status,video_url,duration_ms,error_message,created_at,completed_at&order=created_at.desc&limit=5"
resp = requests.get(url, headers=HEADERS, timeout=60)
print("Status:", resp.status_code)
print(resp.text)
