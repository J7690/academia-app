#!/usr/bin/env python3
"""
Audit réel de Supabase - Récupération des secrets, Edge Functions, configuration
Basé exclusivement sur les données réelles de Supabase
"""

import os
import sys
import json
from pathlib import Path

# Configuration Supabase (à adapter selon votre configuration)
# Note: Ces valeurs doivent être récupérées depuis les sources de production
SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SUPABASE_ANON_KEY = os.environ.get("SUPABASE_ANON_KEY", "")
SUPABASE_SERVICE_ROLE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")

def audit_supabase():
    """Audit de Supabase"""
    print("=== AUDIT SUPABASE RÉEL ===")
    
    # Vérifier les variables d'environnement
    print("\n[1] Variables d'environnement Supabase:")
    print(f"  SUPABASE_URL: {'✅ Configuré' if SUPABASE_URL else '❌ Non configuré'}")
    print(f"  SUPABASE_ANON_KEY: {'✅ Configuré' if SUPABASE_ANON_KEY else '❌ Non configuré'}")
    print(f"  SUPABASE_SERVICE_ROLE_KEY: {'✅ Configuré' if SUPABASE_SERVICE_ROLE_KEY else '❌ Non configuré'}")
    
    if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
        print("\n❌ Variables d'environnement manquantes")
        print("Veuillez configurer SUPABASE_URL et SUPABASE_SERVICE_ROLE_KEY")
        return
    
    # Tenter de lister les Edge Functions via Supabase CLI
    print("\n[2] Edge Functions déployées:")
    try:
        import subprocess
        result = subprocess.run(
            ["supabase", "functions", "list"],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode == 0:
            print(result.stdout)
        else:
            print(f"⚠️ Impossible de lister les Edge Functions: {result.stderr}")
    except Exception as e:
        print(f"⚠️ Erreur: {e}")
    
    # Tenter de lister les secrets Supabase
    print("\n[3] Secrets Supabase:")
    try:
        result = subprocess.run(
            ["supabase", "secrets", "list"],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode == 0:
            print(result.stdout)
        else:
            print(f"⚠️ Impossible de lister les secrets: {result.stderr}")
    except Exception as e:
        print(f"⚠️ Erreur: {e}")
    
    # Vérifier les fichiers de configuration locaux
    print("\n[4] Fichiers de configuration locaux:")
    config_files = [
        "academia_app/lib/config/supabase_config.dart",
        ".env",
        ".env.local",
        ".env.example"
    ]
    
    for file in config_files:
        path = Path(file)
        if path.exists():
            print(f"  ✅ {file}")
        else:
            print(f"  ❌ {file}")
    
    print("\n=== AUDIT TERMINÉ ===")


if __name__ == "__main__":
    audit_supabase()
