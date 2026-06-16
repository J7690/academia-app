"""
Bobodo Vocal - STT Service v3
Speech-to-Text with Faster Whisper Small — Multi-Session + Dictionnaire Academia
"""

import logging
import asyncio
import tempfile
import os
import traceback
import struct
import time
import re
from typing import Optional
from faster_whisper import WhisperModel


logger = logging.getLogger(__name__)


# ─── DICTIONNAIRE ACADEMIA ─────────────────────────────────────────────────────
# Corrections post-transcription pour le vocabulaire spécifique Academia/Burkina.
# Appliqué après chaque transcription Whisper.

ACADEMIA_DICTIONARY = {
    # Plateforme
    "l'académie": "Academia",
    "l'academie": "Academia",
    "académie": "Academia",
    "academie": "Academia",
    "académia": "Academia",
    "academia": "Academia",
    # Assistant
    "bob au dos": "Bobodo",
    "bob odo": "Bobodo",
    "bobo do": "Bobodo",
    "bobodo": "Bobodo",
    # Universités
    "kizerbo": "Ki-Zerbo",
    "ki zerbo": "Ki-Zerbo",
    "kisebo": "Ki-Zerbo",
    "ki-zerbo": "Ki-Zerbo",
    # Entreprise
    "nexium": "Nexiom",
    "nexion": "Nexiom",
    "nexyom": "Nexiom",
    # Villes / Pays
    "ouaga": "Ouagadougou",
    "ouagadougou": "Ouagadougou",
    "koudougou": "Koudougou",
    "bobo-dioulasso": "Bobo-Dioulasso",
    "bobo dioulasso": "Bobo-Dioulasso",
    "burkina fasso": "Burkina Faso",
}


def apply_dictionary(text: str) -> tuple[str, list[str]]:
    """Apply Academia dictionary corrections. Returns (corrected_text, list of corrections applied)."""
    corrections = []
    result = text
    for wrong, correct in ACADEMIA_DICTIONARY.items():
        pattern = re.compile(re.escape(wrong), re.IGNORECASE)
        if pattern.search(result):
            result = pattern.sub(correct, result)
            corrections.append(f"'{wrong}' → '{correct}'")
    return result, corrections


class STTSession:
    """Isolated STT session — one per WebSocket connection"""

    def __init__(self, session_id: str, callback, model, sample_rate: int = 16000):
        self.session_id = session_id
        self.audio_buffer = bytearray()
        self.sample_rate = sample_rate
        self.bytes_per_sample = 2
        self.silence_threshold_ms = 800
        self.min_audio_duration = 0.5
        self.last_audio_time = None
        self.silence_task = None
        self.transcription_callback = callback
        self.model = model
        self.lock = asyncio.Lock()
        logger.info(f"[STT_SESSION] Created session {session_id}")

    async def append_audio(self, audio_bytes: bytes):
        async with self.lock:
            self.audio_buffer.extend(audio_bytes)
            current_duration = len(self.audio_buffer) / (self.sample_rate * self.bytes_per_sample)
            self.last_audio_time = time.time()
            logger.info(f"[STT_SESSION:{self.session_id}] Buffer: {len(self.audio_buffer)} bytes, {current_duration:.2f}s")

            if self.silence_task and not self.silence_task.done():
                self.silence_task.cancel()

            self.silence_task = asyncio.create_task(self._wait_for_silence())

    async def _wait_for_silence(self) -> Optional[str]:
        try:
            await asyncio.sleep(self.silence_threshold_ms / 1000.0)
            if self.last_audio_time:
                time_since_last_audio = (time.time() - self.last_audio_time) * 1000
                if time_since_last_audio >= self.silence_threshold_ms:
                    return await self._detect_silence()
                else:
                    remaining = (self.silence_threshold_ms - time_since_last_audio) / 1000.0
                    self.silence_task = asyncio.create_task(self._wait_for_silence())
                    return None
            else:
                return None
        except asyncio.CancelledError:
            return None

    async def _detect_silence(self) -> Optional[str]:
        current_duration = len(self.audio_buffer) / (self.sample_rate * self.bytes_per_sample)
        logger.info(f"[STT_SESSION:{self.session_id}] Silence detected, buffer: {current_duration:.2f}s")

        if current_duration < self.min_audio_duration:
            self.audio_buffer.clear()
            self.last_audio_time = None
            return None

        audio_to_transcribe = bytes(self.audio_buffer)
        self.audio_buffer.clear()
        self.last_audio_time = None

        wav_data = self._add_wav_header(audio_to_transcribe)

        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as temp_file:
            temp_file.write(wav_data)
            temp_path = temp_file.name

        t_stt_start = time.time()
        result = await self._transcribe_file(temp_path)
        t_stt_elapsed = (time.time() - t_stt_start) * 1000
        os.unlink(temp_path)

        # Apply dictionary corrections
        if result:
            corrected, corrections = apply_dictionary(result)
            if corrections:
                logger.info(f"[STT_DICT:{self.session_id}] Corrections: {', '.join(corrections)}")
                result = corrected

        logger.info(f"[STT_LATENCY:{self.session_id}] STT took {t_stt_elapsed:.0f}ms")

        if self.transcription_callback and result:
            await self.transcription_callback(result)

        return result

    def _add_wav_header(self, raw_pcm: bytes) -> bytes:
        data_size = len(raw_pcm)
        total_size = 36 + data_size
        byte_rate = self.sample_rate * 1 * 16 // 8
        block_align = 1 * 16 // 8
        header = struct.pack('<4sI4s', b'RIFF', total_size, b'WAVE')
        fmt_chunk = struct.pack('<4sIHHIIHH',
                                b'fmt ', 16, 1, 1,
                                self.sample_rate, byte_rate, block_align, 16)
        data_chunk_header = struct.pack('<4sI', b'data', data_size)
        return header + fmt_chunk + data_chunk_header + raw_pcm

    async def _transcribe_file(self, audio_path: str) -> Optional[str]:
        if not self.model:
            logger.error("[STT_ERROR] Model not loaded")
            return None
        try:
            segments, info = self.model.transcribe(
                audio_path, language="fr", beam_size=5, vad_filter=False
            )
            transcription = ""
            for segment in segments:
                transcription += segment.text + " "
            text = transcription.strip()
            logger.info(f"[STT_SESSION:{self.session_id}] Raw: '{text}' (duration={info.duration:.2f}s)")
            return text
        except Exception as e:
            logger.error(f"[STT_SESSION:{self.session_id}] Transcription error: {e}")
            logger.error(traceback.format_exc())
            return None

    def cleanup(self):
        if self.silence_task and not self.silence_task.done():
            self.silence_task.cancel()
        self.audio_buffer.clear()
        self.transcription_callback = None
        self.last_audio_time = None
        logger.info(f"[STT_SESSION] Destroyed session {self.session_id}")


