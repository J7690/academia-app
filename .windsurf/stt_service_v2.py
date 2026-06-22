"""
Bobodo Vocal - STT Service v2
Speech-to-Text service with Faster Whisper — Multi-Session
"""

import logging
import asyncio
import tempfile
import os
import traceback
import wave
import struct
import time
from typing import Optional
from faster_whisper import WhisperModel


logger = logging.getLogger(__name__)


class STTSession:
    """Isolated STT session — one per WebSocket connection"""

    def __init__(self, session_id: str, callback, model, sample_rate: int = 16000):
        self.session_id = session_id
        self.audio_buffer = bytearray()
        self.sample_rate = sample_rate
        self.bytes_per_sample = 2
        self.silence_threshold_ms = 1000
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
                logger.info(f"[STT_SESSION:{self.session_id}] Silence detection cancelled")

            self.silence_task = asyncio.create_task(self._wait_for_silence())

    async def _wait_for_silence(self) -> Optional[str]:
        try:
            await asyncio.sleep(self.silence_threshold_ms / 1000.0)
            # Check without lock — slight race acceptable for timing
            if self.last_audio_time:
                time_since_last_audio = (time.time() - self.last_audio_time) * 1000
                if time_since_last_audio >= self.silence_threshold_ms:
                    return await self._detect_silence()
                else:
                    remaining = (self.silence_threshold_ms - time_since_last_audio) / 1000.0
                    logger.info(f"[STT_SESSION:{self.session_id}] Silence not confirmed ({time_since_last_audio:.0f}ms < {self.silence_threshold_ms}ms), rescheduling in {remaining:.2f}s")
                    self.silence_task = asyncio.create_task(self._wait_for_silence())
                    return None
            else:
                logger.info(f"[STT_SESSION:{self.session_id}] No audio in buffer")
                return None
        except asyncio.CancelledError:
            logger.info(f"[STT_SESSION:{self.session_id}] Silence detection cancelled")
            return None

    async def _detect_silence(self) -> Optional[str]:
        current_duration = len(self.audio_buffer) / (self.sample_rate * self.bytes_per_sample)
        logger.info(f"[STT_SESSION:{self.session_id}] Silence detected, buffer: {current_duration:.2f}s")

        if current_duration < self.min_audio_duration:
            logger.info(f"[STT_SESSION:{self.session_id}] Not enough audio, clearing")
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

        logger.info(f"[STT_SESSION:{self.session_id}] Temp file: {temp_path}, {os.path.getsize(temp_path)} bytes")

        result = await self._transcribe_file(temp_path)
        os.unlink(temp_path)
        logger.info(f"[STT_SESSION:{self.session_id}] Temp file cleaned")

        if self.transcription_callback and result:
            logger.info(f"[STT_SESSION:{self.session_id}] Calling callback")
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
            logger.info(f"[STT_SESSION:{self.session_id}] Transcribing {audio_path}")
            segments, info = self.model.transcribe(
                audio_path, language="fr", beam_size=5, vad_filter=False
            )
            logger.info(f"[STT_SESSION:{self.session_id}] Lang: {info.language}, Duration: {info.duration}s")
            transcription = ""
            segment_count = 0
            for segment in segments:
                transcription += segment.text + " "
                segment_count += 1
            text = transcription.strip()
            logger.info(f"[STT_SESSION:{self.session_id}] Transcription: {len(text)} chars, {segment_count} segments")
            logger.info(f"[STT_SESSION:{self.session_id}] Text: '{text}'")
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

    def __init__(self, model_size: str = "medium", device: str = "cpu", compute_type: str = "int8"):
        self.model_size = model_size
        self.device = device
        self.compute_type = compute_type
        self.model = None
        self.sessions = {}
        self.lock = asyncio.Lock()
        self._load_model()
        logger.info(f"[STT_SERVICE_INIT] STTService factory ready with model {model_size}")

    def _load_model(self):
        try:
            logger.info(f"[STT_MODEL_LOADING] Loading Faster Whisper {self.model_size}...")
            self.model = WhisperModel(
                self.model_size, device=self.device, compute_type=self.compute_type
            )
            logger.info(f"[STT_MODEL_READY] Model loaded successfully")
        except Exception as e:
            logger.error(f"[STT_MODEL_ERROR] {e}")
            logger.error(traceback.format_exc())
            raise

    def create_session(self, session_id: str, callback) -> STTSession:
        session = STTSession(session_id, callback, self.model)
        self.sessions[session_id] = session
        logger.info(f"[STT_SERVICE] Registered session {session_id}. Total: {len(self.sessions)}")
        return session

    def destroy_session(self, session_id: str):
        if session_id in self.sessions:
            self.sessions[session_id].cleanup()
            del self.sessions[session_id]
            logger.info(f"[STT_SERVICE] Removed session {session_id}. Total: {len(self.sessions)}")
        else:
            logger.warning(f"[STT_SERVICE] Session {session_id} not found for destruction")

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
