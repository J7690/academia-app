# Bobodo Vocal Service

WebSocket service for voice interaction with Bobodo AI assistant.

## Architecture

```
Flutter App → WebSocket → STT (Faster Whisper) → Bobodo Edge Function → TTS (Piper) → Flutter App
```

## Features

- Real-time speech-to-text transcription using Faster Whisper Medium
- Text-to-speech synthesis using Piper
- Seamless integration with Bobodo Edge Function
- Session management for conversation continuity
- Hybrid text + voice support

## Prerequisites

- Python 3.11+
- Docker
- Kamatera VPS (4 vCPU, 8 GB RAM recommended)

## Installation

### 1. Clone repository

```bash
git clone <repository-url>
cd bobodo-vocal
```

### 2. Configure environment

```bash
cp .env.example .env
# Edit .env with your credentials
```

### 3. Download models

```bash
mkdir -p models
cd models

# Download Faster Whisper Medium
wget https://huggingface.co/guillaumekln/faster-whisper-medium/resolve/main/model.bin
wget https://huggingface.co/guillaumekln/faster-whisper-medium/resolve/main/config.json

# Download Piper Medium French
mkdir -p fr_FR-medium
cd fr_FR-medium
wget https://huggingface.co/rhasspy/piper-voices/v1.0.0/fr/fr_FR-medium/resolve/main/model.onnx
wget https://huggingface.co/rhasspy/piper-voices/v1.0.0/fr/fr_FR-medium/resolve/main/config.json
```

### 4. Build and run with Docker

```bash
docker-compose build
docker-compose up -d
```

## API Endpoints

### WebSocket

**URL**: `ws://<server-ip>:8000/ws`

**Message format (client → server)**:
```json
{
  "type": "audio",
  "session_id": "uuid",
  "audio": "base64_encoded_audio_bytes"
}
```

**Message format (server → client - transcription)**:
```json
{
  "type": "transcription",
  "text": "transcribed text"
}
```

**Message format (server → client - audio response)**:
```json
{
  "type": "audio_response",
  "audio": "base64_encoded_audio_bytes"
}
```

### Health Check

**URL**: `http://<server-ip>:8000/health`

**Response**:
```json
{
  "status": "healthy",
  "stt_loaded": true,
  "tts_loaded": true
}
```

## Development

### Run locally

```bash
pip install -r requirements.txt
uvicorn main:app --reload
```

### Run tests

```bash
pytest tests/
```

## Monitoring

Check logs:
```bash
docker-compose logs -f
```

Check resource usage:
```bash
docker stats
```

## Troubleshooting

### Model not found

Ensure models are downloaded in the `models/` directory with the correct structure.

### WebSocket connection failed

Check firewall rules:
```bash
ufw allow 8000/tcp
```

### Out of memory

Reduce the number of concurrent users or upgrade server resources.

## License

Proprietary - Academia Learning Engine
