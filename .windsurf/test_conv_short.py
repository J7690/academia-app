#!/usr/bin/env python3
"""Quick 3-exchange conversation test."""
import asyncio, json, base64, time, websockets, os

WS_URL = "ws://localhost:8000/ws"
AUDIO_DIR = "/tmp/tiny_academia_benchmark"

def read_pcm_base64(wav_path):
    import wave
    with wave.open(wav_path, "rb") as wf:
        return base64.b64encode(wf.readframes(wf.getnframes())).decode("utf-8")

async def main():
    wav_files = sorted([os.path.join(AUDIO_DIR, f) for f in os.listdir(AUDIO_DIR) if f.endswith(".wav")])[:3]
    session_id = "conv-final-test"
    results = []

    async with websockets.connect(WS_URL, open_timeout=5) as ws:
        await ws.send(json.dumps({"type": "session_id", "session_id": session_id}))

        for i, wav_path in enumerate(wav_files):
            t0 = time.time()
            await ws.send(json.dumps({"type": "audio", "audio": read_pcm_base64(wav_path)}))
            got_transcription = False
            got_audio = False
            while time.time() - t0 < 30:
                try:
                    msg = await asyncio.wait_for(ws.recv(), timeout=10)
                    data = json.loads(msg)
                    if data.get("type") == "transcription":
                        got_transcription = True
                        print(f"  [{i}] Transcription ({time.time()-t0:.1f}s): '{data['text'][:50]}'")
                    elif data.get("type") == "audio_response":
                        got_audio = True
                        print(f"  [{i}] Audio ({time.time()-t0:.1f}s): {len(data['audio'])} chars")
                        break
                    elif data.get("type") == "error":
                        print(f"  [{i}] Error: {data['message']}")
                        break
                except asyncio.TimeoutError:
                    break
            results.append({"exchange": i, "transcription": got_transcription, "audio": got_audio, "time": round(time.time()-t0, 1)})
            await asyncio.sleep(1)

    print(f"\n--- RÉSUMÉ ---")
    ok = sum(1 for r in results if r["transcription"] and r["audio"])
    print(f"  Échanges complets: {ok}/{len(results)}")
    for r in results:
        print(f"  [{r['exchange']}] trans={r['transcription']} audio={r['audio']} time={r['time']}s")
    print(json.dumps(results))

if __name__ == "__main__":
    asyncio.run(main())
