#!/usr/bin/env python3
"""
Script de deploiement LiveKit Server sur Google Cloud Compute Engine.

Pre-requis:
  - gcloud CLI installe et authentifie
  - Service account key: academia_app/secrets/google-cloud-key.json
  - Projet GCP: cool-reality-460913-i8

Ce script:
  1. Active le service account
  2. Cree une VM e2-standard-2 avec Docker
  3. Installe et configure LiveKit Server
  4. Configure le firewall pour les ports LiveKit
  5. Affiche les informations de connexion

Utilisation:
  python deploy_livekit_gcloud.py
"""

import subprocess
import sys
import json
import secrets
import string
from pathlib import Path

# Configuration
PROJECT_ID = "cool-reality-460913-i8"
ZONE = "europe-west1-b"
INSTANCE_NAME = "academia-livekit"
MACHINE_TYPE = "e2-standard-2"  # 2 vCPU, 8 GB RAM (~$50/mois)
SERVICE_ACCOUNT_KEY = str(Path(__file__).parent.parent / "academia_app" / "secrets" / "google-cloud-key.json")

def generate_secret(length=32):
    alphabet = string.ascii_letters + string.digits
    return ''.join(secrets.choice(alphabet) for _ in range(length))

# Generer les cles LiveKit
LIVEKIT_API_KEY = "API" + generate_secret(12)
LIVEKIT_API_SECRET = generate_secret(40)

def run_cmd(cmd, check=True):
    print(f"\n$ {cmd}")
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if result.stdout:
        print(result.stdout[:500])
    if result.stderr:
        print(f"STDERR: {result.stderr[:500]}")
    if check and result.returncode != 0:
        print(f"ERREUR: code retour {result.returncode}")
        return False
    return True

