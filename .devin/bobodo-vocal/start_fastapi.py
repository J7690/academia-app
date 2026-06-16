#!/usr/bin/env python3
"""
Script de lancement du service FastAPI
Lance le serveur avec WebSocket
"""

import sys
import time
from pathlib import Path

# Ajouter le répertoire parent au path
sys.path.insert(0, str(Path(__file__).parent))


def start_fastapi():
    """Lancement du serveur FastAPI"""
    print("=== LANCEMENT FASTAPI ===")
    
    try:
        import uvicorn
        from main import app
        
        print("Démarrage du serveur sur 0.0.0.0:8000...")
        print("WebSocket disponible sur ws://0.0.0.0:8000/ws")
        print("Health check disponible sur http://0.0.0.0:8000/health")
        
        uvicorn.run(
            app,
            host="0.0.0.0",
            port=8000,
            log_level="info"
        )
        
    except Exception as e:
        print(f"❌ Erreur: {e}")
        sys.exit(1)


if __name__ == "__main__":
    start_fastapi()
