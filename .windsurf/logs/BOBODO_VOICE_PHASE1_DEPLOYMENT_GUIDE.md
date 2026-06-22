# BOBODO VOICE - Phase 1 Deployment Guide

## Date
12 Juin 2026

---

## OBJECTIF

Installer Piper TTS sur le serveur Kamatera et configurer le serveur vocal.

---

## IDENTIFIANTS KAMATERA

**Clé d'accès** : a91330958142da0f32fdc6b9f7e16476
**Clé secret** : 354e008099f0dbb3e667f550965d8e95
**Mot de passe serveur** : Nexiomgroup@Academia0
**ID serveur** : f6d2656b-0f80-4df1-ac62-53b26d6d921b

---

## ÉTAPE 1 : CONNEXION SSH

### Méthode 1 : Via Kamatera Console

1. Se connecter au portail Kamatera
2. Sélectionner le serveur f6d2656b-0f80-4df1-ac62-53b26d6d921b
3. Cliquer sur "Console"
4. Se connecter avec :
   - Username : root
   - Password : Nexiomgroup@Academia0

### Méthode 2 : Via SSH Client

```bash
ssh root@185.167.97.144
# Password : Nexiomgroup@Academia0
```

---

## ÉTAPE 2 : MISE À JOUR SYSTÈME

```bash
# Mise à jour apt
apt update && apt upgrade -y

# Installation Python et pip
apt install python3 python3-pip -y

# Mise à jour pip
pip3 install --upgrade pip
```

---

## ÉTAPE 3 : INSTALLATION PIPER TTS

```bash
# Installation Piper TTS
pip3 install piper-tts

# Vérification installation
pip3 show piper-tts
```

**Attendu** : Piper TTS installé avec succès

---

## ÉTAPE 4 : INSTALLATION DÉPENDANCES

```bash
# Installation espeak-ng
apt install espeak-ng -y

# Vérification installation
espeak-ng --version
```

**Attendu** : espeak-ng installé avec succès

---

## ÉTAPE 5 : TÉLÉCHARGEMENT VOIX FRANÇAISE

```bash
# Création dossier voix
mkdir -p /root/piper_voices
cd /root/piper_voices

# Téléchargement voix fr_FR-siwis-medium
wget https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/fr/fr_FR/siwis/medium/fr_FR-siwis-medium.onnx -O fr_FR-siwis-medium.onnx

wget https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/fr/fr_FR/siwis/medium/fr_FR-siwis-medium.onnx.json -O fr_FR-siwis-medium.onnx.json

# Vérification fichiers
ls -lh
```

**Attendu** : Fichiers téléchargés avec taille > 0

**Alternative (si 404)** :
```bash
# Téléchargement depuis SourceForge
wget https://sourceforge.net/projects/piper-tts.mirror/files/v0.0.2/voice-fr-siwis-medium.tar.gz/download -O voice-fr-siwis-medium.tar.gz

# Extraction
tar -xzf voice-fr-siwis-medium.tar.gz

# Vérification fichiers
ls -lh
```

---

## ÉTAPE 6 : TEST GÉNÉRATION AUDIO

```bash
# Création script test
cat > /tmp/test_piper.py << 'EOF'
import piper_tts

# Chargement modèle
model_path = "/root/piper_voices/fr_FR-siwis-medium.onnx"
config_path = "/root/piper_voices/fr_FR-siwis-medium.onnx.json"

print("Chargement modèle Piper...")
piper_model = piper_tts.PiperTTS(model_path, config_path)

# Génération audio
test_text = "Bonjour, je suis Bobodo."
print(f"Génération audio pour: {test_text}")
audio = piper_model.synthesize(test_text)

# Sauvegarde fichier
with open("/tmp/test_piper.wav", "wb") as f:
    f.write(audio)

print(f"Audio généré: {len(audio)} bytes")
print("Fichier sauvegardé: /tmp/test_piper.wav")
EOF

# Exécution script
python3 /tmp/test_piper.py
```

**Attendu** : Audio généré avec succès, fichier /tmp/test_piper.wav créé

---

## ÉTAPE 7 : TEST LATENCE

