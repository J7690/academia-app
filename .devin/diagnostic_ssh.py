#!/usr/bin/env python3
"""
Diagnostic SSH approfondi du serveur Kamatera
Utilise les identifiants fournis
"""

import socket
import subprocess
import sys

# Identifiants fournis
SERVER_IP = "185.167.97.144"
SERVER_USER = "root"
SERVER_PASS = "Nexiomgroup@Academia0"
SSH_PORT = 22

def diagnostic_ssh():
    """Diagnostic SSH approfondi"""
    print("=== DIAGNOSTIC SSH APPROFONDI ===")
    print(f"IP: {SERVER_IP}")
    print(f"Port: {SSH_PORT}")
    print(f"User: {SERVER_USER}")
    print(f"Password: {SERVER_PASS[:8]}...")
    print()
    
    # Test 1: Vérifier si le port SSH répond
    print("[1] Test port SSH (socket)...")
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        result = sock.connect_ex((SERVER_IP, SSH_PORT))
        sock.close()
        
        if result == 0:
            print("  ✅ Port SSH ouvert et répond")
        else:
            print(f"  ❌ Port SSH ne répond pas (code: {result})")
    except Exception as e:
        print(f"  ❌ Erreur: {e}")
    
    # Test 2: Vérifier si le serveur répond (ping)
    print("\n[2] Test ping...")
    try:
        result = subprocess.run(
            ["ping", "-n", "2", SERVER_IP],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode == 0:
            print("  ✅ Serveur répond au ping")
            print(f"  {result.stdout.splitlines()[-1]}")
        else:
            print("  ❌ Serveur ne répond pas au ping")
    except Exception as e:
        print(f"  ❌ Erreur: {e}")
    
    # Test 3: Test connexion SSH avec mot de passe
    print("\n[3] Test connexion SSH (mot de passe)...")
    try:
        # Utiliser plink (PuTTY) sur Windows ou ssh sur Linux/Mac
        if sys.platform == "win32":
            # Sur Windows, utiliser plink si disponible
            try:
                result = subprocess.run(
                    ["plink", "-ssh", f"{SERVER_USER}@{SERVER_IP}", "-pw", SERVER_PASS, "echo 'SSH_OK'"],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                
                if "SSH_OK" in result.stdout:
                    print("  ✅ Connexion SSH réussie avec mot de passe")
                else:
                    print(f"  ❌ Connexion SSH échouée")
                    print(f"  Stdout: {result.stdout[:200]}")
                    print(f"  Stderr: {result.stderr[:200]}")
            except FileNotFoundError:
                print("  ⚠️ plink non disponible (PuTTY non installé)")
        else:
            # Sur Linux/Mac, utiliser sshpass
            try:
                result = subprocess.run(
                    ["sshpass", "-p", SERVER_PASS, "ssh", f"{SERVER_USER}@{SERVER_IP}", "echo 'SSH_OK'"],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                
                if "SSH_OK" in result.stdout:
                    print("  ✅ Connexion SSH réussie avec mot de passe")
                else:
                    print(f"  ❌ Connexion SSH échouée")
                    print(f"  Stdout: {result.stdout[:200]}")
                    print(f"  Stderr: {result.stderr[:200]}")
            except FileNotFoundError:
                print("  ⚠️ sshpass non disponible")
    except Exception as e:
        print(f"  ❌ Erreur: {e}")
    
    # Test 4: Vérifier si une clé SSH est exigée
    print("\n[4] Test authentification par clé SSH...")
    try:
        result = subprocess.run(
            ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=5", f"{SERVER_USER}@{SERVER_IP}", "echo 'SSH_KEY_OK'"],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if "SSH_KEY_OK" in result.stdout:
            print("  ✅ Connexion SSH réussie avec clé SSH")
        else:
            print("  ❌ Connexion SSH avec clé échouée")
            if "Permission denied" in result.stderr:
                print("  ℹ️ Clé SSH non configurée ou incorrecte")
            print(f"  Stderr: {result.stderr[:200]}")
    except Exception as e:
        print(f"  ❌ Erreur: {e}")
    
    print("\n=== DIAGNOSTIC TERMINÉ ===")


if __name__ == "__main__":
    diagnostic_ssh()
