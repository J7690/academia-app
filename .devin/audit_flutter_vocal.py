#!/usr/bin/env python3
"""
Audit Flutter pour l'intégration vocale
Cartographie des fichiers existants liés à l'audio/vocal
"""

import os
from pathlib import Path
import re

def audit_flutter_vocal():
    """Audit Flutter pour fonctionnalités vocales"""
    print("=== AUDIT FLUTTER - INTÉGRATION VOCAL ===")
    
    flutter_dir = Path("academia_app")
    
    # Rechercher les fichiers liés à l'audio/vocal
    print("\n[1] Recherche fichiers audio/vocal...")
    
    audio_files = []
    for root, dirs, files in os.walk(flutter_dir):
        for file in files:
            if file.endswith('.dart'):
                file_path = Path(root) / file
                content = file_path.read_text(encoding='utf-8', errors='ignore')
                
                # Rechercher des mots-clés audio/vocal
                keywords = ['audio', 'voice', 'speech', 'microphone', 'recorder', 'stt', 'tts', 'whisper', 'vocal']
                if any(keyword.lower() in content.lower() for keyword in keywords):
                    audio_files.append(file_path)
                    print(f"  {file_path.relative_to(flutter_dir)}")
    
    print(f"\nTotal fichiers audio/vocal: {len(audio_files)}")
    
    # Vérifier les packages audio dans pubspec.yaml
    print("\n[2] Vérification packages audio dans pubspec.yaml...")
    pubspec_path = flutter_dir / "pubspec.yaml"
    if pubspec_path.exists():
        content = pubspec_path.read_text()
        audio_packages = []
        for line in content.split('\n'):
            if any(pkg in line.lower() for pkg in ['audio', 'voice', 'speech', 'record', 'microphone']):
                audio_packages.append(line.strip())
        
        if audio_packages:
            print("  Packages audio trouvés:")
            for pkg in audio_packages:
                print(f"    {pkg}")
        else:
            print("  ⚠️ Aucun package audio trouvé")
    
    # Vérifier les permissions Android
    print("\n[3] Vérification permissions Android...")
    manifest_path = flutter_dir / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
    if manifest_path.exists():
        content = manifest_path.read_text()
        audio_permissions = []
        for line in content.split('\n'):
            if 'RECORD_AUDIO' in line or 'MICROPHONE' in line or 'AUDIO' in line:
                audio_permissions.append(line.strip())
        
        if audio_permissions:
            print("  Permissions audio trouvées:")
            for perm in audio_permissions:
                print(f"    {perm}")
        else:
            print("  ⚠️ Aucune permission audio trouvée")
    
    print("\n=== AUDIT TERMINÉ ===")


if __name__ == "__main__":
    audit_flutter_vocal()
