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
print("TEST RÉEL EDGE FUNCTION")
print("=" * 80)
print("Sujet: dérivés")
print("Narration: tts")
print("=" * 80)

payload = {
    "mode": "simple_subject",
    "subject": "dérivés",
    "content": "",
    "renderer": "scientific",
    "theme": "scientific",
    "narration_mode": "tts"
}

print("\nPAYLOAD ENVOYÉ:")
print(json.dumps(payload, indent=2))

print("\n" + "=" * 80)
print("APPEL EDGE FUNCTION...")
print("=" * 80)

resp = requests.post(edge_function_url, headers=headers, json=payload, timeout=120)
print(f"\nSTATUS: {resp.status_code}")
print(f"HEADERS: {dict(resp.headers)}")

print("\n" + "=" * 80)
print("RÉPONSE BRUTE:")
print("=" * 80)
print(resp.text)

if resp.status_code == 200:
    try:
        data = resp.json()
        print("\n" + "=" * 80)
        print("JSON PARSED:")
        print("=" * 80)
        print(json.dumps(data, indent=2))
    except:
        print("\n" + "=" * 80)
        print("ERREUR PARSING JSON")
        print("=" * 80)
