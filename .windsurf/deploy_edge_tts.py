import paramiko
import time

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"
REMOTE_PATH = "/opt/bobodo-vocal"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS)

# Backup current TTS
print("Backup gTTS...")
ssh.exec_command(f"cp {REMOTE_PATH}/tts_service.py {REMOTE_PATH}/tts_service.py.backup_gtts")

# Install edge-tts
print("Installing edge-tts...")
stdin, stdout, stderr = ssh.exec_command(f"cd {REMOTE_PATH} && source venv/bin/activate && pip install edge-tts 2>&1 | tail -5")
print(stdout.read().decode())

# Upload new TTS
sftp = ssh.open_sftp()
sftp.put(r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\tts_service_edge.py", f"{REMOTE_PATH}/tts_service.py")
sftp.close()

# Syntax check
stdin, stdout, stderr = ssh.exec_command(f"cd {REMOTE_PATH} && source venv/bin/activate && python -m py_compile tts_service.py && echo 'OK'")
out = stdout.read().decode()
if "OK" not in out:
    print("SYNTAX ERROR:", out, stderr.read().decode())
    ssh.close()
    exit(1)
print("Syntax OK.")

# Restart
print("Restarting service...")
ssh.exec_command("systemctl restart bobodo-vocal")
time.sleep(10)

stdin, stdout, stderr = ssh.exec_command("systemctl is-active bobodo-vocal")
status = stdout.read().decode().strip()
print(f"Service: {status}")

if status != "active":
    print("FAILED — rolling back...")
    ssh.exec_command(f"cp {REMOTE_PATH}/tts_service.py.backup_gtts {REMOTE_PATH}/tts_service.py")
    ssh.exec_command("systemctl restart bobodo-vocal")
    ssh.close()
    exit(1)

# === BENCHMARK: Run single user test to compare latency ===
print("\n=== BENCHMARK EDGE-TTS ===")

test_script = """
import asyncio, json, base64, time, websockets, os
WS_URL = "ws://localhost:8000/ws"
AUDIO_DIR = "/tmp/tiny_academia_benchmark"
def read_pcm_base64(wav_path):
    import wave
    with wave.open(wav_path, "rb") as wf:
        return base64.b64encode(wf.readframes(wf.getnframes())).decode("utf-8")

async def main():
    wav_files = sorted([os.path.join(AUDIO_DIR, f) for f in os.listdir(AUDIO_DIR) if f.endswith(".wav")])
    wav = wav_files[0]
    session_id = "edge-tts-bench"
    async with websockets.connect(WS_URL, open_timeout=5) as ws:
        await ws.send(json.dumps({"type": "session_id", "session_id": session_id}))
        t0 = time.time()
        await ws.send(json.dumps({"type": "audio", "audio": read_pcm_base64(wav)}))
        t_trans = None
        t_audio = None
        while time.time() - t0 < 30:
            try:
                msg = await asyncio.wait_for(ws.recv(), timeout=10)
                data = json.loads(msg)
                if data.get("type") == "transcription":
                    t_trans = time.time() - t0
                    print(f"Transcription: {t_trans:.2f}s — '{data['text'][:40]}'")
                elif data.get("type") == "audio_response":
                    t_audio = time.time() - t0
                    print(f"Audio response: {t_audio:.2f}s — {len(data['audio'])} chars")
                    break
                elif data.get("type") == "error":
                    print(f"Error: {data['message']}")
                    break
            except asyncio.TimeoutError:
                break
    if t_trans and t_audio:
        print(f"\\nSTT: {t_trans:.2f}s | Bobodo+TTS: {t_audio - t_trans:.2f}s | Total: {t_audio:.2f}s")

asyncio.run(main())
"""

# Use file approach
ssh.exec_command(f"cat > /tmp/bench_edge.py << 'PYEOF'\n{test_script}\nPYEOF")
stdin, stdout, stderr = ssh.exec_command(f"cd {REMOTE_PATH} && source venv/bin/activate && python /tmp/bench_edge.py", timeout=60)
bench_out = stdout.read().decode()
print(bench_out)
print("STDERR:", stderr.read().decode()[:200])

# Check logs for TTS timing
print("\n=== TTS LOGS ===")
stdin, stdout, stderr = ssh.exec_command("journalctl -u bobodo-vocal --since='1 min ago' | grep TTS")
print(stdout.read().decode()[:1000])

# RAM
stdin, stdout, stderr = ssh.exec_command("systemctl status bobodo-vocal --no-pager | grep Memory")
print(stdout.read().decode().strip())

ssh.close()
print("\nÉTAPE 3 TERMINÉE.")
