#!/usr/bin/env python3
"""
Mission 1 — Multi-session validation
Teste le service de production (ws://localhost:8000/ws) avec 2/3/5 sessions.
Aucun changement de code. Audit uniquement.
"""

import asyncio
import json
import base64
import time
import websockets
import subprocess
import os

WS_URL = "ws://localhost:8000/ws"
AUDIO_DIR = "/tmp/session_test_audio"

async def generate_test_audio():
    """Génère 5 fichiers audio courts avec phrases distinctes."""
    os.makedirs(AUDIO_DIR, exist_ok=True)
    phrases = [
        "Bonjour Bobodo",
        "Je veux parler a Academia",
        "Comment fonctionne l application",
        "Merci pour votre aide",
        "Au revoir et bonne journee",
    ]
    for i, phrase in enumerate(phrases):
        wav_path = os.path.join(AUDIO_DIR, f"user_{i}.wav")
        if os.path.exists(wav_path):
            continue
        # générer avec gTTS
        mp3_path = wav_path.replace(".wav", ".mp3")
        subprocess.run(["python3", "-c",
            f"from gtts import gTTS; tts=gTTS('{phrase}', lang='fr'); tts.save('{mp3_path}')"],
            capture_output=True)
        # convertir en WAV 16kHz mono PCM16
        subprocess.run([
            "ffmpeg", "-y", "-i", mp3_path, "-ar", "16000", "-ac", "1", "-sample_fmt", "s16",
            wav_path
        ], capture_output=True)
        if os.path.exists(mp3_path):
            os.remove(mp3_path)
    print(f"Audio généré dans {AUDIO_DIR}")


def read_pcm_base64(wav_path):
    """Lit un WAV et retourne les données PCM brutes encodées en base64."""
    import wave
    with wave.open(wav_path, "rb") as wf:
        frames = wf.readframes(wf.getnframes())
    return base64.b64encode(frames).decode("utf-8")


async def client_session(user_id, audio_path, results):
    """Client WebSocket qui envoie de l'audio et collecte les réponses."""
    session_id = f"test-session-{user_id}"
    messages = []
    start_time = time.time()

    try:
        async with websockets.connect(WS_URL, open_timeout=5, close_timeout=5) as ws:
            connect_time = time.time() - start_time
            messages.append({"event": "connected", "time": connect_time})

            # Envoyer session_id
            await ws.send(json.dumps({"type": "session_id", "session_id": session_id}))

            # Lire audio
            audio_b64 = read_pcm_base64(audio_path)

            # Envoyer audio
            send_start = time.time()
            await ws.send(json.dumps({"type": "audio", "audio": audio_b64}))
            messages.append({"event": "audio_sent", "time": time.time() - send_start})

            # Attendre les réponses (max 15s)
            receive_start = time.time()
            while time.time() - receive_start < 15:
                try:
                    msg = await asyncio.wait_for(ws.recv(), timeout=3)
                    data = json.loads(msg)
                    data["elapsed"] = round(time.time() - receive_start, 2)
                    messages.append(data)
                    if data.get("type") in ("audio_response", "error"):
                        break
                except asyncio.TimeoutError:
                    messages.append({"event": "timeout", "elapsed": round(time.time() - receive_start, 2)})
                    break

    except Exception as e:
        messages.append({"event": "exception", "error": str(e)})

    results[user_id] = messages


async def run_multi_session_test(num_users):
    """Lance N clients simultanés."""
    print(f"\n{'='*60}")
    print(f"TEST MULTI-SESSION: {num_users} utilisateurs simultanés")
    print(f"{'='*60}")

    results = {}
    audio_files = [os.path.join(AUDIO_DIR, f"user_{i % 5}.wav") for i in range(num_users)]

    # Vérifier que les fichiers existent
    for f in audio_files:
        if not os.path.exists(f):
            print(f"MISSING: {f}")
            return {}

    tasks = [client_session(i, audio_files[i], results) for i in range(num_users)]
    await asyncio.gather(*tasks)

    # Analyse
    print(f"\n--- Résultats {num_users} users ---")
    transcriptions_received = {}
    for uid, msgs in results.items():
        print(f"\nUser {uid}:")
        transcriptions = [m for m in msgs if m.get("type") == "transcription"]
        errors = [m for m in msgs if m.get("type") == "error"]
        timeouts = [m for m in msgs if m.get("event") == "timeout"]

        for m in transcriptions:
            print(f"  TRANSCRIPTION: '{m.get('text', '')[:60]}' (elapsed={m.get('elapsed')}s)")
        for m in errors:
            print(f"  ERROR: {m.get('message', '')[:60]}")
        for m in timeouts:
            print(f"  TIMEOUT after {m.get('elapsed')}s")

        if transcriptions:
            transcriptions_received[uid] = transcriptions[0].get("text", "")

    # Vérifier le mélange
    unique_texts = set(transcriptions_received.values())
    print(f"\n  --- ANALYSE MÉLANGE ---")
    print(f"  Users ayant reçu transcription: {len(transcriptions_received)}/{num_users}")
    print(f"  Transcriptions uniques reçues: {len(unique_texts)}")
    if len(transcriptions_received) > 0 and len(unique_texts) < len(transcriptions_received):
        print(f"  ⚠️ MÉLANGE DÉTECTÉ: plusieurs users ont reçu la même transcription")
    if len(transcriptions_received) < num_users:
        print(f"  ⚠️ PERTE: {num_users - len(transcriptions_received)} users n'ont rien reçu")

    return results


async def main():
    await generate_test_audio()

    print("\n" + "="*60)
    print("MISSION 1 — VALIDATION MULTI-SESSION")
    print("Service de production (Medium) — ws://localhost:8000/ws")
    print("="*60)

    all_results = {}

    for n in [2, 3, 5]:
        results = await run_multi_session_test(n)
        all_results[f"{n}_users"] = results
        await asyncio.sleep(2)  # pause entre tests

    # Sauvegarde JSON
    import json as json_mod
    with open("/tmp/multi_session_test.json", "w") as f:
        json_mod.dump(all_results, f, indent=2)

    print(f"\n{'='*60}")
    print("Résultats sauvegardés: /tmp/multi_session_test.json")
    print(f"{'='*60}")


if __name__ == "__main__":
    asyncio.run(main())
