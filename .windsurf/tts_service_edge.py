"""
Bobodo Vocal - TTS Service v2
Text-to-Speech using Edge-TTS (Microsoft Neural Voices)
Fallback to gTTS if Edge-TTS fails.
"""

import logging
import asyncio
import os
import time
import tempfile
from typing import Optional

logger = logging.getLogger(__name__)


class TTSService:
    """Text-to-Speech service using Edge-TTS with gTTS fallback"""

    def __init__(self, voice: str = "fr-FR-DeniseNeural", language: str = "fr"):
        self.voice = voice
        self.language = language
        self._edge_available = True
        logger.info(f"[TTS_INIT] TTS service initialized: voice={voice}, fallback=gTTS")

    async def synthesize(self, text: str) -> Optional[bytes]:
        """
        Synthesize text to audio bytes (MP3).
        Uses Edge-TTS primarily, falls back to gTTS on failure.
        """
        t_start = time.time()

        # Try Edge-TTS first
        if self._edge_available:
            result = await self._synthesize_edge(text)
            if result:
                elapsed = (time.time() - t_start) * 1000
                logger.info(f"[TTS_EDGE] Synthesis completed in {elapsed:.0f}ms ({len(result)} bytes)")
                return result

        # Fallback to gTTS
        result = await self._synthesize_gtts(text)
        if result:
            elapsed = (time.time() - t_start) * 1000
            logger.info(f"[TTS_GTTS_FALLBACK] Synthesis completed in {elapsed:.0f}ms ({len(result)} bytes)")
        return result

    async def _synthesize_edge(self, text: str) -> Optional[bytes]:
        """Synthesize using Edge-TTS (Microsoft Neural Voice)."""
        try:
            import edge_tts

            communicate = edge_tts.Communicate(text, self.voice)
            temp_path = tempfile.mktemp(suffix=".mp3")

            await communicate.save(temp_path)

            with open(temp_path, "rb") as f:
                audio_bytes = f.read()

            os.remove(temp_path)
            return audio_bytes

        except ImportError:
            logger.warning("[TTS_EDGE] edge-tts not installed, using gTTS fallback")
            self._edge_available = False
            return None
        except Exception as e:
            logger.error(f"[TTS_EDGE_ERROR] Edge-TTS failed: {e}, using gTTS fallback")
            return None

    async def _synthesize_gtts(self, text: str) -> Optional[bytes]:
        """Synthesize using gTTS (Google TTS) as fallback."""
        try:
            from gtts import gTTS

            tts = gTTS(text=text, lang=self.language, slow=False)
            temp_path = tempfile.mktemp(suffix=".mp3")
            tts.save(temp_path)

            with open(temp_path, "rb") as f:
                audio_bytes = f.read()

            os.remove(temp_path)
            return audio_bytes

        except Exception as e:
            logger.error(f"[TTS_GTTS_ERROR] gTTS failed: {e}")
            return None

    async def synthesize_to_file(self, text: str, output_path: str) -> bool:
        """Synthesize text to audio file."""
        try:
            audio_bytes = await self.synthesize(text)
            if audio_bytes:
                with open(output_path, "wb") as f:
                    f.write(audio_bytes)
                return True
            return False
        except Exception as e:
            logger.error(f"[TTS_ERROR] File synthesis failed: {e}")
            return False
