#!/usr/bin/env python3
"""Audit Bobodo-chat - Test réel de l'Edge Function en production"""

import requests
import json
from pathlib import Path

# Charger la clé API depuis le fichier .env
root = Path(__file__).resolve().parents[1]
env_path = root / "academia_bobodo_backend" / ".env"

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = None

if env_path.exists():
    try:
        content = env_path.read_text(encoding="utf-8")
        for line in content.splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            key = key.strip()
            value = value.strip().strip('"').strip("'")
            
            if key == "SUPABASE_SERVICE_KEY":
                SERVICE_KEY = value
                break
    except Exception as e:
        print(f"Erreur lecture fichier .env: {e}")

if not SERVICE_KEY:
    print("❌ SUPABASE_SERVICE_KEY non trouvée")
    exit(1)

print("=" * 80)
print("AUDIT BOBODO-CHAT - TEST EDGE FUNCTION EN PRODUCTION")
print("=" * 80)
print(f"\nSupabase URL: {SUPABASE_URL}")
print(f"Service Key (tronquée): {SERVICE_KEY[:20]}...{SERVICE_KEY[-10:]}")

# Test 1: Appel bobodo-chat avec message simple
print("\n" + "=" * 80)
print("TEST 1: APPEL BOBODO-CHAT (CHAT COMPLETIONS)")
print("=" * 80)

headers = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
    "Accept": "application/json"
}

payload = {
    "message": "Bonjour",
    "session_id": "audit_test_session"
}

try:
    response = requests.post(
        f"{SUPABASE_URL}/functions/v1/bobodo-chat",
        headers=headers,
        json=payload,
        timeout=30
    )
    
    print(f"\nHTTP Status: {response.status_code}")
    
    if response.status_code == 200:
        data = response.json()
        print(f"✅ Bobodo-chat répond")
        print(f"   Réponse: {data.get('answer', 'N/A')[:100]}...")
    else:
        print(f"❌ Erreur: {response.text[:200]}")
        
except Exception as e:
    print(f"❌ Erreur: {e}")

# Test 2: Appel avec message qui nécessite embeddings (si RAG activé)
print("\n" + "=" * 80)
print("TEST 2: APPEL BOBODO-CHAT (AVEC QUESTION COMPLEXE)")
print("=" * 80)

payload = {
    "message": "Comment postuler sur Academia ?",
    "session_id": "audit_test_session_2"
}

try:
    response = requests.post(
        f"{SUPABASE_URL}/functions/v1/bobodo-chat",
        headers=headers,
        json=payload,
        timeout=30
    )
    
    print(f"\nHTTP Status: {response.status_code}")
    
    if response.status_code == 200:
        data = response.json()
        print(f"✅ Bobodo-chat répond")
        print(f"   Réponse: {data.get('answer', 'N/A')[:100]}...")
        
        # Vérifier si la réponse contient des indices d'utilisation de RAG
        answer = data.get('answer', '').lower()
        rag_indicators = ['candidature', 'postuler', 'formulaire', 'dossier']
        found = [ind for ind in rag_indicators if ind in answer]
        if found:
            print(f"   ✅ Indicateurs RAG trouvés: {', '.join(found)}")
        else:
            print(f"   ⚠️ Aucun indicateur RAG évident")
    else:
        print(f"❌ Erreur: {response.text[:200]}")
        
except Exception as e:
    print(f"❌ Erreur: {e}")

print("\n" + "=" * 80)
print("CONCLUSION")
print("=" * 80)
print("Si Bobodo-chat répond avec HTTP 200:")
print("→ Les secrets Supabase sont valides")
print("→ Bobodo utilise les secrets Supabase de production")
print("\nSi Bobodo-chat échoue:")
print("→ Les secrets Supabase sont invalides ou manquants")
