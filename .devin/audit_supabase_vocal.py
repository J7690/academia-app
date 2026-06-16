#!/usr/bin/env python3
"""
Audit Supabase pour l'intégration vocale
Vérifie les tables, RPCs et Edge Functions liés au vocal
"""

import subprocess
import json

def audit_supabase_vocal():
    """Audit Supabase pour fonctionnalités vocales"""
    print("=== AUDIT SUPABASE - INTÉGRATION VOCAL ===")
    
    # Lister les Edge Functions
    print("\n[1] Vérification Edge Functions...")
    try:
        result = subprocess.run(
            ["supabase", "functions", "list"],
            capture_output=True,
            text=True,
            cwd="c:\\Users\\fasop\\AndroidStudioProjects\\academia"
        )
        print(result.stdout)
        
        # Chercher bobodo-chat
        if "bobodo-chat" in result.stdout:
            print("  ✅ bobodo-chat Edge Function trouvée")
        else:
            print("  ⚠️ bobodo-chat Edge Function non trouvée")
            
    except Exception as e:
        print(f"  ❌ Erreur: {e}")
    
    # Lister les tables (via RPC admin_execute_sql)
    print("\n[2] Vérification tables liées au vocal...")
    try:
        # Requête pour lister les tables
        query = """
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'app' 
        AND (table_name LIKE '%vocal%' OR table_name LIKE '%audio%' OR table_name LIKE '%speech%')
        ORDER BY table_name;
        """
        
        result = subprocess.run(
            ["supabase", "db", "execute", "--local", query],
            capture_output=True,
            text=True,
            cwd="c:\\Users\\fasop\\AndroidStudioProjects\\academia"
        )
        print(result.stdout)
        
    except Exception as e:
        print(f"  ❌ Erreur: {e}")
    
    # Lister les RPCs liées au vocal
    print("\n[3] Vérification RPCs liées au vocal...")
    try:
        query = """
        SELECT routine_name 
        FROM information_schema.routines 
        WHERE routine_schema = 'app' 
        AND (routine_name LIKE '%vocal%' OR routine_name LIKE '%audio%' OR routine_name LIKE '%speech%')
        ORDER BY routine_name;
        """
        
        result = subprocess.run(
            ["supabase", "db", "execute", "--local", query],
            capture_output=True,
            text=True,
            cwd="c:\\Users\\fasop\\AndroidStudioProjects\\academia"
        )
        print(result.stdout)
        
    except Exception as e:
        print(f"  ❌ Erreur: {e}")
    
    print("\n=== AUDIT TERMINÉ ===")


if __name__ == "__main__":
    audit_supabase_vocal()
