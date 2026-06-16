import piper_tts
import base64
import json
import logging
import numpy as np
import time

# Configuration logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('tts_service')

# Chargement modèle Piper
model_path = "/root/piper_voices/fr_FR-siwis-medium.onnx"
config_path = "/root/piper_voices/fr_FR-siwis-medium.onnx.json"

try:
    logger.info("Chargement modèle Piper...")
    piper_model = piper_tts.PiperTTS(model_path, config_path)
    logger.info("Modèle Piper chargé avec succès")
except Exception as e:
    logger.error(f"Erreur chargement modèle Piper: {e}")
    piper_model = None

# Fallback gTTS
try:
    from gtts import gTTS
    import io
    gtts_available = True
    logger.info("gTTS disponible comme fallback")
except ImportError:
    gtts_available = False
    logger.warning("gTTS non disponible")

def generate_tts_piper(text: str) -> bytes:
    """
    Génère audio avec Piper TTS.
    
    Args:
        text: Texte à convertir en audio
        
    Returns:
        bytes: Audio généré (WAV format)
    """
    try:
        logger.info(f"[TTS_REQUEST] Text length: {len(text)}")
        start_time = time.time()
        
        # Génération audio
        audio = piper_model.synthesize(text)
        
        # Conversion en bytes
        audio_bytes = audio.tobytes()
        
        end_time = time.time()
        latency = end_time - start_time
        logger.info(f"[TTS_SUCCESS] Audio generated: {len(audio_bytes)} bytes, latency: {latency:.3f}s")
        return audio_bytes
    except Exception as e:
        logger.error(f"[TTS_PIPER_ERROR] {e}")
        raise

def generate_tts_gtts(text: str) -> bytes:
    """
    Génère audio avec gTTS (fallback).
    
    Args:
        text: Texte à convertir en audio
        
    Returns:
        bytes: Audio généré (MP3 format)
    """
    try:
        logger.info(f"[TTS_GTTS_REQUEST] Text length: {len(text)}")
        start_time = time.time()
        
        # Génération audio
        tts = gTTS(text=text, lang='fr')
        audio_buffer = io.BytesIO()
        tts.write_to_fp(audio_buffer)
        audio_bytes = audio_buffer.getvalue()
        
        end_time = time.time()
        latency = end_time - start_time
        logger.info(f"[TTS_GTTS_SUCCESS] Audio generated: {len(audio_bytes)} bytes, latency: {latency:.3f}s")
        return audio_bytes
    except Exception as e:
        logger.error(f"[TTS_GTTS_ERROR] {e}")
        raise

def generate_tts(text: str) -> bytes:
    """
    Génère audio avec Piper TTS (fallback gTTS).
    
    Args:
        text: Texte à convertir en audio
        
    Returns:
        bytes: Audio généré
    """
    try:
        if piper_model is not None:
            return generate_tts_piper(text)
        elif gtts_available:
            return generate_tts_gtts(text)
        else:
            raise Exception("No TTS engine available")
    except Exception as e:
        logger.error(f"[TTS_ERROR] {e}")
        if gtts_available:
            logger.info("Attempting gTTS fallback...")
            return generate_tts_gtts(text)
        else:
            raise

if __name__ == "__main__":
    # Test
    test_text = "Bonjour, je suis Bobodo."
    audio_bytes = generate_tts(test_text)
    
    # Sauvegarde fichier test
    with open("/tmp/test_tts_service.wav", "wb") as f:
        f.write(audio_bytes)
    
    print(f"[TTS_TEST] Audio saved: {len(audio_bytes)} bytes")
