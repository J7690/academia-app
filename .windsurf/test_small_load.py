#!/usr/bin/env python3
"""
Mission 2 — Charge réelle avec Small
Script standalone. Charge Small et mesure latence/RAM/CPU pour 1/2/3/5 users.
Aucun changement du service de production.
"""

import os
import time
import json
import asyncio
import tempfile
import struct
from concurrent.futures import ThreadPoolExecutor

CLK_TCK = os.sysconf(os.sysconf_names['SC_CLK_TCK'])

def get_pid_resources(pid):
    try:
        with open(f"/proc/{pid}/stat", "r") as f:
            parts = f.read().split()
            utime, stime = int(parts[13]), int(parts[14])
        with open("/proc/uptime", "r") as f:
            uptime = float(f.read().split()[0])
        with open(f"/proc/{pid}/status", "r") as f:
            rss = None
            for line in f:
                if line.startswith("VmRSS:"):
                    rss = int(line.split()[1]) / 1024
                    break
        return (utime, stime, uptime, rss)
    except:
        return (None, None, None, None)

def create_wav_from_pcm(pcm_path, wav_path):
    """Convertit un fichier PCM16 16kHz mono en WAV."""
    with open(pcm_path, "rb") as f:
        raw_pcm = f.read()
    data_size = len(raw_pcm)
    total_size = 36 + data_size
    byte_rate = 16000 * 1 * 16 // 8
    block_align = 1 * 16 // 8
    header = struct.pack('<4sI4s', b'RIFF', total_size, b'WAVE')
    fmt_chunk = struct.pack('<4sIHHIIHH',
                           b'fmt ', 16, 1, 1, 16000, byte_rate, block_align, 16)
    data_chunk_header = struct.pack('<4sI', b'data', data_size)
    with open(wav_path, "wb") as f:
        f.write(header + fmt_chunk + data_chunk_header + raw_pcm)

def transcribe_one(model, wav_path):
    """Transcrit un fichier WAV."""
    segments, info = model.transcribe(wav_path, language="fr", beam_size=5, vad_filter=False)
    return " ".join([s.text for s in segments]).strip()

def run_user_batch(model, wav_paths, user_id, results):
    """Un 'user' transcrit tous ses fichiers séquentiellement."""
    pid = os.getpid()
    times = []
    rams = []
    cpus = []
    transcriptions = []

    for wav in wav_paths:
        r1 = get_pid_resources(pid)
        t1 = time.time()
        text = transcribe_one(model, wav)
        t2 = time.time()
        r2 = get_pid_resources(pid)

        elapsed = (t2 - t1) * 1000
        times.append(elapsed)
        rams.append(r2[3] if r2[3] else 0)

        if r1[0] is not None and r2[0] is not None:
            cpu = ((r2[0] + r2[1]) - (r1[0] + r1[1])) / CLK_TCK / (r2[2] - r1[2]) * 100
            cpus.append(cpu)
        else:
            cpus.append(0)

        transcriptions.append(text)

    results[user_id] = {
        "times": times,
        "rams": rams,
        "cpus": cpus,
        "transcriptions": transcriptions,
        "total_time_ms": sum(times),
        "avg_time_ms": sum(times) / len(times),
        "max_time_ms": max(times),
        "min_time_ms": min(times),
    }

