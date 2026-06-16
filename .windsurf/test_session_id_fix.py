import paramiko
import asyncio
import websockets
import json
import base64
import time

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"
WS_URL = "ws://185.167.97.144:8000/ws"

async def test_websocket():
    print("[TEST] Connexion WebSocket...")
    async with websockets.connect(WS_URL) as ws:
        print("[TEST] Connecté")
        
        # Envoyer session_id
        session_msg = {"type": "session_id", "session_id": "test-session-abc-123"}
        await ws.send(json.dumps(session_msg))
        print(f"[TEST] Envoyé: {session_msg}")
        
        # Envoyer audio factice (silence PCM16)
        fake_audio = base64.b64encode(bytes(32000)).decode('utf-8')  # 1s silence @ 16kHz 16bit
        audio_msg = {"type": "audio", "audio": fake_audio}
        await ws.send(json.dumps(audio_msg))
        print(f"[TEST] Envoyé audio: {len(fake_audio)} chars base64")
        
        # Attendre réponse
        try:
            response = await asyncio.wait_for(ws.recv(), timeout=15.0)
            print(f"[TEST] Réponse reçue: {response}")
            data = json.loads(response)
            if data.get("type") == "transcription":
                print("[TEST] ✅ Transcription reçue")
            elif data.get("type") == "error":
                print(f"[TEST] ❌ Erreur: {data.get('message')}")
            else:
                print(f"[TEST] ⚠️ Type inattendu: {data.get('type')}")
        except asyncio.TimeoutError:
            print("[TEST] ⏱️ Timeout après 15s")
        
        await ws.close()
        print("[TEST] Déconnecté")

def read_journalctl():
    print("\n[JOURNAL] Connexion SSH...")
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASS)
    
    # Lire les 50 dernières lignes de logs
    stdin, stdout, stderr = ssh.exec_command("journalctl -u bobodo-vocal --no-pager -n 50")
    logs = stdout.read().decode('utf-8')
    err = stderr.read().decode('utf-8')
    ssh.close()
    
    return logs, err

if __name__ == "__main__":
    # 1. Lire logs avant
    logs_before, _ = read_journalctl()
    
    # 2. Tester WS
    asyncio.run(test_websocket())
    time.sleep(3)  # Attendre que les logs s'écrivent
    
    # 3. Lire logs après
    logs_after, _ = read_journalctl()
    
    # 4. Diff
    before_lines = set(logs_before.splitlines())
    after_lines = logs_after.splitlines()
    new_lines = [l for l in after_lines if l not in before_lines]
    
    print("\n========== NOUVEAUX LOGS ==========")
    for line in new_lines:
        print(line)
    print("========== FIN LOGS ==========")
    
    # 5. Vérifier preuves
    has_session = any("Session ID set" in l or "session_id" in l.lower() for l in new_lines)
    has_audio = any("audio" in l.lower() or "stt" in l.lower() for l in new_lines)
    
    print(f"\n[PREUVE] Session ID enregistré: {'✅ OUI' if has_session else '❌ NON'}")
    print(f"[PREUVE] Audio reçu: {'✅ OUI' if has_audio else '❌ NON'}")
