# BOBODO VOICE - Server Changes

## Date
12 Juin 2026

---

## OBJECTIF

Documenter les modifications serveur requises pour l'intégration Piper TTS.

---

## SERVEUR CIBLE

**Adresse** : 185.167.97.144:8000

**OS** : Linux (Kamatera)

**Architecture** : CPU only (pas de GPU)

---

## ÉTAT ACTUEL

### TTS Actuel

**Moteur** : gTTS (Google Text-to-Speech)

**Fichier** : `tts_service.py`

**Flux** :
1. Réception texte via WebSocket
2. Appel gTTS
3. Génération audio
4. Encodage base64
5. Envoi audio via WebSocket

**Problème** :
- gTTS 404 error (déjà rencontré)
- Latence élevée
- Dépendance Internet

---

## MODIFICATIONS REQUISES

### 1. Installation Piper TTS

**Commandes** :
```bash
# Mise à jour pip
pip install --upgrade pip

# Installation Piper TTS
pip install piper-tts

# Installation espeak-ng (dépendance)
sudo apt-get install espeak-ng
```

**Risques** :
- Téléchargement Piper (404 HuggingFace)
- **Mitigation** : Utiliser mirror alternatif ou téléchargement manuel

---

### 2. Téléchargement Voix Française

**Voix recommandée** : fr_FR-siwis-medium

**Commandes** :
```bash
# Création dossier voix
mkdir -p /root/piper_voices

# Téléchargement voix
wget https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/fr/fr_FR/siwis/medium/fr_FR-siwis-medium.onnx -O /root/piper_voices/fr_FR-siwis-medium.onnx

wget https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/fr/fr_FR/siwis/medium/fr_FR-siwis-medium.onnx.json -O /root/piper_voices/fr_FR-siwis-medium.onnx.json
```

**Alternative** (si 404) :
```bash
# Téléchargement manuel depuis SourceForge
wget https://sourceforge.net/projects/piper-tts.mirror/files/v0.0.2/voice-fr-siwis-medium.tar.gz/download -O /root/piper_voices/voice-fr-siwis-medium.tar.gz

# Extraction
cd /root/piper_voices
tar -xzf voice-fr-siwis-medium.tar.gz
```

---

### 3. Modification tts_service.py

**Import Piper** :
```python
import piper_tts
import numpy as np
```

**Chargement modèle** :
```python
# Chargement modèle Piper
model_path = "/root/piper_voices/fr_FR-siwis-medium.onnx"
config_path = "/root/piper_voices/fr_FR-siwis-medium.onnx.json"

# Initialisation Piper
piper_model = piper_tts.PiperTTS(model_path, config_path)
```

**Fonction TTS** :
```python
def generate_tts_piper(text: str) -> bytes:
    """
    Génère audio avec Piper TTS.
    
    Args:
        text: Texte à convertir en audio
        
    Returns:
        bytes: Audio généré (WAV format)
    """
    try:
        # Génération audio
        audio = piper_model.synthesize(text)
        
        # Conversion en bytes
        audio_bytes = audio.tobytes()
        
        return audio_bytes
    except Exception as e:
        print(f"[TTS_PIPER_ERROR] {e}")
        raise
```

**Fallback gTTS** :
```python
def generate_tts(text: str) -> bytes:
    """
    Génère audio avec Piper TTS (fallback gTTS).
    
    Args:
        text: Texte à convertir en audio
        
    Returns:
        bytes: Audio généré (WAV format)
    """
    try:
        # Essai Piper TTS
        return generate_tts_piper(text)
    except Exception as e:
        print(f"[TTS_PIPER_FALLBACK] {e}")
        # Fallback gTTS
        return generate_tts_gtts(text)
```

---

### 4. Intégration WebSocket

**Modification handler WebSocket** :
```python
async def handle_websocket(websocket):
    """
    Handler WebSocket pour communication vocale.
    """
    try:
        async for message in websocket:
            data = json.loads(message)
            
            if data['type'] == 'text':
                # Génération TTS
                text = data['text']
                audio_bytes = generate_tts(text)
                
                # Encodage base64
                audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')
                
                # Envoi audio
                response = {
                    'type': 'audio_response',
                    'audio': audio_base64
                }
                await websocket.send(json.dumps(response))
                
    except Exception as e:
        print(f"[WS_ERROR] {e}")
```

---

### 5. Configuration Paramètres

**Vitesse** :
```python
# Configuration vitesse (speaking_rate)
speaking_rate = 1.0  # Vitesse normale

# Modification si nécessaire
piper_model.set_speaking_rate(speaking_rate)
```

