"""
Bobodo Vocal - TTS Service
Text-to-Speech service using Piper TTS
Optimized for low latency and French language
"""

import logging
import asyncio
from typing import Optional
import io


logger = logging.getLogger(__name__)


class TTSService:
    """Text-to-Speech service using Piper TTS"""

    def __init__(self, language: str = "fr", model_path: str = "/opt/bobodo-vocal/models/fr_FR-siwis-low.onnx"):
        """
        Initialize TTS service

        Args:
            language: Language code (fr, en, etc.)
            model_path: Path to Piper TTS model
        """
        self.language = language
        self.model_path = model_path
        self.piper = None
        logger.info(f"TTS service initialized with language: {language}")
        logger.info(f"TTS model path: {model_path}")
        self._load_model()

    def _load_model(self):
        """Load Piper TTS model"""
        try:
            from piper import PiperVoice
            logger.info(f"[TTS_MODEL_LOADING] Loading Piper TTS model from {self.model_path}...")
            self.piper = PiperVoice.load(self.model_path)
            logger.info("[TTS_MODEL_READY] Piper TTS model loaded successfully")
        except ImportError:
            logger.error("[TTS_MODEL_ERROR] Piper not installed. Falling back to gTTS.")
            logger.error("[TTS_MODEL_ERROR] Install with: pip install piper-tts")
            self.piper = None
        except Exception as e:
            logger.error(f"[TTS_MODEL_ERROR] Error loading Piper model: {e}")
            self.piper = None

    async def synthesize(self, text: str) -> Optional[bytes]:
        """
        Synthesize text to audio bytes

        Args:
            text: Text to synthesize

        Returns:
            Audio bytes (WAV) or None if failed
        """
        try:
            logger.info(f"[TTS_SYNTHESIS] Synthesizing text: {text[:50]}...")

            if self.piper:
                # Use Piper TTS (in-memory, no file I/O)
                import numpy as np

                # Synthesize audio
                audio_array = self.piper.synthesize(text, self.piper.config)

                # Convert to WAV bytes in memory
                audio_bytes = self._array_to_wav(audio_array, self.piper.config.sample_rate)

                logger.info("[TTS_SYNTHESIS] Piper synthesis completed")
                return audio_bytes
            else:
                # Fallback to gTTS if Piper not available
                logger.warning("[TTS_FALLBACK] Using gTTS as fallback")
                return await self._synthesize_with_gtts(text)

        except Exception as e:
            logger.error(f"[TTS_SYNTHESIS_ERROR] Synthesis failed: {e}")
            return None

    async def _synthesize_with_gtts(self, text: str) -> Optional[bytes]:
        """Fallback to gTTS if Piper not available"""
        try:
            from gtts import gTTS
            import os

            logger.info("[TTS_GTTS] Using gTTS fallback")

            tts = gTTS(text=text, lang=self.language, slow=False)
            temp_path = "/tmp/tts_output.mp3"
            tts.save(temp_path)

            with open(temp_path, "rb") as f:
                audio_bytes = f.read()

            os.remove(temp_path)

            logger.info("[TTS_GTTS] gTTS synthesis completed")
            return audio_bytes

        except Exception as e:
            logger.error(f"[TTS_GTTS_ERROR] gTTS fallback failed: {e}")
            return None

    def _array_to_wav(self, audio_array, sample_rate: int) -> bytes:
        """Convert numpy audio array to WAV bytes in memory"""
        import struct
        import wave

        audio_buffer = io.BytesIO()

        with wave.open(audio_buffer, 'wb') as wav_file:
            wav_file.setnchannels(1)  # Mono
            wav_file.setsampwidth(2)  # 16-bit
            wav_file.setframerate(sample_rate)
            wav_file.writeframes(audio_array.tobytes())

        audio_buffer.seek(0)
        return audio_buffer.read()
            
    async def synthesize_to_file(self, text: str, output_path: str) -> bool:
        """
        Synthesize text to audio file
        
        Args:
            text: Text to synthesize
            output_path: Path to output audio file
            
        Returns:
            True if successful, False otherwise
        """
        try:
            logger.info(f"Synthesizing to file: {output_path}")
            
            # Create gTTS object
            tts = gTTS(text=text, lang=self.language, slow=False)
            
            # Save to file
            tts.save(output_path)
            
            logger.info("Synthesis completed")
            
            return True
            
        except Exception as e:
            logger.error(f"File synthesis failed: {e}")
            return False
