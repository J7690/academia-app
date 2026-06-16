# BOBODO_WS_ROUTE_DISCOVERY

## Mission 1 — grep routes websocket


### app_websocket
```bash
grep -R '@app.websocket' /opt/bobodo-vocal/
```

**Exit:** 0
```
/opt/bobodo-vocal/main.py:@app.websocket("/ws")
/opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/applications.py:        @app.websocket("/ws")
/opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/exceptions.py:    @app.websocket("/items/{item_id}/ws")
/opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/applications.py:        @app.websocket("/ws")
/opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/exceptions.py:    @app.websocket("/items/{item_id}/ws")
```
**STDERR:** grep: /opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/__pycache__/applications.cpython-312.pyc: binary file matches
grep: /opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/__pycache__/exceptions.cpython-312.pyc: binary file matches
grep: /opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/__pycache__/applications.cpython-312.pyc: binary file matches
grep: /opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/__pycache__/exceptions.cpython-312.pyc: binary file matches

### router_websocket
```bash
grep -R '@router.websocket' /opt/bobodo-vocal/
```

**Exit:** 0
```
/opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/routing.py:        @router.websocket("/ws")
/opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/routing.py:        @router.websocket("/ws")
```
**STDERR:** grep: /opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/__pycache__/routing.cpython-312.pyc: binary file matches
grep: /opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/__pycache__/routing.cpython-312.pyc: binary file matches

### websocket_all_py
```bash
grep -R 'websocket' /opt/bobodo-vocal/*.py
```

**Exit:** 0
```
/opt/bobodo-vocal/main.py:from websocket_handler import WebSocketHandler
/opt/bobodo-vocal/main.py:    websocket_host: str = "0.0.0.0"
/opt/bobodo-vocal/main.py:    websocket_port: int = 8000
/opt/bobodo-vocal/main.py:@app.websocket("/ws")
/opt/bobodo-vocal/main.py:async def websocket_endpoint(websocket: WebSocket):
/opt/bobodo-vocal/main.py:    handler = WebSocketHandler(websocket, stt_service, tts_service, settings)
/opt/bobodo-vocal/main.py:        host=settings.websocket_host,
/opt/bobodo-vocal/main.py:        port=settings.websocket_port,
/opt/bobodo-vocal/websocket_handler.py:from starlette.websockets import WebSocketDisconnect
/opt/bobodo-vocal/websocket_handler.py:        websocket: WebSocket,
/opt/bobodo-vocal/websocket_handler.py:        self.websocket = websocket
/opt/bobodo-vocal/websocket_handler.py:        await self.websocket.accept()
/opt/bobodo-vocal/websocket_handler.py:                data = await self.websocket.receive_text()
/opt/bobodo-vocal/websocket_handler.py:        await self.websocket.send_text(json.dumps(message))
```

### WebSocket_class
```bash
grep -R 'WebSocket' /opt/bobodo-vocal/*.py
```

**Exit:** 0
```
/opt/bobodo-vocal/main.py:WebSocket server for voice interaction with Bobodo
/opt/bobodo-vocal/main.py:from fastapi import FastAPI, WebSocket, WebSocketDisconnect
/opt/bobodo-vocal/main.py:from websocket_handler import WebSocketHandler
/opt/bobodo-vocal/main.py:    description="WebSocket service for voice interaction with Bobodo",
/opt/bobodo-vocal/main.py:# WebSocket endpoint
/opt/bobodo-vocal/main.py:async def websocket_endpoint(websocket: WebSocket):
/opt/bobodo-vocal/main.py:    """WebSocket endpoint for voice interaction"""
/opt/bobodo-vocal/main.py:    handler = WebSocketHandler(websocket, stt_service, tts_service, settings)
/opt/bobodo-vocal/websocket_handler.py:Bobodo Vocal - WebSocket Handler
/opt/bobodo-vocal/websocket_handler.py:Handles WebSocket connections and message routing
/opt/bobodo-vocal/websocket_handler.py:from fastapi import WebSocket
/opt/bobodo-vocal/websocket_handler.py:from starlette.websockets import WebSocketDisconnect
/opt/bobodo-vocal/websocket_handler.py:class WebSocketHandler:
/opt/bobodo-vocal/websocket_handler.py:    """WebSocket connection handler"""
/opt/bobodo-vocal/websocket_handler.py:        websocket: WebSocket,
/opt/bobodo-vocal/websocket_handler.py:        """Handle WebSocket connection"""
/opt/bobodo-vocal/websocket_handler.py:        logger.info("WebSocket connection established")
/opt/bobodo-vocal/websocket_handler.py:        except WebSocketDisconnect:
/opt/bobodo-vocal/websocket_handler.py:            logger.info("WebSocket connection closed")
/opt/bobodo-vocal/websocket_handler.py:            logger.error(f"WebSocket error: {e}")
```

