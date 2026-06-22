import paramiko

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

# This script runs ON the server and performs all audit missions
SCRIPT = r'''
import asyncio
import websockets
import json
import base64
import time
import os
import subprocess
import sys
import threading
from gtts import gTTS

WS_URL = "ws://localhost:8000/ws"

# ============================================================
# MISSION 3: REPRODUCTION DU MELANGE DE SESSIONS
# ============================================================
async def mission_3_session_isolation():
    print("\n" + "="*70)
    print("MISSION 3 — REPRODUCTION DU MELANGE DE SESSIONS")
    print("="*70)
    
    sessions = [
        ("session-a", "Bonjour Bobodo"),
        ("session-b", "Quelle est la capitale du Burkina"),
        ("session-c", "Comment postuler sur Academia"),
    ]
    
    results = []
    
    for sid, phrase in sessions:
        # Generate audio
        mp3_path = f"/tmp/m3_{sid}.mp3"
        pcm_path = f"/tmp/m3_{sid}.pcm"
        tts = gTTS(phrase, lang="fr")
        tts.save(mp3_path)
        os.system(f"ffmpeg -y -i {mp3_path} -ar 16000 -ac 1 -f s16le {pcm_path} 2>/dev/null")
        with open(pcm_path, "rb") as f:
            pcm = f.read()
        
        # Connect, send, disconnect IMMEDIATELY (no waiting for response)
        async with websockets.connect(WS_URL) as ws:
            await ws.send(json.dumps({"type": "session_id", "session_id": sid}))
            await ws.send(json.dumps({
                "type": "audio",
                "audio": base64.b64encode(pcm).decode('utf-8')
            }))
            print(f"[{sid}] Sent: '{phrase}' ({len(pcm)} bytes)")
            # DO NOT wait for response - disconnect immediately
            # This leaves audio in the buffer
        
        await asyncio.sleep(0.5)
    
    # Now connect a 4th session and wait for transcription
    # The buffer should contain audio from ALL 3 previous sessions
    print("\n[FINAL] Connecting session-d to drain accumulated buffer...")
    
    # Wait for silence detection on accumulated buffer
    await asyncio.sleep(2)  # Wait for silence threshold of first sessions
    
    async with websockets.connect(WS_URL) as ws:
        await ws.send(json.dumps({"type": "session_id", "session_id": "session-d"}))
        # Send tiny audio to trigger silence detection on accumulated buffer
        tiny_pcm = b'\x00\x00' * 1600  # 100ms of silence
        await ws.send(json.dumps({
            "type": "audio",
            "audio": base64.b64encode(tiny_pcm).decode('utf-8')
        }))
        
        try:
            msg = await asyncio.wait_for(ws.recv(), timeout=20.0)
            data = json.loads(msg)
            if data.get("type") == "transcription":
                print(f"[FINAL] Transcription received: '{data.get('text')}'")
                print(f"[FINAL] MELANGE DETECTE: {'OUI' if len(data.get('text','')) > 50 else 'NON'}")
            else:
                print(f"[FINAL] Unexpected: {data}")
        except asyncio.TimeoutError:
            print("[FINAL] Timeout - no transcription received")

# ============================================================
# MISSION 4: PROFILAGE model.transcribe()
# ============================================================
async def mission_4_transcribe_profiling():
    print("\n" + "="*70)
    print("MISSION 4 — PROFILAGE model.transcribe()")
    print("="*70)
    
    # We need to monkey-patch or use internal faster_whisper logging
    # Let's create a script that runs whisper with detailed timing
    profile_script = """
import time
import sys
sys.path.insert(0, '/opt/bobodo-vocal')

from faster_whisper import WhisperModel
import tempfile
import os

# Load the same model as the service
print("[PROFILER] Loading model...")
t0 = time.time()
model = WhisperModel("medium", device="cpu", compute_type="int8")
print(f"[PROFILER] Model loaded in {(time.time()-t0)*1000:.0f}ms")

# Generate test audio
from gtts import gTTS
import subprocess

for i, text in enumerate([
    "Bonjour Bobodo",
    "Quelle est la capitale du Burkina Faso",
    "Explique moi la photosynthese en termes simples pour un eleve de college"
]):
    mp3 = f"/tmp/prof_{i}.mp3"
    pcm = f"/tmp/prof_{i}.pcm"
    tts = gTTS(text, lang="fr")
    tts.save(mp3)
    subprocess.run(["ffmpeg", "-y", "-i", mp3, "-ar", "16000", "-ac", "1", "-f", "s16le", pcm], 
                   capture_output=True)
    
    with open(pcm, "rb") as f:
        data = f.read()
    
    # Add WAV header
    import struct
    raw_pcm = data
    header = struct.pack('<4sI4s', b'RIFF', 36 + len(raw_pcm), b'WAVE')
    fmt = struct.pack('<4sIHHIIHH', b'fmt ', 16, 1, 1, 16000, 32000, 2, 16)
    data_hdr = struct.pack('<4sI', b'data', len(raw_pcm))
    wav = header + fmt + data_hdr + raw_pcm
    
    wav_path = f"/tmp/prof_{i}.wav"
    with open(wav_path, "wb") as f:
        f.write(wav)
    
    print(f"\\n[PROFILER] Test {i}: '{text[:40]}...'")
    print(f"[PROFILER] Audio: {len(data)/32000:.2f}s, {len(wav)} bytes")
    
    # Time the transcription
    t1 = time.time()
    segments, info = model.transcribe(wav_path, language="fr", beam_size=5, vad_filter=False)
    
    # Force generator consumption
    text_out = ""
    for seg in segments:
        text_out += seg.text + " "
    
    t2 = time.time()
    print(f"[PROFILER] Transcription: {(t2-t1)*1000:.0f}ms")
    print(f"[PROFILER] Result: '{text_out.strip()}'")
    print(f"[PROFILER] Info: lang={info.language}, dur={info.duration:.2f}s")
    print(f"[PROFILER] Ratio: {(t2-t1)/info.duration:.2f}x realtime")
"""
    
    with open("/tmp/profile_whisper.py", "w") as f:
        f.write(profile_script)
    
    print("[MISSION 4] Running whisper profiler...")
    result = subprocess.run(
        ["bash", "-c", "cd /opt/bobodo-vocal && source venv/bin/activate && python /tmp/profile_whisper.py"],
        capture_output=True, text=True, timeout=300
    )
    print(result.stdout)
    if result.stderr:
        print("STDERR:", result.stderr[:2000])

# ============================================================
# MISSION 5: CPU/RAM PENDANT TRANSCRIPTION
# ============================================================
async def mission_5_resource_monitoring():
    print("\n" + "="*70)
    print("MISSION 5 — CPU/RAM PENDANT TRANSCRIPTION")
    print("="*70)
    
    # Start resource monitoring in background
    monitor_script = """
import time
import psutil
import sys

# Find the bobodo-vocal process
for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
    if 'bobodo-vocal' in str(proc.info.get('cmdline', '')) or 'main.py' in str(proc.info.get('cmdline', '')):
        pid = proc.info['pid']
        break
else:
    # Fallback: find python process with highest CPU
    pid = None
    for proc in psutil.process_iter(['pid', 'name', 'cpu_percent']):
        if proc.info['name'] == 'python' or proc.info['name'] == 'python3':
            pid = proc.info['pid']
            break

if not pid:
    print("Process not found")
    sys.exit(1)

print(f"Monitoring PID {pid}")
proc = psutil.Process(pid)

# Wait for transcription to start
print("timestamp,cpu_percent,memory_rss_mb,memory_vms_mb,num_threads,load_avg")
for i in range(60):  # Monitor for 60 seconds
    try:
        cpu = proc.cpu_percent(interval=0.5)
        mem = proc.memory_info()
        threads = proc.num_threads()
        load = os.getloadavg() if hasattr(os, 'getloadavg') else (0,0,0)
        print(f"{time.time():.3f},{cpu:.1f},{mem.rss/1024/1024:.1f},{mem.vms/1024/1024:.1f},{threads},{load[0]:.2f}")
        sys.stdout.flush()
    except Exception as e:
        print(f"ERROR: {e}")
        break
"""
    with open("/tmp/monitor_resources.py", "w") as f:
        f.write(monitor_script)
    
    # Start monitor in background
    import subprocess
    monitor_proc = subprocess.Popen(
        ["bash", "-c", "cd /opt/bobodo-vocal && source venv/bin/activate && python /tmp/monitor_resources.py"],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
    )
    
    await asyncio.sleep(1)  # Let monitor start
    
    # Trigger transcription
    mp3_path = "/tmp/m5_test.mp3"
    pcm_path = "/tmp/m5_test.pcm"
    tts = gTTS("Bonjour Bobodo comment vas tu aujourdhui", lang="fr")
    tts.save(mp3_path)
    os.system(f"ffmpeg -y -i {mp3_path} -ar 16000 -ac 1 -f s16le {pcm_path} 2>/dev/null")
    with open(pcm_path, "rb") as f:
        pcm = f.read()
    
    print("[MISSION 5] Triggering transcription...")
    t_start = time.time()
    
    async with websockets.connect(WS_URL) as ws:
        await ws.send(json.dumps({"type": "session_id", "session_id": "m5-test"}))
        await ws.send(json.dumps({
            "type": "audio",
            "audio": base64.b64encode(pcm).decode('utf-8')
        }))
        try:
            msg = await asyncio.wait_for(ws.recv(), timeout=30.0)
            print(f"[MISSION 5] Response in {(time.time()-t_start)*1000:.0f}ms")
        except asyncio.TimeoutError:
            print("[MISSION 5] Timeout")
    
    # Collect monitor output
    await asyncio.sleep(2)
    monitor_proc.terminate()
    stdout, stderr = monitor_proc.communicate(timeout=5)
    
    print("\n[MISSION 5] Resource monitoring results:")
    lines = stdout.strip().split('\n')
    for line in lines:
        print(f"  {line}")

# ============================================================
# MISSION 6: CONCURRENCE MULTI-UTILISATEURS
# ============================================================
async def mission_6_concurrent_users():
    print("\n" + "="*70)
    print("MISSION 6 — CONCURRENCE MULTI-UTILISATEURS")
    print("="*70)
    
    async def user_session(sid, phrase, results, idx):
        mp3_path = f"/tmp/m6_{sid}.mp3"
        pcm_path = f"/tmp/m6_{sid}.pcm"
        tts = gTTS(phrase, lang="fr")
        tts.save(mp3_path)
        os.system(f"ffmpeg -y -i {mp3_path} -ar 16000 -ac 1 -f s16le {pcm_path} 2>/dev/null")
        with open(pcm_path, "rb") as f:
            pcm = f.read()
        
        t0 = time.time()
        transcription = None
        error = None
        
        try:
            async with websockets.connect(WS_URL) as ws:
                await ws.send(json.dumps({"type": "session_id", "session_id": sid}))
                await ws.send(json.dumps({
                    "type": "audio",
                    "audio": base64.b64encode(pcm).decode('utf-8')
                }))
                
                msg = await asyncio.wait_for(ws.recv(), timeout=35.0)
                data = json.loads(msg)
                if data.get("type") == "transcription":
                    transcription = data.get("text")
                elif data.get("type") == "error":
                    error = data.get("message")
        except Exception as e:
            error = str(e)
        
        t1 = time.time()
        results[idx] = {
            'sid': sid,
            'phrase': phrase,
            'latency_ms': (t1-t0)*1000,
            'transcription': transcription,
            'error': error
        }
    
    for num_users in [2, 3, 5]:
        print(f"\n--- Testing {num_users} concurrent users ---")
        
        phrases = [
            "Bonjour Bobodo",
            "Quelle est la capitale",
            "Explique la photosynthese",
            "Comment postuler sur Academia",
            "Donne moi un conseil de revision"
        ]
        
        results = [None] * num_users
        tasks = []
        for i in range(num_users):
            sid = f"user-{i+1}"
            task = asyncio.create_task(user_session(sid, phrases[i], results, i))
            tasks.append(task)
        
        await asyncio.gather(*tasks, return_exceptions=True)
        
        for r in results:
            if r:
                status = "OK" if r['transcription'] else f"FAIL: {r['error']}"
                print(f"  {r['sid']}: {r['latency_ms']:.0f}ms | {status}")
                if r['transcription']:
                    print(f"    Trans: '{r['transcription']}'")
        
        # Clear buffer between tests by waiting
        await asyncio.sleep(5)

# ============================================================
# MAIN
# ============================================================
async def main():
    # Run missions
    await mission_3_session_isolation()
    await asyncio.sleep(3)
    
    await mission_4_transcribe_profiling()
    await asyncio.sleep(3)
    
    await mission_5_resource_monitoring()
    await asyncio.sleep(3)
    
    await mission_6_concurrent_users()

asyncio.run(main())
'''

def main():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASS)
    
    stdin, stdout, stderr = ssh.exec_command("cat > /tmp/audit_missions.py << 'EOF'\n" + SCRIPT + "\nEOF")
    stdout.channel.recv_exit_status()
    
    print("Running comprehensive audit missions on server...")
    print("This will take several minutes...")
    stdin, stdout, stderr = ssh.exec_command(
        "cd /opt/bobodo-vocal && source venv/bin/activate && python /tmp/audit_missions.py",
        get_pty=True
    )
    
    for line in iter(stdout.readline, ""):
        print(line, end="")
    
    err = stderr.read().decode('utf-8')
    if err:
        print("STDERR:", err[:2000])
    
    ssh.close()

if __name__ == "__main__":
    main()
