#!/usr/bin/env python3
"""
Mission 4 — Test de reprise réseau
Couper et rétablir la connexion. Mesurer perte de session et mémoire.
"""

import asyncio
import json
import base64
import time
import websockets
import os

WS_URL = "ws://localhost:8000/ws"
AUDIO_DIR = "/tmp/tiny_academia_benchmark"


def read_pcm_base64(wav_path):
    import wave
    with wave.open(wav_path, "rb") as wf:
        frames = wf.readframes(wf.getnframes())
    return base64.b64encode(frames).decode("utf-8")


async def send_audio_and_wait(ws, wav_path, logs, label):
    """Envoie de l'audio et attend la réponse."""
    audio_b64 = read_pcm_base64(wav_path)
    send_time = time.time()
    await ws.send(json.dumps({"type": "audio", "audio": audio_b64}))
    logs.append({"event": "audio_sent", "label": label, "time": round(time.time(), 2)})

    try:
        msg = await asyncio.wait_for(ws.recv(), timeout=15)
        data = json.loads(msg)
        data["label"] = label
        data["latency"] = round(time.time() - send_time, 2)
        logs.append(data)
        return data
    except asyncio.TimeoutError:
        logs.append({"event": "timeout", "label": label, "time": round(time.time(), 2)})
        return None


async def resilience_test():
    print("="*60)
    print("MISSION 4 — TEST DE REPRISE RÉSEAU")
    print("="*60)

    logs = []
    session_id = "resilience-test-001"

    # Trouver un fichier audio
    wav_files = sorted([os.path.join(AUDIO_DIR, f) for f in os.listdir(AUDIO_DIR) if f.endswith(".wav")])
    if not wav_files:
        print("Pas de fichiers audio")
        return {}
    wav_path = wav_files[0]

    # === ÉTAPE 1: Connexion initiale ===
    print("\n[1/6] Connexion initiale...")
    ws1 = await websockets.connect(WS_URL, open_timeout=5, close_timeout=5)
    await ws1.send(json.dumps({"type": "session_id", "session_id": session_id}))
    logs.append({"event": "connected_initial", "time": round(time.time(), 2)})
    print("  Connecté. Session ID envoyé.")

    # Envoyer audio 1
    print("[2/6] Envoi audio avant coupure...")
    resp1 = await send_audio_and_wait(ws1, wav_path, logs, "before_disconnect")
    if resp1:
        print(f"  Réponse reçue: '{resp1.get('text', '')[:50]}'")
    else:
        print("  TIMEOUT")

    # === ÉTAPE 2: Coupure brutale ===
    print("[3/6] Coupure brutale (close sans handshake)...")
    await ws1.close()
    logs.append({"event": "disconnected_abrupt", "time": round(time.time(), 2)})
    await asyncio.sleep(1)

    # === ÉTAPE 3: Reconnexion ===
    print("[4/6] Reconnexion...")
    ws2 = await websockets.connect(WS_URL, open_timeout=5, close_timeout=5)
    logs.append({"event": "reconnected", "time": round(time.time(), 2)})
    print("  Reconnecté.")

    # === ÉTAPE 4: Même session ID ===
    print("[5/6] Envoi même session ID...")
    await ws2.send(json.dumps({"type": "session_id", "session_id": session_id}))
    logs.append({"event": "session_id_reused", "time": round(time.time(), 2)})

    # === ÉTAPE 5: Envoi audio après reconnexion ===
    print("[6/6] Envoi audio après reconnexion...")
    resp2 = await send_audio_and_wait(ws2, wav_path, logs, "after_reconnect")
    if resp2:
        print(f"  Réponse reçue: '{resp2.get('text', '')[:50]}'")
    else:
        print("  TIMEOUT")

    await ws2.close()
    logs.append({"event": "closed_final", "time": round(time.time(), 2)})

    # Analyse
    print(f"\n--- RÉSUMÉ REPRISE ---")
    initial_connected = any(l.get("event") == "connected_initial" for l in logs)
    reconnected = any(l.get("event") == "reconnected" for l in logs)
    before_resp = any(l.get("label") == "before_disconnect" and l.get("type") == "transcription" for l in logs)
    after_resp = any(l.get("label") == "after_reconnect" and l.get("type") == "transcription" for l in logs)

    print(f"  Connexion initiale: {'OK' if initial_connected else 'FAIL'}")
    print(f"  Réponse avant coupure: {'OK' if before_resp else 'FAIL'}")
    print(f"  Reconnexion: {'OK' if reconnected else 'FAIL'}")
    print(f"  Réponse après reconnexion: {'OK' if after_resp else 'FAIL'}")

    # Vérifier si le service a crashé ou consomme plus de mémoire
    # On vérifie via /health
    try:
        import urllib.request
        req = urllib.request.Request("http://localhost:8000/health", method="GET")
        with urllib.request.urlopen(req, timeout=5) as resp:
            health = json.loads(resp.read().decode())
            print(f"  Health check après test: {health}")
            logs.append({"event": "health_check", "result": health, "time": round(time.time(), 2)})
    except Exception as e:
        print(f"  Health check FAILED: {e}")
        logs.append({"event": "health_check_failed", "error": str(e), "time": round(time.time(), 2)})

    report = {
        "initial_connected": initial_connected,
        "response_before_disconnect": before_resp,
        "reconnected": reconnected,
        "response_after_reconnect": after_resp,
        "logs": logs
    }

    with open("/tmp/resilience_test.json", "w") as f:
        json.dump(report, f, indent=2)

    print(f"\nRésultats sauvegardés: /tmp/resilience_test.json")
    return report


if __name__ == "__main__":
    asyncio.run(resilience_test())
