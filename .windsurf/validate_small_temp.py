#!/usr/bin/env python3
"""
Validation temporaire Small — charge le modèle Small sans modifier la config.
Teste 5 phrases + multi-session 2 users.
"""

import time
import os
import tempfile
import struct
import json

def get_ram_mb():
    """Get current process RSS in MB via /proc."""
    try:
        with open(f"/proc/{os.getpid()}/status") as f:
            for line in f:
                if line.startswith("VmRSS:"):
                    return int(line.split()[1]) / 1024
    except:
        pass
    return 0

def get_cpu_percent():
    """Simple CPU usage approximation."""
    try:
        load = os.getloadavg()[0]
        return round(load * 100, 1)
    except:
        return 0

# ─── MISSION 1 & 3: Chargement temporaire Small + mesures ───

print("="*60)
print("VALIDATION SMALL TEMPORAIRE")
print("="*60)

# RAM avant
ram_before = get_ram_mb()
print(f"RAM avant chargement: {ram_before:.0f} MB")

# Charger Small temporairement
from faster_whisper import WhisperModel

t_load_start = time.time()
model_small = WhisperModel("small", device="cpu", compute_type="int8")
t_load = (time.time() - t_load_start) * 1000

ram_after_load = get_ram_mb()
print(f"Small chargé en {t_load:.0f} ms")
print(f"RAM après chargement: {ram_after_load:.0f} MB (+{ram_after_load - ram_before:.0f} MB)")

# ─── MISSION 2: 5 phrases Academia ───

from gtts import gTTS
import wave

PHRASES = [
    "Bonjour Bobodo",
    "Je cherche une bourse d'étude",
    "Université Joseph Ki-Zerbo",
    "Comment fonctionne Academia",
    "Je veux m'orienter après le baccalauréat",
]

def generate_wav(text, path):
    """Génère audio WAV 16kHz mono via gTTS + conversion."""
    mp3_path = path + ".mp3"
    tts = gTTS(text=text, lang="fr", slow=False)
    tts.save(mp3_path)
    # Convert mp3 to wav 16kHz mono using ffmpeg
    os.system(f"ffmpeg -y -i {mp3_path} -ar 16000 -ac 1 -f wav {path} 2>/dev/null")
    os.remove(mp3_path)
    return path

print(f"\n--- Génération audio pour 5 phrases ---")
audio_files = []
for i, phrase in enumerate(PHRASES):
    wav_path = f"/tmp/small_validate_{i}.wav"
    generate_wav(phrase, wav_path)
    size = os.path.getsize(wav_path)
    audio_files.append(wav_path)
    print(f"  [{i}] {phrase} → {size} bytes")

# ─── MISSION 3: Transcription + mesures ───

print(f"\n--- Transcription Small (5 phrases) ---")
results = []

for i, (phrase, wav_path) in enumerate(zip(PHRASES, audio_files)):
    t_start = time.time()
    
    segments, info = model_small.transcribe(wav_path, language="fr", beam_size=5, vad_filter=False)
    text = ""
    for seg in segments:
        text += seg.text + " "
    text = text.strip()
    
    t_elapsed = (time.time() - t_start) * 1000
    cpu_after = get_cpu_percent()
    ram_now = get_ram_mb()
    
    results.append({
        "phrase": phrase,
        "transcription": text,
        "latency_ms": round(t_elapsed, 1),
        "ram_mb": round(ram_now, 1),
        "cpu_percent": round(cpu_after, 1),
        "duration_s": round(info.duration, 2),
    })
    
    match = "✅" if text.lower().strip() == phrase.lower().strip() else "⚠️"
    print(f"  [{i}] {t_elapsed:.0f}ms | {match} '{text}'")

# Moyennes
avg_latency = sum(r["latency_ms"] for r in results) / len(results)
max_latency = max(r["latency_ms"] for r in results)
ram_peak = max(r["ram_mb"] for r in results)
cpu_avg = sum(r["cpu_percent"] for r in results) / len(results)

print(f"\n  Latence moyenne: {avg_latency:.0f} ms")
print(f"  Latence max: {max_latency:.0f} ms")
print(f"  RAM peak: {ram_peak:.0f} MB")

# ─── MISSION 4: Multi-session 2 users ───

print(f"\n--- Test multi-session 2 users (isolation) ---")

import asyncio
import concurrent.futures

def transcribe_user(user_id, wav_path):
    """Transcription pour un user (exécuté en thread)."""
    t_start = time.time()
    segments, info = model_small.transcribe(wav_path, language="fr", beam_size=5, vad_filter=False)
    text = ""
    for seg in segments:
        text += seg.text + " "
    return {
        "user_id": user_id,
        "text": text.strip(),
        "latency_ms": round((time.time() - t_start) * 1000, 1),
    }

# 2 users avec des fichiers différents
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
    future_a = executor.submit(transcribe_user, 0, audio_files[0])
    future_b = executor.submit(transcribe_user, 1, audio_files[1])
    
    result_a = future_a.result()
    result_b = future_b.result()

print(f"  User 0: '{result_a['text']}' ({result_a['latency_ms']:.0f}ms)")
print(f"  User 1: '{result_b['text']}' ({result_b['latency_ms']:.0f}ms)")

# Contamination check
contamination = result_a["text"] == result_b["text"]
print(f"  Contamination: {'❌ OUI' if contamination else '✅ NON'}")
print(f"  Transcriptions uniques: {'OUI' if not contamination else 'NON'}")

# ─── Résumé final ───

print(f"\n{'='*60}")
print("RÉSUMÉ VALIDATION SMALL")
print(f"{'='*60}")

report = {
    "model": "small",
    "load_time_ms": round(t_load, 1),
    "ram_model_mb": round(ram_after_load - ram_before, 1),
    "ram_peak_mb": round(ram_peak, 1),
    "avg_latency_ms": round(avg_latency, 1),
    "max_latency_ms": round(max_latency, 1),
    "transcriptions": results,
    "multi_session": {
        "user_0": result_a,
        "user_1": result_b,
        "contamination": contamination,
    },
}

with open("/tmp/small_validation.json", "w") as f:
    json.dump(report, f, indent=2, ensure_ascii=False)

print(f"  Chargement: {t_load:.0f} ms")
print(f"  RAM modèle: +{ram_after_load - ram_before:.0f} MB")
print(f"  RAM peak: {ram_peak:.0f} MB")
print(f"  Latence moyenne: {avg_latency:.0f} ms")
print(f"  Latence max: {max_latency:.0f} ms")
print(f"  Multi-session: {'OK' if not contamination else 'ÉCHEC'}")
print(f"\nSauvegardé: /tmp/small_validation.json")
