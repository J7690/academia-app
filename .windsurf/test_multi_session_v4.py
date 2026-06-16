#!/usr/bin/env python3
"""
Test multi-session v4 — proves isolation after architecture fix.
Longer timeouts for Medium model sequential processing.
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
            await ws.send(json.dumps({"type": "audio", "audio": read_pcm_base64(wav_path)}))
            messages.append({"event": "audio_sent", "time": time.time() - start_time})

            receive_start = time.time()
            while time.time() - receive_start < 90:
                try:
                    msg = await asyncio.wait_for(ws.recv(), timeout=15)
                    data = json.loads(msg)
                    data["elapsed"] = round(time.time() - receive_start, 2)
                    messages.append(data)
                    print(f"  [User {user_id}] Received {data.get('type')} at {data['elapsed']}s")
                    if data.get("type") == "audio_response":
                        break
                    if data.get("type") == "error":
                        break
                except asyncio.TimeoutError:
                    continue
    except Exception as e:
        messages.append({"event": "exception", "error": str(e)})
    results[user_id] = messages


async def run_test(num_users):
    print(f"\n--- TEST {num_users} USERS ---")
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
    return results, transcriptions


async def main():
    print("="*60)
    print("MISSION 5 v4 — MULTI-SESSION TEST (post-fix, 90s timeout)")
    print("="*60)
    all_results = {}
    all_transcriptions = {}
    for n in [1, 2, 3]:
        results, transcriptions = await run_test(n)
        all_results[f"{n}_users"] = results
        all_transcriptions[f"{n}_users"] = transcriptions
        await asyncio.sleep(3)

    print("\n--- CONTAMINATION CHECK ---")
    for n in [1, 2, 3]:
        transcriptions = all_transcriptions[f"{n}_users"]
        unique_texts = set(transcriptions.values())
        ok = len(unique_texts) == len(transcriptions) and len(transcriptions) == n
        print(f"{n} users: {'NO CONTAMINATION' if ok else 'CONTAMINATION DETECTED'}")

    with open("/tmp/multi_session_v4_test.json", "w") as f:
        json.dump({"results": all_results, "transcriptions": all_transcriptions, "timestamp": time.time()}, f, indent=2)
    print("\nSaved: /tmp/multi_session_v4_test.json")


if __name__ == "__main__":
    asyncio.run(main())
