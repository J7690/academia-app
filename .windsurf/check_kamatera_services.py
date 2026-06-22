import requests

# Interroger Kamatera via le backend Docker local qui a accès à Kamatera
# On utilise le backend comme proxy pour exécuter des commandes sur Kamatera

backend_url = "http://10.0.2.2:8000/kamatera/check-services"

try:
    resp = requests.get(backend_url, timeout=30)
    print("KAMATERA SERVICES STATUS:", resp.status_code)
    print("KAMATERA SERVICES BODY:", resp.text)
except Exception as e:
    print("ERROR: Cannot connect to backend:", str(e))
    print("Trying direct SSH check...")
    
    # Alternative: utiliser subprocess pour SSH direct
    import subprocess
    try:
        # Vérifier si SSH est disponible
        result = subprocess.run(
            ["ssh", "-o", "ConnectTimeout=5", "-o", "StrictHostKeyChecking=no", 
             "root@185.167.97.144", "systemctl list-units --type=service --state=running"],
            capture_output=True,
            text=True,
            timeout=10
        )
        print("SSH STATUS:", result.returncode)
        print("SSH STDOUT:", result.stdout[:2000])
        print("SSH STDERR:", result.stderr[:500])
    except Exception as e2:
        print("SSH ERROR:", str(e2))
