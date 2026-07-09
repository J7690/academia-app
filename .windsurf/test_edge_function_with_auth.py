import requests
import json

base_url = "https://thevdfcwlcqzdoybfvgs.supabase.co"
anon_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMwNTY1NjAsImV4cCI6MjA3ODYzMjU2MH0.8Zm6i6UaOrEOUvOafHOXOf0UiPOdp7on-aajYASOdk8"

print("=" * 80)
print("TEST RÉEL EDGE FUNCTION AVEC AUTHENTIFICATION")
print("=" * 80)
print("Sujet: dérivés")
print("Narration: tts")
print("=" * 80)

# Étape 1: Se connecter avec email/password
print("\nÉTAPE 1: Connexion utilisateur...")
auth_url = f"{base_url}/auth/v1/token?grant_type=password"
auth_payload = {
    "email": "nexiomgroup@gmail.com",
    "password": "Academia2024"
}

auth_resp = requests.post(auth_url, headers={"apikey": anon_key}, json=auth_payload)
print(f"STATUS: {auth_resp.status_code}")

if auth_resp.status_code != 200:
    print(f"ERREUR CONNEXION: {auth_resp.text}")
    exit(1)

auth_data = auth_resp.json()
access_token = auth_data.get('access_token')
print(f"✅ Connexion réussie, JWT obtenu")

# Étape 2: Appeler Edge Function avec JWT
print("\nÉTAPE 2: Appel Edge Function...")
edge_function_url = f"{base_url}/functions/v1/whiteboard-generate-storyboard"

headers = {
    "apikey": anon_key,
    "Authorization": f"Bearer {access_token}",
    "Content-Type": "application/json"
}

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
