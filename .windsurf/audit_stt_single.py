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

phrases = [
    "Bonjour Bobodo, comment ça va ?",
    "Quelle est la capitale du Burkina Faso ?",
    "Explique-moi la photosynthèse en deux phrases.",
    "Résous cette equation : deux x plus trois egale sept.",
    "Donne-moi un conseil pour reviser efficacement."
]

async def run_trial(trial_num, phrase):
    print(f"\n{'='*70}")
    print(f"TRIAL {trial_num}: {phrase}")
    print(f"{'='*70}")
    
    # Generate audio
    mp3_path = f"/tmp/trial_{trial_num}.mp3"
    pcm_path = f"/tmp/trial_{trial_num}.pcm"
    
    t0 = time.time()
    tts = gTTS(phrase, lang="fr")
    tts.save(mp3_path)
    os.system(f"ffmpeg -y -i {mp3_path} -ar 16000 -ac 1 -f s16le {pcm_path} 2>/dev/null")
    with open(pcm_path, "rb") as f:
        pcm = f.read()
    t1 = time.time()
    
    audio_duration = len(pcm) / 32000.0
    print(f"[GEN] Audio generated in {(t1-t0)*1000:.0f}ms | Duration: {audio_duration:.2f}s | Size: {len(pcm)} bytes")
    
    # Clear logs first
    os.system("journalctl --rotate >/dev/null 2>&1 && journalctl --vacuum-time=1s >/dev/null 2>&1")
    await asyncio.sleep(0.5)
    
    # Mark time before WS connect
    t_mark = time.time()
    
    async with websockets.connect(WS_URL) as ws:
        t_conn = time.time()
        print(f"[WS] Connected in {(t_conn-t_mark)*1000:.0f}ms")
        
        await ws.send(json.dumps({"type": "session_id", "session_id": SESSION_ID}))
        
        t_send = time.time()
        await ws.send(json.dumps({
            "type": "audio",
            "audio": base64.b64encode(pcm).decode('utf-8')
        }))
        print(f"[SEND] Audio sent in {(time.time()-t_send)*1000:.0f}ms")
        
        # Wait for transcription
        t_wait = time.time()
        transcription = None
        error = None
        
        while True:
            try:
                msg = await asyncio.wait_for(ws.recv(), timeout=35.0)
                data = json.loads(msg)
                if data.get("type") == "transcription":
                    t_recv = time.time()
                    transcription = data.get("text")
                    print(f"[STT] Transcription received in {(t_recv-t_wait)*1000:.0f}ms")
                    print(f"[STT] Text: {transcription}")
                    break
                elif data.get("type") == "error":
                    error = data.get("message")
                    break
            except asyncio.TimeoutError:
                error = "timeout_stt"
                break
        
        # Wait for Bobodo+TTS
        t_bobodo = time.time()
        bobodo_text = None
        
        if transcription and not error:
            while True:
                try:
                    msg = await asyncio.wait_for(ws.recv(), timeout=45.0)
                    data = json.loads(msg)
                    if data.get("type") == "audio_response":
                        t_bobodo_recv = time.time()
                        print(f"[BOBODO+TTS] Response in {(t_bobodo_recv-t_bobodo)*1000:.0f}ms | Audio size: {len(data.get('audio',''))}")
                        break
                    elif data.get("type") == "error":
                        error = data.get("message")
                        break
                except asyncio.TimeoutError:
                    error = "timeout_bobodo"
                    break
    
    # Get fresh logs for this trial
    result = subprocess.run(
        ["journalctl", "-u", "bobodo-vocal", "--no-pager", "-n", "80", "--since", "1 minute ago"],
        capture_output=True, text=True
    )
    logs = result.stdout
    
    # Parse STT-specific log timestamps
    stt_events = []
    for line in logs.split('\n'):
        if 'stt_service' in line:
            # Extract timestamp from log line: "Jun 13 07:00:59 academia00 python[...]: 2026-06-13 07:00:59,901 - stt_service"
            parts = line.split()
            if len(parts) >= 3:
                try:
                    # Try to extract the Python logger timestamp
                    idx = line.find(' - stt_service')
                    if idx > 0:
                        # Look for the datetime before the log level
                        stt_events.append(line)
                except:
                    pass
    
    print(f"\n[LOGS] {len(stt_events)} STT log entries:")
    for ev in stt_events:
        print(f"  {ev}")
    
    return {
        'trial': trial_num,
        'phrase': phrase,
        'audio_duration': audio_duration,
        'pcm_size': len(pcm),
        'transcription': transcription,
        'error': error,
        'stt_events': stt_events
    }

async def main():
    results = []
    for i, phrase in enumerate(phrases, 1):
        r = await run_trial(i, phrase)
        results.append(r)
        await asyncio.sleep(2)
    
    print(f"\n{'='*70}")
    print("FINAL SUMMARY")
    print(f"{'='*70}")
    
    for r in results:
        print(f"\nTrial {r['trial']}: {r['phrase'][:40]}...")
        print(f"  Audio: {r['audio_duration']:.2f}s | {r['pcm_size']} bytes")
        if r['transcription']:
            print(f"  OK: {r['transcription'][:60]}")
        else:
            print(f"  FAIL: {r['error']}")

asyncio.run(main())
'''

def main():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASS)
    
    stdin, stdout, stderr = ssh.exec_command("cat > /tmp/audit_single.py << 'EOF'\n" + SCRIPT + "\nEOF")
    stdout.channel.recv_exit_status()
    
    print("Running single-trial STT audit...")
    stdin, stdout, stderr = ssh.exec_command("cd /opt/bobodo-vocal && source venv/bin/activate && python /tmp/audit_single.py", get_pty=True)
    
    for line in iter(stdout.readline, ""):
        print(line, end="")
    
    err = stderr.read().decode('utf-8')
    if err:
        print("STDERR:", err[:2000])
    
    ssh.close()

if __name__ == "__main__":
    main()
