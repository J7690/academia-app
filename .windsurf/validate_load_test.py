import paramiko
import time

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

def main():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASS)

    # Script exécuté sur le serveur : 5 connexions WS simultanées + monitoring ressources
    server_script = r'''
import asyncio
import websockets
import json
import base64
import time
import os
import sys

# === CONFIG ===
NUM_USERS = 5
WS_URL = "ws://localhost:8000/ws"
PHRASES = [
    "Bonjour Bobodo",
    "Quelle est la capitale du Burkina Faso",
    "Explique la photosynthese",
    "Donne moi un conseil de revision",
    "Comment postuler sur Academia"
]

results = []

async def user_test(user_id, phrase):
    start = time.time()
    try:
        async with websockets.connect(WS_URL, open_timeout=5, close_timeout=5) as ws:
            await ws.send(json.dumps({"type": "session_id", "session_id": f"load-{user_id}"}))
            # Generer audio simple : 2 secondes de PCM16 silence + phrase
            # On envoie un petit buffer audio valide (PCM16 16kHz)
            # Pour simplifier, on envoie 2 secondes de 0x00 (silence)
            silence = bytes(64000)  # 2s * 16000 * 2 bytes
            await ws.send(json.dumps({"type": "audio", "audio": base64.b64encode(silence).decode()}))
            try:
                msg = await asyncio.wait_for(ws.recv(), timeout=20.0)
                elapsed = (time.time() - start) * 1000
                results.append({"user": user_id, "status": "OK", "time_ms": elapsed, "response": msg[:100]})
            except asyncio.TimeoutError:
                elapsed = (time.time() - start) * 1000
                results.append({"user": user_id, "status": "TIMEOUT", "time_ms": elapsed, "response": ""})
    except Exception as e:
        elapsed = (time.time() - start) * 1000
        results.append({"user": user_id, "status": f"ERROR:{e}", "time_ms": elapsed, "response": ""})

async def run_all():
    tasks = [user_test(i, PHRASES[i]) for i in range(NUM_USERS)]
    await asyncio.gather(*tasks)

# Monitoring ressources pendant le test
def monitor_resources(pid, duration_sec=30):
    print("=== RESOURCE MONITOR ===")
    print("time,cpu_percent,memory_rss_mb,threads,load_1min")
    for _ in range(duration_sec):
        try:
            # CPU
            with open(f"/proc/{pid}/stat", "r") as f:
                parts = f.read().split()
                utime1 = int(parts[13])
                stime1 = int(parts[14])
            with open("/proc/uptime", "r") as f:
                uptime1 = float(f.read().split()[0])
            time.sleep(1)
            with open(f"/proc/{pid}/stat", "r") as f:
                parts = f.read().split()
                utime2 = int(parts[13])
                stime2 = int(parts[14])
            with open("/proc/uptime", "r") as f:
                uptime2 = float(f.read().split()[0])
            clk_tck = os.sysconf(os.sysconf_names['SC_CLK_TCK'])
            cpu = ((utime2 + stime2) - (utime1 + stime1)) / clk_tck / (uptime2 - uptime1) * 100
            # RAM
            with open(f"/proc/{pid}/status", "r") as f:
                rss = None
                for line in f:
                    if line.startswith("VmRSS:"):
                        rss = int(line.split()[1]) / 1024
                        break
            # Threads
            threads = len(os.listdir(f"/proc/{pid}/task"))
            # Load
            with open("/proc/loadavg", "r") as f:
                load = f.read().split()[0]
            print(f"{time.time():.0f},{cpu:.1f},{rss:.1f},{threads},{load}")
            sys.stdout.flush()
        except Exception as e:
            print(f"MONITOR_ERROR,{e}")
            sys.stdout.flush()

# Find PID
pid = None
for proc in os.listdir("/proc"):
    if proc.isdigit():
        try:
            with open(f"/proc/{proc}/cmdline", "r") as f:
                cmd = f.read()
                if "main.py" in cmd and "bobodo" in cmd:
                    pid = int(proc)
                    break
        except:
            pass

if not pid:
    print("PID_NOT_FOUND")
    sys.exit(1)

print(f"TARGET_PID:{pid}")

# Start monitor in background thread
import threading
t = threading.Thread(target=monitor_resources, args=(pid, 30))
t.daemon = True
t.start()

# Run load test
asyncio.run(run_all())

# Wait for monitor to finish
 t.join(timeout=5)

# Print results
print("\n=== LOAD TEST RESULTS ===")
for r in results:
    print(f"user-{r['user']}: {r['status']} | {r['time_ms']:.0f}ms | {r['response']}")
'''

    print("Uploading and executing load test on server...")
    stdin, stdout, stderr = ssh.exec_command("cat > /tmp/load_test.py << 'PYEOF'\n" + server_script + "\nPYEOF")
    stdout.channel.recv_exit_status()

    stdin, stdout, stderr = ssh.exec_command("cd /opt/bobodo-vocal && source venv/bin/activate && python /tmp/load_test.py")
    output = stdout.read().decode('utf-8')
    errors = stderr.read().decode('utf-8')
    print(output)
    if errors.strip():
        print("=== STDERR ===")
        print(errors)

    ssh.close()

if __name__ == "__main__":
    main()