### add_api_ws
```bash
grep -R 'add_api_websocket_route' /opt/bobodo-vocal/
```

**Exit:** 0
```
/opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/routing.py:    def add_api_websocket_route(
/opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/routing.py:            self.add_api_websocket_route(
/opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/routing.py:                self.add_api_websocket_route(
/opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/applications.py:    def add_api_websocket_route(
/opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/applications.py:        self.router.add_api_websocket_route(
/opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/applications.py:            self.add_api_websocket_route(
/opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/routing.py:    def add_api_websocket_route(
/opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/routing.py:            self.add_api_websocket_route(
/opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/routing.py:                self.add_api_websocket_route(
/opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/applications.py:    def add_api_websocket_route(
/opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/applications.py:        self.router.add_api_websocket_route(
/opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/applications.py:            self.add_api_websocket_route(
```
**STDERR:** grep: /opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/__pycache__/applications.cpython-312.pyc: binary file matches
grep: /opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/__pycache__/routing.cpython-312.pyc: binary file matches
grep: /opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/__pycache__/applications.cpython-312.pyc: binary file matches
grep: /opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/__pycache__/routing.cpython-312.pyc: binary file matches

### include_router
```bash
grep -R 'include_router' /opt/bobodo-vocal/
```

**Exit:** 0
```
/opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/routing.py:    app.include_router(router)
/opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/routing.py:        app.include_router(router)
/opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/routing.py:    def include_router(
/opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/routing.py:        internal_router.include_router(users_router)
/opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/routing.py:        app.include_router(internal_router)
/opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/routing.py:        app.include_router(router)
/opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/routing.py:        app.include_router(router)
/opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/routing.py:        app.include_router(router)
/opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/routing.py:        app.include_router(router)
/opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/routing.py:        app.include_router(router)
/opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/routing.py:        app.include_router(router)
/opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/routing.py:        app.include_router(router)
/opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/routing.py:        app.include_router(router)
/opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/applications.py:    def include_router(
/opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/applications.py:                app.include_router(
/opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/applications.py:                app.include_router(
/opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/applications.py:                app.include_router(
/opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/applications.py:                app.include_router(
/opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/applications.py:        app.include_router(users_router)
/opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/applications.py:        self.router.include_router(
/opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/routing.py:    app.include_router(router)
/opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/routing.py:        app.include_router(router)
/opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/routing.py:    def include_router(
/opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/routing.py:        internal_router.include_router(users_router)
/opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/routing.py:        app.include_router(internal_router)
/opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/routing.py:        app.include_router(router)
/opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/routing.py:        app.include_router(router)
/opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/routing.py:        app.include_router(router)
/opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/routing.py:        app.include_router(router)
/opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/routing.py:        app.include_router(router)
/opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/routing.py:        app.include_router(router)
/opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/routing.py:        app.include_router(router)
/opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/routing.py:        app.include_router(router)
/opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/applications.py:    def include_router(
/opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/applications.py:                app.include_router(
/opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/applications.py:                app.include_router(
/opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/applications.py:                app.include_router(
/opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/applications.py:                app.include_router(
/opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/applications.py:        app.include_router(users_router)
/opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/applications.py:        self.router.include_router(
```
**STDERR:** grep: /opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/__pycache__/applications.cpython-312.pyc: binary file matches
grep: /opt/bobodo-vocal/venv/lib64/python3.12/site-packages/fastapi/__pycache__/routing.cpython-312.pyc: binary file matches
grep: /opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/__pycache__/applications.cpython-312.pyc: binary file matches
grep: /opt/bobodo-vocal/venv/lib/python3.12/site-packages/fastapi/__pycache__/routing.cpython-312.pyc: binary file matches

