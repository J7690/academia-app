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
