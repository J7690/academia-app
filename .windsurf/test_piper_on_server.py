import paramiko
import time

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

SCRIPT = '''
import subprocess
import time
import os

text = "Bonjour Bobodo, comment ça va ?"

# 1. Test Piper
print("=== PIPER TEST ===")
try:
    t0 = time.time()
    proc = subprocess.run(
        [
            "/opt/bobodo-vocal/venv/bin/piper",
            "-m", "/opt/bobodo-vocal/models/model.onnx",
            "-c", "/opt/bobodo-vocal/models/config.json",
            "--output_file", "/tmp/piper_test.wav"
        ],
        input=text.encode('utf-8'),
        capture_output=True,
        timeout=30
    )
    t1 = time.time()
    print(f"Piper exit code: {proc.returncode}")
    print(f"Piper stderr: {proc.stderr.decode('utf-8')[:500]}")
    if os.path.exists("/tmp/piper_test.wav"):
        size = os.path.getsize("/tmp/piper_test.wav")
        print(f"Piper latency: {(t1-t0)*1000:.0f} ms")
        print(f"Piper file size: {size} bytes")
    else:
        print("Piper: no output file")
except Exception as e:
    print(f"Piper error: {e}")

# 2. Test gTTS
print("\\n=== GTTS TEST ===")
try:
    from gtts import gTTS
    t0 = time.time()
    tts = gTTS(text, lang="fr")
    tts.save("/tmp/gtts_test.mp3")
    t1 = time.time()
    size = os.path.getsize("/tmp/gtts_test.mp3")
    print(f"gTTS latency: {(t1-t0)*1000:.0f} ms")
    print(f"gTTS file size: {size} bytes")
except Exception as e:
    print(f"gTTS error: {e}")
'''

def main():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASS)
    
    stdin, stdout, stderr = ssh.exec_command("cat > /tmp/test_piper.py << 'EOF'\n" + SCRIPT + "\nEOF")
    stdout.channel.recv_exit_status()
    
    stdin, stdout, stderr = ssh.exec_command("cd /opt/bobodo-vocal && source venv/bin/activate && python /tmp/test_piper.py")
    for line in iter(stdout.readline, ""):
        print(line, end="")
    
    err = stderr.read().decode('utf-8')
    if err:
        print("STDERR:", err)
    
    ssh.close()

if __name__ == "__main__":
    main()
