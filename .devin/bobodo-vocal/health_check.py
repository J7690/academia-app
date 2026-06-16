#!/usr/bin/env python3
"""
Script de health check pour Bobodo Vocal
Vérifie que tous les services sont opérationnels
"""

import sys
import time
import requests
from pathlib import Path

# Ajouter le répertoire parent au path
sys.path.insert(0, str(Path(__file__).parent))


def check_health():
    """Vérification de la santé du service"""
    print("=== HEALTH CHECK BOBODO VOCAL ===")
    
    # Vérifier le endpoint health
    try:
        response = requests.get("http://localhost:8000/health", timeout=5)
        
        if response.status_code == 200:
            data = response.json()
            print("✅ Service FastAPI opérationnel")
            print(f"   STT chargé: {data.get('stt_loaded', False)}")
            print(f"   TTS chargé: {data.get('tts_loaded', False)}")
            
            if data.get('stt_loaded') and data.get('tts_loaded'):
                print("✅ Tous les services sont opérationnels")
                return True
            else:
                print("⚠️ Certains services ne sont pas chargés")
                return False
        else:
            print(f"❌ Health check failed: HTTP {response.status_code}")
            return False
            
    except requests.exceptions.ConnectionError:
        print("❌ Impossible de se connecter au service")
        return False
    except Exception as e:
        print(f"❌ Erreur: {e}")
        return False


if __name__ == "__main__":
    success = check_health()
    sys.exit(0 if success else 1)