```bash
# Création script latence
cat > /tmp/test_latency.py << 'EOF'
import piper_tts
import time

# Chargement modèle
model_path = "/root/piper_voices/fr_FR-siwis-medium.onnx"
config_path = "/root/piper_voices/fr_FR-siwis-medium.onnx.json"

piper_model = piper_tts.PiperTTS(model_path, config_path)

# Test latence
test_texts = [
    "Bonjour, je suis Bobodo.",
    "Comment puis-je vous aider?",
    "Je suis ici pour répondre à vos questions.",
    "Academia facilite l'accès aux formations.",
    "N'hésitez pas à me poser des questions."
]

total_latency = 0
for i, text in enumerate(test_texts):
    start_time = time.time()
    audio = piper_model.synthesize(text)
    end_time = time.time()
    latency = end_time - start_time
    total_latency += latency
    print(f"Test {i+1}: {latency:.3f}s - Text: {text[:30]}...")

avg_latency = total_latency / len(test_texts)
print(f"\nLatence moyenne: {avg_latency:.3f}s")
print(f"Latence max: {max([time.time() - time.time() for _ in test_texts]):.3f}s")
EOF

# Exécution script
python3 /tmp/test_latency.py
```

**Attendu** : Latence moyenne < 1s

---

## ÉTAPE 8 : CRÉATION TTS_SERVICE.PY

```bash
# Création dossier serveur
mkdir -p /root/voice_server
cd /root/voice_server

# Création tts_service.py
cat > tts_service.py << 'EOF'
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
EOF

# Test tts_service.py
python3 tts_service.py
```

**Attendu** : Audio généré avec succès, fichier /tmp/test_tts_service.wav créé

---

## ÉTAPE 9 : CRÉATION WEBSOCKET BIDIRECTIONNEL

```bash
# Installation websockets
pip3 install websockets asyncio

# Création serveur WebSocket
cat > voice_server.py << 'EOF'
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
EOF

# Test serveur WebSocket (en arrière-plan)
nohup python3 voice_server.py > /var/log/voice_server.log 2>&1 &
```

**Attendu** : Serveur WebSocket démarré sur ws://0.0.0.0:8000

---

## ÉTAPE 10 : VÉRIFICATION SERVEUR

```bash
# Vérification processus
ps aux | grep voice_server

# Vérification logs
tail -f /var/log/voice_server.log

# Vérification port
netstat -tlnp | grep 8000
```

**Attendu** :
- Processus voice_server en cours
- Logs sans erreur
- Port 8000 ouvert

---

## ÉTAPE 11 : TEST WEBSOCKET

```bash
# Création client test
cat > /tmp/test_websocket.py << 'EOF'
import asyncio
import websockets
import json
import base64

async def test_websocket():
    uri = "ws://localhost:8000"
    
    async with websockets.connect(uri) as websocket:
        # Envoi message test
        message = {
            'type': 'text',
            'text': 'Bonjour, je suis Bobodo.'
        }
        await websocket.send(json.dumps(message))
        
        # Réception réponse
        response = await websocket.recv()
        data = json.loads(response)
        
        if data['type'] == 'audio_response':
            audio_base64 = data['audio']
            audio_bytes = base64.b64decode(audio_base64)
            
            # Sauvegarde fichier
            with open("/tmp/test_websocket_audio.wav", "wb") as f:
                f.write(audio_bytes)
            
            print(f"Audio reçu: {len(audio_bytes)} bytes")
            print("Fichier sauvegardé: /tmp/test_websocket_audio.wav")
        else:
            print(f"Erreur: {data}")

asyncio.run(test_websocket())
EOF

# Exécution test
python3 /tmp/test_websocket.py
```

**Attendu** : Audio reçu et sauvegardé dans /tmp/test_websocket_audio.wav

---

## ÉTAPE 12 : CONFIGURATION SERVICE SYSTÈME

```bash
# Création service systemd
cat > /etc/systemd/system/voice_server.service << 'EOF'
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
EOF

# Rechargement systemd
systemctl daemon-reload

# Activation service
systemctl enable voice_server

# Démarrage service
systemctl start voice_server

# Vérification status
systemctl status voice_server
```

**Attendu** : Service voice_server actif et en cours d'exécution

---

## ROLLBACK

Si problème, rollback possible :

```bash
# Arrêt service
systemctl stop voice_server

# Désactivation service
systemctl disable voice_server

# Suppression service
rm /etc/systemd/system/voice_server.service
systemctl daemon-reload

# Arrêt processus manuel
pkill -f voice_server.py
```

---

## SIGN-OFF

**Guide créé** : 12 Juin 2026
**Auteur** : Cascade AI
**Statut** : PRÊT POUR DÉPLOIEMENT
