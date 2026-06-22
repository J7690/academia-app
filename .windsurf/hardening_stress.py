#!/usr/bin/env python3
"""
Mission 2+3+4: Reconnexion, fuite mémoire, charge réaliste.
Exécuté sur le serveur Kamatera (localhost).
"""
import asyncio
import json
import base64
import time
import websockets
import os
import random

WS_URL = "ws://localhost:8000/ws"
AUDIO_DIR = "/tmp/tiny_academia_benchmark"

def read_pcm_base64(wav_path):
    import wave
    with wave.open(wav_path, "rb") as wf:
        return base64.b64encode(wf.readframes(wf.getnframes())).decode("utf-8")

def get_ram_mb():
    try:
        with open("/proc/meminfo") as f:
            for line in f:
                if line.startswith("MemAvailable:"):
                    return int(line.split()[1]) / 1024
    except:
        return 0

# ─── MISSION 2: RECONNEXION ───

async def test_reconnection():
    print("\n=== MISSION 2 — RECONNEXION ===")
    wav_files = sorted([os.path.join(AUDIO_DIR, f) for f in os.listdir(AUDIO_DIR) if f.endswith(".wav")])
    wav = wav_files[0]
    session_id = "reconnect-test"
    results = {}

    # Connect, send, get response
    print("  [1] Connexion initiale...")
    ws = await websockets.connect(WS_URL, open_timeout=5)
    await ws.send(json.dumps({"type": "session_id", "session_id": session_id}))
    await ws.send(json.dumps({"type": "audio", "audio": read_pcm_base64(wav)}))
    t0 = time.time()
    got = False
    while time.time() - t0 < 20:
        try:
            msg = await asyncio.wait_for(ws.recv(), timeout=10)
            data = json.loads(msg)
            if data.get("type") == "transcription":
                print(f"  → Transcription: '{data['text'][:40]}'")
                got = True
                break
        except:
            break
    results["initial_transcription"] = got
    
    # Abrupt close (simulate network drop)
    print("  [2] Coupure brutale...")
    await ws.close()
    await asyncio.sleep(2)

    # Reconnect with same session_id
    print("  [3] Reconnexion...")
    ws2 = await websockets.connect(WS_URL, open_timeout=5)
    await ws2.send(json.dumps({"type": "session_id", "session_id": session_id}))
    await ws2.send(json.dumps({"type": "audio", "audio": read_pcm_base64(wav)}))
    t0 = time.time()
    got2 = False
    while time.time() - t0 < 20:
        try:
            msg = await asyncio.wait_for(ws2.recv(), timeout=10)
            data = json.loads(msg)
            if data.get("type") == "transcription":
                print(f"  → Transcription après reconnexion: '{data['text'][:40]}'")
                got2 = True
                break
        except:
            break
    await ws2.close()
    results["reconnection_transcription"] = got2
    
    print(f"  Résultat: initial={'OK' if got else 'FAIL'}, reconnexion={'OK' if got2 else 'FAIL'}")
    return results

# ─── MISSION 3: FUITE MÉMOIRE ───

