#!/usr/bin/env python3
"""Déployer l'Edge Function test-bobodo-secrets"""

import subprocess
import sys

print("=" * 80)
print("DÉPLOIEMENT EDGE FUNCTION test-bobodo-secrets")
print("=" * 80)

try:
    result = subprocess.run(
        ["supabase", "functions", "deploy", "test-bobodo-secrets", "--no-verify-jwt"],
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
    else:
        print(f"\n❌ Erreur (code {result.returncode})")
        sys.exit(1)
        
except subprocess.TimeoutExpired:
    print("❌ Timeout après 120 secondes")
    sys.exit(1)
except Exception as e:
    print(f"❌ Erreur: {e}")
    sys.exit(1)
