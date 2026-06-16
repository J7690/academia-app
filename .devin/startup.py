#!/usr/bin/env python3
"""
Script de démarrage automatique des règles Windsurf
Doit être exécuté au lancement de Windsurf
"""

import sys
import os
from pathlib import Path

# Ajouter le chemin .windsurf au Python path
windsurf_path = Path(__file__).parent
sys.path.insert(0, str(windsurf_path))

try:
    from __init__ import initialize_windsurf_rules
    
    print("=" * 60)
    print("🚀 DÉMARRAGE DU SYSTÈME DE RÈGLES WINDSURF")
    print("=" * 60)
    
    # Initialisation obligatoire
    success = initialize_windsurf_rules()
    
    if success:
        print("\n✅ SUCCÈS: Règles Windsurf activées et obligatoires")
        print("🎯 Toutes les tâches suivront automatiquement les règles définies")
        print("🔒 Aucune exécution possible sans respect des règles")
        print("\n" + "=" * 60)
        print("SYSTÈME PRÊT - EN ATTENTE DES TÂCHES")
        print("=" * 60)
    else:
        print("\n❌ ERREUR CRITIQUE: Échec d'activation des règles")
        print("🚫 Windsurf ne peut pas fonctionner sans les règles")
        print("Veuillez vérifier les fichiers dans .windsurf/")
        sys.exit(1)
        
except ImportError as e:
    print(f"❌ Erreur d'import: {e}")
    print("Vérifiez que tous les fichiers sont présents dans .windsurf/")
    sys.exit(1)
    
except Exception as e:
    print(f"❌ Erreur inattendue: {e}")
    print("Le système ne peut pas démarrer")
    sys.exit(1)
