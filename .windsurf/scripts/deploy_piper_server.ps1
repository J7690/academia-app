# Bobodo Voice - Phase 1 Deployment Script
# This script installs Piper TTS on Kamatera server

$SERVER_IP = "185.167.97.144"
$SERVER_USER = "root"
$SERVER_PASSWORD = "Nexiomgroup@Academia0"

Write-Host "=== Bobodo Voice - Phase 1 Deployment ===" -ForegroundColor Green
Write-Host "Server: $SERVER_IP" -ForegroundColor Yellow
Write-Host ""

# Function to execute SSH command using plink
function Invoke-SSHCommand {
    param(
        [string]$Command
    )

    # Essayer plink d'abord
    $plinkPath = Get-Command plink -ErrorAction SilentlyContinue
    if ($plinkPath) {
        $plinkExe = $plinkPath.Source
        $sshCommand = "`"$plinkExe`" -ssh -batch -pw $SERVER_PASSWORD $SERVER_USER@$SERVER_IP `"$Command`""
        $output = cmd /c $sshCommand 2>&1
        return $output
    }

    # Fallback: utiliser ssh si disponible (WSL ou Git Bash)
    $sshPath = Get-Command ssh -ErrorAction SilentlyContinue
    if ($sshPath) {
        $sshExe = $sshPath.Source
        $sshCommand = "`"$sshExe`" -o StrictHostKeyChecking=no -o PubkeyAuthentication=no $SERVER_USER@$SERVER_IP `"$Command`""
        $env:SSHPASS = $SERVER_PASSWORD
        $output = cmd /c $sshCommand 2>&1
        return $output
    }

    # Erreur si aucun client SSH disponible
    Write-Host "ERREUR: Aucun client SSH (plink ou ssh) trouvé" -ForegroundColor Red
    Write-Host "Veuillez installer PuTTY (incluant plink.exe) ou Git Bash (incluant ssh.exe)" -ForegroundColor Yellow
    exit 1
}

Write-Host "Step 1: Update system..." -ForegroundColor Cyan
$output = Invoke-SSHCommand "apt update && apt upgrade -y"
Write-Host $output

Write-Host "Step 2: Install Python and pip..." -ForegroundColor Cyan
$output = Invoke-SSHCommand "apt install python3 python3-pip -y"
Write-Host $output

Write-Host "Step 3: Upgrade pip..." -ForegroundColor Cyan
$output = Invoke-SSHCommand "pip3 install --upgrade pip"
Write-Host $output

Write-Host "Step 4: Install Piper TTS..." -ForegroundColor Cyan
$output = Invoke-SSHCommand "pip3 install piper-tts"
Write-Host $output

Write-Host "Step 5: Install espeak-ng..." -ForegroundColor Cyan
$output = Invoke-SSHCommand "apt install espeak-ng -y"
Write-Host $output

Write-Host "Step 6: Create voices directory..." -ForegroundColor Cyan
$output = Invoke-SSHCommand "mkdir -p /root/piper_voices"
Write-Host $output

Write-Host "Step 7: Download French voice..." -ForegroundColor Cyan
$output = Invoke-SSHCommand "cd /root/piper_voices && wget https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/fr/fr_FR/siwis/medium/fr_FR-siwis-medium.onnx -O fr_FR-siwis-medium.onnx"
Write-Host $output

$output = Invoke-SSHCommand "cd /root/piper_voices && wget https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/fr/fr_FR/siwis/medium/fr_FR-siwis-medium.onnx.json -O fr_FR-siwis-medium.onnx.json"
Write-Host $output

Write-Host "Step 8: Verify files..." -ForegroundColor Cyan
$output = Invoke-SSHCommand "ls -lh /root/piper_voices"
Write-Host $output

Write-Host "Step 9: Install websockets..." -ForegroundColor Cyan
$output = Invoke-SSHCommand "pip3 install websockets asyncio"
Write-Host $output

Write-Host "Step 10: Create voice server directory..." -ForegroundColor Cyan
$output = Invoke-SSHCommand "mkdir -p /root/voice_server"
Write-Host $output

Write-Host "Step 11: Create tts_service.py..." -ForegroundColor Cyan
$ttsServiceContent = @'
import piper_tts
import base64
import json
import logging
import numpy as np

# Configuration logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('tts_service')

# Chargement modèle Piper
model_path = "/root/piper_voices/fr_FR-siwis-medium.onnx"
config_path = "/root/piper_voices/fr_FR-siwis-medium.onnx.json"

try:
    logger.info("Chargement modèle Piper...")
    piper_model = piper_tts.PiperTTS(model_path, config_path)
    logger.info("Modèle Piper chargé avec succès")
except Exception as e:
    logger.error(f"Erreur chargement modèle Piper: {e}")
    piper_model = None