def main():
    print("=" * 60)
    print("DEPLOIEMENT LIVEKIT SERVER SUR GOOGLE CLOUD")
    print("=" * 60)
    print(f"Projet: {PROJECT_ID}")
    print(f"Zone: {ZONE}")
    print(f"VM: {INSTANCE_NAME} ({MACHINE_TYPE})")
    print(f"LiveKit API Key: {LIVEKIT_API_KEY}")
    print(f"LiveKit API Secret: {LIVEKIT_API_SECRET[:8]}...")
    print()

    # 1. Authentifier avec le service account
    print("\n--- Etape 1: Authentification ---")
    run_cmd(f'gcloud auth activate-service-account --key-file="{SERVICE_ACCOUNT_KEY}" --project={PROJECT_ID}')

    # 2. Configurer le projet
    print("\n--- Etape 2: Configuration projet ---")
    run_cmd(f"gcloud config set project {PROJECT_ID}")

    # 3. Creer les regles firewall pour LiveKit
    print("\n--- Etape 3: Firewall ---")
    # HTTP API
    run_cmd(f"gcloud compute firewall-rules create livekit-http "
            f"--allow=tcp:7880 --target-tags=livekit --project={PROJECT_ID}", check=False)
    # WebRTC/ICE UDP
    run_cmd(f"gcloud compute firewall-rules create livekit-rtc "
            f"--allow=udp:50000-60000 --target-tags=livekit --project={PROJECT_ID}", check=False)
    # WebRTC/ICE TCP fallback
    run_cmd(f"gcloud compute firewall-rules create livekit-rtc-tcp "
            f"--allow=tcp:7881 --target-tags=livekit --project={PROJECT_ID}", check=False)
    # TURN/TLS
    run_cmd(f"gcloud compute firewall-rules create livekit-turn "
            f"--allow=udp:443,tcp:443 --target-tags=livekit --project={PROJECT_ID}", check=False)

    # 4. Script de startup pour la VM
    startup_script = f"""#!/bin/bash
set -e

# Installer Docker
apt-get update
apt-get install -y docker.io docker-compose-plugin
systemctl enable docker
systemctl start docker

# Creer le repertoire de configuration LiveKit
mkdir -p /opt/livekit
cat > /opt/livekit/livekit.yaml << 'LKEOF'
port: 7880
rtc:
  port_range_start: 50000
  port_range_end: 60000
  tcp_port: 7881
  use_external_ip: true
keys:
  {LIVEKIT_API_KEY}: {LIVEKIT_API_SECRET}
logging:
  level: info
room:
  auto_create: true
  empty_timeout: 300
  max_participants: 50
turn:
  enabled: true
  domain: ""
  tls_port: 443
  udp_port: 443
  external_tls: false
LKEOF

# Lancer LiveKit Server via Docker
docker pull livekit/livekit-server:latest

docker run -d \\
  --name livekit \\
  --restart unless-stopped \\
  --network host \\
  -v /opt/livekit/livekit.yaml:/etc/livekit.yaml \\
  livekit/livekit-server:latest \\
  --config /etc/livekit.yaml \\
  --node-ip $(curl -s http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip -H "Metadata-Flavor: Google")

echo "LiveKit Server deploye avec succes!" > /opt/livekit/deploy.log
"""

    # Sauvegarder le script de startup
    startup_path = Path(__file__).parent / "livekit_startup.sh"
    startup_path.write_text(startup_script)
    print(f"Script startup sauvegarde: {startup_path}")

    # 5. Creer la VM
    print("\n--- Etape 5: Creation VM ---")
    ok = run_cmd(
        f'gcloud compute instances create {INSTANCE_NAME} '
        f'--zone={ZONE} '
        f'--machine-type={MACHINE_TYPE} '
        f'--image-family=ubuntu-2204-lts '
        f'--image-project=ubuntu-os-cloud '
        f'--boot-disk-size=30GB '
        f'--tags=livekit,http-server,https-server '
        f'--metadata-from-file=startup-script={startup_path} '
        f'--project={PROJECT_ID}'
    )

    if not ok:
        print("\nERREUR: Impossible de creer la VM.")
        print("Verifiez que le service account a les droits Compute Engine.")
        return

    # 6. Obtenir l'IP externe
    print("\n--- Etape 6: IP externe ---")
    result = subprocess.run(
        f'gcloud compute instances describe {INSTANCE_NAME} --zone={ZONE} --project={PROJECT_ID} --format="json"',
        shell=True, capture_output=True, text=True
    )
    
    external_ip = "UNKNOWN"
    if result.returncode == 0:
        try:
            data = json.loads(result.stdout)
            for iface in data.get("networkInterfaces", []):
                for access in iface.get("accessConfigs", []):
                    if access.get("natIP"):
                        external_ip = access["natIP"]
        except:
            pass

    # 7. Afficher les informations
    print("\n" + "=" * 60)
    print("DEPLOIEMENT TERMINE")
    print("=" * 60)
    print(f"""
VM: {INSTANCE_NAME}
Zone: {ZONE}
IP externe: {external_ip}

LiveKit Server:
  HTTP API: http://{external_ip}:7880
  WebSocket: ws://{external_ip}:7880
  RTC (UDP): {external_ip}:50000-60000
  RTC (TCP): {external_ip}:7881

Credentials LiveKit:
  API Key:    {LIVEKIT_API_KEY}
  API Secret: {LIVEKIT_API_SECRET}

Secrets Supabase a configurer:
  supabase secrets set LIVEKIT_API_KEY={LIVEKIT_API_KEY}
  supabase secrets set LIVEKIT_API_SECRET={LIVEKIT_API_SECRET}
  supabase secrets set LIVEKIT_URL=ws://{external_ip}:7880

Pour deployer l'Edge Function:
  supabase functions deploy livekit-token --no-verify-jwt

Pour verifier que LiveKit fonctionne:
  curl http://{external_ip}:7880

Pour SSH dans la VM:
  gcloud compute ssh {INSTANCE_NAME} --zone={ZONE} --project={PROJECT_ID}

Pour voir les logs:
  gcloud compute ssh {INSTANCE_NAME} --zone={ZONE} --project={PROJECT_ID} -- docker logs livekit
""")

    # Sauvegarder les credentials dans un fichier
    creds_path = Path(__file__).parent / "livekit_credentials.json"
    creds = {
        "instance_name": INSTANCE_NAME,
        "zone": ZONE,
        "project_id": PROJECT_ID,
        "external_ip": external_ip,
        "livekit_api_key": LIVEKIT_API_KEY,
        "livekit_api_secret": LIVEKIT_API_SECRET,
        "livekit_url": f"ws://{external_ip}:7880",
        "livekit_http": f"http://{external_ip}:7880",
    }
    creds_path.write_text(json.dumps(creds, indent=2))
    print(f"Credentials sauvegardees: {creds_path}")

if __name__ == "__main__":
    main()
