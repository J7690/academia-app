#!/usr/bin/env python3
"""
Script de déploiement Edge Function Bobodo Voice via RPC admin_execute_sql
Utilise le service_role_key existant dans le projet
"""

import requests
import json
from pathlib import Path

# Credentials Supabase (du supabase_auto_manager.py)
SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

def deploy_via_admin_rpc():
    """Tente de déployer via RPC admin_execute_sql"""
    print("=== Déploiement Edge Function via admin_execute_sql ===")
    
    headers = {
        "apikey": SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
        "Content-Type": "application/json"
    }
    
    # Lire le code de la fonction
    function_path = Path(__file__).parent.parent / "supabase" / "functions" / "bobodo-chat" / "index.ts"
    
    if not function_path.exists():
        print(f"ERREUR: Fichier introuvable: {function_path}")
        return False
    
    with open(function_path, 'r', encoding='utf-8') as f:
        function_code = f.read()
    
    print(f"Code lu: {len(function_code)} caractères")
    
    # Note: admin_execute_sql ne peut pas déployer des Edge Functions
    # Les Edge Functions doivent être déployées via Supabase CLI ou Management API
    print("INFO: admin_execute_sql ne peut pas déployer des Edge Functions")
    print("INFO: Les Edge Functions nécessitent Supabase CLI ou Management API")
    
    return False

def check_supabase_cli():
    """Vérifie si Supabase CLI est disponible"""
    import subprocess
    
    try:
        result = subprocess.run(["supabase", "--version"], capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            print(f"Supabase CLI trouvé: {result.stdout.strip()}")
            return True
    except Exception as e:
        print(f"Supabase CLI non trouvé: {e}")
    
    return False

def deploy_via_cli():
    """Déploie via Supabase CLI"""
    import subprocess
    
    print("=== Déploiement via Supabase CLI ===")
    
    try:
        result = subprocess.run(
            ["supabase", "functions", "deploy", "bobodo-chat", "--no-verify-jwt"],
            cwd=Path(__file__).parent.parent,
            capture_output=True,
            text=True,
            timeout=120
        )
        
        print("STDOUT:", result.stdout)
        print("STDERR:", result.stderr)
        
        if result.returncode == 0:
            print("✓ Déploiement réussi via Supabase CLI")
            return True
        else:
            print(f"✗ Déploiement échoué: code {result.returncode}")
            return False
            
    except Exception as e:
        print(f"✗ Exception: {e}")
        return False

def main():
    print("=== Déploiement Edge Function Bobodo Voice ===")
    print()
    
    # Essayer Supabase CLI d'abord
    if check_supabase_cli():
        if deploy_via_cli():
            return 0
    
    # Fallback: RPC (ne fonctionnera pas pour Edge Functions)
    print()
    print("INFO: Supabase CLI non disponible, tentative via RPC...")
    if deploy_via_admin_rpc():
        return 0
    
    print()
    print("=== DÉPLOIEMENT ÉCHOUÉ ===")
    print("ERREUR: Supabase CLI requis pour déployer des Edge Functions")
    print("SOLUTION: Installer Supabase CLI via npm install -g supabase")
    return 1

if __name__ == "__main__":
    exit(main())