### fastapi_decl
```bash
grep -R 'FastAPI' /opt/bobodo-vocal/*.py
```

**Exit:** 0
```
/opt/bobodo-vocal/main.py:Bobodo Vocal - Main FastAPI Application
/opt/bobodo-vocal/main.py:from fastapi import FastAPI, WebSocket, WebSocketDisconnect
/opt/bobodo-vocal/main.py:async def lifespan(app: FastAPI):
/opt/bobodo-vocal/main.py:# FastAPI app
/opt/bobodo-vocal/main.py:app = FastAPI(
```

---

# BOBODO_WS_REGISTRATION

## Mission 2 — Contenu exact fichiers


### main_py_full
```bash
cat /opt/bobodo-vocal/main.py
```

**Exit:** 0
```python
"""
Bobodo Vocal - Main FastAPI Application
WebSocket server for voice interaction with Bobodo
"""

import os
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic_settings import BaseSettings
from dotenv import load_dotenv

# Charger les variables d'environnement depuis .env
load_dotenv()

from websocket_handler import WebSocketHandler
from stt_service import STTService
from tts_service import TTSService


# Configuration
class Settings(BaseSettings):
    supabase_url: str = ""
    supabase_service_role_key: str = ""
    openrouter_api_key: str = ""
    openrouter_model: str = "google/gemini-2.5-flash"
    openrouter_embedding_model: str = "openai/text-embedding-3-small"
    whisper_model: str = "tiny"
    whisper_device: str = "cpu"
    whisper_quantization: str = "int8"
    piper_model: str = "medium"
    piper_voice: str = "fr_FR-medium"
    websocket_host: str = "0.0.0.0"
    websocket_port: int = 8000
    log_level: str = "INFO"

    class Config:
        env_file = ".env"
        extra = "ignore"  # Permettre les champs supplémentaires


settings = Settings()

# Logging configuration
logging.basicConfig(
    level=getattr(logging, settings.log_level),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


# Services initialization
stt_service = None
tts_service = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize and cleanup services"""
    global stt_service, tts_service
    
    logger.info("Starting Bobodo Vocal service...")
    
    # Initialize STT service (placeholder mode)
    logger.info("Initializing STT service (placeholder mode)")
    stt_service = STTService()
    
    # Initialize TTS service
    logger.info("Initializing TTS service")
    tts_service = TTSService()
    
    logger.info("Bobodo Vocal service started successfully")
    
    yield
    
    logger.info("Shutting down Bobodo Vocal service...")
    # Cleanup services if needed
    logger.info("Bobodo Vocal service stopped")


# FastAPI app
app = FastAPI(
    title="Bobodo Vocal",
    description="WebSocket service for voice interaction with Bobodo",
    version="1.0.0",
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "stt_loaded": stt_service is not None,
        "tts_loaded": tts_service is not None
    }


# WebSocket endpoint
@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for voice interaction"""
    handler = WebSocketHandler(websocket, stt_service, tts_service, settings)
    await handler.handle()


if __name__ == "__main__":
    import uvicorn
    
    uvicorn.run(
        "main:app",
        host=settings.websocket_host,
        port=settings.websocket_port,
        reload=False
    )
```

### websocket_handler_full
```bash
cat /opt/bobodo-vocal/websocket_handler.py
```

