import paramiko
import time

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

# Script to run ON the server for precise measurement
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

def generate_test_audio(text, trial_num):
    """Generate gTTS audio and convert to PCM16 16kHz mono"""
    mp3_path = f"/tmp/test_{trial_num}.mp3"
    pcm_path = f"/tmp/test_{trial_num}.pcm"
    
    tts = gTTS(text, lang="fr")
    tts.save(mp3_path)
    
    # Convert to PCM16 16kHz mono
    cmd = f"ffmpeg -y -i {mp3_path} -ar 16000 -ac 1 -f s16le {pcm_path} 2>/dev/null"
    os.system(cmd)
    
    with open(pcm_path, "rb") as f:
        pcm = f.read()
    
    # Get audio duration from file size (16kHz, 16bit, mono = 32000 bytes/sec)
    duration = len(pcm) / 32000.0
    
    return pcm, duration, len(pcm), mp3_path

async def measure_trial(trial_num, phrase):
    """Run one complete measurement trial"""
    print(f"\n{'='*60}")
    print(f"TRIAL {trial_num}: \"{phrase}\"")
    print(f"{'='*60}")
    
    # Generate audio BEFORE connecting to measure it separately
    t_gen0 = time.time()
    pcm_data, audio_duration, pcm_size, mp3_path = generate_test_audio(phrase, trial_num)
    t_gen1 = time.time()
    gen_time_ms = (t_gen1 - t_gen0) * 1000
    
    print(f"\n[PRE-TEST] Audio generation: {gen_time_ms:.0f}ms")
    print(f"[PRE-TEST] Audio duration: {audio_duration:.2f}s")
    print(f"[PRE-TEST] PCM size: {pcm_size} bytes")
    print(f"[PRE-TEST] MP3 size: {os.path.getsize(mp3_path)} bytes")
    
    # Clear journal logs to get fresh STT logs for this trial
    os.system("journalctl --rotate >/dev/null 2>&1 && journalctl --vacuum-time=1s >/dev/null 2>&1")
    await asyncio.sleep(1)
    
    # Now connect and send
    t_ws0 = time.time()
    async with websockets.connect(WS_URL) as ws:
        t_ws1 = time.time()
        ws_connect_ms = (t_ws1 - t_ws0) * 1000
        
        # Send session_id
        t_sid0 = time.time()
        await ws.send(json.dumps({"type": "session_id", "session_id": SESSION_ID}))
        t_sid1 = time.time()
        sid_send_ms = (t_sid1 - t_sid0) * 1000
        
        # Send audio
        t_send0 = time.time()
        await ws.send(json.dumps({
            "type": "audio",
            "audio": base64.b64encode(pcm_data).decode('utf-8')
        }))
        t_send1 = time.time()
        audio_send_ms = (t_send1 - t_send0) * 1000
        
        # Wait for transcription
        t_wait0 = time.time()
        transcription = None
        stt_result = None
        error_msg = None
        
        while True:
            try:
                msg = await asyncio.wait_for(ws.recv(), timeout=30.0)
                data = json.loads(msg)
                
                if data.get("type") == "transcription":
                    t_wait1 = time.time()
                    transcription = data.get("text")
                    stt_latency_ms = (t_wait1 - t_wait0) * 1000
                    break
                elif data.get("type") == "error":
                    t_wait1 = time.time()
                    error_msg = data.get("message")
                    stt_latency_ms = (t_wait1 - t_wait0) * 1000
                    break
            except asyncio.TimeoutError:
                stt_latency_ms = (time.time() - t_wait0) * 1000
                error_msg = "timeout"
                break
        
        # Wait for audio_response or error
        t_bobodo0 = time.time()
        bobodo_latency_ms = None
        audio_response_size = None
        
        if not error_msg:
            while True:
                try:
                    msg = await asyncio.wait_for(ws.recv(), timeout=45.0)
                    data = json.loads(msg)
                    if data.get("type") == "audio_response":
                        t_bobodo1 = time.time()
                        bobodo_latency_ms = (t_bobodo1 - t_bobodo0) * 1000
                        audio_response_size = len(data.get("audio", ""))
                        break
                    elif data.get("type") == "error":
                        t_bobodo1 = time.time()
                        bobodo_latency_ms = (t_bobodo1 - t_bobodo0) * 1000
                        error_msg = data.get("message")
                        break
                except asyncio.TimeoutError:
                    bobodo_latency_ms = (time.time() - t_bobodo0) * 1000
                    error_msg = "timeout_bobodo"
                    break
    
    # Get logs for this trial
    result = subprocess.run(
        ["journalctl", "-u", "bobodo-vocal", "--no-pager", "-n", "100"],
        capture_output=True, text=True
    )
    logs = result.stdout
    
    # Parse logs for STT timing details
    stt_logs = []
    for line in logs.split('\n'):
        if 'stt_service' in line or 'STT_' in line:
            stt_logs.append(line)
    
    return {
        'trial': trial_num,
        'phrase': phrase,
        'audio_duration_s': audio_duration,
        'pcm_size_bytes': pcm_size,
        'mp3_size_bytes': os.path.getsize(mp3_path),
        'gen_time_ms': gen_time_ms,
        'ws_connect_ms': ws_connect_ms,
        'sid_send_ms': sid_send_ms,
        'audio_send_ms': audio_send_ms,
        'stt_latency_ms': stt_latency_ms,
        'transcription': transcription,
        'bobodo_tts_latency_ms': bobodo_latency_ms,
        'audio_response_size': audio_response_size,
        'error': error_msg,
        'stt_logs': stt_logs
    }

