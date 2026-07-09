"""D26 — Analyse packets + audio silence check"""
import paramiko, json

H, U, P = "185.167.97.144", "root", "Nexiomgroup@Academia0"

def run(cmd, t=120):
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(H, username=U, password=P, timeout=20)
    _, o, e = c.exec_command(cmd, timeout=t)
    out = o.read().decode(errors="replace")
    err = e.read().decode(errors="replace")
    c.close()
    return out, err

MP4 = "/tmp/d26_final.mp4"

# 1. Video packets raw JSON (first 80)
print("=== VIDEO PACKETS RAW ===")
o1, _ = run(f"ffprobe -v quiet -print_format json -show_packets -select_streams v -read_intervals '%+#80' {MP4}", 60)
try:
    d = json.loads(o1)
    pkts = d.get("packets", [])
    print(f"Video packets sampled: {len(pkts)}")
    if pkts:
        times = [float(p.get("pts_time", 0)) for p in pkts]
        dts_times = [float(p.get("dts_time", 0)) for p in pkts]
        pts_mono = all(times[i] >= times[i-1] for i in range(1, len(times)))
        dts_mono = all(dts_times[i] >= dts_times[i-1] for i in range(1, len(dts_times)))
        print(f"PTS monotone: {pts_mono}")
        print(f"DTS monotone: {dts_mono}")
        kf = [p for p in pkts if "K" in p.get("flags", "")]
        print(f"Keyframes: {len(kf)} / {len(pkts)}")
        if len(kf) > 1:
            kt = [float(p.get("pts_time", 0)) for p in kf]
            g = [kt[i] - kt[i-1] for i in range(1, len(kt))]
            print(f"GOP avg={sum(g)/len(g):.3f}s  min={min(g):.3f}  max={max(g):.3f}")
        print("\nFirst 15 video packets:")
        for p in pkts[:15]:
            print(f"  pts={p.get('pts_time','?'):>10} dts={p.get('dts_time','?'):>10} dur={p.get('duration_time','?'):>8} size={p.get('size','?'):>6} flags={p.get('flags','?')}")
except Exception as e:
    print(f"PARSE ERROR: {e}")
    print(o1[:2000])

# 2. Audio packets raw JSON (first 50)
print("\n\n=== AUDIO PACKETS RAW ===")
o2, _ = run(f"ffprobe -v quiet -print_format json -show_packets -select_streams a -read_intervals '%+#50' {MP4}", 60)
try:
    d2 = json.loads(o2)
    apkts = d2.get("packets", [])
    print(f"Audio packets sampled: {len(apkts)}")
    if apkts:
        at = [float(p.get("pts_time", 0)) for p in apkts]
        a_mono = all(at[i] >= at[i-1] for i in range(1, len(at)))
        print(f"Audio PTS monotone: {a_mono}")
        sizes = [int(p.get("size", 0)) for p in apkts]
        avg_sz = sum(sizes) / len(sizes)
        unique_sizes = len(set(sizes))
        print(f"Avg packet size: {avg_sz:.1f} bytes")
        print(f"Unique sizes: {unique_sizes}")
        print(f"Silence indicator (all ~same small size): {unique_sizes <= 5 and avg_sz < 200}")
        print("\nFirst 15 audio packets:")
        for p in apkts[:15]:
            print(f"  pts={p.get('pts_time','?'):>10} dur={p.get('duration_time','?'):>8} size={p.get('size','?'):>5}")
except Exception as e:
    print(f"PARSE ERROR: {e}")
    print(o2[:2000])

# 3. Total packet counts
print("\n\n=== TOTAL PACKET COUNTS ===")
o3, _ = run(f"ffprobe -v quiet -count_packets -show_entries stream=codec_type,nb_read_packets -print_format json {MP4}", 60)
try:
    d3 = json.loads(o3)
    for s in d3.get("streams", []):
        print(f"  {s.get('codec_type')}: {s.get('nb_read_packets')} packets")
except:
    print(o3[:500])

# 4. Silence detection via ffmpeg
print("\n\n=== SILENCE DETECTION ===")
o4, _ = run(f"ffmpeg -i {MP4} -af silencedetect=n=-50dB:d=1 -f null - 2>&1 | grep -i 'silence' | head -20", 60)
print(o4 if o4.strip() else "[No silence markers found — likely entirely silent]")

# 5. Audio waveform check (max amplitude)
print("\n=== AUDIO MAX AMPLITUDE ===")
o5, _ = run(f"ffmpeg -i {MP4} -af astats=metadata=1:reset=0,ametadata=print:key=lavfi.astats.Overall.Peak_level -f null - 2>&1 | grep Peak | tail -5", 60)
print(o5 if o5.strip() else "[Could not extract peak level]")

# Alt: volumedetect
o6, _ = run(f"ffmpeg -i {MP4} -af volumedetect -f null - 2>&1 | grep -E 'mean_volume|max_volume'", 30)
print("\n=== VOLUME DETECT ===")
print(o6 if o6.strip() else "[volumedetect empty]")

# Save
results = {"video_packets": o1[:5000], "audio_packets": o2[:5000], "counts": o3, "silence": o4, "volume": o6}
with open(r"C:\Users\fasop\AndroidStudioProjects\academia\.windsurf\d26_packets.json", "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False, default=str)
print("\nSaved d26_packets.json")
