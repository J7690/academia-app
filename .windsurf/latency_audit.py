#!/usr/bin/env python3
"""
Audit de latence bout-en-bout — mesure chaque étape du pipeline vocal.
Exécuté sur le serveur Kamatera (localhost).
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


async def measure_latency():
    print("="*60)
    print("AUDIT LATENCE BOUT-EN-BOUT")
    print("="*60)

    wav_files = sorted([os.path.join(AUDIO_DIR, f) for f in os.listdir(AUDIO_DIR) if f.endswith(".wav")])
    if not wav_files:
        print("No audio files")
        return

    results = []

    for i, wav_path in enumerate(wav_files[:5]):
        print(f"\n--- Échange {i} ---")
        session_id = f"latency-test-{i}"

        async with websockets.connect(WS_URL, open_timeout=5, close_timeout=5) as ws:
            await ws.send(json.dumps({"type": "session_id", "session_id": session_id}))

            audio_b64 = read_pcm_base64(wav_path)

            # T0: audio envoyé
            t0_send = time.time()
            await ws.send(json.dumps({"type": "audio", "audio": audio_b64}))
            print(f"  T0 (audio sent): {t0_send:.3f}")

            # Attendre tous les messages
            t_transcription = None
            t_audio_response = None
            transcription_text = ""

            receive_start = time.time()
            while time.time() - receive_start < 90:
                try:
                    msg = await asyncio.wait_for(ws.recv(), timeout=15)
                    data = json.loads(msg)
                    now = time.time()

                    if data.get("type") == "transcription":
                        t_transcription = now
                        transcription_text = data.get("text", "")
                        print(f"  T_transcription: {now:.3f} (+{now - t0_send:.2f}s) → '{transcription_text[:40]}'")

                    elif data.get("type") == "audio_response":
                        t_audio_response = now
                        audio_size = len(data.get("audio", ""))
                        print(f"  T_audio_response: {now:.3f} (+{now - t0_send:.2f}s) → {audio_size} chars base64")
                        break

                    elif data.get("type") == "error":
                        print(f"  ERROR: {data.get('message')}")
                        break

                except asyncio.TimeoutError:
                    print(f"  Timeout at {time.time() - t0_send:.1f}s")
                    break

        # Calculate segments
        entry = {
            "exchange": i,
            "audio_file": os.path.basename(wav_path),
            "transcription": transcription_text,
            "t0_send": t0_send,
        }

        if t_transcription:
            entry["t1_silence_plus_stt"] = round(t_transcription - t0_send, 3)
        if t_transcription and t_audio_response:
            entry["t2_bobodo_plus_tts"] = round(t_audio_response - t_transcription, 3)
        if t_audio_response:
            entry["t_total"] = round(t_audio_response - t0_send, 3)

        results.append(entry)
        print(f"  TOTAL: {entry.get('t_total', 'N/A')}s")

    # Summary
    print("\n" + "="*60)
    print("RÉSUMÉ")
    print("="*60)
    print(f"{'#':<3} {'T1(STT)':<10} {'T2(Bobodo+TTS)':<15} {'Total':<10} {'Texte'}")
    print("-"*60)
    for r in results:
        t1 = r.get('t1_silence_plus_stt', '-')
        t2 = r.get('t2_bobodo_plus_tts', '-')
        total = r.get('t_total', '-')
        text = r.get('transcription', '')[:30]
        print(f"{r['exchange']:<3} {t1:<10} {t2:<15} {total:<10} {text}")

    with open("/tmp/latency_audit.json", "w") as f:
        json.dump(results, f, indent=2)
    print(f"\nSaved: /tmp/latency_audit.json")


if __name__ == "__main__":
    asyncio.run(measure_latency())
