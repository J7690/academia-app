import paramiko
import time

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

SCRIPT = '''
import asyncio
import websockets
import json
import base64
import time
import os
from gtts import gTTS

WS_URL = "ws://localhost:8000/ws"
SESSION_ID = "a5eea5b6-7477-4035-b332-444d94de3125"

async def measure():
    timings = {}
    
    t0 = time.time()
    async with websockets.connect(WS_URL) as ws:
        timings['ws_connect'] = (time.time() - t0) * 1000
        
        # 1. Envoyer session_id
        t1 = time.time()
        await ws.send(json.dumps({"type": "session_id", "session_id": SESSION_ID}))
        timings['send_session_id'] = (time.time() - t1) * 1000
        
        # 2. Générer audio TTS
        tts = gTTS("Bonjour Bobodo, comment ça va", lang="fr")
        tts.save("/tmp/latency_test.mp3")
        os.system("ffmpeg -y -i /tmp/latency_test.mp3 -ar 16000 -ac 1 -f s16le /tmp/latency_test.pcm 2>/dev/null")
        with open("/tmp/latency_test.pcm", "rb") as f:
            pcm = f.read()
        
        # 3. Envoyer audio
        t2 = time.time()
        await ws.send(json.dumps({
            "type": "audio",
            "audio": base64.b64encode(pcm).decode('utf-8')
        }))
        timings['send_audio'] = (time.time() - t2) * 1000
        
        # 4. Attendre transcription
        t3 = time.time()
        while True:
            msg = await asyncio.wait_for(ws.recv(), timeout=30.0)
            data = json.loads(msg)
            if data.get("type") == "transcription":
                timings['stt_latency'] = (time.time() - t3) * 1000
                timings['transcription_text'] = data.get("text")
                break
            elif data.get("type") == "error":
                timings['error'] = data.get("message")
                return timings
        
        # 5. Attendre audio_response (TTS + Bobodo)
        t4 = time.time()
        while True:
            msg = await asyncio.wait_for(ws.recv(), timeout=60.0)
            data = json.loads(msg)
            if data.get("type") == "audio_response":
                timings['bobodo_tts_latency'] = (time.time() - t4) * 1000
                timings['audio_length'] = len(data.get("audio", ""))
                break
            elif data.get("type") == "error":
                timings['error'] = data.get("message")
                return timings
    
    timings['total'] = (time.time() - t0) * 1000
    return timings

async def run_trials(n=3):
    results = []
    for i in range(n):
        print(f"=== Trial {i+1}/{n} ===")
        try:
            r = await measure()
            results.append(r)
            print(json.dumps(r, ensure_ascii=False, indent=2))
        except Exception as e:
            print(f"Trial {i+1} failed: {e}")
        await asyncio.sleep(2)
    
    if results:
        stt_vals = [r['stt_latency'] for r in results if 'stt_latency' in r]
        bobodo_vals = [r['bobodo_tts_latency'] for r in results if 'bobodo_tts_latency' in r]
        total_vals = [r['total'] for r in results if 'total' in r]
        
        print("\\n=== LATENCY REPORT ===")
        print(f"STT latency (ms): min={min(stt_vals):.0f}, avg={sum(stt_vals)/len(stt_vals):.0f}, max={max(stt_vals):.0f}")
        print(f"Bobodo+TTS latency (ms): min={min(bobodo_vals):.0f}, avg={sum(bobodo_vals)/len(bobodo_vals):.0f}, max={max(bobodo_vals):.0f}")
        print(f"Total latency (ms): min={min(total_vals):.0f}, avg={sum(total_vals)/len(total_vals):.0f}, max={max(total_vals):.0f}")

asyncio.run(run_trials(3))
'''

def main():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASS)
    
    stdin, stdout, stderr = ssh.exec_command("cat > /tmp/test_latency.py << 'EOF'\n" + SCRIPT + "\nEOF")
    stdout.channel.recv_exit_status()
    
    stdin, stdout, stderr = ssh.exec_command("cd /opt/bobodo-vocal && source venv/bin/activate && python /tmp/test_latency.py", get_pty=True)
    for line in iter(stdout.readline, ""):
        print(line, end="")
    
    err = stderr.read().decode('utf-8')
    if err:
        print("STDERR:", err)
    
    ssh.close()

if __name__ == "__main__":
    main()
