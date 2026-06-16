# BOBODO VOCAL - PHASE 1 : PRÉPARATION TECHNIQUE

**Date** : 10 juin 2026  
**Statut** : ✅ TERMINÉ

---

## ARCHITECTURE FINALE

### Schéma global

```
┌─────────────────────────────────────────────────────────────┐
│ Flutter App (Academia)                                      │
│ ─ BobodoProvider (session, messages)                        │
│ ─ Mode texte : TextField → sendUserMessage()                │
│ ─ Mode vocal : Microphone → WebSocket → STT → sendUserMessage() │
│ ─ Audio playback : just_audio                               │
└──────────┬──────────────────────────────────────────────────┘
           │ WebSocket (TLS 1.3)
           ▼
┌─────────────────────────────────────────────────────────────┐
│ Kamatera - Service Vocal (Dedicated)                        │
│ ─ WebSocket server (FastAPI + Uvicorn)                      │
│ ─ Faster Whisper Medium (STT) : audio → text               │
│ �─ HTTP POST → Edge Function bobodo-chat                     │
│ ─ Piper Medium (TTS) : text → audio                        │
│ ─ WebSocket response (audio streaming)                      │
└──────────┬──────────────────────────────────────────────────┘
           │ HTTP POST
           ▼
┌─────────────────────────────────────────────────────────────┐
│ Supabase Edge Function bobodo-chat                          │
│ ─ Charge historique (session_id)                            │
│ ─ Charge mémoire cross-session (session_id)                  │
│ ─ Charge profil étudiant (session_id)                       │
│ ─ Détection émotionnelle (message)                          │
│ ─ RAG interne Academia                                      │
│ ─ Escalade Support                                          │
│ ─ Réponse IA (OpenRouter)                                   │
└─────────────────────────────────────────────────────────────┘
```

---

### Flux détaillé

**1. Capture audio (Flutter)**
```
Microphone → flutter_sound → Audio bytes (PCM)
```

**2. Envoi WebSocket (Flutter → Kamatera)**
```
Audio bytes → WebSocket → Kamatera Service Vocal
```

**3. Transcription STT (Kamatera)**
```
Audio bytes → Faster Whisper Medium → Texte transcrit
```

**4. Envoi à Bobodo (Kamatera → Supabase)**
```
Texte transcrit → HTTP POST → Edge Function bobodo-chat
```

**5. Traitement Bobodo (Supabase)**
```
Edge Function bobodo-chat :
  - Charge historique (session_id)
  - Charge mémoire cross-session
  - Charge profil étudiant
  - Détection émotionnelle
  - RAG interne Academia
  - Escalade Support
  - Réponse IA (OpenRouter)
```

**6. Réception réponse (Kamatera)**
```
Réponse texte ← HTTP POST ← Edge Function bobodo-chat
```

**7. Synthèse TTS (Kamatera)**
```
Réponse texte → Piper Medium → Audio bytes
```

**8. Envoi audio (Kamatera → Flutter)**
```
Audio bytes → WebSocket → Flutter
```

**9. Lecture audio (Flutter)**
```
Audio bytes → just_audio → Haut-parleur
```

---

### Protocole WebSocket

**Message client → serveur** :
```json
{
  "type": "audio",
  "session_id": "uuid",
  "audio": "base64_encoded_audio_bytes"
}
```

**Message serveur → client (transcription)** :
```json
{
  "type": "transcription",
  "text": "texte transcrit"
}
```

**Message serveur → client (audio réponse)** :
```json
{
  "type": "audio_response",
  "audio": "base64_encoded_audio_bytes"
}
```

**Message erreur** :
```json
{
  "type": "error",
  "message": "erreur description"
}
```

---

## STRUCTURE DOCKER

### Dockerfile

```dockerfile
FROM python:3.11-slim

# Variables d'environnement
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Répertoire de travail
WORKDIR /app

# Dépendances système
RUN apt-get update && apt-get install -y \
    ffmpeg \
    libsndfile1 \
    portaudio19-dev \
    && rm -rf /var/lib/apt/lists/*

# Copier requirements
COPY requirements.txt .

# Installer dépendances Python
RUN pip install --no-cache-dir -r requirements.txt

# Copier code
COPY . .

# Exposer port
EXPOSE 8000

# Commande de démarrage
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

---

### docker-compose.yml

```yaml
version: '3.8'

services:
  bobodo-vocal:
    build: .
    container_name: bobodo-vocal
    restart: unless-stopped
    ports:
      - "8000:8000"
    environment:
      - SUPABASE_URL=${SUPABASE_URL}
      - SUPABASE_SERVICE_ROLE_KEY=${SUPABASE_SERVICE_ROLE_KEY}
      - OPENROUTER_API_KEY=${OPENROUTER_API_KEY}
      - WHISPER_MODEL=medium
      - WHISPER_DEVICE=cpu
      - PIPER_MODEL=medium
      - PIPER_VOICE=fr_FR
    volumes:
      - ./models:/app/models
      - ./logs:/app/logs
    deploy:
      resources:
        limits:
          cpus: '3.5'
          memory: 7G
        reservations:
          cpus: '2'
          memory: 4G
```

---

### requirements.txt

```
fastapi==0.109.0
uvicorn[standard]==0.27.0
websockets==12.0
pydantic==2.5.3
pydantic-settings==2.1.0
faster-whisper==0.10.0
piper-tts==1.2.0
torch==2.1.2
torchaudio==2.1.2
numpy==1.26.3
httpx==0.26.0
python-multipart==0.0.6
```

---

## VARIABLES D'ENVIRONNEMENT

### Variables requises

```bash
# Supabase
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# OpenRouter
OPENROUTER_API_KEY=sk-or-v1-xxx

