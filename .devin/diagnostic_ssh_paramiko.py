#!/usr/bin/env python3
"""
Diagnostic SSH approfondi du serveur Kamatera avec paramiko
Utilise les identifiants fournis
"""

import paramiko
import socket
import sys

# Identifiants fournis
SERVER_IP = "185.167.97.144"
SERVER_USER = "root"
SERVER_PASS = "Nexiomgroup@Academia0"
SSH_PORT = 22

def diagnostic_ssh_paramiko():
    """Diagnostic SSH avec paramiko"""
    print("=== DIAGNOSTIC SSH PARAMIKO ===")
    print(f"IP: {SERVER_IP}")
    print(f"Port: {SSH_PORT}")
    print(f"User: {SERVER_USER}")
    print(f"Password: {SERVER_PASS[:8]}...")
    print()
    
    # Créer un client SSH
    client = paramiko.SSHClient()
    
    # Auto-accepter la clé hôte (pour le test)
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        print("[1] Connexion SSH avec mot de passe...")
        client.connect(
            hostname=SERVER_IP,
            port=SSH_PORT,
            username=SERVER_USER,
            password=SERVER_PASS,
            timeout=10
        )
        
        print("  ✅ Connexion SSH réussie avec mot de passe")
        
        # Exécuter une commande simple
        print("\n[2] Test exécution commande...")
        stdin, stdout, stderr = client.exec_command("echo 'SSH_TEST_OK'")
        output = stdout.read().decode('utf-8')
        error = stderr.read().decode('utf-8')
        
        if "SSH_TEST_OK" in output:
            print("  ✅ Exécution commande réussie")
            print(f"  Output: {output.strip()}")
        else:
            print(f"  ❌ Exécution commande échouée")
            print(f"  Error: {error}")
        
        # Vérifier les ressources
        print("\n[3] Vérification ressources...")
        stdin, stdout, stderr = client.exec_command("free -h")
        output = stdout.read().decode('utf-8')
        print(f"  RAM:\n{output}")
        
        stdin, stdout, stderr = client.exec_command("nproc")
        output = stdout.read().decode('utf-8')
        print(f"  CPU: {output.strip()} cores")
        
        stdin, stdout, stderr = client.exec_command("df -h /")
        output = stdout.read().decode('utf-8')
        print(f"  Disk:\n{output}")
        
        # Vérifier Docker
        print("\n[4] Vérification Docker...")
        stdin, stdout, stderr = client.exec_command("docker ps")
        output = stdout.read().decode('utf-8')
        print(f"  Containers:\n{output}")
        
        # Fermer la connexion
        client.close()
        
        print("\n=== DIAGNOSTIC TERMINÉ AVEC SUCCÈS ===")
        
    except paramiko.AuthenticationException:
        print("  ❌ Authentication failed: mot de passe incorrect")
    except paramiko.SSHException as e:
        print(f"  ❌ SSH error: {e}")
    except socket.timeout:
        print("  ❌ Timeout: serveur ne répond pas")
    except Exception as e:
        print(f"  ❌ Erreur: {e}")
    finally:
        client.close()


if __name__ == "__main__":
    diagnostic_ssh_paramiko()
