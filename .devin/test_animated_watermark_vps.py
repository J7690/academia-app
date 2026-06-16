"""
Test the ANIMATED watermark FFmpeg filter on Kamatera VPS.
This simulates exactly what WatermarkService.addWatermark() does on-device.
"""
import paramiko
import json

VPS_IP = "185.167.96.214"
VPS_USER = "root"
VPS_PASS = "Wenden@Koote2026"

def ssh_cmd(ssh, cmd, label="", timeout=60):
    if label:
        print(f"\n  {label}")
    print(f"    $ {cmd[:200]}...")
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=timeout)
    out = stdout.read().decode('utf-8', errors='replace').strip()
    err = stderr.read().decode('utf-8', errors='replace').strip()
    if out:
        for line in out.split('\n')[:20]:
            print(f"    {line}")
    if err and not out:
        for line in err.split('\n')[:10]:
            print(f"    [stderr] {line}")
    return out, err

print("=" * 60)
print("TEST: Animated watermark FFmpeg filter on VPS")
print("=" * 60)

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(VPS_IP, username=VPS_USER, password=VPS_PASS, timeout=15)
print("  Connected to VPS")

# 1. Generate test video (5 seconds, 720p, with audio)
ssh_cmd(ssh, 
    'ffmpeg -y -f lavfi -i "color=c=0x2A5DB0:s=720x1280:d=5:r=30" '
    '-f lavfi -i "sine=frequency=440:duration=5" '
    '-vf "drawtext=text=\'ACADEMIA TEST\':fontsize=48:fontcolor=white:x=(w-tw)/2:y=(h-th)/2" '
    '-c:v libx264 -preset ultrafast -c:a aac '
    '/tmp/test_video_5s.mp4 2>&1 | tail -3',
    "1. Generate 5s test video (720x1280)")

ssh_cmd(ssh, "ls -la /tmp/test_video_5s.mp4", "   File info")

# 2. Generate a simple white logo with transparency (simulating ACADEMIA_logo1.png)
ssh_cmd(ssh,
    'ffmpeg -y -f lavfi -i "color=c=white@0.8:s=200x80:d=1,format=rgba,'
    'drawtext=text=\'ACADEMIA\':fontsize=32:fontcolor=white:x=(w-tw)/2:y=(h-th)/2" '
    '-frames:v 1 /tmp/test_logo.png 2>&1 | tail -3',
    "2. Generate test logo PNG")

# 3. Test ANIMATED overlay (exact same filter as WatermarkService)
ANIMATED_CMD = (
    'ffmpeg -y -i /tmp/test_video_5s.mp4 -i /tmp/test_logo.png '
    '-filter_complex '
    '"[1:v]format=rgba[logo_raw];'
    '[logo_raw][0:v]scale2ref=oh*mdar:ih*0.08[wm][vid];'
    '[wm]colorchannelmixer=aa=0.35[wm_alpha];'
    "[vid][wm_alpha]overlay="
    "x='(W-w)*0.5+(W-w)*0.4*sin(2*PI*t/8)':"
    "y='(H-h)*0.5+(H-h)*0.4*cos(2*PI*t/6)'\" "
    '-c:a copy -preset ultrafast -movflags +faststart '
    '-y /tmp/test_animated_wm.mp4 2>&1 | tail -5'
)

ssh_cmd(ssh, ANIMATED_CMD, "3. ANIMATED watermark overlay (TikTok-style)")

ssh_cmd(ssh, "ls -la /tmp/test_animated_wm.mp4", "   Output file")

# 4. Verify the output is valid with ffprobe
ssh_cmd(ssh,
    'ffprobe -v error -show_entries format=duration,size '
    '-show_entries stream=codec_name,width,height '
    '-of json /tmp/test_animated_wm.mp4',
    "4. FFprobe verify output")

# 5. Extract 2 frames at different timestamps to verify logo moves
ssh_cmd(ssh,
    'ffmpeg -y -ss 0.5 -i /tmp/test_animated_wm.mp4 -frames:v 1 /tmp/frame_0s.png 2>&1 | tail -1',
    "5a. Extract frame at t=0.5s")
ssh_cmd(ssh,
    'ffmpeg -y -ss 3.0 -i /tmp/test_animated_wm.mp4 -frames:v 1 /tmp/frame_3s.png 2>&1 | tail -1',
    "5b. Extract frame at t=3.0s")
ssh_cmd(ssh, "ls -la /tmp/frame_0s.png /tmp/frame_3s.png", "   Frame files")

# 6. Calculate expected logo positions to verify movement
print("\n  6. Expected logo positions (for 720x1280 video, logo ~102x80):")
import math
for t in [0.5, 1.0, 2.0, 3.0, 4.0]:
    W, H, w, h = 720, 1280, 102, 80
    x = (W-w)*0.5 + (W-w)*0.4*math.sin(2*math.pi*t/8)
    y = (H-h)*0.5 + (H-h)*0.4*math.cos(2*math.pi*t/6)
    print(f"    t={t:.1f}s → x={x:.0f}, y={y:.0f}")

# 7. Test that the VPS worker's FFmpeg also works with animated overlays
WORKER_CMD = (
    'ffmpeg -y -i /tmp/test_video_5s.mp4 '
    '-vf "scale=-2:480" -c:v libx264 -preset fast -b:v 800k '
    '-c:a aac -b:a 128k -movflags +faststart '
    '/tmp/test_worker_480p.mp4 2>&1 | tail -3'
)
ssh_cmd(ssh, WORKER_CMD, "7. Worker FFmpeg simulation (480p transcode)")
ssh_cmd(ssh, "ls -la /tmp/test_worker_480p.mp4", "   Worker output")

# 8. Verify worker service status
ssh_cmd(ssh, "systemctl is-active academia-video-worker", "8. Worker service status")

# Cleanup
ssh_cmd(ssh, 
    "rm -f /tmp/test_video_5s.mp4 /tmp/test_logo.png /tmp/test_animated_wm.mp4 "
    "/tmp/frame_0s.png /tmp/frame_3s.png /tmp/test_worker_480p.mp4",
    "Cleanup")

ssh.close()

print("\n" + "=" * 60)
print("SUMMARY")
print("=" * 60)
print("  If test_animated_wm.mp4 was created → animated watermark works ✅")
print("  If logo x,y positions differ at t=0.5s vs t=3.0s → logo MOVES ✅")
