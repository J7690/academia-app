# BOBODO VOCAL - PLAN DE DÉPLOIEMENT

**Date** : 10 juin 2026  
**Version** : 1.0  
**Statut** : ✅ FINAL

---

## RÉSUMÉ

Ce plan de déploiement décrit les étapes pour mettre en production Bobodo Vocal sur l'infrastructure Academia existante (Kamatera + Supabase).

**Durée estimée** : 2-3 semaines  
**Complexité** : Moyenne  
**Risque** : Faible

---

## PRÉREQUIS

### Infrastructure

- Compte Kamatera actif
- Compte Supabase actif
- Accès SSH au serveur Kamatera
- Accès admin Supabase

### Outils

- Python 3.11+
- Docker (optionnel)
- Git
- Supabase CLI

### Connaissances

- Administration Linux (Ubuntu)
- Python FastAPI
- Flutter
- WebSocket

---

## PHASE 1 : PRÉPARATION SERVEUR KAMATERA (2 jours)

### 1.1 Provisionner VPS

**Action** : Créer nouveau VPS Kamatera

**Spécifications** :
- vCPU : 2
- RAM : 4 GB
- Stockage : 20 GB SSD
- OS : Ubuntu 22.04 LTS
- Datacenter : Amsterdam

**Commande** :
```bash
# Via dashboard Kamatera
# Ou via API Kamatera
```

**Vérification** :
```bash
ssh root@<IP>
uname -a
free -h
df -h
```

---

### 1.2 Configuration de base

**Action** : Configurer serveur

**Commandes** :
```bash
# Mise à jour système
apt update && apt upgrade -y

# Installer dépendances
apt install -y python3.11 python3-pip python3-venv git nginx certbot

# Créer utilisateur dédié
useradd -m -s /bin/bash bobodo
usermod -aG sudo bobodo

# Configurer firewall (UFW)
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 9000/tcp
ufw enable
```

---

### 1.3 Installer Python et dépendances

**Action** : Installer environnement Python

**Commandes** :
```bash
# Créer environnement virtuel
sudo -u bobodo python3 -m venv /home/bobodo/venv
source /home/bobodo/venv/bin/activate

# Installer packages
pip install fastapi uvicorn websockets faster-whisper piper-tts requests httpx

# Installer ffmpeg (requis pour audio)
apt install -y ffmpeg
```

---

### 1.4 Configurer SSL/TLS

**Action** : Générer certificat SSL

**Commandes** :
```bash
# Installer Nginx
apt install -y nginx

# Générer certificat Let's Encrypt
certbot --nginx -d vocal.academia.bf

# Vérifier renouvellement automatique
certbot renew --dry-run
```

---

## PHASE 2 : DÉVELOPPEMENT SERVICE VOCAL (5 jours)

### 2.1 Créer structure projet

**Action** : Créer structure de fichiers

**Commandes** :
```bash
mkdir -p /home/bobodo/bobodo-vocal
cd /home/bobodo/bobodo-vocal

# Structure
mkdir -p app logs
touch app/main.py app/websocket.py app/stt.py app/tts.py app/config.py
touch requirements.txt Dockerfile nginx.conf
```

---

### 2.2 Implémenter WebSocket server

**Fichier** : `app/main.py`

```python
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
async def health():
    return {"status": "ok"}

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    try:
        while True:
            data = await websocket.receive_text()
            # Traitement audio
            # STT → LLM → TTS
            await websocket.send_text("response")
    except WebSocketDisconnect:
        pass

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=9000)
```

---

### 2.3 Implémenter STT (Faster-Whisper)

**Fichier** : `app/stt.py`

```python
from faster_whisper import WhisperModel

model = WhisperModel("small", device="cpu", compute_type="int8")

def transcribe(audio_path: str) -> str:
    segments, info = model.transcribe(audio_path, language="fr")
    text = "".join([segment.text for segment in segments])
    return text
```

---

### 2.4 Implémenter TTS (Piper)

**Fichier** : `app/tts.py`

```python
from piper import PiperVoice

voice = PiperVoice.load("fr-french-medium", "cpu")

def synthesize(text: str) -> bytes:
    audio = voice.synthesize(text)
    return audio
```

---

### 2.5 Configurer Nginx

**Fichier** : `nginx.conf`

```nginx
server {
    listen 80;
    server_name vocal.academia.bf;

    location / {
        proxy_pass http://127.0.0.1:9000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}
```

---

### 2.6 Créer service systemd

**Fichier** : `/etc/systemd/system/bobodo-vocal.service`

```ini
[Unit]
Description=Bobodo Vocal Service
After=network.target

[Service]
Type=simple
User=bobodo
WorkingDirectory=/home/bobodo/bobodo-vocal
Environment="PATH=/home/bobodo/venv/bin"
ExecStart=/home/bobodo/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 9000
Restart=always

[Install]
WantedBy=multi-user.target
```

**Commandes** :
```bash
systemctl enable bobodo-vocal
systemctl start bobodo-vocal
systemctl status bobodo-vocal
```

---

## PHASE 3 : DÉVELOPPEMENT FLUTTER (5 jours)

### 3.1 Ajouter packages

**Fichier** : `pubspec.yaml`

```yaml
dependencies:
  flutter_sound: ^9.0.0
  just_audio: ^0.9.0
  web_socket_channel: ^2.4.0
  permission_handler: ^11.0.0
```

**Commande** :
```bash
flutter pub get
```

---

### 3.2 Créer BobodoVocalProvider

**Fichier** : `lib/providers/bobodo_vocal_provider.dart`

