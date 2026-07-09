#!/usr/bin/env python3
"""MISSION D31.3 — Phase 1 : audit ffprobe complet du MP4 Smart Whiteboard."""
import paramiko
import json

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"
VIDEO_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/public/whiteboard-renders/renders/4eb83d32-b476-4d3d-932e-32fc99f9569c/072458be96bc421d9caf056543ea03dd.mp4"


def ssh_command(cmd):
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASS, timeout=20)
    stdin, stdout, stderr = ssh.exec_command(cmd)
    out = stdout.read().decode(errors='ignore')
    err = stderr.read().decode(errors='ignore')
    ssh.close()
    return out, err


# Download video
download_cmd = f"curl -L -o /tmp/d31_3_smart_whiteboard.mp4 '{VIDEO_URL}'"
out, err = ssh_command(download_cmd)
print(f"Download: {err.strip()}")

# ffprobe format
ffprobe_format = "ffprobe -v error -show_entries format=format_name,duration,bit_rate,size:stream=index,codec_name,codec_long_name,profile,level,bit_rate,width,height,pix_fmt,color_range,color_space,color_primaries,color_transfer,display_aspect_ratio,r_frame_rate,avg_frame_rate,nb_frames,g=frame:stream=0 -of json /tmp/d31_3_smart_whiteboard.mp4"
# Simpler: use ffprobe -show_streams and -show_format
ffprobe_full = "ffprobe -v quiet -print_format json -show_format -show_streams /tmp/d31_3_smart_whiteboard.mp4"
out, err = ssh_command(ffprobe_full)
ffprobe_data = json.loads(out)

# ffprobe GOP/keyframe info
ffprobe_gop = "ffprobe -v error -show_entries frame=pkt_pts_time,pict_type,key_frame -of csv=p=0 /tmp/d31_3_smart_whiteboard.mp4"
gop_out, _ = ssh_command(ffprobe_gop)
keyframes = [l for l in gop_out.strip().splitlines() if l.endswith('I') or l.endswith(',1')]

# MediaInfo if available
mediainfo_cmd = "mediainfo --Output=JSON /tmp/d31_3_smart_whiteboard.mp4"
mediainfo_out, mediainfo_err = ssh_command(mediainfo_cmd)
mediainfo_available = "command not found" not in mediainfo_err

# Bento4 mp4info if available
mp4info_cmd = "mp4info /tmp/d31_3_smart_whiteboard.mp4"
mp4info_out, mp4info_err = ssh_command(mp4info_cmd)
mp4info_available = "command not found" not in mp4info_err and "error" not in mp4info_err.lower()

# Audio loudness / silence detection
loudness_cmd = "ffmpeg -i /tmp/d31_3_smart_whiteboard.mp4 -af ebur128=peak=true -f null -"
loudness_out, loudness_err = ssh_command(loudness_cmd)

# Audio volumedetect
volume_cmd = "ffmpeg -i /tmp/d31_3_smart_whiteboard.mp4 -af volumedetect -f null -"
volume_out, volume_err = ssh_command(volume_cmd)

report = f"""# D31_3_ffprobe_complete.md

**Date :** 2026-06-30
**Vidéo analysée :** `{VIDEO_URL}`

---

## 1. ffprobe complet (format + streams)

```json
{json.dumps(ffprobe_data, indent=2, ensure_ascii=False)}
```

---

## 2. Keyframes / GOP

Nombre total de keyframes détectés : **{len(keyframes)}**

```
{gop_out[:2000]}
```

---

## 3. MediaInfo

Disponible : {'✅ Oui' if mediainfo_available else '❌ Non'}

```
{mediainfo_out[:2000] if mediainfo_available else mediainfo_err[:500]}
```

---

## 4. Bento4 mp4info

Disponible : {'✅ Oui' if mp4info_available else '❌ Non'}

```
{mp4info_out[:2000] if mp4info_available else mp4info_err[:500]}
```

---

## 5. Audio loudness / silence

### EBU R128
```
{loudness_err[-2000:]}
```

### Volume detect
```
{volume_err[-2000:]}
```

---

## 6. Synthèse rapide

| Attribut | Valeur |
|---|---|
| Format | {ffprobe_data.get('format', {}).get('format_name', 'N/A')} |
| Durée | {ffprobe_data.get('format', {}).get('duration', 'N/A')} s |
| Bitrate total | {ffprobe_data.get('format', {}).get('bit_rate', 'N/A')} bps |

"""

for stream in ffprobe_data.get('streams', []):
    if stream.get('codec_type') == 'video':
        report += f"""
### Vidéo
| Attribut | Valeur |
|---|---|
| Codec | {stream.get('codec_name')} |
| Profil | {stream.get('profile')} |
| Level | {stream.get('level', 'N/A')} |
| Résolution | {stream.get('width')}x{stream.get('height')} |
| Pixel format | {stream.get('pix_fmt')} |
| Frame rate | {stream.get('r_frame_rate')} |
| Avg frame rate | {stream.get('avg_frame_rate')} |
| Bitrate | {stream.get('bit_rate', 'N/A')} |
| Color range | {stream.get('color_range')} |
| Color space | {stream.get('color_space')} |
| Color primaries | {stream.get('color_primaries')} |
| Color transfer | {stream.get('color_transfer')} |
| Nb frames | {stream.get('nb_frames', 'N/A')} |
"""
    elif stream.get('codec_type') == 'audio':
        report += f"""
### Audio
| Attribut | Valeur |
|---|---|
| Codec | {stream.get('codec_name')} |
| Profil | {stream.get('profile', 'N/A')} |
| Sample rate | {stream.get('sample_rate')} Hz |
| Channels | {stream.get('channels')} |
| Bitrate | {stream.get('bit_rate', 'N/A')} |
| Nb frames | {stream.get('nb_frames', 'N/A')} |
"""

report += """
---

**Fin du rapport ffprobe.**
"""

outfile = r"C:\Users\fasop\AndroidStudioProjects\academia\.windsurf\D31_3_ffprobe_complete.md"
with open(outfile, "w", encoding="utf-8") as f:
    f.write(report)
print(f"Saved {outfile}")
