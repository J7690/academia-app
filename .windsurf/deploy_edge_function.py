#!/usr/bin/env python3
"""
Script de déploiement Edge Function Bobodo Voice via Supabase Management API
Utilise les credentials fournis pour déployer sans Supabase CLI
"""

import requests
import json
import time
from pathlib import Path

# Credentials Supabase Management
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
PROJECT_REF = "thevdfcwlcqzdoybfvgs"  # Extrait de l'URL Supabase

class SupabaseEdgeFunctionDeployer:
    def __init__(self):
        self.base_url = f"https://api.supabase.com/v1/projects/{PROJECT_REF}/functions"
        self.headers = {
            "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
            "Content-Type": "application/json"
        }
    
    def deploy_function(self, function_name: str, function_path: Path) -> bool:
        """Déploie une Edge Function via l'API Management"""
        print(f"=== Déploiement Edge Function: {function_name} ===")
        
        # Lire le code de la fonction
        if not function_path.exists():
            print(f"ERREUR: Fichier introuvable: {function_path}")
            return False
        
        with open(function_path, 'r', encoding='utf-8') as f:
            function_code = f.read()
        
        print(f"Code lu: {len(function_code)} caractères")
        
        # Créer ou mettre à jour la fonction
        url = f"{self.base_url}/{function_name}"
        
        # Préparer le payload
        payload = {
            "name": function_name,
            "verify_jwt": False  # Correspond à --no-verify-jwt
        }
        
        try:
            # Essayer de mettre à jour d'abord
            print("Tentative de mise à jour...")
            response = requests.patch(url, headers=self.headers, json=payload, timeout=30)
            
            if response.status_code == 404:
                # Fonction n'existe pas, la créer
                print("Fonction n'existe pas, création...")
                response = requests.post(self.base_url, headers=self.headers, json=payload, timeout=30)
            
            if response.status_code not in [200, 201]:
                print(f"ERREUR création/mise à jour: {response.status_code}")
                print(response.text)
                return False
            
            print("✓ Fonction créée/mise à jour")
            
            # Uploader le code
            print("Upload du code...")
            code_url = f"{url}/body"
            code_response = requests.put(code_url, headers=self.headers, data=function_code, timeout=30)
            
            if code_response.status_code != 200:
                print(f"ERREUR upload code: {code_response.status_code}")
                print(code_response.text)
                return False
            
            print("✓ Code uploadé")
            
            # Vérifier le déploiement
            print("Vérification du déploiement...")
            time.sleep(2)
            verify_response = requests.get(url, headers=self.headers, timeout=10)
            
            if verify_response.status_code == 200:
                print("✓ Déploiement vérifié avec succès")
                return True
            else:
                print(f"ERREUR vérification: {verify_response.status_code}")
                return False
                
        except Exception as e:
            print(f"ERREUR exception: {e}")
            return False

def main():
    print("=== Déploiement Edge Function Bobodo Voice ===")
    print()
    
    deployer = SupabaseEdgeFunctionDeployer()
    
    # Chemin vers l'Edge Function
    function_path = Path(__file__).parent.parent / "supabase" / "functions" / "bobodo-chat" / "index.ts"
    
    success = deployer.deploy_function("bobodo-chat", function_path)
    
    print()
    if success:
        print("=== DÉPLOIEMENT RÉUSSI ===")
        print("Edge Function bobodo-chat déployée avec succès")
        print("URL: https://thevdfcwlcqzdoybfvgs.supabase.co/functions/v1/bobodo-chat")
        return 0
    else:
        print("=== DÉPLOIEMENT ÉCHOUÉ ===")
        return 1

if __name__ == "__main__":
    exit(main())
