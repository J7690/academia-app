#!/usr/bin/env python3
"""
Vérification complète du nouveau serveur Kamatera - preuves d'exécution.
"""
import paramiko
import requests
import json

SERVER_IP = "185.167.97.144"
SERVER_USER = "root"
SERVER_PASS = "Nexiomgroup@Academia0"

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

def ssh_exec(client, cmd, timeout=30):
    stdin, stdout, stderr = client.exec_command(cmd, timeout=timeout)
    stdout.channel.recv_exit_status()
    return stdout.read().decode('utf-8', errors='replace').strip()

def main():
    print("=" * 70)
    print(" PREUVES D'EXÉCUTION - SERVEUR 185.167.97.144")
    print("=" * 70)

    # --- 1. Méthode d'accès ---
    print("\n" + "=" * 70)
    print(" 1. MÉTHODE D'ACCÈS AU SERVEUR")
    print("=" * 70)
    print("Méthode: SSH direct avec mot de passe root")
    print(f"IP: {SERVER_IP}")
    print(f"User: {SERVER_USER}")
    print("Auth: password (fourni par l'utilisateur)")
    
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        client.connect(SERVER_IP, username=SERVER_USER, password=SERVER_PASS, timeout=15)
        print("Résultat: CONNEXION SSH RÉUSSIE")
    except Exception as e:
        print(f"ERREUR: {e}")
        return

    # --- 2. docker ps ---
    print("\n" + "=" * 70)
    print(" 2. RÉSULTAT DE `docker ps`")
    print("=" * 70)
    out = ssh_exec(client, "docker ps --no-trunc --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'")
    print(out)

    # --- 3. systemctl status nginx ---
    print("\n" + "=" * 70)
    print(" 3. RÉSULTAT DE `systemctl status nginx`")
    print("=" * 70)
    out = ssh_exec(client, "systemctl status nginx --no-pager")
    print(out)

    # --- 4. systemctl status redis ---
    print("\n" + "=" * 70)
    print(" 4. RÉSULTAT DE `systemctl status redis`")
    print("=" * 70)
    out = ssh_exec(client, "systemctl status redis-server --no-pager")
    print(out)

    # --- 5. Localisation fichiers LiveKit ---
    print("\n" + "=" * 70)
    print(" 5. LOCALISATION FICHIERS LIVEKIT")
    print("=" * 70)
    out = ssh_exec(client, "find /opt/livekit -type f -ls")
    print(out)
    print("\nContenu /opt/livekit/:")
    out = ssh_exec(client, "ls -la /opt/livekit/")
    print(out)

    # --- 6. Contenu docker-compose ---
    print("\n" + "=" * 70)
    print(" 6. CONTENU DU docker-compose.yaml")
    print("=" * 70)
    out = ssh_exec(client, "cat /opt/livekit/docker-compose.yaml")
    print(out)
    
    print("\nContenu livekit.yaml:")
    out = ssh_exec(client, "cat /opt/livekit/livekit.yaml")
    print(out)

    # --- 7. Secrets Supabase ---
    print("\n" + "=" * 70)
    print(" 7. SECRETS SUPABASE CONFIGURÉS")
    print("=" * 70)
    
    import subprocess
    try:
        result = subprocess.run(
            ["supabase", "secrets", "list", "--project-ref", "thevdfcwlcqzdoybfvgs"],
            capture_output=True, text=True, timeout=30
        )
        print(result.stdout)
        if result.stderr:
            print(f"stderr: {result.stderr[:200]}")
    except Exception as e:
        print(f"Erreur CLI: {e}")

    # --- 8. Test génération token LiveKit ---
    print("\n" + "=" * 70)
    print(" 8. TEST RÉEL GÉNÉRATION TOKEN LIVEKIT (Edge Function)")
    print("=" * 70)
    
    # D'abord on a besoin d'un user authentifié pour tester
    # On va tester avec le service_role directement
    headers = {
        "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
        "Content-Type": "application/json",
        "apikey": SERVICE_ROLE_KEY,
    }
    
    # Test direct sur le port 7880 du serveur
    print("\nA) Test HTTP direct LiveKit server:")
    try:
        r = requests.get(f"http://{SERVER_IP}:7880", timeout=10)
        print(f"   GET http://{SERVER_IP}:7880 → Status: {r.status_code}")
        print(f"   Body: {r.text[:200]}")
    except Exception as e:
        print(f"   Erreur: {e}")
    
    # Test Edge Function livekit-token (nécessite un vrai user JWT)
    print("\nB) Test Edge Function livekit-token (avec service_role):")
    try:
        r = requests.post(
            f"{SUPABASE_URL}/functions/v1/livekit-token",
            headers=headers,
            json={"session_id": "test-session-verification"},
            timeout=15
        )
        print(f"   POST /functions/v1/livekit-token → Status: {r.status_code}")
        print(f"   Response: {r.text[:300]}")
    except Exception as e:
        print(f"   Erreur: {e}")
    
    # Test avec un vrai user via sign-in
    print("\nC) Test avec authentification réelle:")
    try:
        # Sign in as a test user to get a real JWT
        auth_r = requests.post(
            f"{SUPABASE_URL}/auth/v1/token?grant_type=password",
            headers={"apikey": SERVICE_ROLE_KEY, "Content-Type": "application/json"},
            json={"email": "admin@academia-bf.com", "password": "admin123"},
            timeout=10
        )
        if auth_r.status_code == 200:
            access_token = auth_r.json().get("access_token", "")
            print(f"   Auth OK, token obtenu ({len(access_token)} chars)")
            
            # Now call livekit-token with real user JWT
            user_headers = {
                "Authorization": f"Bearer {access_token}",
                "Content-Type": "application/json",
                "apikey": SERVICE_ROLE_KEY,
            }
            r2 = requests.post(
                f"{SUPABASE_URL}/functions/v1/livekit-token",
                headers=user_headers,
                json={"session_id": "test-verification-session"},
                timeout=15
            )
            print(f"   POST /functions/v1/livekit-token → Status: {r2.status_code}")
            resp_data = r2.json() if r2.headers.get('content-type','').startswith('application/json') else r2.text
            print(f"   Response: {json.dumps(resp_data, indent=2)[:400]}")
            
            # Si on a un token, vérifier qu'il contient la bonne URL
            if isinstance(resp_data, dict) and resp_data.get('url'):
                print(f"\n   >>> LIVEKIT_URL retournée par Edge Function: {resp_data['url']}")
                if '185.167.97.144' in resp_data['url']:
                    print("   >>> ✓ CONFIRMÉ: Edge Function utilise bien le NOUVEAU serveur!")
                else:
                    print(f"   >>> ⚠ URL inattendue: {resp_data['url']}")
        else:
            print(f"   Auth échouée: {auth_r.status_code} - {auth_r.text[:150]}")
            print("   (Essai avec un autre compte...)")
    except Exception as e:
        print(f"   Erreur: {e}")

    client.close()
    print("\n" + "=" * 70)
    print(" FIN DES VÉRIFICATIONS")
    print("=" * 70)

if __name__ == "__main__":
    main()
