import paramiko

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS)

# Get TTS-specific logs
stdin, stdout, stderr = ssh.exec_command(
    "journalctl -u bobodo-vocal --since='5 minutes ago' | grep -iE 'TTS|synthesiz|audio_response'"
)
out = stdout.read().decode()
print(out[:10000])

# Also check the tts_service.py source
stdin, stdout, stderr = ssh.exec_command("cat /opt/bobodo-vocal/tts_service.py")
tts = stdout.read().decode()
print("\n=== TTS SERVICE SOURCE ===")
print(tts[:5000])

ssh.close()
