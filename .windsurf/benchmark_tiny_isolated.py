#!/usr/bin/env python3
"""
Benchmark Tiny isolé — Kamatera
Aucun impact sur le service en cours.
Génère ses propres fichiers audio, charge tiny séparément.
"""

import os
import sys
import time
import json
import tempfile
import subprocess
import threading
from concurrent.futures import ThreadPoolExecutor

# === CONFIG ===
PHRASES = [
    "Bonjour Bobodo, comment postuler sur Academia ?",
    "Quelle est la capitale du Burkina Faso et pourquoi ?",
    "Explique la photosynthese en termes simples",
    "Donne moi un conseil de revision pour le concours",
    "Comment fonctionne le systeme de credits sur Academia"
]

OUT_DIR = "/tmp/tiny_benchmark"
os.makedirs(OUT_DIR, exist_ok=True)

# === Génération audio ===
def generate_audio_files():
    """Génère des WAV 16kHz mono à partir des phrases via gTTS + ffmpeg."""
    files = []
    for i, phrase in enumerate(PHRASES):
        mp3_path = os.path.join(OUT_DIR, f"phrase_{i}.mp3")
        wav_path = os.path.join(OUT_DIR, f"phrase_{i}.wav")
        # gTTS
        subprocess.run([
            "gtts-cli", phrase, "--lang", "fr", "--output", mp3_path
        ], check=True, capture_output=True)
        # ffmpeg → WAV 16kHz mono
        subprocess.run([
            "ffmpeg", "-y", "-i", mp3_path, "-ar", "16000", "-ac", "1",
            "-c:a", "pcm_s16le", wav_path
        ], check=True, capture_output=True)
        files.append(wav_path)
        size = os.path.getsize(wav_path)
        print(f"  phrase_{i}.wav generated: {size} bytes")
    return files

# === Monitoring ressources ===
CLK_TCK = os.sysconf(os.sysconf_names['SC_CLK_TCK'])

def get_pid_resources(pid):
    """Retourne (cpu_percent, ram_rss_mb, threads) pour un PID."""
    try:
        # CPU
        with open(f"/proc/{pid}/stat", "r") as f:
            parts = f.read().split()
            utime = int(parts[13])
            stime = int(parts[14])
        with open("/proc/uptime", "r") as f:
            uptime = float(f.read().split()[0])
        # On fera le delta dans la boucle appelante
        # RAM
        with open(f"/proc/{pid}/status", "r") as f:
            rss = None
            for line in f:
                if line.startswith("VmRSS:"):
                    rss = int(line.split()[1]) / 1024
                    break
        # Threads
        threads = len(os.listdir(f"/proc/{pid}/task"))
        return utime, stime, uptime, rss, threads
    except Exception as e:
        return None, None, None, None, None

# === Benchmark 1 user (séquentiel) ===
def benchmark_single(model_name, audio_files, model):
    """Transcrit chaque fichier, mesure temps, RAM, CPU."""
    results = []
    pid = os.getpid()
    
    # Warm-up (première transcription qui charge tout)
    print(f"  Warm-up with {model_name}...")
    _ = list(model.transcribe(audio_files[0], language="fr", beam_size=5))
    
    for i, wav_path in enumerate(audio_files):
        phrase = PHRASES[i]
        
        # Mesure ressources avant
        r1 = get_pid_resources(pid)
        t1 = time.time()
        
        segments, info = model.transcribe(wav_path, language="fr", beam_size=5)
        text = " ".join([s.text for s in segments]).strip()
        
        t2 = time.time()
        r2 = get_pid_resources(pid)
        
        elapsed_ms = (t2 - t1) * 1000
        
        # Calcul CPU approx
        if r1[0] is not None and r2[0] is not None:
            cpu = ((r2[0] + r2[1]) - (r1[0] + r1[1])) / CLK_TCK / (r2[2] - r1[2]) * 100
        else:
            cpu = 0
        
        ram_mb = r2[3] if r2[3] else 0
        
        results.append({
            "phrase": phrase,
            "file": os.path.basename(wav_path),
            "elapsed_ms": round(elapsed_ms, 1),
            "cpu_percent": round(cpu, 1),
            "ram_mb": round(ram_mb, 1),
            "transcription": text,
            "model": model_name
        })
        print(f"  {model_name} phrase_{i}: {elapsed_ms:.0f}ms | CPU={cpu:.0f}% | RAM={ram_mb:.0f}MB | '{text[:60]}...'")
    
    return results

# === Benchmark multi-users (concurrence) ===
def benchmark_concurrent(model_name, model, audio_files, num_users):
    """Simule N users qui transcrivent simultanément la même phrase."""
    results = []
    pid = os.getpid()
    
    def worker(user_id):
        wav = audio_files[user_id % len(audio_files)]
        t1 = time.time()
        try:
            segments, info = model.transcribe(wav, language="fr", beam_size=5)
            text = " ".join([s.text for s in segments]).strip()
            status = "OK"
        except Exception as e:
            text = str(e)
            status = f"ERROR:{e}"
        t2 = time.time()
        return {
            "user": user_id,
            "elapsed_ms": round((t2 - t1) * 1000, 1),
            "status": status,
            "transcription": text
        }
    
    # Monitoring ressources pendant
    monitor_data = []
    stop_event = threading.Event()
    
    def monitor():
        while not stop_event.is_set():
            r = get_pid_resources(pid)
            if r[3]:
                monitor_data.append({"ram_mb": r[3], "threads": r[4]})
            time.sleep(0.5)
    
    t_monitor = threading.Thread(target=monitor)
    t_monitor.start()
    
    t_start = time.time()
    with ThreadPoolExecutor(max_workers=num_users) as ex:
        futures = [ex.submit(worker, i) for i in range(num_users)]
        for f in futures:
            results.append(f.result())
    t_end = time.time()
    
    stop_event.set()
    t_monitor.join()
    
    total_ms = (t_end - t_start) * 1000
    max_ram = max([m["ram_mb"] for m in monitor_data]) if monitor_data else 0
    
    print(f"  {model_name} {num_users}users: total={total_ms:.0f}ms | max_RAM={max_ram:.0f}MB | OK={sum(1 for r in results if r['status']=='OK')}/{num_users}")
    
    return {
        "num_users": num_users,
        "model": model_name,
        "total_ms": round(total_ms, 1),
        "max_ram_mb": round(max_ram, 1),
        "user_results": results
    }

