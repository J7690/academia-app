#!/bin/bash
# Script de déploiement Bobodo Vocal sur Kamatera
# À exécuter sur le serveur Kamatera via SSH

set -e

echo "=== DÉPLOIEMENT BOBODO VOCAL ==="

# Variables
PROJECT_DIR="/opt/bobodo-vocal"
MODELS_DIR="$PROJECT_DIR/models"
LOGS_DIR="$PROJECT_DIR/logs"

# Créer les répertoires
echo "Création des répertoires..."
mkdir -p $PROJECT_DIR
mkdir -p $MODELS_DIR
mkdir -p $LOGS_DIR

# Copier les fichiers (à adapter selon le mode de transfert)
# scp -r . root@185.167.97.144:$PROJECT_DIR/

# Installer les dépendances système
echo "Installation des dépendances système..."
apt-get update
apt-get install -y \
    python3.11 \
    python3-pip \
    python3.11-venv \
    ffmpeg \
    libsndfile1 \
    portaudio19-dev \
    git

# Créer l'environnement virtuel
echo "Création de l'environnement virtuel..."
cd $PROJECT_DIR
python3.11 -m venv venv
source venv/bin/activate

# Installer les dépendances Python
echo "Installation des dépendances Python..."
pip install --upgrade pip
pip install -r requirements.txt

# Télécharger les modèles
echo "Téléchargement des modèles..."
python download_models.py

# Configurer les variables d'environnement
echo "Configuration des variables d'environnement..."
# Copier .env.local vers .env
cp .env.local .env

# Construire et lancer Docker
echo "Construction Docker..."
docker-compose build

echo "Lancement Docker..."
docker-compose up -d

# Vérifier le démarrage
echo "Vérification du démarrage..."
sleep 10
curl http://localhost:8000/health

echo "=== DÉPLOIEMENT TERMINÉ ==="
