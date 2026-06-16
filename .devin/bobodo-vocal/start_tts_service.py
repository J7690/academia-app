#!/usr/bin/env python3
"""
Script de test du service TTS (Text-to-Speech)
Teste Piper avec un texte
"""

import sys
import time
from pathlib import Path

# Ajouter le répertoire parent au path
sys.path.insert(0, str(Path(__file__).parent))

from tts_service import TTSService


def test_tts_service():
    """Test du service TTS"""
    print("=== TEST SERVICE TTS ===")
    
    # Initialiser le service
    print("Initialisation du service TTS...")
    start_time = time.time()
    
    try:
        tts_service = TTSService()
        
        load_time = time.time() - start_time
        print(f"✅ Modèle chargé en {load_time:.2f}s")
        
        # Tester avec un texte
        test_text = "Bonjour, ceci est un test de synthèse vocale pour Bobodo."
        print(f"Test avec texte: {test_text}")
        
        start_time = time.time()
        
        # Test de synthèse vers fichier
        output_file = "test_audio_output.wav"
        success = tts_service.synthesize_to_file(test_text, output_file)
        
        synthesize_time = time.time() - start_time
        
        if success:
            print(f"✅ Synthèse en {synthesize_time:.2f}s")
            print(f"✅ Audio sauvegardé dans: {output_file}")
        else:
            print("❌ Synthèse échouée")
        
        print("=== TEST TTS TERMINÉ ===")
        
    except Exception as e:
        print(f"❌ Erreur: {e}")
        sys.exit(1)


if __name__ == "__main__":
    test_tts_service()