# === Main ===
if __name__ == "__main__":
    print("="*60)
    print("BOBODO TINY REAL BENCHMARK — Kamatera")
    print("="*60)
    
    # Vérifier dépendances
    print("\n[1/6] Checking dependencies...")
    try:
        subprocess.run(["gtts-cli", "--help"], check=True, capture_output=True)
        print("  gtts-cli: OK")
    except:
        print("  gtts-cli: NOT FOUND — installing gTTS")
        subprocess.run([sys.executable, "-m", "pip", "install", "gTTS", "-q"])
    
    try:
        subprocess.run(["ffmpeg", "-version"], check=True, capture_output=True)
        print("  ffmpeg: OK")
    except:
        print("  ffmpeg: NOT FOUND")
        sys.exit(1)
    
    # Charger faster-whisper
    print("\n[2/6] Loading faster-whisper...")
    from faster_whisper import WhisperModel
    
    # Générer audio
    print("\n[3/6] Generating 5 test audio files...")
    audio_files = generate_audio_files()
    
    # === TINY ===
    print("\n[4/6] Loading TINY model (this may download ~39MB)...")
    t_load_start = time.time()
    model_tiny = WhisperModel("tiny", device="cpu", compute_type="int8")
    t_load_tiny = (time.time() - t_load_start) * 1000
    print(f"  Tiny loaded in {t_load_tiny:.0f}ms")
    
    print("\n[5/6] Benchmarking TINY — Single user (5 phrases)...")
    results_tiny_single = benchmark_single("tiny", audio_files, model_tiny)
    
    print("\n[5/6b] Benchmarking TINY — Concurrent users...")
    results_tiny_1 = benchmark_concurrent("tiny", model_tiny, audio_files, 1)
    results_tiny_3 = benchmark_concurrent("tiny", model_tiny, audio_files, 3)
    results_tiny_5 = benchmark_concurrent("tiny", model_tiny, audio_files, 5)
    
    # === MEDIUM ===
    print("\n[6/6] Loading MEDIUM model (this may take time, ~1.5GB)...")
    t_load_start = time.time()
    model_medium = WhisperModel("medium", device="cpu", compute_type="int8")
    t_load_medium = (time.time() - t_load_start) * 1000
    print(f"  Medium loaded in {t_load_medium:.0f}ms")
    
    print("\n[6/6b] Benchmarking MEDIUM — Single user (5 phrases)...")
    results_medium_single = benchmark_single("medium", audio_files, model_medium)
    
    print("\n[6/6c] Benchmarking MEDIUM — Concurrent users...")
    results_medium_1 = benchmark_concurrent("medium", model_medium, audio_files, 1)
    results_medium_3 = benchmark_concurrent("medium", model_medium, audio_files, 3)
    results_medium_5 = benchmark_concurrent("medium", model_medium, audio_files, 5)
    
    # === RAPPORT ===
    report = {
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "server": "Kamatera 185.167.97.144",
        "cpu": "Intel Xeon SapphireRapids 4 cores @ 2.0GHz",
        "ram_total_mb": 9970,
        "load_tiny_ms": round(t_load_tiny, 1),
        "load_medium_ms": round(t_load_medium, 1),
        "tiny_single": results_tiny_single,
        "medium_single": results_medium_single,
        "tiny_concurrent": [results_tiny_1, results_tiny_3, results_tiny_5],
        "medium_concurrent": [results_medium_1, results_medium_3, results_medium_5]
    }
    
    report_path = os.path.join(OUT_DIR, "benchmark_report.json")
    with open(report_path, "w") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)
    
    print("\n" + "="*60)
    print(f"REPORT SAVED TO: {report_path}")
    print("="*60)
    
    # Print summary table
    print("\n--- SUMMARY ---")
    print(f"{'Phrase':<45} {'Tiny (ms)':<12} {'Medium (ms)':<12} {'Gain':<8}")
    for i in range(len(PHRASES)):
        t = results_tiny_single[i]["elapsed_ms"]
        m = results_medium_single[i]["elapsed_ms"]
        gain = round(m / t, 1) if t > 0 else 0
        print(f"{PHRASES[i][:44]:<45} {t:<12} {m:<12} {gain}x")
    
    avg_tiny = sum(r["elapsed_ms"] for r in results_tiny_single) / len(results_tiny_single)
    avg_medium = sum(r["elapsed_ms"] for r in results_medium_single) / len(results_medium_single)
    print(f"\nAverage: {avg_tiny:.0f}ms (tiny) vs {avg_medium:.0f}ms (medium) = {avg_medium/avg_tiny:.1f}x faster")
