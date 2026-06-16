#!/usr/bin/env python3
"""
Injecter les secrets de production dans bobodo-vocal sur le serveur
Lit les secrets depuis academia_bobodo_backend/.env et les injecte sur le serveur
"""

import paramiko
from pathlib import Path

# Identifiants serveur
SERVER_IP = "185.167.97.144"
SERVER_USER = "root"
SERVER_PASS = "Nexiomgroup@Academia0"

# Chemins
REMOTE_DIR = "/opt/bobodo-vocal"
LOCAL_ENV = Path("academia_bobodo_backend/.env")

def inject_secrets():
    """Injecter les secrets de production sur le serveur"""
    print("=== INJECTION SECRETS PRODUCTION ===")
    
    # Lire les secrets depuis le fichier .env local
    print("[1] Lecture secrets locaux...")
    if not LOCAL_ENV.exists():
        print(f"  ❌ Fichier non trouvé: {LOCAL_ENV}")
        return
    
    content = LOCAL_ENV.read_text(encoding="utf-8")
    
    secrets = {}
    for line in content.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        secrets[key] = value
    
    # Vérifier les secrets requis
    required_keys = ["SUPABASE_SERVICE_KEY", "OPENROUTER_API_KEY"]
    for key in required_keys:
        if key not in secrets:
            print(f"  ❌ Secret manquant: {key}")
            return
        else:
            print(f"  ✅ {key}: {secrets[key][:20]}...{secrets[key][-10:]}")
    
    # Créer le fichier .env pour bobodo-vocal
    print("\n[2] Création fichier .env sur serveur...")
    
    supabase_url = "https://thevdfcwlcqzdoybfvgs.supabase.co"
    
    env_content = f"""# Supabase
SUPABASE_URL={supabase_url}
SUPABASE_SERVICE_ROLE_KEY={secrets['SUPABASE_SERVICE_KEY']}

# OpenRouter
OPENROUTER_API_KEY={secrets['OPENROUTER_API_KEY']}
OPENROUTER_MODEL=google/gemini-2.5-flash
OPENROUTER_EMBEDDING_MODEL=openai/text-embedding-3-small

# Whisper
WHISPER_MODEL=medium
WHISPER_DEVICE=cpu
WHISPER_QUANTIZATION=int8

# Piper
PIPER_MODEL=medium
PIPER_VOICE=fr_FR-medium

# WebSocket
WEBSOCKET_HOST=0.0.0.0
WEBSOCKET_PORT=8000

# Logging
LOG_LEVEL=INFO
"""
    
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        client.connect(
            hostname=SERVER_IP,
            username=SERVER_USER,
            password=SERVER_PASS,
            timeout=10
        )
        
        stdin, stdout, stderr = client.exec_command(
            f"echo '{env_content}' > {REMOTE_DIR}/.env",
            get_pty=True
        )
        
        print("  ✅ Fichier .env créé avec secrets de production")
        
        # Redémarrer le service
        print("\n[3] Redémarrage service...")
        stdin, stdout, stderr = client.exec_command(
            "systemctl restart bobodo-vocal",
            get_pty=True
        )
        
        print("  ✅ Service redémarré")
        
        # Vérifier le statut
        print("\n[4] Vérification statut...")
        stdin, stdout, stderr = client.exec_command("systemctl status bobodo-vocal")
        output = stdout.read().decode('utf-8')
        print(output[:500])
        
        client.close()
        
        print("\n=== INJECTION TERMINÉE ===")
        print("✅ Secrets de production injectés dans bobodo-vocal")
        
    except Exception as e:
        print(f"❌ Erreur: {e}")
        client.close()


if __name__ == "__main__":
    inject_secrets()
