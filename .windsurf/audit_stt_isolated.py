import paramiko
import time

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

SCRIPT = r'''
import asyncio
import websockets
import json
import base64
import time
import os
import subprocess
from gtts import gTTS

WS_URL = "ws://localhost:8000/ws"
SESSION_ID = "a5eea5b6-7477-4035-b332-444d94de3125"

async def run_isolated_test():
    phrase = "Bonjour Bobodo"
    
    # Generate short audio
    mp3_path = "/tmp/isolated_test.mp3"
    pcm_path = "/tmp/isolated_test.pcm"
    
    t0 = time.time()
    tts = gTTS(phrase, lang="fr")
    tts.save(mp3_path)
    os.system(f"ffmpeg -y -i {mp3_path} -ar 16000 -ac 1 -f s16le {pcm_path} 2>/dev/null")
    with open(pcm_path, "rb") as f:
        pcm = f.read()
    print(f"[0] Audio gen: {(time.time()-t0)*1000:.0f}ms | {len(pcm)} bytes | {len(pcm)/32000:.2f}s")
    
    # Clear buffer on server by restarting service
    os.system("systemctl restart bobodo-vocal >/dev/null 2>&1")
    print("[0] Service restarted to clear buffer")
    await asyncio.sleep(5)
    
    # Clear logs
    os.system("journalctl --rotate >/dev/null 2>&1 && journalctl --vacuum-time=1s >/dev/null 2>&1")
    await asyncio.sleep(1)
    
    t_start = time.time()
    
    async with websockets.connect(WS_URL) as ws:
        t_conn = time.time()
        print(f"[1] WS connect: {(t_conn-t_start)*1000:.0f}ms")
        
        await ws.send(json.dumps({"type": "session_id", "session_id": SESSION_ID}))
        
        t_send = time.time()
        await ws.send(json.dumps({
            "type": "audio",
            "audio": base64.b64encode(pcm).decode('utf-8')
        }))
        print(f"[2] Audio sent: {(time.time()-t_send)*1000:.0f}ms")
        
        # Wait for transcription
        t_wait = time.time()
        while True:
            msg = await asyncio.wait_for(ws.recv(), timeout=60.0)
            data = json.loads(msg)
            if data.get("type") == "transcription":
                t_recv = time.time()
                print(f"[3] Transcription recv: {(t_recv-t_wait)*1000:.0f}ms")
                print(f"[3] Text: {data.get('text')}")
                break
            elif data.get("type") == "error":
                print(f"[3] ERROR: {data.get('message')}")
                return
        
        # Wait for audio_response
        t_bobodo = time.time()
        while True:
            msg = await asyncio.wait_for(ws.recv(), timeout=60.0)
            data = json.loads(msg)
            if data.get("type") == "audio_response":
                t_bobodo_recv = time.time()
                print(f"[4] Bobodo+TTS recv: {(t_bobodo_recv-t_bobodo)*1000:.0f}ms")
                break
            elif data.get("type") == "error":
                print(f"[4] ERROR: {data.get('message')}")
                return
    
    t_total = time.time()
    print(f"[5] TOTAL end-to-end: {(t_total-t_start)*1000:.0f}ms")
    
    # Get logs
    await asyncio.sleep(1)
    result = subprocess.run(
        ["journalctl", "-u", "bobodo-vocal", "--no-pager", "-n", "100"],
        capture_output=True, text=True
    )
    logs = result.stdout
    
    print("\n=== STT LOGS ===")
    for line in logs.split('\n'):
        if 'stt_service' in line or 'STT_' in line:
            print(line)

asyncio.run(run_isolated_test())
'''

def main():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASS)
    
    stdin, stdout, stderr = ssh.exec_command("cat > /tmp/audit_iso.py << 'EOF'\n" + SCRIPT + "\nEOF")
    stdout.channel.recv_exit_status()
    
    print("Running isolated STT test with service restart...")
    stdin, stdout, stderr = ssh.exec_command("cd /opt/bobodo-vocal && source venv/bin/activate && python /tmp/audit_iso.py", get_pty=True)
    
    for line in iter(stdout.readline, ""):
        print(line, end="")
    
    err = stderr.read().decode('utf-8')
    if err:
        print("STDERR:", err[:2000])
    
    ssh.close()

if __name__ == "__main__":
    main()
