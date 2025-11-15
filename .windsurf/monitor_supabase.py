#!/usr/bin/env python3
"""
Script de monitoring automatique Supabase
Exécuté toutes les heures pour vérifier l'accès
"""

import sys
import os
sys.path.append(os.path.dirname(__file__))

from supabase_permanent_access import SupabasePermanentAccess

def main():
    access = SupabasePermanentAccess()
    
    # Vérifier l'accès
    health = access.verify_permanent_access()
    
    print(f"🔍 Health Check: {health['overall_status']}")
    print(f"✅ Méthodes fonctionnelles: {len(health['methods_working'])}")
    print(f"❌ Méthodes défaillantes: {len(health['methods_failing'])}")
    
    # Renouveler si nécessaire
    if health['overall_status'] == 'critical':
        print("🔄 Tentative de renouvellement automatique...")
        access.auto_renew_access()
    
    return 0

if __name__ == "__main__":
    exit(main())