async def main():
    phrases = [
        "Bonjour Bobodo, comment ça va ?",
        "Quelle est la capitale du Burkina Faso ?",
        "Explique-moi la photosynthèse en deux phrases.",
        "Résous cette équation : deux x plus trois égale sept.",
        "Donne-moi un conseil pour réviser efficacement."
    ]
    
    results = []
    for i, phrase in enumerate(phrases, 1):
        try:
            r = await measure_trial(i, phrase)
            results.append(r)
            
            # Print summary
            print(f"\n--- TRIAL {i} SUMMARY ---")
            print(f"  Audio duration: {r['audio_duration_s']:.2f}s")
            print(f"  PCM size: {r['pcm_size_bytes']} bytes")
            print(f"  STT latency: {r['stt_latency_ms']:.0f}ms")
            print(f"  Transcription: {r['transcription']}")
            print(f"  Bobodo+TTS: {r['bobodo_tts_latency_ms']:.0f}ms")
            if r['error']:
                print(f"  ERROR: {r['error']}")
            
        except Exception as e:
            print(f"TRIAL {i} FAILED: {e}")
            import traceback
            traceback.print_exc()
        
        await asyncio.sleep(3)
    
    # Final aggregate report
    print(f"\n{'='*60}")
    print("AGGREGATE REPORT")
    print(f"{'='*60}")
    
    valid_stt = [r for r in results if r['stt_latency_ms'] and not r['error']]
    if valid_stt:
        stt_vals = [r['stt_latency_ms'] for r in valid_stt]
        print(f"\nSTT Latency (ms):")
        print(f"  Min: {min(stt_vals):.0f}")
        print(f"  Avg: {sum(stt_vals)/len(stt_vals):.0f}")
        print(f"  Max: {max(stt_vals):.0f}")
        
        bobodo_vals = [r['bobodo_tts_latency_ms'] for r in valid_stt if r['bobodo_tts_latency_ms']]
        if bobodo_vals:
            print(f"\nBobodo+TTS Latency (ms):")
            print(f"  Min: {min(bobodo_vals):.0f}")
            print(f"  Avg: {sum(bobodo_vals)/len(bobodo_vals):.0f}")
            print(f"  Max: {max(bobodo_vals):.0f}")
        
        audio_durations = [r['audio_duration_s'] for r in valid_stt]
        print(f"\nAudio Duration (s):")
        print(f"  Min: {min(audio_durations):.2f}")
        print(f"  Avg: {sum(audio_durations)/len(audio_durations):.2f}")
        print(f"  Max: {max(audio_durations):.2f}")
        
        pcm_sizes = [r['pcm_size_bytes'] for r in valid_stt]
        print(f"\nPCM Size (bytes):")
        print(f"  Min: {min(pcm_sizes)}")
        print(f"  Avg: {sum(pcm_sizes)//len(pcm_sizes)}")
        print(f"  Max: {max(pcm_sizes)}")
    
    # Save detailed results
    with open("/tmp/stt_audit_results.json", "w") as f:
        # Don't save full logs in JSON to keep it manageable
        json_results = []
        for r in results:
            r_copy = {k: v for k, v in r.items() if k != 'stt_logs'}
            r_copy['stt_log_count'] = len(r['stt_logs'])
            json_results.append(r_copy)
        json.dump(json_results, f, indent=2)
    
    print("\nDetailed results saved to /tmp/stt_audit_results.json")
    
    # Print all STT logs for analysis
    print(f"\n{'='*60}")
    print("STT LOGS FROM LAST TRIAL")
    print(f"{'='*60}")
    if results:
        for log in results[-1]['stt_logs']:
            print(log)

asyncio.run(main())
'''

def main():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASS)
    
    stdin, stdout, stderr = ssh.exec_command("cat > /tmp/audit_stt.py << 'EOF'\n" + SCRIPT + "\nEOF")
    stdout.channel.recv_exit_status()
    
    print("Running STT audit script on server...")
    stdin, stdout, stderr = ssh.exec_command("cd /opt/bobodo-vocal && source venv/bin/activate && python /tmp/audit_stt.py", get_pty=True)
    
    for line in iter(stdout.readline, ""):
        print(line, end="")
    
    err = stderr.read().decode('utf-8')
    if err:
        print("STDERR:", err[:2000])
    
    # Retrieve results file
    sftp = ssh.open_sftp()
    try:
        sftp.get("/tmp/stt_audit_results.json", "/tmp/stt_audit_results.json")
        print("\nResults file downloaded to /tmp/stt_audit_results.json")
    except:
        print("Could not download results file")
    
    ssh.close()

if __name__ == "__main__":
    main()
