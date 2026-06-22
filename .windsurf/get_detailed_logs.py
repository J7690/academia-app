import paramiko

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS)

# Get detailed timestamped logs from the last test
stdin, stdout, stderr = ssh.exec_command(
    "journalctl -u bobodo-vocal --since='5 minutes ago' | grep -E 'AUDIO_RECEIVED|Buffer:|Silence detected|Transcribing|Transcription:|Temp file cleaned|Calling callback|STT_CALLBACK|BOBODO_START|BOBODO_CLIENT|BOBODO_SUCCESS|TTS_START|TTS|audio_response|send_audio' | head -80"
)
out = stdout.read().decode()
print(out[:15000])

ssh.close()
