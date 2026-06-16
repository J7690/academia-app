#!/usr/bin/env python3
"""
Audit réel de l'infrastructure Kamatera pour Bobodo Vocal
Récupère les mesures réelles : vCPU, RAM, disque, CPU, Docker, ports, réseau
"""

import paramiko
import json
import sys

# Configuration SSH (depuis documentation INFRASTRUCTURE_KAMATERA.md)
KAMATERA_IP = "185.167.97.144"  # IP LiveKit serveur principal
SSH_USER = "root"
SSH_PASSWORD = "Ouedraogogilbert@Wendenkoote0"

def ssh_connect():
    """Connexion SSH au serveur Kamatera"""
    try:
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        client.connect(KAMATERA_IP, username=SSH_USER, password=SSH_PASSWORD, timeout=30)
        return client
    except Exception as e:
        print(f"Erreur connexion SSH: {e}")
        return None

def execute_command(client, command):
    """Exécute une commande SSH et retourne la sortie"""
    try:
        stdin, stdout, stderr = client.exec_command(command, timeout=30)
        output = stdout.read().decode('utf-8').strip()
        error = stderr.read().decode('utf-8').strip()
        if error:
            print(f"Erreur commande '{command}': {error}")
        return output
    except Exception as e:
        print(f"Erreur exécution commande '{command}': {e}")
        return None

def audit_infrastructure():
    """Audit complet de l'infrastructure"""
    client = ssh_connect()
    if not client:
        return None

    results = {}

    # 1. vCPU
    print("=== vCPU ===")
    cpu_info = execute_command(client, "nproc")
    results["vcpu_count"] = int(cpu_info) if cpu_info else None
    print(f"vCPU: {results['vcpu_count']}")

    # 2. RAM totale et disponible
    print("\n=== RAM ===")
    mem_info = execute_command(client, "free -h")
    if mem_info:
        lines = mem_info.split('\n')
        for line in lines:
            if line.startswith('Mem:'):
                parts = line.split()
                results["ram_total"] = parts[1]
                results["ram_used"] = parts[2]
                results["ram_free"] = parts[3]
                results["ram_available"] = parts[6] if len(parts) > 6 else "N/A"
                print(f"RAM Total: {results['ram_total']}")
                print(f"RAM Used: {results['ram_used']}")
                print(f"RAM Free: {results['ram_free']}")
                print(f"RAM Available: {results['ram_available']}")

    # 3. Espace disque
    print("\n=== Disque ===")
    disk_info = execute_command(client, "df -h /")
    if disk_info:
        lines = disk_info.split('\n')
        for line in lines:
            if line.startswith('/dev'):
                parts = line.split()
                results["disk_total"] = parts[1]
                results["disk_used"] = parts[2]
                results["disk_free"] = parts[3]
                results["disk_percent"] = parts[4]
                print(f"Disque Total: {results['disk_total']}")
                print(f"Disque Used: {results['disk_used']}")
                print(f"Disque Free: {results['disk_free']}")
                print(f"Disque %: {results['disk_percent']}")

    # 4. Charge CPU moyenne
    print("\n=== Charge CPU ===")
    loadavg = execute_command(client, "cat /proc/loadavg")
    if loadavg:
        parts = loadavg.split()
        results["load_1min"] = parts[0]
        results["load_5min"] = parts[1]
        results["load_15min"] = parts[2]
        print(f"Load 1min: {results['load_1min']}")
        print(f"Load 5min: {results['load_5min']}")
        print(f"Load 15min: {results['load_15min']}")

    # 5. Conteneurs Docker actifs
    print("\n=== Docker ===")
    docker_ps = execute_command(client, "docker ps --format '{{.Names}}\t{{.Status}}'")
    if docker_ps:
        containers = docker_ps.split('\n')
        results["docker_containers"] = containers
        print(f"Conteneurs actifs: {len(containers)}")
        for container in containers:
            print(f"  - {container}")

    # 6. Conteneurs LiveKit spécifiques
    print("\n=== LiveKit ===")
    livekit_containers = execute_command(client, "docker ps --format '{{.Names}}' | grep -i livekit")
    if livekit_containers:
        results["livekit_containers"] = livekit_containers.split('\n')
        print(f"Conteneurs LiveKit: {len(results['livekit_containers'])}")
        for container in results['livekit_containers']:
            print(f"  - {container}")
    else:
        results["livekit_containers"] = []
        print("Aucun conteneur LiveKit détecté")

    # 7. Ports exposés
    print("\n=== Ports ===")
    ports = execute_command(client, "ss -tlnp | grep LISTEN")
    if ports:
        results["listening_ports"] = ports.split('\n')
        print(f"Ports ouverts: {len(results['listening_ports'])}")
        for port in results['listening_ports']:
            print(f"  - {port}")

    # 8. Utilisation réseau
    print("\n=== Réseau ===")
    network_stats = execute_command(client, "cat /proc/net/dev | tail -n +3")
    if network_stats:
        results["network_interfaces"] = network_stats.split('\n')
        print("Interfaces réseau:")
        for iface in results['network_interfaces']:
            print(f"  - {iface}")

    # 9. Info système
    print("\n=== Système ===")
    os_info = execute_command(client, "uname -a")
    results["os_info"] = os_info
    print(f"OS: {os_info}")

    # 10. Uptime
    print("\n=== Uptime ===")
    uptime = execute_command(client, "uptime -p")
    results["uptime"] = uptime
    print(f"Uptime: {uptime}")

    client.close()
    return results

if __name__ == "__main__":
    print("=== AUDIT RÉEL INFRASTRUCTURE KAMATERA ===\n")
    results = audit_infrastructure()

    if results:
        # Sauvegarder en JSON
        with open('.windsurf/kamatera_real_audit.json', 'w') as f:
            json.dump(results, f, indent=2)
        print("\n=== RÉSULTATS SAUVEGARDÉS ===")
        print("Fichier: .windsurf/kamatera_real_audit.json")
    else:
        print("\n=== ÉCHEC AUDIT ===")
        sys.exit(1)
