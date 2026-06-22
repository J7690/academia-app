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

async def measure_step(step_name, phrase):
    print(f"\n{'='*60}")
    print(f"STEP: {step_name}")
    print(f"Phrase: {phrase}")
    print(f"{'='*60}")
    
    # Generate audio
    t0 = time.time()
    mp3_path = f"/tmp/{step_name}.mp3"
    pcm_path = f"/tmp/{step_name}.pcm"
    tts = gTTS(phrase, lang="fr")
    tts.save(mp3_path)
    os.system(f"ffmpeg -y -i {mp3_path} -ar 16000 -ac 1 -f s16le {pcm_path} 2>/dev/null")
    with open(pcm_path, "rb") as f:
        pcm = f.read()
    gen_ms = (time.time() - t0) * 1000
    audio_dur = len(pcm) / 32000.0
    
    print(f"[A] Audio generation: {gen_ms:.0f}ms")
    print(f"[A] Audio duration: {audio_dur:.2f}s")
    print(f"[A] PCM bytes: {len(pcm)}")
    
    # Clear logs
    os.system("journalctl --rotate >/dev/null 2>&1 && journalctl --vacuum-time=1s >/dev/null 2>&1")
    await asyncio.sleep(0.5)
    
    # Connect and measure
    t_ws0 = time.time()
    async with websockets.connect(WS_URL) as ws:
        t_ws1 = time.time()
        ws_ms = (t_ws1 - t_ws0) * 1000
        print(f"[B] WS connect: {ws_ms:.0f}ms")
        
        await ws.send(json.dumps({"type": "session_id", "session_id": SESSION_ID}))
        
        t_send = time.time()
        await ws.send(json.dumps({
            "type": "audio",
            "audio": base64.b64encode(pcm).decode('utf-8')
        }))
        send_ms = (time.time() - t_send) * 1000
        print(f"[C] Audio send: {send_ms:.0f}ms")
        
        # Wait for transcription with generous timeout
        t_wait = time.time()
        transcription = None
        
        while True:
            try:
                msg = await asyncio.wait_for(ws.recv(), timeout=45.0)
                data = json.loads(msg)
                if data.get("type") == "transcription":
                    t_recv = time.time()
                    stt_ms = (t_recv - t_wait) * 1000
                    transcription = data.get("text")
                    print(f"[D] STT total: {stt_ms:.0f}ms")
                    print(f"[D] Transcription: {transcription}")
                    break
                elif data.get("type") == "error":
                    print(f"[D] ERROR: {data.get('message')}")
                    return None
            except asyncio.TimeoutError:
                print(f"[D] TIMEOUT after 45s")
                return None
        
        # Wait for Bobodo+TTS
        t_b0 = time.time()
        while True:
            try:
                msg = await asyncio.wait_for(ws.recv(), timeout=45.0)
                data = json.loads(msg)
                if data.get("type") == "audio_response":
                    t_b1 = time.time()
                    bobodo_ms = (t_b1 - t_b0) * 1000
                    print(f"[E] Bobodo+TTS: {bobodo_ms:.0f}ms")
                    print(f"[E] Audio response size: {len(data.get('audio',''))} chars")
                    break
                elif data.get("type") == "error":
                    print(f"[E] ERROR: {data.get('message')}")
                    break
            except asyncio.TimeoutError:
                print(f"[E] TIMEOUT")
                break
    
    # Get and analyze logs
    await asyncio.sleep(0.5)
    result = subprocess.run(
        ["journalctl", "-u", "bobodo-vocal", "--no-pager", "-n", "100"],
        capture_output=True, text=True
    )
    logs = result.stdout
    
    print(f"\n[F] STT INTERNAL LOGS:")
    stt_lines = [l for l in logs.split('\n') if 'stt_service' in l or 'faster_whisper' in l]
    for line in stt_lines:
        # Extract just the timestamp and message
        idx = line.find(' - stt_service')
        if idx > 0:
            # Extract Python logger timestamp
            start = line.rfind(' ', 0, idx-20)
            print(f"  {line[start+1:idx+30]}...")
        else:
            print(f"  {line[:120]}")
    
    # Parse timestamps
    events = []
    for line in stt_lines:
        if 'STT_AUDIO_RECEIVED' in line:
            events.append(('audio_received', line))
        elif 'STT_SILENCE_DETECTED' in line and 'Starting transcription' in line:
            events.append(('silence_start', line))
        elif 'STT_TRANSCRIPTION_START' in line and 'File size' in line:
            events.append(('transcribe_start', line))
        elif 'STT_TRANSCRIPTION_INFO' in line:
            events.append(('transcribe_info', line))
        elif 'STT_TRANSCRIPTION_SUCCESS' in line:
            events.append(('transcribe_end', line))
        elif 'STT_CALLBACK' in line and 'Calling transcription callback' in line:
            events.append(('callback', line))
    
    print(f"\n[G] KEY EVENTS ({len(events)} found):")
    for ev_type, ev_line in events:
        # Extract time
        parts = ev_line.split()
        for i, p in enumerate(parts):
            if ':' in p and len(p) == 8 and i > 0:  # Time like 07:09:19
                time_str = f"{parts[i-1]} {p}"
                break
        else:
            time_str = "N/A"
        print(f"  {ev_type:20s} | {time_str}")
    
    return {
        'step': step_name,
        'audio_dur': audio_dur,
        'pcm_bytes': len(pcm),
        'ws_ms': ws_ms,
        'send_ms': send_ms,
        'stt_ms': stt_ms if 'stt_ms' in dir() else None,
        'transcription': transcription,
        'events': events
    }

async def main():
    results = []
    
    # Run 3 tests with different phrase lengths
    tests = [
        ("short", "Bonjour Bobodo"),
        ("medium", "Quelle est la capitale du Burkina Faso"),
        ("long", "Explique moi la photosynthese en termes simples pour un eleve de college")
    ]
    
    for step_name, phrase in tests:
        try:
            r = await measure_step(step_name, phrase)
            if r:
                results.append(r)
        except Exception as e:
            print(f"ERROR in {step_name}: {e}")
        await asyncio.sleep(3)
    
    print(f"\n{'='*60}")
    print("SUMMARY")
    print(f"{'='*60}")
    for r in results:
        print(f"\n{r['step']}: {r['transcription'][:50]}...")
        print(f"  Audio: {r['audio_dur']:.2f}s | STT: {r['stt_ms']:.0f}ms")

asyncio.run(main())
'''

def main():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASS)
    
    stdin, stdout, stderr = ssh.exec_command("cat > /tmp/audit_precise.py << 'EOF'\n" + SCRIPT + "\nEOF")
    stdout.channel.recv_exit_status()
    
    print("Running precise STT audit...")
    stdin, stdout, stderr = ssh.exec_command("cd /opt/bobodo-vocal && source venv/bin/activate && python /tmp/audit_precise.py", get_pty=True)
    
    for line in iter(stdout.readline, ""):
        print(line, end="")
    
    err = stderr.read().decode('utf-8')
    if err:
        print("STDERR:", err[:2000])
    
    ssh.close()

if __name__ == "__main__":
    main()
