"""
Script pour télécharger les modèles Faster Whisper et Piper
Exécutez ce script avant de lancer le service vocal
"""

import os
import sys
from pathlib import Path
import subprocess
import logging

# Configuration
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Répertoires
MODELS_DIR = Path("./models")
MODELS_DIR.mkdir(exist_ok=True)

# URLs des modèles
FASTER_WHISPER_MEDIUM_URL = "https://huggingface.co/guillaumekln/faster-whisper-medium/resolve/main"
PIPER_VOICE_URL = "https://huggingface.co/rhasspy/piper-voices/v1.0.0/fr/fr_FR-medium/resolve/main"


def download_file(url: str, dest_path: Path) -> bool:
    """Télécharger un fichier depuis une URL"""
    try:
        logger.info(f"Téléchargement: {url}")
        logger.info(f"Destination: {dest_path}")
        
        # Créer le répertoire parent si nécessaire
        dest_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Télécharger avec wget ou curl
        if sys.platform == "win32":
            # Windows
            subprocess.run(
                ["curl", "-L", "-o", str(dest_path), url],
                check=True
            )
        else:
            # Linux/Mac
            subprocess.run(
                ["wget", "-O", str(dest_path), url],
                check=True
            )
        
        logger.info(f"Téléchargement réussi: {dest_path}")
        return True
        
    except subprocess.CalledProcessError as e:
        logger.error(f"Erreur téléchargement: {e}")
        return False
    except Exception as e:
        logger.error(f"Erreur inattendue: {e}")
        return False


def download_faster_whisper_medium():
    """Télécharger le modèle Faster Whisper Medium"""
    logger.info("=== Téléchargement Faster Whisper Medium ===")
    
    model_dir = MODELS_DIR / "faster-whisper-medium"
    model_dir.mkdir(exist_ok=True)
    
    files = [
        "model.bin",
        "config.json",
        "vocabulary.txt",
        "tokenizer.json"
    ]
    
    success_count = 0
    for file in files:
        url = f"{FASTER_WHISPER_MEDIUM_URL}/{file}"
        dest = model_dir / file
        if download_file(url, dest):
            success_count += 1
    
    logger.info(f"Faster Whisper Medium: {success_count}/{len(files)} fichiers téléchargés")
    return success_count == len(files)


def download_piper_french():
    """Télécharger la voix Piper française"""
    logger.info("=== Téléchargement Piper Français ===")
    
    voice_dir = MODELS_DIR / "fr_FR-medium"
    voice_dir.mkdir(exist_ok=True)
    
    files = [
        "model.onnx",
        "config.json"
    ]
    
    success_count = 0
    for file in files:
        url = f"{PIPER_VOICE_URL}/{file}"
        dest = voice_dir / file
        if download_file(url, dest):
            success_count += 1
    
    logger.info(f"Piper Français: {success_count}/{len(files)} fichiers téléchargés")
    return success_count == len(files)


def main():
    """Fonction principale"""
    logger.info("=== Téléchargement des modèles Bobodo Vocal ===")
    
    # Télécharger Faster Whisper Medium
    whisper_success = download_faster_whisper_medium()
    
    # Télécharger Piper Français
    piper_success = download_piper_french()
    
    # Résumé
    logger.info("=== Résumé ===")
    logger.info(f"Faster Whisper Medium: {'✅ Succès' if whisper_success else '❌ Échec'}")
    logger.info(f"Piper Français: {'✅ Succès' if piper_success else '❌ Échec'}")
    
    if whisper_success and piper_success:
        logger.info("✅ Tous les modèles téléchargés avec succès")
        return 0
    else:
        logger.error("❌ Certains modèles n'ont pas pu être téléchargés")
        return 1


if __name__ == "__main__":
    sys.exit(main())
