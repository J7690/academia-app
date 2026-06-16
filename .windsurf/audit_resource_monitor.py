import paramiko
import time

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

def main():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASS)
    
    # Simple resource script that runs WHILE we trigger transcription
    monitor_script = r'''
import time
import psutil
import sys

# Find bobodo-vocal process
pid = None
for proc in psutil.process_iter(['pid', 'cmdline']):
    cmdline = str(proc.info.get('cmdline', ''))
    if 'main.py' in cmdline and 'bobodo-vocal' in cmdline:
        pid = proc.info['pid']
        break

if not pid:
    print("PROCESS_NOT_FOUND")
    sys.exit(1)

print(f"MONITOR_PID:{pid}")
proc = psutil.Process(pid)

print("timestamp,cpu_percent,memory_rss_mb,memory_vms_mb,num_threads,load_1min")
for i in range(40):
    try:
        cpu = proc.cpu_percent(interval=0.5)
        mem = proc.memory_info()
        threads = proc.num_threads()
        load = os.getloadavg() if hasattr(os, 'getloadavg') else (0,0,0)
        print(f"{time.time():.3f},{cpu:.1f},{mem.rss/1024/1024:.1f},{mem.vms/1024/1024:.1f},{threads},{load[0]:.2f}")
        sys.stdout.flush()
    except Exception as e:
        print(f"ERROR,{e}")
'''
    
    # Write monitor script
    stdin, stdout, stderr = ssh.exec_command("cat > /tmp/monitor.py << 'EOF'\n" + monitor_script + "\nEOF")
    stdout.channel.recv_exit_status()
    
    # Start monitor in background, capture output to a file
    ssh.exec_command("nohup bash -c 'cd /opt/bobodo-vocal && source venv/bin/activate && python /tmp/monitor.py' > /tmp/monitor_out.txt 2>&1 &")
    time.sleep(1)
    
    # Now trigger transcription via a simple WS client
    trigger_script = r'''
import asyncio
import websockets
import json
import base64
from gtts import gTTS
import os

async def trigger():
    tts = gTTS("Bonjour Bobodo comment vas tu aujourdhui", lang="fr")
    tts.save("/tmp/trig.mp3")
    os.system("ffmpeg -y -i /tmp/trig.mp3 -ar 16000 -ac 1 -f s16le /tmp/trig.pcm 2>/dev/null")
    with open("/tmp/trig.pcm", "rb") as f:
        pcm = f.read()
    
    async with websockets.connect("ws://localhost:8000/ws") as ws:
        await ws.send(json.dumps({"type": "session_id", "session_id": "res-test"}))
        await ws.send(json.dumps({"type": "audio", "audio": base64.b64encode(pcm).decode('utf-8')}))
        msg = await asyncio.wait_for(ws.recv(), timeout=30.0)
        print(f"RESPONSE:{msg}")

asyncio.run(trigger())
'''
    
    stdin, stdout, stderr = ssh.exec_command("cat > /tmp/trigger.py << 'EOF'\n" + trigger_script + "\nEOF")
    stdout.channel.recv_exit_status()
    
    print("Triggering transcription for resource monitoring...")
    stdin, stdout, stderr = ssh.exec_command("cd /opt/bobodo-vocal && source venv/bin/activate && python /tmp/trigger.py")
    trigger_out = stdout.read().decode('utf-8')
    print(trigger_out)
    
    time.sleep(2)
    
    # Get monitor output
    stdin, stdout, stderr = ssh.exec_command("cat /tmp/monitor_out.txt")
    monitor_out = stdout.read().decode('utf-8')
    print("\n=== RESOURCE MONITORING OUTPUT ===")
    print(monitor_out)
    
    ssh.close()

if __name__ == "__main__":
    main()
