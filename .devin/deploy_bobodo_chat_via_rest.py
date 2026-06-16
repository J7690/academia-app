#!/usr/bin/env python3
"""Déployer l'Edge Function bobodo-chat via l'API REST Supabase."""

import json
import requests
from auto_supabase_import import SUPABASE_URL, SUPABASE_SERVICE_KEY

def deploy_edge_function():
    """Déployer l'Edge Function via l'API REST Supabase."""
    
    # Lire le code de l'Edge Function
    edge_function_path = "../supabase/functions/bobodo-chat/index.ts"
    try:
        with open(edge_function_path, "r", encoding="utf-8") as f:
            edge_function_code = f.read()
    except Exception as exc:
        print(f"[ERROR] Impossible de lire le fichier Edge Function: {exc}")
        return False

    # Préparer le payload pour l'API
    payload = {
        "name": "bobodo-chat",
        "body": edge_function_code,
        "verify_jwt": True
    }

    # Headers pour l'API
    headers = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Content-Type": "application/json"
    }

    # URL pour créer/mettre à jour une Edge Function
    url = f"{SUPABASE_URL}/rest/v1/functions"
    
    print("=== Déploiement de l'Edge Function bobodo-chat ===")
    print(f"URL: {url}")
    print(f"Taille du code: {len(edge_function_code)} caractères")
    
    try:
        # Essayer de créer la fonction
        response = requests.post(url, headers=headers, json=payload, timeout=30)
        print(f"POST STATUS: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ Edge Function créée avec succès")
            return True
        elif response.status_code == 409:
            print("⚠️  La fonction existe déjà, tentative de mise à jour...")
            # Mettre à jour la fonction existante
            update_url = f"{url}/bobodo-chat"
            response = requests.put(update_url, headers=headers, json=payload, timeout=30)
            print(f"PUT STATUS: {response.status_code}")
            
            if response.status_code == 200:
                print("✅ Edge Function mise à jour avec succès")
                return True
            else:
                print(f"❌ Échec de la mise à jour: {response.text}")
                return False
        else:
            print(f"❌ Échec de la création: {response.text}")
            return False
            
    except Exception as exc:
        print(f"[ERROR] Exception lors du déploiement: {exc}")
        return False

def verify_edge_function():
    """Vérifier que l'Edge Function est bien déployée."""
    
    headers = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Content-Type": "application/json"
    }
    
    url = f"{SUPABASE_URL}/rest/v1/functions/bobodo-chat"
    
    print("\n=== Vérification de l'Edge Function ===")
    
    try:
        response = requests.get(url, headers=headers, timeout=30)
        print(f"GET STATUS: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            print("✅ Edge Function trouvée:")
            print(f"  - Nom: {data.get('name')}")
            print(f"  - Status: {data.get('status')}")
            print(f"  - Créée le: {data.get('created_at')}")
            print(f"  - Modifiée le: {data.get('updated_at')}")
            return True
        else:
            print(f"❌ Edge Function non trouvée: {response.text}")
            return False
            
    except Exception as exc:
        print(f"[ERROR] Exception lors de la vérification: {exc}")
        return False

def main() -> int:
    print("Déploiement de l'Edge Function bobodo-chat via API REST Supabase")
    print("=" * 60)
    
    # Déployer la fonction
    if not deploy_edge_function():
        return 1
    
    # Vérifier le déploiement
    if not verify_edge_function():
        return 1
    
    print("\n✅ Déploiement terminé avec succès!")
    print("L'Edge Function bobodo-chat est maintenant active.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
