#!/usr/bin/env python3
"""
Configuration des secrets Bobodo Vocal sur le serveur
Récupère les secrets depuis Supabase et les configure dans .env
"""

import paramiko
import subprocess
from pathlib import Path

# Identifiants serveur
SERVER_IP = "185.167.97.144"
SERVER_USER = "root"
SERVER_PASS = "Nexiomgroup@Academia0"

# Chemins
REMOTE_DIR = "/opt/bobodo-vocal"

def get_supabase_anon_key():
    """Récupérer la clé ANON depuis le fichier config Flutter"""
    config_path = Path("academia_app/lib/config/supabase_config.dart")
    if config_path.exists():
        content = config_path.read_text()
        # Extraire la clé ANON
        for line in content.split('\n'):
            if 'anonKey' in line and '=' in line:
                key = line.split('=')[1].strip().rstrip(';').strip("'\"")
                return key
    return None

def configure_secrets():
    """Configurer les secrets sur le serveur"""
    print("=== CONFIGURATION SECRETS BOBODO VOCAL ===")
    
    # Récupérer la clé ANON depuis Flutter
    print("[1] Récupération clé ANON Supabase...")
    anon_key = get_supabase_anon_key()
    if anon_key:
        print(f"  ✅ Clé ANON récupérée: {anon_key[:20]}...")
    else:
        print("  ❌ Clé ANON non trouvée")
        return
    
    # Pour le service role key et OpenRouter, l'utilisateur doit les fournir
    # car ils ne sont pas accessibles via CLI
    print("\n[2] Configuration secrets...")
    print("  ⚠️ SUPABASE_SERVICE_ROLE_KEY et OPENROUTER_API_KEY doivent être fournis manuellement")
    print("  ⚠️ Ces secrets ne sont pas accessibles via Supabase CLI")
    
    # Créer le fichier .env avec les valeurs disponibles
    supabase_url = "https://thevdfcwlcqzdoybfvgs.supabase.co"
    
    env_content = f"""# Supabase
SUPABASE_URL={supabase_url}
SUPABASE_ANON_KEY={anon_key}
SUPABASE_SERVICE_ROLE_KEY=SERVICE_ROLE_KEY_PLACEHOLDER

# OpenRouter
OPENROUTER_API_KEY=OPENROUTER_API_KEY_PLACEHOLDER

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
        
        print("  ✅ Fichier .env créé avec clé ANON")
        
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
        
        print("\n=== CONFIGURATION TERMINÉE ===")
        print("\n⚠️ ACTIONS MANUELLES REQUISES :")
        print("  1. Éditer /opt/bobodo-vocal/.env sur le serveur")
        print("  2. Remplacer SERVICE_ROLE_KEY_PLACEHOLDER par la vraie clé")
        print("  3. Remplacer OPENROUTER_API_KEY_PLACEHOLDER par la vraie clé")
        print("  4. Redémarrer: systemctl restart bobodo-vocal")
        
    except Exception as e:
        print(f"❌ Erreur: {e}")
        client.close()


if __name__ == "__main__":
    configure_secrets()
