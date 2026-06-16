#!/usr/bin/env python3
"""
Met à jour les secrets Supabase (LIVEKIT_API_KEY, LIVEKIT_API_SECRET, LIVEKIT_URL)
pour pointer vers le nouveau serveur Kamatera 185.167.97.144.
Utilise la Supabase Management API.
"""
import requests
import json

# Supabase project
PROJECT_REF = "thevdfcwlcqzdoybfvgs"
# Supabase Management API requires a service_role or personal access token
# Using the Management API endpoint for secrets
SUPABASE_URL = f"https://{PROJECT_REF}.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

# New LiveKit credentials
NEW_LIVEKIT_API_KEY = "APIKeylrmgQYJgiEZa"
NEW_LIVEKIT_API_SECRET = "uXu7tiObNgaLkYA3VydinjsKRzPJjL8SNWC9pRx8"
NEW_LIVEKIT_URL = "ws://185.167.97.144:7880"

def main():
    print("=" * 60)
    print(" MISE À JOUR SECRETS SUPABASE - LIVEKIT")
    print("=" * 60)
    
    # Method 1: Try via Supabase Management API (requires access token)
    # The Management API is at https://api.supabase.com
    # But we may not have a personal access token.
    
    # Method 2: Use a DDL RPC to create a wrapper function that the Edge Function reads
    # Actually, Supabase Edge Functions read secrets from Deno.env which are set via
    # the Supabase dashboard or CLI. We can't set them via SQL.
    
    # Method 3: Use the vault (Supabase Vault) to store secrets accessible from Edge Functions
    # Actually that won't work either - Edge Functions use Deno.env.get() not vault.
    
    # The correct approach: Supabase secrets are set via:
    # - Dashboard: Project Settings > Edge Functions > Secrets
    # - CLI: supabase secrets set KEY=VALUE
    # - Management API: POST /v1/projects/{ref}/secrets
    
    # Let's try the Management API approach
    # We need a Supabase access token (not service_role_key)
    # Alternative: we can use the service_role_key with a special RPC
    
    # Actually, let's check if we can use the Supabase CLI approach by running it
    # Or better: use the Management API with the service_role_key as Bearer
    
    mgmt_url = f"https://api.supabase.com/v1/projects/{PROJECT_REF}/secrets"
    
    # Try with service_role_key (might not work for mgmt API)
    headers = {
        "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
        "Content-Type": "application/json",
    }
    
    secrets_payload = [
        {"name": "LIVEKIT_API_KEY", "value": NEW_LIVEKIT_API_KEY},
        {"name": "LIVEKIT_API_SECRET", "value": NEW_LIVEKIT_API_SECRET},
        {"name": "LIVEKIT_URL", "value": NEW_LIVEKIT_URL},
    ]
    
    print(f"\nTentative via Management API: {mgmt_url}")
    try:
        r = requests.post(mgmt_url, headers=headers, json=secrets_payload, timeout=30)
        print(f"Status: {r.status_code}")
        if r.status_code in (200, 201):
            print("✓ Secrets mis à jour via Management API!")
            return True
        else:
            print(f"Réponse: {r.text[:200]}")
            print("Management API nécessite un Personal Access Token.")
    except Exception as e:
        print(f"Erreur: {e}")
    
    # If Management API fails, provide instructions
    print("\n" + "=" * 60)
    print(" INSTRUCTIONS MANUELLES")
    print("=" * 60)
    print(f"""
Les secrets Supabase doivent être mis à jour via le Dashboard ou CLI:

Option 1 - Dashboard Supabase:
  1. Aller sur https://supabase.com/dashboard/project/{PROJECT_REF}/settings/functions
  2. Section "Edge Function Secrets"
  3. Mettre à jour:
     LIVEKIT_API_KEY    = {NEW_LIVEKIT_API_KEY}
     LIVEKIT_API_SECRET = {NEW_LIVEKIT_API_SECRET}
     LIVEKIT_URL        = {NEW_LIVEKIT_URL}

Option 2 - Supabase CLI:
  supabase secrets set LIVEKIT_API_KEY={NEW_LIVEKIT_API_KEY} --project-ref {PROJECT_REF}
  supabase secrets set LIVEKIT_API_SECRET={NEW_LIVEKIT_API_SECRET} --project-ref {PROJECT_REF}
  supabase secrets set LIVEKIT_URL={NEW_LIVEKIT_URL} --project-ref {PROJECT_REF}
""")
    
    # Try alternative: check if supabase CLI is available
    import subprocess
    try:
        result = subprocess.run(["supabase", "--version"], capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            print(f"Supabase CLI trouvé: {result.stdout.strip()}")
            print("Tentative via CLI...")
            
            cmds = [
                f'supabase secrets set LIVEKIT_API_KEY={NEW_LIVEKIT_API_KEY} --project-ref {PROJECT_REF}',
                f'supabase secrets set LIVEKIT_API_SECRET={NEW_LIVEKIT_API_SECRET} --project-ref {PROJECT_REF}',
                f'supabase secrets set LIVEKIT_URL={NEW_LIVEKIT_URL} --project-ref {PROJECT_REF}',
            ]
            for cmd in cmds:
                print(f"$ {cmd}")
                r = subprocess.run(cmd.split(), capture_output=True, text=True, timeout=30)
                if r.returncode == 0:
                    print(f"  ✓ OK")
                else:
                    print(f"  ✗ {r.stderr.strip()[:100]}")
        else:
            print("Supabase CLI non disponible.")
    except FileNotFoundError:
        print("Supabase CLI non installé.")
    except Exception as e:
        print(f"Erreur CLI: {e}")
    
    return False

if __name__ == "__main__":
    main()
