#!/usr/bin/env python3
"""
Mission 3 — Conversation complète 5 minutes
Connecte au service de production, envoie audio périodiquement, mesure stabilité.
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


async def conversation_test():
    print("="*60)
    print("MISSION 3 — CONVERSATION 5 MINUTES")
    print("="*60)

    session_id = "conv-test-001"
    logs = []
    start_time = time.time()

    # Collecter les fichiers audio disponibles
    wav_files = sorted([os.path.join(AUDIO_DIR, f) for f in os.listdir(AUDIO_DIR) if f.endswith(".wav")])
    if len(wav_files) < 10:
        print(f"Pas assez de fichiers audio dans {AUDIO_DIR}")
        return {}

    # Sélectionner 10 fichiers pour 10 échanges
    audio_files = wav_files[:10]
    audio_interval = 30  # envoyer audio toutes les 30 secondes
    total_duration = 300  # 5 minutes

    try:
        async with websockets.connect(WS_URL, open_timeout=5, close_timeout=5) as ws:
            connect_time = time.time() - start_time
            logs.append({"event": "connected", "time": connect_time})
            print(f"[{(time.time()-start_time):.0f}s] Connecté")

            # Envoyer session_id
            await ws.send(json.dumps({"type": "session_id", "session_id": session_id}))

            exchange_count = 0
            last_send_time = 0

            while time.time() - start_time < total_duration:
                elapsed = time.time() - start_time

                # Envoyer audio toutes les 30s
                if elapsed - last_send_time >= audio_interval and exchange_count < len(audio_files):
                    wav_path = audio_files[exchange_count]
                    audio_b64 = read_pcm_base64(wav_path)
                    await ws.send(json.dumps({"type": "audio", "audio": audio_b64}))
                    send_time = time.time()
                    logs.append({"event": "audio_sent", "exchange": exchange_count, "time": elapsed})
                    print(f"[{(time.time()-start_time):.0f}s] Audio envoyé (échange {exchange_count})")
                    last_send_time = elapsed
                    exchange_count += 1

                    # Attendre réponse (max 15s)
                    try:
                        msg = await asyncio.wait_for(ws.recv(), timeout=15)
                        data = json.loads(msg)
                        data["elapsed_since_send"] = round(time.time() - send_time, 2)
                        data["time"] = round(time.time() - start_time, 2)
                        logs.append(data)
                        if data.get("type") == "transcription":
                            print(f"  → Transcription: '{data.get('text', '')[:50]}'")
                        elif data.get("type") == "audio_response":
                            print(f"  → Audio reçu ({len(data.get('audio', ''))} chars base64)")
                        elif data.get("type") == "error":
                            print(f"  → ERROR: {data.get('message', '')}")
                    except asyncio.TimeoutError:
                        logs.append({"event": "response_timeout", "exchange": exchange_count - 1, "time": round(time.time() - start_time, 2)})
                        print(f"  → TIMEOUT (pas de réponse)")

                # Ping toutes les 10s pour garder la connexion
                if int(elapsed) % 10 == 0 and elapsed > 0:
                    try:
                        await asyncio.wait_for(ws.send(json.dumps({"type": "ping"})), timeout=2)
                        msg = await asyncio.wait_for(ws.recv(), timeout=3)
                        data = json.loads(msg)
                        if data.get("type") == "pong":
                            logs.append({"event": "pong", "time": round(elapsed, 1)})
                    except:
                        pass

                await asyncio.sleep(0.5)

    except websockets.exceptions.ConnectionClosed as e:
        logs.append({"event": "connection_closed", "code": e.code, "reason": str(e.reason), "time": round(time.time() - start_time, 2)})
        print(f"[{(time.time()-start_time):.0f}s] Connexion fermée: {e}")
    except Exception as e:
        logs.append({"event": "exception", "error": str(e), "time": round(time.time() - start_time, 2)})
        print(f"[{(time.time()-start_time):.0f}s] Exception: {e}")

    # Analyse
    total_time = time.time() - start_time
    transcriptions = [l for l in logs if l.get("type") == "transcription"]
    audio_responses = [l for l in logs if l.get("type") == "audio_response"]
    errors = [l for l in logs if l.get("type") == "error"]
    timeouts = [l for l in logs if l.get("event") == "response_timeout"]
    disconnections = [l for l in logs if l.get("event") == "connection_closed"]

    print(f"\n--- RÉSUMÉ 5 MINUTES ---")
    print(f"  Durée totale: {total_time:.0f}s")
    print(f"  Échanges audio envoyés: {exchange_count}")
    print(f"  Transcriptions reçues: {len(transcriptions)}")
    print(f"  Réponses audio reçues: {len(audio_responses)}")
    print(f"  Erreurs: {len(errors)}")
    print(f"  Timeouts: {len(timeouts)}")
    print(f"  Déconnexions: {len(disconnections)}")

    report = {
        "duration_seconds": round(total_time, 1),
        "exchanges_sent": exchange_count,
        "transcriptions_received": len(transcriptions),
        "audio_responses_received": len(audio_responses),
        "errors_count": len(errors),
        "timeouts_count": len(timeouts),
        "disconnections_count": len(disconnections),
        "stability_percent": round((len(transcriptions) / max(exchange_count, 1)) * 100, 1),
        "logs": logs
    }

    with open("/tmp/conversation_test.json", "w") as f:
        json.dump(report, f, indent=2)

    print(f"\nRésultats sauvegardés: /tmp/conversation_test.json")
    return report


if __name__ == "__main__":
    asyncio.run(conversation_test())
