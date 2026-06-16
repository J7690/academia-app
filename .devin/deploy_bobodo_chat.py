#!/usr/bin/env python3
"""Déployer l'Edge Function bobodo-chat avec la règle d'escalade support"""

import subprocess
import sys

print("=" * 80)
print("DÉPLOIEMENT EDGE FUNCTION bobodo-chat (RÈGLE ESCALADE SUPPORT)")
print("=" * 80)

try:
    result = subprocess.run(
        ["supabase", "functions", "deploy", "bobodo-chat", "--no-verify-jwt"],
        cwd="c:\\Users\\fasop\\AndroidStudioProjects\\academia",
        capture_output=True,
        text=True,
        timeout=120
    )
    
    print(result.stdout)
    if result.stderr:
        print("STDERR:", result.stderr)
    
    if result.returncode == 0:
        print("\n✅ Edge Function déployée avec succès")
        print("   Règle d'escalade vers le support humain ajoutée")
    else:
        print(f"\n❌ Erreur (code {result.returncode})")
        sys.exit(1)
        
except subprocess.TimeoutExpired:
    print("❌ Timeout après 120 secondes")
    sys.exit(1)
except Exception as e:
    print(f"❌ Erreur: {e}")
    sys.exit(1)
