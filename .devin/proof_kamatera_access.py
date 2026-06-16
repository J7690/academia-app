#!/usr/bin/env python3
"""
Preuves d'accès brutes — Kamatera API + VPS SSH.
Aucune modification, uniquement lecture.
"""
import paramiko
import requests
import json

# --- Kamatera API ---
KAMATERA_API = "https://console.kamatera.com/service"
KAMATERA_ACCESS_KEY = "a91330958142da0f32fdc6b9f7e16476"
KAMATERA_SECRET_KEY = "354e008099f0dbb3e667f550965d8e95"

# --- VPS SSH ---
SERVER_IP = "185.167.97.144"
SERVER_USER = "root"
SERVER_PASS = "Nexiomgroup@Academia0"

def section(title):
    print("\n" + "=" * 70)
    print(f" {title}")
    print("=" * 70)

def ssh_exec(client, cmd):
    print(f"\nroot@{SERVER_IP}:~# {cmd}")
    stdin, stdout, stderr = client.exec_command(cmd, timeout=30)
    stdout.channel.recv_exit_status()
    out = stdout.read().decode('utf-8', errors='replace')
    err = stderr.read().decode('utf-8', errors='replace')
    print(out, end='')
    if err.strip():
        print(err, end='')

def main():
    # ================================================================
    # 1. PREUVE D'ACCÈS AU COMPTE KAMATERA (API)
    # ================================================================
    section("1. PREUVE D'ACCÈS AU COMPTE KAMATERA — API")

    kamatera_headers = {
        "AuthClientId": KAMATERA_ACCESS_KEY,
        "AuthSecret": KAMATERA_SECRET_KEY,
        "Content-Type": "application/json",
        "Accept": "application/json",
    }

    # 1a. Liste des serveurs
    print("\n--- API CALL: GET /service/servers ---")
    print(f"URL: {KAMATERA_API}/servers")
    print(f"Headers: AuthClientId={KAMATERA_ACCESS_KEY}, AuthSecret={KAMATERA_SECRET_KEY[:8]}...")
    try:
        r = requests.get(f"{KAMATERA_API}/servers", headers=kamatera_headers, timeout=30)
        print(f"HTTP Status: {r.status_code}")
        print(f"Response Body:\n{json.dumps(r.json(), indent=2)}")
    except Exception as e:
        print(f"Error: {e}")
        # Try alternative endpoint
        print("\n--- Trying alternative endpoint: /service/server/info ---")
        try:
            r2 = requests.get(f"{KAMATERA_API}/server/info", headers=kamatera_headers, timeout=30)
            print(f"HTTP Status: {r2.status_code}")
            print(f"Response Body:\n{r2.text[:2000]}")
        except Exception as e2:
            print(f"Error: {e2}")

    # 1b. Détail du serveur spécifique
    server_id = "f6d2656b-0f80-4df1-ac62-53b26d6d921b"
    print(f"\n--- API CALL: GET /service/server/{server_id}/info ---")
    try:
        r = requests.get(f"{KAMATERA_API}/server/{server_id}/info", headers=kamatera_headers, timeout=30)
        print(f"HTTP Status: {r.status_code}")
        print(f"Response Body:\n{json.dumps(r.json(), indent=2) if r.headers.get('content-type','').startswith('application/json') else r.text[:2000]}")
    except Exception as e:
        print(f"Error: {e}")

    # 1c. Try queue endpoint for server list
    print(f"\n--- API CALL: POST /service/server/info (body with id) ---")
    try:
        r = requests.post(f"{KAMATERA_API}/server/info", headers=kamatera_headers, json={"id": server_id}, timeout=30)
        print(f"HTTP Status: {r.status_code}")
        print(f"Response Body:\n{r.text[:2000]}")
    except Exception as e:
        print(f"Error: {e}")

    # 1d. Try the /my/servers endpoint
    for endpoint in ["/servers", "/server", "/my/servers", f"/server/{server_id}"]:
        print(f"\n--- API CALL: GET {KAMATERA_API}{endpoint} ---")
        try:
            r = requests.get(f"{KAMATERA_API}{endpoint}", headers=kamatera_headers, timeout=15)
            print(f"HTTP Status: {r.status_code}")
            body = r.text[:2000]
            try:
                body = json.dumps(r.json(), indent=2)[:2000]
            except:
                pass
            print(f"Response:\n{body}")
            if r.status_code == 200:
                break
        except Exception as e:
            print(f"Error: {e}")

    # ================================================================
    # 2-5. PREUVES VPS VIA SSH
    # ================================================================
    section("2. PREUVE D'ACCÈS AU VPS — SSH")

    print(f"\nCommande de connexion: ssh root@{SERVER_IP}")
    print(f"Méthode d'authentification: mot de passe")

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        client.connect(SERVER_IP, username=SERVER_USER, password=SERVER_PASS, timeout=15)
        print(f"Résultat: CONNEXION ÉTABLIE")
    except Exception as e:
        print(f"ÉCHEC: {e}")
        return

    # 2. Commandes système
    ssh_commands_2 = ["hostname", "whoami", "pwd", "uname -a", "free -h", "df -h"]
    for cmd in ssh_commands_2:
        ssh_exec(client, cmd)

    # 3. Présence des services
    section("3. PREUVE DE PRÉSENCE DES SERVICES")
    ssh_exec(client, "docker ps")
    ssh_exec(client, "systemctl status nginx --no-pager")
    ssh_exec(client, "systemctl status redis-server --no-pager")

    # 4. Fichiers installés
    section("4. PREUVE DES FICHIERS INSTALLÉS")
    ssh_exec(client, "ls -la /opt/livekit")
    ssh_exec(client, "cat /opt/livekit/docker-compose.yaml")

    # 5. Vérification réseau
    section("5. VÉRIFICATION RÉSEAU")
    ssh_exec(client, "curl http://185.167.97.144:7880")
    ssh_exec(client, "ss -tulpn | grep 7880")

    client.close()
    print("\n" + "=" * 70)
    print(" FIN DES PREUVES")
    print("=" * 70)

if __name__ == "__main__":
    main()
