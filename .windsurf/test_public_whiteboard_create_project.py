import requests
import json

base_url = "https://thevdfcwlcqzdoybfvgs.supabase.co"
anon_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMwNTY1NjAsImV4cCI6MjA3ODYzMjU2MH0.8Zm6i6UaOrEOUvOafHOXOf0UiPOdp7on-aajYASOdk8"

headers = {
    "apikey": anon_key,
    "Authorization": f"Bearer {anon_key}",
    "Content-Type": "application/json"
}

print("=" * 80)
print("TEST API REST POSTGREST - whiteboard_create_project")
print("=" * 80)

url = f"{base_url}/rest/v1/rpc/whiteboard_create_project"
params = {
    "p_student_id": "c63e9c1e-92d9-43f3-ab41-066ec3dc788b",
    "p_subject": "Test dérivés",
    "p_renderer_id": "scientific",
    "p_theme_id": "scientific",
    "p_narration_mode": "none",
    "p_storyboard_json": {}
}

resp = requests.post(url, headers=headers, json=params, timeout=30)
print(f"\nSTATUS: {resp.status_code}")
print(f"RESPONSE: {resp.text}")

if resp.status_code == 200:
    data = resp.json()
    print(f"\nJSON BRUT:")
    print(json.dumps(data, indent=2))