async def test_memory_leak():
    print("\n=== MISSION 3 — FUITE MÉMOIRE (20 sessions) ===")
    wav_files = sorted([os.path.join(AUDIO_DIR, f) for f in os.listdir(AUDIO_DIR) if f.endswith(".wav")])
    
    # Get initial RAM of service
    import subprocess
    def get_service_ram():
        r = subprocess.run(["bash", "-c", "ps -o rss= -p $(pgrep -f 'python main.py')"], capture_output=True, text=True)
        try:
            return int(r.stdout.strip()) / 1024
        except:
            return 0

    ram_initial = get_service_ram()
    print(f"  RAM initiale service: {ram_initial:.0f} MB")
    
    sessions_created = 0
    sessions_destroyed = 0
    
    for i in range(20):
        session_id = f"memleak-test-{i}"
        try:
            ws = await websockets.connect(WS_URL, open_timeout=5)
            await ws.send(json.dumps({"type": "session_id", "session_id": session_id}))
            sessions_created += 1
            wav = wav_files[i % len(wav_files)]
            await ws.send(json.dumps({"type": "audio", "audio": read_pcm_base64(wav)}))
            # Wait for transcription
            try:
                msg = await asyncio.wait_for(ws.recv(), timeout=15)
            except:
                pass
            await ws.close()
            sessions_destroyed += 1
        except Exception as e:
            print(f"  Session {i} error: {e}")
        
        if i % 5 == 4:
            ram_now = get_service_ram()
            print(f"  After {i+1} sessions: RAM={ram_now:.0f} MB")
    
    await asyncio.sleep(2)
    ram_final = get_service_ram()
    print(f"\n  RAM initiale: {ram_initial:.0f} MB")
    print(f"  RAM finale: {ram_final:.0f} MB")
    print(f"  Delta: +{ram_final - ram_initial:.0f} MB")
    print(f"  Sessions créées: {sessions_created}")
    print(f"  Sessions détruites: {sessions_destroyed}")
    leak = ram_final - ram_initial > 50
    print(f"  Fuite mémoire: {'⚠️ OUI' if leak else '✅ NON'} (seuil: +50 MB)")
    return {
        "ram_initial": round(ram_initial, 1),
        "ram_final": round(ram_final, 1),
        "delta_mb": round(ram_final - ram_initial, 1),
        "sessions_created": sessions_created,
        "sessions_destroyed": sessions_destroyed,
        "leak_detected": leak,
    }

# ─── MISSION 4: CHARGE RÉALISTE ───

async def test_realistic_load():
    print("\n=== MISSION 4 — CHARGE RÉALISTE (10 conversations) ===")
    wav_files = sorted([os.path.join(AUDIO_DIR, f) for f in os.listdir(AUDIO_DIR) if f.endswith(".wav")])
    
    latencies = []
    errors = 0
    
    for i in range(10):
        session_id = f"load-test-{i}"
        wav = wav_files[i % len(wav_files)]
        t0 = time.time()
        try:
            ws = await websockets.connect(WS_URL, open_timeout=5)
            await ws.send(json.dumps({"type": "session_id", "session_id": session_id}))
            await ws.send(json.dumps({"type": "audio", "audio": read_pcm_base64(wav)}))
            got = False
            while time.time() - t0 < 20:
                try:
                    msg = await asyncio.wait_for(ws.recv(), timeout=10)
                    data = json.loads(msg)
                    if data.get("type") == "audio_response":
                        got = True
                        break
                    elif data.get("type") == "error":
                        errors += 1
                        break
                except asyncio.TimeoutError:
                    break
            await ws.close()
            elapsed = time.time() - t0
            if got:
                latencies.append(elapsed)
            else:
                errors += 1
        except Exception as e:
            errors += 1
        
        # Espacement réaliste (2-5s entre conversations)
        await asyncio.sleep(random.uniform(2, 5))
    
    if latencies:
        latencies.sort()
        avg = sum(latencies) / len(latencies)
        p95 = latencies[int(len(latencies) * 0.95)] if len(latencies) > 1 else latencies[0]
        print(f"  Conversations réussies: {len(latencies)}/10")
        print(f"  Erreurs: {errors}")
        print(f"  Latence moyenne: {avg:.1f}s")
        print(f"  Latence P95: {p95:.1f}s")
        print(f"  Latence min: {latencies[0]:.1f}s")
        print(f"  Latence max: {latencies[-1]:.1f}s")
    else:
        print(f"  AUCUNE conversation réussie. Erreurs: {errors}")
    
    return {
        "success": len(latencies),
        "errors": errors,
        "avg_s": round(avg, 2) if latencies else 0,
        "p95_s": round(p95, 2) if latencies else 0,
        "max_s": round(latencies[-1], 2) if latencies else 0,
    }

async def main():
    print("="*60)
    print("HARDENING PRE-PILOTE")
    print("="*60)
    
    r_reconnect = await test_reconnection()
    r_memory = await test_memory_leak()
    r_load = await test_realistic_load()
    
    report = {
        "reconnection": r_reconnect,
        "memory": r_memory,
        "load": r_load,
    }
    
    with open("/tmp/hardening_report.json", "w") as f:
        json.dump(report, f, indent=2)
    print(f"\nSauvegardé: /tmp/hardening_report.json")

if __name__ == "__main__":
    asyncio.run(main())