def generate_tts_piper(text: str) -> bytes:
    """
    Génère audio avec Piper TTS.
    
    Args:
        text: Texte à convertir en audio
        
    Returns:
        bytes: Audio généré (WAV format)
    """
    try:
        logger.info(f"[TTS_REQUEST] Text length: {len(text)}")
        
        # Génération audio
        audio = piper_model.synthesize(text)
        
        # Conversion en bytes
        audio_bytes = audio.tobytes()
        
        logger.info(f"[TTS_SUCCESS] Audio generated: {len(audio_bytes)} bytes")
        return audio_bytes
    except Exception as e:
        logger.error(f"[TTS_PIPER_ERROR] {e}")
        raise

def generate_tts(text: str) -> bytes:
    """
    Génère audio avec Piper TTS (fallback gTTS).
    
    Args:
        text: Texte à convertir en audio
        
    Returns:
        bytes: Audio généré (WAV format)
    """
    try:
        if piper_model is not None:
            return generate_tts_piper(text)
        else:
            # Fallback gTTS (à implémenter)
            raise Exception("Piper model not loaded")
    except Exception as e:
        logger.error(f"[TTS_ERROR] {e}")
        raise

if __name__ == "__main__":
    # Test
    test_text = "Bonjour, je suis Bobodo."
    audio_bytes = generate_tts(test_text)
    
    # Sauvegarde fichier test
    with open("/tmp/test_tts_service.wav", "wb") as f:
        f.write(audio_bytes)
    
    print(f"[TTS_TEST] Audio saved: {len(audio_bytes)} bytes")
'@

$ttsServiceContent | Invoke-SSHCommand "cat > /root/voice_server/tts_service.py"
Write-Host "tts_service.py created"

Write-Host "Step 12: Create voice_server.py..." -ForegroundColor Cyan
$voiceServerContent = @'
import asyncio
import websockets
import json
import base64
import logging
from tts_service import generate_tts

# Configuration logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('voice_server')

async def handle_websocket(websocket):
    """
    Handler WebSocket pour communication vocale.
    """
    try:
        logger.info("Client connecté")
        
        async for message in websocket:
            data = json.loads(message)
            message_type = data.get('type')
            
            if message_type == 'text':
                # Génération TTS
                text = data.get('text', '')
                logger.info(f"Message reçu: {text[:50]}...")
                
                try:
                    audio_bytes = generate_tts(text)
                    
                    # Encodage base64
                    audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')
                    
                    # Envoi audio
                    response = {
                        'type': 'audio_response',
                        'audio': audio_base64
                    }
                    await websocket.send(json.dumps(response))
                    logger.info("Audio envoyé")
                    
                except Exception as e:
                    logger.error(f"Erreur génération TTS: {e}")
                    error_response = {
                        'type': 'error',
                        'message': str(e)
                    }
                    await websocket.send(json.dumps(error_response))
                    
            elif message_type == 'interrupt':
                # Interruption (barge-in)
                logger.info("Interruption reçue")
                # Arrêt génération TTS (à implémenter)
                
    except Exception as e:
        logger.error(f"Erreur WebSocket: {e}")
    finally:
        logger.info("Client déconnecté")

async def main():
    """
    Point d'entrée serveur WebSocket.
    """
    server = await websockets.serve(handle_websocket, "0.0.0.0", 8000)
    logger.info("Serveur WebSocket démarré sur ws://0.0.0.0:8000")
    await server.wait_closed()

if __name__ == "__main__":
    asyncio.run(main())
'@

$voiceServerContent | Invoke-SSHCommand "cat > /root/voice_server/voice_server.py"
Write-Host "voice_server.py created"

Write-Host "Step 13: Test TTS generation..." -ForegroundColor Cyan
$output = Invoke-SSHCommand "cd /root/voice_server && python3 tts_service.py"
Write-Host $output

Write-Host "Step 14: Create systemd service..." -ForegroundColor Cyan
$systemdContent = @'
[Unit]
Description=Bobodo Voice Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/voice_server
ExecStart=/usr/bin/python3 /root/voice_server/voice_server.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
'@

$systemdContent | Invoke-SSHCommand "cat > /etc/systemd/system/voice_server.service"
Write-Host "systemd service created"

Write-Host "Step 15: Enable and start service..." -ForegroundColor Cyan
$output = Invoke-SSHCommand "systemctl daemon-reload && systemctl enable voice_server && systemctl start voice_server"
Write-Host $output

Write-Host "Step 16: Check service status..." -ForegroundColor Cyan
$output = Invoke-SSHCommand "systemctl status voice_server"
Write-Host $output

Write-Host "Step 17: Check logs..." -ForegroundColor Cyan
$output = Invoke-SSHCommand "tail -20 /var/log/syslog | grep voice_server"
Write-Host $output

Write-Host "=== Phase 1 Deployment Complete ===" -ForegroundColor Green
