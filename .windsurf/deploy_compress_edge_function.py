#!/usr/bin/env python3
import subprocess
import os

print("=== DÉPLOIEMENT EDGE FUNCTION compress-video ===\n")

# Changer vers le répertoire academia_app
os.chdir('c:/Users/fasop/AndroidStudioProjects/academia')

# Déployer l'Edge Function
cmd = 'supabase functions deploy compress-video --no-verify-jwt'
print(f"Exécution: {cmd}")

result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
print("STDOUT:", result.stdout)
print("STDERR:", result.stderr)
print("Return code:", result.returncode)

if result.returncode == 0:
    print("\n✓ Edge Function compress-video déployée avec succès")
else:
    print("\n✗ Erreur lors du déploiement")
