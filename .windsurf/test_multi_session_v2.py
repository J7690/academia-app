#!/usr/bin/env python3
"""
Mission 1 v2 — Multi-session avec timeout 25s (pour tenir compte du modèle Medium).
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

async def client_session(user_id, wav_path, results):
    session_id = f"test-session-{user_id}"
    messages = []
    start_time = time.time()
    try:
        async with websockets.connect(WS_URL, open_timeout=5, close_timeout=5) as ws:
            connect_time = time.time() - start_time
            messages.append({"event": "connected", "time": connect_time})
            await ws.send(json.dumps({"type": "session_id", "session_id": session_id}))
            audio_b64 = read_pcm_base64(wav_path)
            await ws.send(json.dumps({"type": "audio", "audio": audio_b64}))
            messages.append({"event": "audio_sent", "time": time.time() - start_time})
            # Attendre transcription + audio_response avec timeout 25s
            receive_start = time.time()
            while time.time() - receive_start < 25:
                try:
                    msg = await asyncio.wait_for(ws.recv(), timeout=5)
                    data = json.loads(msg)
                    data["elapsed"] = round(time.time() - receive_start, 2)
                    messages.append(data)
                    if data.get("type") in ("audio_response", "error"):
                        break
                except asyncio.TimeoutError:
                    messages.append({"event": "inner_timeout", "elapsed": round(time.time() - receive_start, 2)})
                    break
    except Exception as e:
        messages.append({"event": "exception", "error": str(e)})
    results[user_id] = messages

async def run_test(num_users):
    print(f"\n--- TEST {num_users} USERS (timeout 25s) ---")
    results = {}
    wav_files = sorted([os.path.join(AUDIO_DIR, f) for f in os.listdir(AUDIO_DIR) if f.endswith(".wav")])
    audio_files = wav_files[:num_users]
    tasks = [client_session(i, audio_files[i], results) for i in range(num_users)]
    await asyncio.gather(*tasks)
    transcriptions = {}
    for uid, msgs in results.items():
        t = [m for m in msgs if m.get("type") == "transcription"]
        e = [m for m in msgs if m.get("type") == "error"]
        print(f"User {uid}: transcriptions={len(t)} errors={len(e)}")
        if t:
            print(f"  → '{t[0].get('text', '')[:60]}' (elapsed={t[0].get('elapsed')}s)")
            transcriptions[uid] = t[0].get("text", "")
    unique = set(transcriptions.values())
    print(f"Users avec transcription: {len(transcriptions)}/{num_users}")
    print(f"Transcriptions uniques: {len(unique)}")
    if len(transcriptions) > 0 and len(unique) < len(transcriptions):
        print("⚠️ MÉLANGE: plusieurs users ont reçu la même transcription")
    if len(transcriptions) < num_users:
        print(f"⚠️ PERTE: {num_users - len(transcriptions)} users sans transcription")
    return results

async def main():
    print("="*60)
    print("MISSION 1 v2 — MULTI-SESSION (timeout 25s)")
    print("="*60)
    all_results = {}
    for n in [2, 3, 5]:
        all_results[f"{n}_users"] = await run_test(n)
        await asyncio.sleep(3)
    with open("/tmp/multi_session_test_v2.json", "w") as f:
        json.dump(all_results, f, indent=2)
    print("\nSauvegardé: /tmp/multi_session_test_v2.json")

if __name__ == "__main__":
    asyncio.run(main())
