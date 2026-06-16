"""
Bobodo Vocal - STT Service
Speech-to-Text service with Faster Whisper Medium
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


class STTService:
    """Speech-to-Text service with Faster Whisper"""

    def __init__(self, model_size: str = "small", device: str = "cpu", compute_type: str = "int8"):
        """Initialize STT service with Faster Whisper"""
        self.model_size = model_size
        self.device = device
        self.compute_type = compute_type
        self.model = None
        self.audio_buffer = bytearray()  # Buffer to accumulate audio chunks
        self.sample_rate = 16000  # Sample rate for PCM16
        self.bytes_per_sample = 2  # 16-bit = 2 bytes per sample
        self.silence_threshold_ms = 500  # Silence threshold: 500ms (0.5 second)
        self.last_audio_time = None  # Timestamp of last audio packet
        self.silence_task = None  # Async task for silence detection
        self.min_audio_duration = 0.5  # Minimum 0.5s before considering silence
        self.transcription_callback = None  # Callback for transcription results
        logger.info(f"[STT_SERVICE_INIT] STT service initialized with Faster Whisper {model_size}")
        logger.info(f"[STT_SERVICE_INIT] Silence threshold: {self.silence_threshold_ms}ms")
        self._load_model()

    def set_transcription_callback(self, callback):
        """Set callback for transcription results"""
        self.transcription_callback = callback
        logger.info("[STT_CALLBACK] Transcription callback registered")
    
    def _load_model(self):
        """Load Faster Whisper model"""
        try:
            logger.info(f"[STT_MODEL_LOADING] Loading Faster Whisper model {self.model_size}...")
            logger.info(f"[STT_MODEL_LOADING] Device: {self.device}, Compute type: {self.compute_type}")
            self.model = WhisperModel(
                self.model_size,
                device=self.device,
                compute_type=self.compute_type
            )
            logger.info(f"[STT_MODEL_READY] Faster Whisper model {self.model_size} loaded successfully")
        except Exception as e:
            logger.error(f"[STT_MODEL_ERROR] Error loading model: {type(e).__name__}: {e}")
            logger.error(f"[STT_MODEL_ERROR] Stacktrace: {traceback.format_exc()}")
            raise
            
    def _add_wav_header(self, raw_pcm: bytes, sample_rate: int = 16000, channels: int = 1, bits_per_sample: int = 16) -> bytes:
        """
        Add WAV header to raw PCM data
        
        Args:
            raw_pcm: Raw PCM audio data
            sample_rate: Sample rate (default 16000 Hz for flutter_sound)
            channels: Number of channels (default 1 for mono)
            bits_per_sample: Bits per sample (default 16 for PCM16)
            
        Returns:
            WAV file data with header
        """
        logger.info(f"[STT_WAV_HEADER] Adding WAV header: {len(raw_pcm)} bytes, {sample_rate}Hz, {channels}ch, {bits_per_sample}bit")
        
        # Calculate sizes
        data_size = len(raw_pcm)
        total_size = 36 + data_size  # 36 bytes header + data
        byte_rate = sample_rate * channels * bits_per_sample // 8
        block_align = channels * bits_per_sample // 8
        
        # Build WAV header
        header = struct.pack('<4sI4s', b'RIFF', total_size, b'WAVE')
        fmt_chunk = struct.pack('<4sIHHIIHH', 
                               b'fmt ',  # Subchunk1ID
                               16,      # Subchunk1Size (16 for PCM)
                               1,       # AudioFormat (1 for PCM)
                               channels,
                               sample_rate,
                               byte_rate,
                               block_align,
                               bits_per_sample)
        data_chunk_header = struct.pack('<4sI', b'data', data_size)
        
        wav_data = header + fmt_chunk + data_chunk_header + raw_pcm
        logger.info(f"[STT_WAV_HEADER] WAV file created: {len(wav_data)} bytes")
        return wav_data
            
    async def _detect_silence(self) -> Optional[str]:
        """
        Detect silence and trigger transcription if buffer has enough audio.
        This method is called after silence_threshold_ms of no audio.
        """
        current_duration = len(self.audio_buffer) / (self.sample_rate * self.bytes_per_sample)
        logger.info(f"[STT_SILENCE_DETECTED] Silence detected after {self.silence_threshold_ms}ms")
        logger.info(f"[STT_SILENCE_DETECTED] Buffer duration: {current_duration:.2f}s")

        # Check if we have enough audio to transcribe
        if current_duration < self.min_audio_duration:
            logger.info(f"[STT_SILENCE_DETECTED] Not enough audio (need {self.min_audio_duration}s, have {current_duration:.2f}s)")
            self.audio_buffer.clear()
            self.last_audio_time = None
            return None

        # Transcribe the accumulated audio
        logger.info(f"[STT_SILENCE_DETECTED] Starting transcription ({current_duration:.2f}s)")
        audio_to_transcribe = bytes(self.audio_buffer)
        self.audio_buffer.clear()
        self.last_audio_time = None

        # Add WAV header to raw PCM data
        wav_data = self._add_wav_header(audio_to_transcribe)

        # Write WAV data to temporary file
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as temp_file:
            temp_file.write(wav_data)
            temp_path = temp_file.name

        logger.info(f"[STT_TEMP_FILE_CREATED] Temporary file created: {temp_path}")
        logger.info(f"[STT_TEMP_FILE_SIZE] File size: {os.path.getsize(temp_path)} bytes")

        # Transcribe
        result = await self.transcribe_file(temp_path)

        # Cleanup
        os.unlink(temp_path)
        logger.info(f"[STT_TEMP_FILE_CLEANED] Temporary file deleted")

        # Call callback with result
        if self.transcription_callback and result:
            logger.info(f"[STT_CALLBACK] Calling transcription callback with result")
            await self.transcription_callback(result)

        return result

    async def transcribe(self, audio_bytes: bytes) -> Optional[str]:
        """
        Transcribe audio bytes to text using silence detection.

        Args:
            audio_bytes: Audio data as bytes (raw PCM16 from flutter_sound)

        Returns:
            Transcribed text or None if failed or waiting for silence
        """
        if not self.model:
            logger.error("[STT_ERROR] Model not loaded")
            return None

        try:
            logger.info(f"[STT_AUDIO_RECEIVED] Audio received: {len(audio_bytes)} bytes")

            # Accumulate audio in buffer
            self.audio_buffer.extend(audio_bytes)
            current_duration = len(self.audio_buffer) / (self.sample_rate * self.bytes_per_sample)
            logger.info(f"[STT_BUFFER] Buffer size: {len(self.audio_buffer)} bytes, Duration: {current_duration:.2f}s")

            # Update last audio time
            self.last_audio_time = time.time()

            # Cancel any existing silence detection task
            if self.silence_task and not self.silence_task.done():
                self.silence_task.cancel()
                logger.info("[STT_SILENCE_CANCELLED] Previous silence detection cancelled")

            # Schedule new silence detection
            self.silence_task = asyncio.create_task(self._wait_for_silence())

            # Return None - transcription will happen after silence
            return None

        except Exception as e:
            logger.error(f"[STT_TRANSCRIPTION_ERROR] Transcription from bytes failed: {type(e).__name__}: {e}")
            logger.error(f"[STT_TRANSCRIPTION_ERROR] Stacktrace: {traceback.format_exc()}")
            return None

    async def _wait_for_silence(self) -> Optional[str]:
        """
        Wait for silence and trigger transcription.
        This is an async task that will be cancelled if new audio arrives.
        """
        try:
            # Wait for silence threshold
            await asyncio.sleep(self.silence_threshold_ms / 1000.0)

            # Check if we're still in silence (no new audio)
            if self.last_audio_time:
                time_since_last_audio = (time.time() - self.last_audio_time) * 1000
                if time_since_last_audio >= self.silence_threshold_ms:
                    # Silence confirmed, trigger transcription
                    return await self._detect_silence()
                else:
                    logger.info(f"[STT_SILENCE_CANCELLED] New audio received ({time_since_last_audio:.0f}ms < {self.silence_threshold_ms}ms)")
                    return None
            else:
                logger.info("[STT_SILENCE_CANCELLED] No audio in buffer")
                return None

        except asyncio.CancelledError:
            logger.info("[STT_SILENCE_CANCELLED] Silence detection cancelled by new audio")
            return None
            
    async def transcribe_file(self, audio_path: str) -> Optional[str]:
        """
        Transcribe audio file to text
        
        Args:
            audio_path: Path to audio file
            
        Returns:
            Transcribed text or None if failed
        """
        if not self.model:
            logger.error("[STT_ERROR] Model not loaded")
            return None
        
        try:
            logger.info(f"[STT_TRANSCRIPTION_START] Transcribing file {audio_path}...")
            logger.info(f"[STT_TRANSCRIPTION_START] File exists: {os.path.exists(audio_path)}")
            logger.info(f"[STT_TRANSCRIPTION_START] File size: {os.path.getsize(audio_path)} bytes")
            
            # Transcribe with Faster Whisper
            segments, info = self.model.transcribe(
                audio_path,
                language="fr",  # French
                beam_size=5,
                vad_filter=False  # Disabled VAD filter for short audio clips
            )
            
            logger.info(f"[STT_TRANSCRIPTION_INFO] Language: {info.language}, Duration: {info.duration}s")
            
            # Concatenate segments
            transcription = ""
            segment_count = 0
            for segment in segments:
                transcription += segment.text + " "
                segment_count += 1
            
            logger.info(f"[STT_TRANSCRIPTION_SUCCESS] Transcription completed: {len(transcription)} characters, {segment_count} segments")
            logger.info(f"[STT_TRANSCRIPTION_RESULT] Text: '{transcription.strip()}'")
            return transcription.strip()
            
        except Exception as e:
            logger.error(f"[STT_TRANSCRIPTION_ERROR] File transcription failed: {type(e).__name__}: {e}")
            logger.error(f"[STT_TRANSCRIPTION_ERROR] Stacktrace: {traceback.format_exc()}")
            return None
