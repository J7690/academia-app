import requests
import json

edge_function_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/functions/v1/whiteboard-generate-storyboard"
anon_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMwNTY1NjAsImV4cCI6MjA3ODYzMjU2MH0.8Zm6i6UaOrEOUvOafHOXOf0UiPOdp7on-aajYASOdk8"

headers = {
    "apikey": anon_key,
    "Authorization": f"Bearer {anon_key}",
    "Content-Type": "application/json"
}

print("=" * 80)
print("TEST EDGE FUNCTION whiteboard-generate-storyboard")
print("=" * 80)

payload = {
    "project_id": "e36a7312-2e2b-44c5-8c5a-48482db2ae64",
    "mode": "simple_subject",
    "subject": "dérivés",
    "content": "",
    "theme_id": "scientific",
    "renderer_id": "scientific",
    "narration_mode": "none"
}

resp = requests.post(edge_function_url, headers=headers, json=payload, timeout=60)
print(f"\nSTATUS: {resp.status_code}")
print(f"RESPONSE TEXT: {resp.text}")

if resp.status_code == 200:
    try:
        data = resp.json()
        print(f"\nJSON BRUT:")
        print(json.dumps(data, indent=2))
    except:
        print(f"\nRESPONSE n'est pas du JSON valide")
else:
    print(f"\nERREUR: {resp.text}")
