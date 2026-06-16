#!/usr/bin/env python3
"""
Script de test du service STT (Speech-to-Text)
Teste Faster Whisper avec un fichier audio
"""

import sys
import time
from pathlib import Path

# Ajouter le répertoire parent au path
sys.path.insert(0, str(Path(__file__).parent))

from stt_service import STTService


def test_stt_service():
    """Test du service STT"""
    print("=== TEST SERVICE STT ===")
    
    # Initialiser le service
    print("Initialisation du service STT...")
    start_time = time.time()
    
    try:
        stt_service = STTService(
            model_size="medium",
            device="cpu"
        )
        
        load_time = time.time() - start_time
        print(f"✅ Modèle chargé en {load_time:.2f}s")
        
        # Tester avec un fichier audio (si disponible)
        audio_file = Path("test_audio.wav")
        if audio_file.exists():
            print(f"Test avec fichier audio: {audio_file}")
            start_time = time.time()
            
            transcription = stt_service.transcribe_file(str(audio_file))
            
            transcribe_time = time.time() - start_time
            print(f"✅ Transcription en {transcribe_time:.2f}s")
            print(f"Résultat: {transcription}")
        else:
            print("⚠️ Aucun fichier audio de test disponible")
            print("Créez un fichier test_audio.wav pour tester")
        
        print("=== TEST STT TERMINÉ ===")
        
    except Exception as e:
        print(f"❌ Erreur: {e}")
        sys.exit(1)


if __name__ == "__main__":
    test_stt_service()