def main():
    print("="*60)
    print("MISSION 2 — CHARGE RÉELLE SMALL (standalone)")
    print("="*60)

    from faster_whisper import WhisperModel

    # Charger Small
    print("\n[1/5] Chargement Small...")
    t0 = time.time()
    model = WhisperModel("small", device="cpu", compute_type="int8")
    load_ms = (time.time() - t0) * 1000
    pid = os.getpid()
    r0 = get_pid_resources(pid)
    ram_load = r0[3] if r0[3] else 0
    print(f"  Chargement: {load_ms:.0f}ms | RAM: {ram_load:.0f}MB")

    # Préparer les fichiers audio (réutiliser ceux du corpus ou en créer)
    audio_dir = "/tmp/tiny_academia_benchmark"
    wav_files = sorted([os.path.join(audio_dir, f) for f in os.listdir(audio_dir) if f.endswith(".wav")])
    if len(wav_files) < 20:
        print("Pas assez de fichiers audio. Génération...")
        # Générer 20 fichiers courts
        os.makedirs(audio_dir, exist_ok=True)
        for i in range(20):
            pcm_path = os.path.join(audio_dir, f"expr_{i:03d}.pcm")
            wav_path = pcm_path.replace(".pcm", ".wav")
            # 2 secondes de PCM16 silence
            with open(pcm_path, "wb") as f:
                f.write(b'\x00' * (16000 * 2 * 2))
            create_wav_from_pcm(pcm_path, wav_path)
            os.remove(pcm_path)
        wav_files = sorted([os.path.join(audio_dir, f) for f in os.listdir(audio_dir) if f.endswith(".wav")])

    # Limite à 20 fichiers par user pour accélérer
    wav_files = wav_files[:20]
    print(f"  Fichiers audio: {len(wav_files)}")

    all_reports = {}

    for num_users in [1, 2, 3, 5]:
        print(f"\n{'='*60}")
        print(f"TEST: {num_users} utilisateur(s)")
        print(f"{'='*60}")

        # Répartir les fichiers entre users
        files_per_user = len(wav_files) // num_users
        user_batches = []
        for u in range(num_users):
            start = u * files_per_user
            end = start + files_per_user
            user_batches.append(wav_files[start:end])

        results = {}
        t_start = time.time()

        # Lancer en parallèle (ThreadPoolExecutor car CTranslate2 libère le GIL)
        with ThreadPoolExecutor(max_workers=num_users) as executor:
            futures = []
            for u in range(num_users):
                f = executor.submit(run_user_batch, model, user_batches[u], u, results)
                futures.append(f)
            for f in futures:
                f.result()

        total_elapsed = (time.time() - t_start) * 1000

        # Stats globales
        all_times = [t for r in results.values() for t in r["times"]]
        all_cpus = [c for r in results.values() for c in r["cpus"]]
        all_rams = [m for r in results.values() for m in r["rams"]]

        report = {
            "num_users": num_users,
            "load_ms": round(load_ms, 1),
            "ram_load_mb": round(ram_load, 1),
            "total_elapsed_ms": round(total_elapsed, 1),
            "avg_time_per_transcription_ms": round(sum(all_times) / len(all_times), 1),
            "min_time_ms": round(min(all_times), 1),
            "max_time_ms": round(max(all_times), 1),
            "avg_cpu_percent": round(sum(all_cpus) / len(all_cpus), 1),
            "max_cpu_percent": round(max(all_cpus), 1),
            "avg_ram_mb": round(sum(all_rams) / len(all_rams), 1),
            "max_ram_mb": round(max(all_rams), 1),
            "transcriptions_per_user": {str(k): len(v["times"]) for k, v in results.items()},
            "total_transcriptions": sum(len(v["times"]) for v in results.values()),
        }

        print(f"  Total elapsed: {total_elapsed:.0f}ms")
        print(f"  Avg/transcription: {report['avg_time_per_transcription_ms']:.0f}ms")
        print(f"  Min: {report['min_time_ms']:.0f}ms | Max: {report['max_time_ms']:.0f}ms")
        print(f"  Avg CPU: {report['avg_cpu_percent']:.0f}% | Max CPU: {report['max_cpu_percent']:.0f}%")
        print(f"  Avg RAM: {report['avg_ram_mb']:.0f}MB | Max RAM: {report['max_ram_mb']:.0f}MB")
        print(f"  Total transcriptions: {report['total_transcriptions']}")

        all_reports[str(num_users)] = report

    # Sauvegarde
    with open("/tmp/small_load_test.json", "w") as f:
        json.dump(all_reports, f, indent=2)

    print(f"\n{'='*60}")
    print("Résultats sauvegardés: /tmp/small_load_test.json")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
