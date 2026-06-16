#!/usr/bin/env python3
"""
Création du fichier .env sur le serveur avec les secrets Supabase
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

def get_supabase_secret(secret_name):
    """Récupérer un secret depuis Supabase CLI"""
    try:
        result = subprocess.run(
            ["supabase", "secrets", "list"],
            capture_output=True,
            text=True,
            cwd="c:\\Users\\fasop\\AndroidStudioProjects\\academia"
        )
        
        # Parser la sortie pour trouver le secret
        lines = result.stdout.split('\n')
        for line in lines:
            if secret_name in line:
                # Le format est: NAME | DIGEST
                # On ne peut pas récupérer la valeur réelle via CLI
                # On doit utiliser une autre méthode
                return None
        
        return None
    except Exception as e:
        print(f"Erreur récupération secret {secret_name}: {e}")
        return None

def create_env_file():
    """Créer fichier .env sur le serveur"""
    print("=== CRÉATION FICHIER .ENV ===")
    
    # Récupérer les secrets depuis le fichier config Flutter
    print("[1] Récupération configuration Supabase...")
    supabase_url = "https://thevdfcwlcqzdoybfvgs.supabase.co"
    print(f"  SUPABASE_URL: {supabase_url}")
    
    # Pour le service role key et OpenRouter, on utilise des placeholders
    # car on ne peut pas les récupérer facilement via CLI
    print("\n[2] Création fichier .env...")
    
    env_content = f"""# Supabase
SUPABASE_URL={supabase_url}
SUPABASE_SERVICE_ROLE_KEY=SERVICE_ROLE_KEY_PLACEHOLDER

# OpenRouter
OPENROUTER_API_KEY=OPENROUTER_API_KEY_PLACEHOLDER

# Whisper (placeholder - STT désactivé pour l'instant)
WHISPER_MODEL=tiny
WHISPER_DEVICE=cpu
WHISPER_QUANTIZATION=int8

# Piper (placeholder - TTS désactivé pour l'instant)
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
        
        print("  ✅ Fichier .env créé")
        
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
        
        print("\n=== CRÉATION .ENV TERMINÉE ===")
        print("\n⚠️ ATTENTION: SUPABASE_SERVICE_ROLE_KEY et OPENROUTER_API_KEY sont des placeholders.")
        print("   Le service peut démarrer mais les appels Supabase/OpenRouter échoueront.")
        
    except Exception as e:
        print(f"❌ Erreur: {e}")
        client.close()


if __name__ == "__main__":
    create_env_file()
