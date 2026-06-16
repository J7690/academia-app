import paramiko
import time

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

def main():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASS)
    
    # Find PID
    stdin, stdout, stderr = ssh.exec_command("ps aux | grep 'main.py' | grep -v grep | awk '{print $2}'")
    pid = stdout.read().decode('utf-8').strip()
    print(f"PID: {pid}")
    
    # Simple monitor using /proc
    monitor_script = r'''
import time
import os

pid = ''' + pid + r'''

def read_stat(pid):
    try:
        with open(f"/proc/{pid}/stat", "r") as f:
            return f.read()
    except:
        return None

def read_status(pid):
    try:
        with open(f"/proc/{pid}/status", "r") as f:
            return f.read()
    except:
        return None

def read_uptime():
    with open("/proc/uptime", "r") as f:
        return float(f.read().split()[0])

def get_cpu_percent(pid, interval=1.0):
    stat1 = read_stat(pid)
    if not stat1:
        return None
    parts1 = stat1.split()
    utime1 = int(parts1[13])
    stime1 = int(parts1[14])
    uptime1 = read_uptime()
    
    time.sleep(interval)
    
    stat2 = read_stat(pid)
    if not stat2:
        return None
    parts2 = stat2.split()
    utime2 = int(parts2[13])
    stime2 = int(parts2[14])
    uptime2 = read_uptime()
    
    clk_tck = os.sysconf(os.sysconf_names['SC_CLK_TCK'])
    total_time = ((utime2 + stime2) - (utime1 + stime1)) / clk_tck
    delta = uptime2 - uptime1
    cpu_percent = (total_time / delta) * 100
    return cpu_percent

def get_memory_mb(pid):
    status = read_status(pid)
    if not status:
        return None, None
    rss = None
    vms = None
    for line in status.split('\n'):
        if line.startswith('VmRSS:'):
            rss = int(line.split()[1]) / 1024  # KB to MB
        if line.startswith('VmSize:'):
            vms = int(line.split()[1]) / 1024
    return rss, vms

def get_threads(pid):
    try:
        return len(os.listdir(f"/proc/{pid}/task"))
    except:
        return None

def get_load():
    try:
        with open("/proc/loadavg", "r") as f:
            return f.read().split()[0]
    except:
        return "0.00"

print("timestamp,cpu_percent,memory_rss_mb,memory_vms_mb,num_threads,load_1min")
for i in range(30):
    cpu = get_cpu_percent(pid, 0.5)
    mem_rss, mem_vms = get_memory_mb(pid)
    threads = get_threads(pid)
    load = get_load()
    if cpu is not None:
        print(f"{time.time():.3f},{cpu:.1f},{mem_rss:.1f},{mem_vms:.1f},{threads},{load}")
    time.sleep(0.2)
'''
    
    stdin, stdout, stderr = ssh.exec_command("cat > /tmp/monitor2.py << 'EOF'\n" + monitor_script + "\nEOF")
    stdout.channel.recv_exit_status()
    
    # Run monitor in background
    ssh.exec_command("nohup python /tmp/monitor2.py > /tmp/monitor2_out.txt 2>&1 &")
    time.sleep(1)
    
    # Trigger transcription
    trigger = r'''
import asyncio
import websockets
import json
import base64
from gtts import gTTS
import os

async def trigger():
    tts = gTTS("Bonjour Bobodo comment vas tu aujourdhui", lang="fr")
    tts.save("/tmp/trig2.mp3")
    os.system("ffmpeg -y -i /tmp/trig2.mp3 -ar 16000 -ac 1 -f s16le /tmp/trig2.pcm 2>/dev/null")
    with open("/tmp/trig2.pcm", "rb") as f:
        pcm = f.read()
    async with websockets.connect("ws://localhost:8000/ws") as ws:
        await ws.send(json.dumps({"type": "session_id", "session_id": "res2-test"}))
        await ws.send(json.dumps({"type": "audio", "audio": base64.b64encode(pcm).decode('utf-8')}))
        msg = await asyncio.wait_for(ws.recv(), timeout=30.0)
        print(f"DONE:{msg}")
asyncio.run(trigger())
'''
    
    stdin, stdout, stderr = ssh.exec_command("cat > /tmp/trigger2.py << 'EOF'\n" + trigger + "\nEOF")
    stdout.channel.recv_exit_status()
    
    print("Triggering transcription...")
    stdin, stdout, stderr = ssh.exec_command("cd /opt/bobodo-vocal && source venv/bin/activate && python /tmp/trigger2.py")
    out = stdout.read().decode('utf-8')
    print(out)
    
    time.sleep(3)
    
    stdin, stdout, stderr = ssh.exec_command("cat /tmp/monitor2_out.txt")
    print("\n=== RESOURCE MONITORING ===")
    print(stdout.read().decode('utf-8'))
    
    ssh.close()

if __name__ == "__main__":
    main()