**Hauteur** :
```python
# Configuration hauteur (pitch)
pitch = 1.0  # Hauteur normale

# Modification si nécessaire
piper_model.set_pitch(pitch)
```

---

### 6. Gestion Erreurs

**Erreur chargement modèle** :
```python
try:
    piper_model = piper_tts.PiperTTS(model_path, config_path)
except Exception as e:
    print(f"[TTS_MODEL_LOAD_ERROR] {e}")
    # Fallback gTTS
    piper_model = None
```

**Erreur génération** :
```python
def generate_tts(text: str) -> bytes:
    try:
        if piper_model is not None:
            return generate_tts_piper(text)
        else:
            return generate_tts_gtts(text)
    except Exception as e:
        print(f"[TTS_ERROR] {e}")
        return generate_tts_gtts(text)
```

---

### 7. Logging

**Logs** :
```python
import logging

# Configuration logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

logger = logging.getLogger('tts_service')

# Logs dans fonction TTS
logger.info(f"[TTS_REQUEST] Text length: {len(text)}")
logger.info(f"[TTS_SUCCESS] Audio generated: {len(audio_bytes)} bytes")
logger.error(f"[TTS_ERROR] {e}")
```

---

### 8. Tests

**Test génération** :
```python
# Test script
if __name__ == "__main__":
    test_text = "Bonjour, je suis Bobodo."
    audio_bytes = generate_tts(test_text)
    
    # Sauvegarde fichier test
    with open("/tmp/test_piper.wav", "wb") as f:
        f.write(audio_bytes)
    
    print(f"[TTS_TEST] Audio saved: {len(audio_bytes)} bytes")
```

**Test latence** :
```python
import time

start_time = time.time()
audio_bytes = generate_tts(test_text)
end_time = time.time()

latency = end_time - start_time
print(f"[TTS_LATENCY] {latency:.3f} seconds")
```

---

## RÉSUMÉ DES MODIFICATIONS

### Nouveaux fichiers
- Aucun (modification tts_service.py existant)

### Nouvelles dépendances
- piper-tts
- espeak-ng

### Nouvelles méthodes
- `generate_tts_piper()` : génération audio avec Piper
- `generate_tts()` : génération audio avec fallback gTTS

### Modifications existantes
- `tts_service.py` : intégration Piper TTS
- Handler WebSocket : envoi audio Piper

### Configuration
- Voix : fr_FR-siwis-medium
- Vitesse : speaking_rate = 1.0
- Hauteur : pitch = 1.0

---

## IMPACT SUR CODE EXISTANT

### Aucun impact sur :
- STT (Faster Whisper Small)
- WebSocket architecture
- Session management
- Bobodo chat logic

### Impact sur :
- TTS (remplacement gTTS par Piper)

---

## DÉPLOIEMENT

### Étapes
1. SSH sur Kamatera
2. Installation Piper TTS
3. Téléchargement voix française
4. Modification tts_service.py
5. Test génération audio
6. Test latence
7. Redémarrage serveur
8. Validation WebSocket

### Rollback
```bash
# Arrêt serveur
systemctl stop voice_server

# Restauration gTTS
git checkout tts_service.py

# Redémarrage serveur
systemctl start voice_server
```

---

## RISQUES

### Risque 1 : Téléchargement Piper (404 HuggingFace)

**Probabilité** : Moyenne
**Impact** : Élevé
**Mitigation** : Utiliser mirror alternatif ou téléchargement manuel

---

### Risque 2 : Installation espeak-ng

**Probabilité** : Faible
**Impact** : Moyen
**Mitigation** : Installation manuelle si apt-get échoue

---

### Risque 3 : Latence supérieure à 3s

**Probabilité** : Faible
**Impact** : Moyen
**Mitigation** : Optimisations si nécessaire

---

### Risque 4 : Fallback gTTS

**Probabilité** : Faible
**Impact** : Faible
**Mitigation** : Fallback automatique vers gTTS

---

## CRITÈRES DE SUCCÈS

1. ✅ Piper TTS installé
2. ✅ Voix française téléchargée
3. ✅ Génération audio fonctionnelle
4. ✅ Latence < 3s
5. ✅ Fallback gTTS fonctionnel
6. ✅ WebSocket intégré
7. ✅ Logs fonctionnels
8. ✅ Tests validés

---

## SIGN-OFF

**Document créé** : 12 Juin 2026
**Auteur** : Cascade AI
**Statut** : PRÊT POUR IMPLÉMENTATION
