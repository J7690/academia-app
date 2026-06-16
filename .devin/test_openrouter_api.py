#!/usr/bin/env python3
"""Test API OpenRouter - Embeddings et Chat Completions"""

import os
import requests
from pathlib import Path

# Charger la clé API depuis le fichier .env
root = Path(__file__).resolve().parents[1]
env_path = root / "academia_bobodo_backend" / ".env"

OPENROUTER_API_KEY = None

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
            
            if key == "OPENROUTER_API_KEY":
                OPENROUTER_API_KEY = value
                break
    except Exception as e:
        print(f"Erreur lecture fichier .env: {e}")

if not OPENROUTER_API_KEY:
    print("❌ OPENROUTER_API_KEY non trouvée")
    exit(1)

print("=" * 80)
print("TEST API OPENROUTER")
print("=" * 80)
print(f"\nClé API (tronquée): {OPENROUTER_API_KEY[:10]}...{OPENROUTER_API_KEY[-4:]}")
print(f"Longueur: {len(OPENROUTER_API_KEY)}")

# Test 1: Embeddings avec modèle correct
print("\n" + "=" * 80)
print("TEST 1: EMBEDDINGS (openai/text-embedding-3-small)")
print("=" * 80)

try:
    url = "https://openrouter.ai/api/v1/embeddings"
    headers = {
        "Authorization": f"Bearer {OPENROUTER_API_KEY}",
        "Content-Type": "application/json"
    }
    payload = {
        "model": "openai/text-embedding-3-small",
        "input": "Test embedding generation"
    }
    
    response = requests.post(url, headers=headers, json=payload, timeout=30)
    
    if response.status_code == 200:
        data = response.json()
        if "data" in data and len(data["data"]) > 0:
            embedding = data["data"][0].get("embedding")
            if embedding:
                print(f"✅ Embeddings générés avec succès")
                print(f"   Dimension: {len(embedding)}")
            else:
                print(f"❌ Embedding vide dans la réponse")
        else:
            print(f"❌ Format de réponse inattendu")
    else:
        print(f"❌ Erreur HTTP {response.status_code}")
        print(f"   {response.text[:200]}")
except Exception as e:
    print(f"❌ Erreur: {e}")

# Test 2: Chat completions avec modèle configuré
print("\n" + "=" * 80)
print("TEST 2: CHAT COMPLETIONS (meta-llama/Meta-Llama-3.1-70B-Instruct)")
print("=" * 80)

try:
    url = "https://openrouter.ai/api/v1/chat/completions"
    headers = {
        "Authorization": f"Bearer {OPENROUTER_API_KEY}",
        "Content-Type": "application/json"
    }
    payload = {
        "model": "meta-llama/Meta-Llama-3.1-70B-Instruct",
        "messages": [{"role": "user", "content": "Hello"}]
    }
    
    response = requests.post(url, headers=headers, json=payload, timeout=30)
    
    if response.status_code == 200:
        data = response.json()
        if "choices" in data and len(data["choices"]) > 0:
            print(f"✅ Chat completions fonctionnent")
            print(f"   Modèle: {data.get('model', 'N/A')}")
        else:
            print(f"❌ Format de réponse inattendu")
    else:
        print(f"❌ Erreur HTTP {response.status_code}")
        print(f"   {response.text[:200]}")
except Exception as e:
    print(f"❌ Erreur: {e}")

# Test 3: Embeddings avec modèle incorrect (pour reproduire l'erreur)
print("\n" + "=" * 80)
print("TEST 3: EMBEDDINGS AVEC MODÈLE INCORRECT (meta-llama/Meta-Llama-3.1-70B-Instruct)")
print("=" * 80)

try:
    url = "https://openrouter.ai/api/v1/embeddings"
    headers = {
        "Authorization": f"Bearer {OPENROUTER_API_KEY}",
        "Content-Type": "application/json"
    }
    payload = {
        "model": "meta-llama/Meta-Llama-3.1-70B-Instruct",
        "input": "Test embedding generation"
    }
    
    response = requests.post(url, headers=headers, json=payload, timeout=30)
    
    if response.status_code == 200:
        print(f"✅ Succès (inattendu - le modèle supporte les embeddings)")
    else:
        print(f"❌ Erreur HTTP {response.status_code}")
        print(f"   {response.text[:200]}")
except Exception as e:
    print(f"❌ Erreur: {e}")

print("\n" + "=" * 80)
