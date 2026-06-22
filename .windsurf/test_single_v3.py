#!/usr/bin/env python3
"""Single session test — 1 user, 60s timeout."""

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


async def main():
    wav_files = sorted([os.path.join(AUDIO_DIR, f) for f in os.listdir(AUDIO_DIR) if f.endswith(".wav")])
    if not wav_files:
        print("No audio files")
        return
    wav_path = wav_files[0]
    audio_b64 = read_pcm_base64(wav_path)
    session_id = "single-test-001"
    
    messages = []
    start = time.time()
    
    async with websockets.connect(WS_URL, open_timeout=5, close_timeout=5) as ws:
        print(f"[{time.time()-start:.1f}s] Connected")
        await ws.send(json.dumps({"type": "session_id", "session_id": session_id}))
        print(f"[{time.time()-start:.1f}s] Session ID sent")
        await ws.send(json.dumps({"type": "audio", "audio": audio_b64}))
        print(f"[{time.time()-start:.1f}s] Audio sent")
        
        receive_start = time.time()
        while time.time() - receive_start < 60:
            try:
                msg = await asyncio.wait_for(ws.recv(), timeout=10)
                data = json.loads(msg)
                data["elapsed"] = round(time.time() - receive_start, 2)
                messages.append(data)
                print(f"[{time.time()-start:.1f}s] Received: {data.get('type')} — {str(data)[:120]}")
                if data.get("type") == "audio_response":
                    break
            except asyncio.TimeoutError:
                print(f"[{time.time()-start:.1f}s] recv timeout (still waiting)")
                continue
    
    print(f"\nTotal messages: {len(messages)}")
    transcriptions = [m for m in messages if m.get("type") == "transcription"]
    audio_responses = [m for m in messages if m.get("type") == "audio_response"]
    errors = [m for m in messages if m.get("type") == "error"]
    print(f"Transcriptions: {len(transcriptions)}")
    print(f"Audio responses: {len(audio_responses)}")
    print(f"Errors: {len(errors)}")
    
    with open("/tmp/single_test_v3.json", "w") as f:
        json.dump({"messages": messages, "transcriptions": len(transcriptions)}, f, indent=2)
    print("Saved: /tmp/single_test_v3.json")


if __name__ == "__main__":
    asyncio.run(main())