```dart
class BobodoVocalProvider extends ChangeNotifier {
  WebSocketChannel? _channel;
  bool _isRecording = false;
  bool _isPlaying = false;

  Future<void> connect() async {
    _channel = WebSocketChannel.connect(
      Uri.parse('wss://vocal.academia.bf/ws'),
    );
  }

  Future<void> startRecording() async {
    // Implémenter capture audio
  }

  Future<void> stopRecording() async {
    // Implémenter arrêt capture
  }

  Future<void> playAudio(String audioData) async {
    // Implémenter playback audio
  }
}
```

---

### 3.3 Créer UI vocal

**Fichier** : `lib/features/student/tabs/student_bobodo_tab.dart`

**Modifications** :
- Ajouter bouton microphone (FloatingActionButton)
- Ajouter visualisation audio (CustomPainter)
- Ajouter animation Bobodo (icônes dynamiques)
- Ajouter mode silencieux (IconButton)

---

### 3.4 Gérer permissions

**Fichier** : `android/app/src/main/AndroidManifest.xml`

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

---

## PHASE 4 : TESTS (3 jours)

### 4.1 Tests unitaires

**STT** :
```python
# test_stt.py
def test_transcribe():
    text = transcribe("test_audio.wav")
    assert len(text) > 0
```

**TTS** :
```python
# test_tts.py
def test_synthesize():
    audio = synthesize("Bonjour")
    assert len(audio) > 0
```

---

### 4.2 Tests intégration

**WebSocket** :
```python
# test_websocket.py
async def test_websocket():
    async with websockets.connect("ws://localhost:9000/ws") as ws:
        await ws.send("test")
        response = await ws.recv()
        assert response == "response"
```

---

### 4.3 Tests Flutter

**Capture audio** :
- Tester permission microphone
- Tester capture audio
- Tester streaming WebSocket

**Playback audio** :
- Tester réception audio
- Tester playback
- Tester mode silencieux

---

### 4.4 Tests end-to-end

**Scénario** :
1. Utilisateur connecte WebSocket
2. Utilisateur active microphone
3. Utilisateur parle
4. STT transcrit
5. LLM génère réponse
6. TTS synthétise
7. Utilisateur écoute réponse

---

## PHASE 5 : DÉPLOIEMENT PRODUCTION (2 jours)

### 5.1 Déployer sur Kamatera

**Commandes** :
```bash
# Copier code
scp -r bobodo-vocal bobodo@<IP>:/home/bobodo/

# Redémarrer service
ssh bobodo@<IP> "systemctl restart bobodo-vocal"

# Vérifier logs
ssh bobodo@<IP> "journalctl -u bobodo-vocal -f"
```

---

### 5.2 Configurer monitoring

**Prometheus** :
```bash
# Installer Prometheus
apt install -y prometheus

# Configurer scrape targets
# /etc/prometheus/prometheus.yml
scrape_configs:
  - job_name: 'bobodo-vocal'
    static_configs:
      - targets: ['localhost:9000']
```

**Grafana** :
```bash
# Installer Grafana
apt install -y grafana

# Configurer dashboard
# CPU, RAM, connexions, latence
```

---

### 5.3 Configurer alertes

**Alertmanager** :
```bash
# Configurer alertes
# CPU > 80% : email
# RAM > 80% : email
# Connexions > 50 : email
```

---

## PHASE 6 : LANCEMENT (1 jour)

### 6.1 Mise à jour documentation

**Actions** :
- Mettre à jour politique de confidentialité
- Ajouter section Bobodo Vocal
- Mettre à jour FAQ

---

### 6.2 Communication utilisateurs

**Actions** :
- Annonce in-app
- Notification push
- Email newsletter
- Réseaux sociaux

---

### 6.3 Monitoring initial

**Actions** :
- Surveillance métriques (24h)
- Logs erreurs
- Feedback utilisateurs
- Ajustements si nécessaire

---

## PHASE 7 : MAINTENANCE

### 7.1 Mises à jour

**STT/TTS** :
- Mise à jour modèles (mensuelle)
- Fine-tuning accents (trimestriel)

**Serveur** :
- Mise à jour OS (mensuelle)
- Mise à jour packages (mensuelle)

---

### 7.2 Sauvegardes

**Configuration** :
- Backup configuration Nginx
- Backup code source
- Backup logs (30 jours)

---

### 7.3 Support

**Incidents** :
- Processus escalade
- Communication utilisateurs
- Rapport post-incident

---

## RISQUES ET MITIGATIONS

### Risque 1 : Latence élevée

**Mitigation** :
- Monitoring latence
- Upgrade serveur si nécessaire
- Optimiser code

### Risque 2 : Surcharge serveur

**Mitigation** :
- Rate limiting
- Limite connexions
- Auto-scaling

### Risque 3 : Erreurs STT/TTS

**Mitigation** :
- Fallback texte
- Logs erreurs
- Retry automatique

---

## CALENDRIER

| Phase | Durée | Dates |
|-------|-------|-------|
| Phase 1 : Préparation serveur | 2 jours | J1-J2 |
| Phase 2 : Développement service | 5 jours | J3-J7 |
| Phase 3 : Développement Flutter | 5 jours | J8-J12 |
| Phase 4 : Tests | 3 jours | J13-J15 |
| Phase 5 : Déploiement | 2 jours | J16-J17 |
| Phase 6 : Lancement | 1 jour | J18 |
| **Total** | **18 jours** | **~3 semaines** |

---

## RESSOURCES

### Documentation

- Faster-Whisper : https://github.com/SYSTRAN/faster-whisper
- Piper : https://github.com/rhasspy/piper
- FastAPI : https://fastapi.tiangolo.com
- WebSocket : https://websockets.readthedocs.io

### Support

- Kamatera : support@kamatera.com
- Supabase : support@supabase.com

---

**DOCUMENT TERMINÉ**
