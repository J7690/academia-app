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
import os

WS_URL = "ws://localhost:8000/ws"

async def test():
    async with websockets.connect(WS_URL) as ws:
        # 1. Envoyer session_id
        await ws.send(json.dumps({"type": "session_id", "session_id": "test-bobodo-123"}))
        print("[TEST] session_id envoyé")
        
        # 2. Générer audio TTS avec gTTS
        try:
            from gtts import gTTS
            tts = gTTS("Bonjour Bobodo, comment ça va?", lang="fr")
            tts.save("/tmp/test_audio.mp3")
            print("[TEST] Audio gTTS généré: /tmp/test_audio.mp3")
        except Exception as e:
            print(f"[TEST] Erreur gTTS: {e}")
            return
        
        # 3. Convertir MP3 -> WAV PCM16 16kHz mono avec ffmpeg
        os.system("ffmpeg -y -i /tmp/test_audio.mp3 -ar 16000 -ac 1 -f s16le /tmp/test_audio.pcm 2>/dev/null")
        
        if not os.path.exists("/tmp/test_audio.pcm"):
            print("[TEST] Erreur conversion ffmpeg")
            return
        
        with open("/tmp/test_audio.pcm", "rb") as f:
            pcm_data = f.read()
        
        print(f"[TEST] Audio PCM: {len(pcm_data)} bytes")
        
        # 4. Envoyer audio
        await ws.send(json.dumps({
            "type": "audio",
            "audio": base64.b64encode(pcm_data).decode('utf-8')
        }))
        print("[TEST] Audio envoyé")
        
        # 5. Attendre réponses (transcription, puis audio_response ou error)
        for _ in range(5):
            try:
                msg = await asyncio.wait_for(ws.recv(), timeout=20.0)
                data = json.loads(msg)
                print(f"[TEST] Réponse: {data.get('type')} -> {str(data)[:200]}")
            except asyncio.TimeoutError:
                print("[TEST] Timeout attente réponse")
                break

asyncio.run(test())
'''

def main():
    print("[SSH] Connexion à Kamatera...")
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASS)
    
    # Écrire le script sur le serveur
    stdin, stdout, stderr = ssh.exec_command("cat > /tmp/test_ws_full.py << 'EOF'\n" + SCRIPT + "\nEOF")
    stdout.channel.recv_exit_status()
    print("[SSH] Script écrit sur /tmp/test_ws_full.py")
    
    # Exécuter dans le venv
    cmd = "cd /opt/bobodo-vocal && source venv/bin/activate && python /tmp/test_ws_full.py"
    stdin, stdout, stderr = ssh.exec_command(cmd, get_pty=True)
    
    print("[SSH] Exécution du test...")
    for line in iter(stdout.readline, ""):
        print(line, end="")
    
    err = stderr.read().decode('utf-8')
    if err:
        print("[SSH] STDERR:", err)
    
    ssh.close()
    print("[SSH] Terminé")

if __name__ == "__main__":
    main()