class STTService:
    """STT Service — factory and registry for isolated STT sessions"""

    def __init__(self, model_size: str = "small", device: str = "cpu", compute_type: str = "int8"):
        self.model_size = model_size
        self.device = device
        self.compute_type = compute_type
        self.model = None
        self.sessions = {}
        self.lock = asyncio.Lock()
        self._load_model()

    def _load_model(self):
        try:
            t_start = time.time()
            logger.info(f"[STT_MODEL_LOADING] Loading Faster Whisper '{self.model_size}' (device={self.device}, compute={self.compute_type})...")
            self.model = WhisperModel(
                self.model_size, device=self.device, compute_type=self.compute_type
            )
            t_elapsed = (time.time() - t_start) * 1000
            logger.info(f"[STT_MODEL_READY] Model '{self.model_size}' loaded in {t_elapsed:.0f}ms")
        except Exception as e:
            logger.error(f"[STT_MODEL_ERROR] {e}")
            logger.error(traceback.format_exc())
            raise

    def create_session(self, session_id: str, callback) -> STTSession:
        session = STTSession(session_id, callback, self.model)
        self.sessions[session_id] = session
        logger.info(f"[STT_SERVICE] Registered session {session_id}. Active: {len(self.sessions)}")
        return session

    def destroy_session(self, session_id: str):
        if session_id in self.sessions:
            self.sessions[session_id].cleanup()
            del self.sessions[session_id]
            logger.info(f"[STT_SERVICE] Removed session {session_id}. Active: {len(self.sessions)}")

    async def transcribe(self, session_id: str, audio_bytes: bytes) -> Optional[str]:
        session = self.sessions.get(session_id)
        if not session:
            logger.error(f"[STT_SERVICE] Session {session_id} not found")
            return None
        await session.append_audio(audio_bytes)
        return None

    async def cleanup_inactive_sessions(self, max_idle_seconds: float = 300.0):
        now = time.time()
        to_remove = []
        for sid, session in self.sessions.items():
            if session.last_audio_time and (now - session.last_audio_time) > max_idle_seconds:
                to_remove.append(sid)
        for sid in to_remove:
            logger.info(f"[STT_SERVICE] Cleaning inactive session {sid}")
            self.destroy_session(sid)
