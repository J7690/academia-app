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