# Faster Whisper
WHISPER_MODEL=medium
WHISPER_DEVICE=cpu
WHISPER_QUANTIZATION=int8

# Piper TTS
PIPER_MODEL=medium
PIPER_VOICE=fr_FR-medium

# WebSocket
WEBSOCKET_HOST=0.0.0.0
WEBSOCKET_PORT=8000

# Logging
LOG_LEVEL=INFO
```

---

### Fichier .env.example

```bash
# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# OpenRouter
OPENROUTER_API_KEY=your-openrouter-api-key

# Faster Whisper
WHISPER_MODEL=medium
WHISPER_DEVICE=cpu
WHISPER_QUANTIZATION=int8

# Piper TTS
PIPER_MODEL=medium
PIPER_VOICE=fr_FR-medium

# WebSocket
WEBSOCKET_HOST=0.0.0.0
WEBSOCKET_PORT=8000

# Logging
LOG_LEVEL=INFO
```

---

## PLAN DE DÉPLOIEMENT KAMATERA

### Prérequis

1. **Accès SSH Kamatera**
   - IP : 185.167.97.144
   - Utilisateur : root
   - Mot de passe : (à obtenir)

2. **Upgrade serveur**
   - Configuration actuelle : 2 vCPU, 4 GB RAM
   - Configuration requise : 4 vCPU, 8 GB RAM
   - Coût : $59/mois

3. **Domaine (optionnel)**
   - SSL/TLS recommandé
   - Certbot Let's Encrypt

---

### Étape 1 : Upgrade serveur Kamatera

```bash
# Se connecter au dashboard Kamatera
# Upgrader le serveur à 4 vCPU, 8 GB RAM
# Redémarrer le serveur
```

---

### Étape 2 : Installation Docker

```bash
# SSH sur le serveur
ssh root@185.167.97.144

# Mettre à jour le système
apt update && apt upgrade -y

# Installer Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Installer Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Vérifier l'installation
docker --version
docker-compose --version
```

---

### Étape 3 : Création répertoire projet

```bash
# Créer répertoire
mkdir -p /opt/bobodo-vocal
cd /opt/bobodo-vocal

# Créer sous-répertoires
mkdir -p models logs
```

---

### Étape 4 : Téléchargement modèles

```bash
# Télécharger Faster Whisper Medium
cd /opt/bobodo-vocal/models
wget https://huggingface.co/guillaumekln/faster-whisper-medium/resolve/main/model.bin
wget https://huggingface.co/guillaumekln/faster-whisper-medium/resolve/main/config.json

# Télécharger Piper Medium
wget https://huggingface.co/rhasspy/piper-voices/v1.0.0/fr/fr_FR-medium/resolve/main/model.onnx
wget https://huggingface.co/rhasspy/piper-voices/v1.0.0/fr/fr_FR-medium/resolve/main/config.json
```

---

### Étape 5 : Déploiement code

```bash
# Copier les fichiers sur le serveur
# (via SCP ou Git clone)

# Exemple avec SCP
scp -r . root@185.167.97.144:/opt/bobodo-vocal/

# Ou avec Git
cd /opt/bobodo-vocal
git clone https://github.com/your-repo/bobodo-vocal.git .
```

---

### Étape 6 : Configuration variables d'environnement

```bash
# Créer fichier .env
cd /opt/bobodo-vocal
nano .env

# Copier les variables depuis .env.example
# Remplir avec les vraies valeurs
```

---

### Étape 7 : Build et démarrage

```bash
# Build Docker image
docker-compose build

# Démarrer le service
docker-compose up -d

# Vérifier les logs
docker-compose logs -f

# Vérifier le statut
docker-compose ps
```

---

### Étape 8 : Configuration Firewall

```bash
# Ouvrir port 8000 (WebSocket)
ufw allow 8000/tcp

# Vérifier les règles
ufw status
```

---

### Étape 9 : Configuration SSL/TLS (optionnel)

```bash
# Installer Certbot
apt install certbot python3-certbot-nginx -y

# Obtenir certificat
certbot --nginx -d vocal.academia.bf

# Renouvellement automatique
certbot renew --dry-run
```

---

### Étape 10 : Monitoring

```bash
# Installer htop
apt install htop -y

# Installer netdata (optionnel)
bash <(curl -Ss https://my-netdata.io/kickstart.sh)

# Accéder au monitoring
# http://185.167.97.144:19999
```

---

## STRUCTURE PROJET

```
bobodo-vocal/
├── Dockerfile
├── docker-compose.yml
├── requirements.txt
├── .env.example
├── .env
├── main.py
├── websocket_handler.py
├── stt_service.py
├── tts_service.py
├── bobodo_client.py
├── models/
│   ├── faster-whisper-medium/
│   └── piper-medium/
├── logs/
└── README.md
```

---

## SÉCURITÉ

### 1. Variables d'environnement

- Ne jamais commit .env
- Utiliser .env.example comme template
- Changer les clés régulièrement

### 2. WebSocket

- TLS 1.3 obligatoire
- Validation JWT Supabase
- Rate limiting par IP

### 3. Docker

- Utiliser utilisateur non-root
- Scanner vulnérabilités régulièrement
- Mettre à jour les images

---

## MONITORING

### Métriques à surveiller

- CPU usage
- RAM usage
- Nombre de connexions WebSocket
- Latence STT
- Latence TTS
- Erreurs HTTP

### Outils

- Docker stats
- htop
- netdata (optionnel)
- Prometheus + Grafana (optionnel)

---

## ROLLBACK

### Procédure

```bash
# Arrêter le service
docker-compose down

# Revenir à la version précédente
git checkout previous-version
docker-compose build
docker-compose up -d
```

---

**DOCUMENT TERMINÉ**
