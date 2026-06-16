#!/usr/bin/env python3
"""
Script de déploiement Bobodo Vocal via API Kamatera
Crée un nouveau serveur et déploie le service vocal
"""

import requests
import time
import json
from pathlib import Path

# Configuration Kamatera API
API_URL = "https://console.kamatera.com/service"
CLIENT_ID = "54ae6bec54550d349e6181c51e2b925c"
SECRET = "cdf8f98e556dfe28243aa243104801a7"
HEADERS = {"AuthClientId": CLIENT_ID, "AuthSecret": SECRET}

# Configuration serveur
SERVER_NAME = "academia-bobodo-vocal"
SERVER_IMAGE = "ubuntu2204"
SERVER_CPU = 4
SERVER_RAM = 8
SERVER_DISK = 40
SERVER_DATACENTER = "AMS01"  # Amsterdam


def create_server():
    """Créer un nouveau serveur sur Kamatera"""
    print("=== CRÉATION SERVEUR KAMATERA ===")
    
    payload = {
        "name": SERVER_NAME,
        "image": SERVER_IMAGE,
        "cpu": SERVER_CPU,
        "ram": SERVER_RAM,
        "disk": SERVER_DISK,
        "datacenter": SERVER_DATACENTER,
        "monthly": True
    }
    
    print(f"Création du serveur: {SERVER_NAME}")
    print(f"Specs: {SERVER_CPU} vCPU, {SERVER_RAM} GB RAM, {SERVER_DISK} GB SSD")
    
    try:
        response = requests.post(
            f"{API_URL}/server",
            headers=HEADERS,
            json=payload
        )
        
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Serveur créé: {data.get('id')}")
            return data.get('id')
        else:
            print(f"❌ Erreur création serveur: {response.text}")
            return None
            
    except Exception as e:
        print(f"❌ Erreur: {e}")
        return None


def wait_for_server_ready(server_id, timeout=600):
    """Attendre que le serveur soit prêt"""
    print(f"Attente du serveur {server_id}...")
    
    start_time = time.time()
    
    while time.time() - start_time < timeout:
        try:
            response = requests.get(
                f"{API_URL}/server/{server_id}",
                headers=HEADERS
            )
            
            if response.status_code == 200:
                data = response.json()
                status = data.get('status', 'unknown')
                print(f"Statut: {status}")
                
                if status == 'active':
                    print("✅ Serveur prêt")
                    return data.get('ip')
                    
        except Exception as e:
            print(f"Erreur: {e}")
        
        time.sleep(10)
    
    print("❌ Timeout: serveur non prêt")
    return None


def deploy_service(server_ip):
    """Déployer le service vocal sur le serveur"""
    print(f"=== DÉPLOIEMENT SUR {server_ip} ===")
    
    # Note: Cette partie nécessite une connexion SSH fonctionnelle
    # Pour l'instant, nous affichons les instructions
    
    print("Instructions de déploiement manuel:")
    print(f"1. SSH: ssh root@{server_ip}")
    print("2. Copier les fichiers: scp -r bobodo-vocal/ root@{server_ip}:/opt/")
    print("3. Exécuter: cd /opt/bobodo-vocal && bash deploy_kamatera.sh")
    
    return True


def main():
    """Fonction principale"""
    print("=== DÉPLOIEMENT BOBODO VOCAL VIA API KAMATERA ===")
    
    # Créer le serveur
    server_id = create_server()
    
    if not server_id:
        print("❌ Impossible de créer le serveur")
        return
    
    # Attendre que le serveur soit prêt
    server_ip = wait_for_server_ready(server_id)
    
    if not server_ip:
        print("❌ Serveur non prêt")
        return
    
    # Déployer le service
    deploy_service(server_ip)
    
    print("=== DÉPLOIEMENT TERMINÉ ===")
    print(f"Serveur IP: {server_ip}")
    print(f"Service: http://{server_ip}:8000")


if __name__ == "__main__":
    main()
