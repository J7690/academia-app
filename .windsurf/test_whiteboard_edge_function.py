import requests
import json

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/functions/v1/whiteboard-generate-storyboard"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=" * 80)
print("TEST EDGE FUNCTION whiteboard-generate-storyboard")
print("=" * 80)

# Test payload
payload = {
    "subject": "Mathématiques",
    "topic": "Dérivées",
    "difficulty": "intermédiaire",
    "language": "fr"
}

print(f"\nPayload: {json.dumps(payload, indent=2)}")

try:
    resp = requests.post(url, headers=headers, json=payload, timeout=30)
    print(f"\nSTATUS: {resp.status_code}")
    print(f"BODY: {resp.text}")
    
    if resp.status_code == 200:
        data = resp.json()
        print(f"\n✅ Edge Function répond correctement")
        
        if "storyboard" in data or "frames" in data or "slides" in data:
            print(f"✅ Storyboard généré avec succès")
            print(f"Structure: {list(data.keys())}")
        else:
            print(f"⚠️ Réponse reçue mais structure de storyboard non reconnue")
    else:
        print(f"❌ Edge Function a retourné une erreur")
        
except Exception as e:
    print(f"❌ Erreur lors de l'appel: {e}")

print("\n" + "=" * 80)
print("TEST TERMINÉ")
print("=" * 80)