**Exit:** 0
```python
"""
Bobodo Vocal - WebSocket Handler
Handles WebSocket connections and message routing
"""

import json
import logging
import base64
import traceback
from typing import Optional
from fastapi import WebSocket
from starlette.websockets import WebSocketDisconnect

from stt_service import STTService
from tts_service import TTSService
from bobodo_client import BobodoClient


logger = logging.getLogger(__name__)


class WebSocketHandler:
    """WebSocket connection handler"""

    def __init__(
        self,
        websocket: WebSocket,
        stt_service: STTService,
        tts_service: TTSService,
        settings
    ):
        self.websocket = websocket
        self.stt_service = stt_service
        self.tts_service = tts_service
        self.settings = settings
        self.bobodo_client = BobodoClient(settings)
        self.session_id: Optional[str] = None
        # Register transcription callback
        self.stt_service.set_transcription_callback(self._on_transcription_complete)
        
    async def handle(self):
        """Handle WebSocket connection"""
        await self.websocket.accept()
        logger.info("WebSocket connection established")
        
        try:
            while True:
                # Receive message from client
                data = await self.websocket.receive_text()
                message = json.loads(data)
                
                # Process message based on type
                message_type = message.get("type")
                
                if message_type == "audio":
                    await self.handle_audio(message)
                elif message_type == "session_id":
                    await self.handle_session_id(message)
                elif message_type == "ping":
                    await self.handle_ping()
                else:
                    logger.warning(f"Unknown message type: {message_type}")
                    await self.send_error(f"Unknown message type: {message_type}")
                    
        except WebSocketDisconnect:
            logger.info("WebSocket connection closed")
        except Exception as e:
            logger.error(f"WebSocket error: {e}")
            await self.send_error(str(e))
            
    async def handle_audio(self, message: dict):
        """Handle audio message from client"""
        try:
            # Extract audio data
            audio_base64 = message.get("audio")
            if not audio_base64:
                logger.error("[WS_AUDIO_ERROR] No audio data provided")
                await self.send_error("No audio data provided")
                return

            # Decode base64 audio
            audio_bytes = base64.b64decode(audio_base64)
            logger.info(f"[WS_AUDIO_RECEIVED] Audio decoded: {len(audio_bytes)} bytes")

            # Send audio to STT service (accumulates in buffer, triggers transcription after silence)
            await self.stt_service.transcribe(audio_bytes)

            # Transcription will be handled asynchronously via callback

        except Exception as e:
            logger.error(f"[WS_AUDIO_ERROR] Error handling audio: {type(e).__name__}: {e}")
            logger.error(f"[WS_AUDIO_ERROR] Stacktrace: {traceback.format_exc()}")
            await self.send_error(str(e))

    async def _on_transcription_complete(self, transcription: str):
        """Handle transcription completion callback"""
        try:
            logger.info(f"[WS_STT_CALLBACK] Transcription completed: {transcription}")

            # Send transcription to client
            await self.send_transcription(transcription)

            # Send transcription to Bobodo
            if not self.session_id:
                logger.error("[WS_SESSION_ERROR] No session ID provided")
                await self.send_error("No session ID provided")
                return

            logger.info("[WS_BOBODO_START] Sending transcription to Bobodo...")
            response = await self.bobodo_client.send_message(
                session_id=self.session_id,
                message=transcription
            )

            if not response:
                logger.error("[WS_BOBODO_ERROR] Bobodo response failed")
                await self.send_error("Bobodo response failed")
                return

            logger.info(f"[WS_BOBODO_SUCCESS] Bobodo response: {response}")

            # Synthesize audio using TTS
            logger.info("[WS_TTS_START] Synthesizing audio...")
            audio_response = await self.tts_service.synthesize(response)

            if not audio_response:
                logger.error("[WS_TTS_ERROR] TTS synthesis failed")
                await self.send_error("TTS synthesis failed")
                return

            # Send audio response to client
            await self.send_audio_response(audio_response)

        except Exception as e:
            logger.error(f"[WS_STT_CALLBACK_ERROR] Error in transcription callback: {type(e).__name__}: {e}")
            logger.error(f"[WS_STT_CALLBACK_ERROR] Stacktrace: {traceback.format_exc()}")
            await self.send_error(str(e))
            
    async def handle_session_id(self, message: dict):
        """Handle session ID message"""
        self.session_id = message.get("session_id")
        logger.info(f"Session ID set: {self.session_id}")
        
    async def handle_ping(self):
        """Handle ping message"""
        await self.send_message({"type": "pong"})
        
    async def send_transcription(self, text: str):
        """Send transcription to client"""
        await self.send_message({
            "type": "transcription",
            "text": text
        })
        
    async def send_audio_response(self, audio_bytes: bytes):
        """Send audio response to client"""
        audio_base64 = base64.b64encode(audio_bytes).decode("utf-8")
        await self.send_message({
            "type": "audio_response",
            "audio": audio_base64
        })
        
    async def send_error(self, message: str):
        """Send error to client"""
        await self.send_message({
            "type": "error",
            "message": message
        })
        
    async def send_message(self, message: dict):
        """Send message to client"""
        await self.websocket.send_text(json.dumps(message))
```