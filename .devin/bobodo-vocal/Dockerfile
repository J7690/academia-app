FROM python:3.11-slim

# Variables d'environnement
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Répertoire de travail
WORKDIR /app

# Dépendances système
RUN apt-get update && apt-get install -y \
    ffmpeg \
    libsndfile1 \
    wget \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Copier requirements
COPY requirements.txt .

# Installer setuptools et wheel d'abord
RUN pip install --no-cache-dir setuptools wheel

# Installer dépendances Python
RUN pip install --no-cache-dir -r requirements.txt

# Créer répertoires
RUN mkdir -p models logs

# Copier code
COPY . .

# Exposer port
EXPOSE 8000

# Commande de démarrage
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
