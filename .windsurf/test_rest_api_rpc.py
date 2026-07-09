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
print("TEST API REST POSTGREST")
print("=" * 80)

# Test 1: whiteboard_create_project
print("\n1. Test POST /rest/v1/rpc/whiteboard_create_project")
url1 = f"{base_url}/rest/v1/rpc/whiteboard_create_project"
params1 = {
    "p_student_id": "c63e9c1e-92d9-43f3-ab41-066ec3dc788b",
    "p_subject": "Test subject",
    "p_renderer_id": "scientific",
    "p_theme_id": "scientific",
    "p_narration_mode": "none",
    "p_storyboard_json": {}
}

resp1 = requests.post(url1, headers=headers, json=params1, timeout=30)
print(f"STATUS: {resp1.status_code}")
print(f"RESPONSE: {resp1.text}")

# Test 2: whiteboard_create_project
print("\n2. Test POST /rest/v1/rpc/whiteboard_create_project")
url2 = f"{base_url}/rest/v1/rpc/whiteboard_create_project"
params2 = {
    "p_student_id": "c63e9c1e-92d9-43f3-ab41-066ec3dc788b",
    "p_subject": "Test subject",
    "p_renderer_id": "scientific",
    "p_theme_id": "scientific",
    "p_narration_mode": "none",
    "p_storyboard_json": {}
}

resp2 = requests.post(url2, headers=headers, json=params2, timeout=30)
print(f"STATUS: {resp2.status_code}")
print(f"RESPONSE: {resp2.text}")

# Test 3: public.whiteboard_create_project
print("\n3. Test POST /rest/v1/rpc/public.whiteboard_create_project")
url3 = f"{base_url}/rest/v1/rpc/public.whiteboard_create_project"
params3 = {
    "p_student_id": "c63e9c1e-92d9-43f3-ab41-066ec3dc788b",
    "p_subject": "Test subject",
    "p_renderer_id": "scientific",
    "p_theme_id": "scientific",
    "p_narration_mode": "none",
    "p_storyboard_json": {}
}

resp3 = requests.post(url3, headers=headers, json=params3, timeout=30)
print(f"STATUS: {resp3.status_code}")
print(f"RESPONSE: {resp3.text}")

# Test 4: app.whiteboard_create_project
print("\n4. Test POST /rest/v1/rpc/app.whiteboard_create_project")
url4 = f"{base_url}/rest/v1/rpc/app.whiteboard_create_project"
params4 = {
    "p_student_id": "c63e9c1e-92d9-43f3-ab41-066ec3dc788b",
    "p_subject": "Test subject",
    "p_renderer_id": "scientific",
    "p_theme_id": "scientific",
    "p_narration_mode": "none",
    "p_storyboard_json": {}
}

resp4 = requests.post(url4, headers=headers, json=params4, timeout=30)
print(f"STATUS: {resp4.status_code}")
print(f"RESPONSE: {resp4.text}")
