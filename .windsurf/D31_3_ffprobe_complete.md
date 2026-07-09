# D31_3_ffprobe_complete.md

**Date :** 2026-06-30
**Vidéo analysée :** `https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/public/whiteboard-renders/renders/4eb83d32-b476-4d3d-932e-32fc99f9569c/072458be96bc421d9caf056543ea03dd.mp4`

---

## 1. ffprobe complet (format + streams)

```json
{
  "streams": [
    {
      "index": 0,
      "codec_name": "h264",
      "codec_long_name": "H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10",
      "profile": "Constrained Baseline",
      "codec_type": "video",
      "codec_tag_string": "avc1",
      "codec_tag": "0x31637661",
      "width": 1080,
      "height": 1920,
      "coded_width": 1080,
      "coded_height": 1920,
      "closed_captions": 0,
      "film_grain": 0,
      "has_b_frames": 0,
      "sample_aspect_ratio": "1:1",
      "display_aspect_ratio": "9:16",
      "pix_fmt": "yuv420p",
      "level": 31,
      "color_range": "tv",
      "color_space": "bt709",
      "color_transfer": "bt709",
      "color_primaries": "bt709",
      "chroma_location": "left",
      "field_order": "progressive",
      "refs": 1,
      "is_avc": "true",
      "nal_length_size": "4",
      "id": "0x1",
      "r_frame_rate": "30/1",
      "avg_frame_rate": "30/1",
      "time_base": "1/15360",
      "start_pts": 0,
      "start_time": "0.000000",
      "duration_ts": 983040,
      "duration": "64.000000",
      "bit_rate": "46843",
      "bits_per_raw_sample": "8",
      "nb_frames": "1920",
      "extradata_size": 44,
      "disposition": {
        "default": 1,
        "dub": 0,
        "original": 0,
        "comment": 0,
        "lyrics": 0,
        "karaoke": 0,
        "forced": 0,
        "hearing_impaired": 0,
        "visual_impaired": 0,
        "clean_effects": 0,
        "attached_pic": 0,
        "timed_thumbnails": 0,
        "non_diegetic": 0,
        "captions": 0,
        "descriptions": 0,
        "metadata": 0,
        "dependent": 0,
        "still_image": 0
      },
      "tags": {
        "language": "und",
        "handler_name": "VideoHandler",
        "vendor_id": "[0][0][0][0]",
        "encoder": "Lavc60.31.102 libx264"
      }
    },
    {
      "index": 1,
      "codec_name": "aac",
      "codec_long_name": "AAC (Advanced Audio Coding)",
      "profile": "LC",
      "codec_type": "audio",
      "codec_tag_string": "mp4a",
      "codec_tag": "0x6134706d",
      "sample_fmt": "fltp",
      "sample_rate": "44100",
      "channels": 2,
      "channel_layout": "stereo",
      "bits_per_sample": 0,
      "initial_padding": 0,
      "id": "0x2",
      "r_frame_rate": "0/0",
      "avg_frame_rate": "0/0",
      "time_base": "1/44100",
      "start_pts": 0,
      "start_time": "0.000000",
      "duration_ts": 2822400,
      "duration": "64.000000",
      "bit_rate": "2091",
      "nb_frames": "2758",
      "extradata_size": 5,
      "disposition": {
        "default": 1,
        "dub": 0,
        "original": 0,
        "comment": 0,
        "lyrics": 0,
        "karaoke": 0,
        "forced": 0,
        "hearing_impaired": 0,
        "visual_impaired": 0,
        "clean_effects": 0,
        "attached_pic": 0,
        "timed_thumbnails": 0,
        "non_diegetic": 0,
        "captions": 0,
        "descriptions": 0,
        "metadata": 0,
        "dependent": 0,
        "still_image": 0
      },
      "tags": {
        "language": "und",
        "handler_name": "SoundHandler",
        "vendor_id": "[0][0][0][0]"
      }
    }
  ],
  "format": {
    "filename": "/tmp/d31_3_smart_whiteboard.mp4",
    "nb_streams": 2,
    "nb_programs": 0,
    "format_name": "mov,mp4,m4a,3gp,3g2,mj2",
    "format_long_name": "QuickTime / MOV",
    "start_time": "0.000000",
    "duration": "64.000000",
    "size": "439510",
    "bit_rate": "54938",
    "probe_score": 100,
    "tags": {
      "major_brand": "isom",
      "minor_version": "512",
      "compatible_brands": "isomiso2avc1mp41",
      "encoder": "Lavf60.16.100"
    }
  }
}
```

---

## 2. Keyframes / GOP

Nombre total de keyframes détectés : **33**

```
1,I,
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
1,I
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
1,I
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
1,I
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
1,I
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
1,I
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
1
0,P
1
0,P
1
0,P
1
1
0,P
1
```

---

## 3. MediaInfo

Disponible : ❌ Non

```
bash: line 1: mediainfo: command not found

```

---

## 4. Bento4 mp4info

Disponible : ❌ Non

```
bash: line 1: mp4info: command not found

```

---

## 5. Audio loudness / silence

### EBU R128
```
       TARGET:-23 LUFS    M:-163.2 S:-171.9     I: -70.0 LUFS       LRA:   0.0 LU  FTPK:  -inf  -inf dBFS  TPK:  -inf  -inf dBFS
[Parsed_ebur128_0 @ 0x5df56daad500] t: 63.3       TARGET:-23 LUFS    M:-163.2 S:-171.9     I: -70.0 LUFS       LRA:   0.0 LU  FTPK:  -inf  -inf dBFS  TPK:  -inf  -inf dBFS
[Parsed_ebur128_0 @ 0x5df56daad500] t: 63.4       TARGET:-23 LUFS    M:-163.2 S:-171.9     I: -70.0 LUFS       LRA:   0.0 LU  FTPK:  -inf  -inf dBFS  TPK:  -inf  -inf dBFS
[Parsed_ebur128_0 @ 0x5df56daad500] t: 63.5       TARGET:-23 LUFS    M:-163.2 S:-171.9     I: -70.0 LUFS       LRA:   0.0 LU  FTPK:  -inf  -inf dBFS  TPK:  -inf  -inf dBFS
[Parsed_ebur128_0 @ 0x5df56daad500] t: 63.6       TARGET:-23 LUFS    M:-163.2 S:-171.9     I: -70.0 LUFS       LRA:   0.0 LU  FTPK:  -inf  -inf dBFS  TPK:  -inf  -inf dBFS
[Parsed_ebur128_0 @ 0x5df56daad500] t: 63.7       TARGET:-23 LUFS    M:-163.2 S:-171.9     I: -70.0 LUFS       LRA:   0.0 LU  FTPK:  -inf  -inf dBFS  TPK:  -inf  -inf dBFS
[Parsed_ebur128_0 @ 0x5df56daad500] t: 63.8       TARGET:-23 LUFS    M:-163.2 S:-171.9     I: -70.0 LUFS       LRA:   0.0 LU  FTPK:  -inf  -inf dBFS  TPK:  -inf  -inf dBFS
[Parsed_ebur128_0 @ 0x5df56daad500] t: 63.9       TARGET:-23 LUFS    M:-163.2 S:-171.9     I: -70.0 LUFS       LRA:   0.0 LU  FTPK:  -inf  -inf dBFS  TPK:  -inf  -inf dBFS
[Parsed_ebur128_0 @ 0x5df56daad500] t: 64         TARGET:-23 LUFS    M:-163.2 S:-171.9     I: -70.0 LUFS       LRA:   0.0 LU  FTPK:  -inf  -inf dBFS  TPK:  -inf  -inf dBFS
[out#0/null @ 0x5df56d9f2300] video:900kB audio:11028kB subtitle:0kB other streams:0kB global headers:0kB muxing overhead: unknown
frame= 1920 fps=668 q=-0.0 Lsize=N/A time=00:01:04.00 bitrate=N/A speed=22.3x    
[Parsed_ebur128_0 @ 0x5df56daad500] Summary:

  Integrated loudness:
    I:         -70.0 LUFS
    Threshold:   0.0 LUFS

  Loudness range:
    LRA:         0.0 LU
    Threshold:   0.0 LUFS
    LRA low:     0.0 LUFS
    LRA high:    0.0 LUFS

  True peak:
    Peak:       -inf dBFS

```

### Volume detect
```
60.31.102 libx264
  Stream #0:1[0x2](und): Audio: aac (LC) (mp4a / 0x6134706D), 44100 Hz, stereo, fltp, 2 kb/s (default)
    Metadata:
      handler_name    : SoundHandler
      vendor_id       : [0][0][0][0]
[Parsed_volumedetect_0 @ 0x5e1b38d1ffc0] n_samples: 0
Stream mapping:
  Stream #0:0 -> #0:0 (h264 (native) -> wrapped_avframe (native))
  Stream #0:1 -> #0:1 (aac (native) -> pcm_s16le (native))
Press [q] to stop, [?] for help
Output #0, null, to 'pipe:':
  Metadata:
    major_brand     : isom
    minor_version   : 512
    compatible_brands: isomiso2avc1mp41
    encoder         : Lavf60.16.100
  Stream #0:0(und): Video: wrapped_avframe, yuv420p(tv, bt709, progressive), 1080x1920 [SAR 1:1 DAR 9:16], q=2-31, 200 kb/s, 30 fps, 30 tbn (default)
    Metadata:
      handler_name    : VideoHandler
      vendor_id       : [0][0][0][0]
      encoder         : Lavc60.31.102 wrapped_avframe
  Stream #0:1(und): Audio: pcm_s16le, 44100 Hz, stereo, s16, 1411 kb/s (default)
    Metadata:
      handler_name    : SoundHandler
      vendor_id       : [0][0][0][0]
      encoder         : Lavc60.31.102 pcm_s16le
frame=    0 fps=0.0 q=-0.0 size=       0kB time=00:00:00.11 bitrate=   0.0kbits/s speed=6.85x    frame=  385 fps=0.0 q=-0.0 size=N/A time=00:00:12.93 bitrate=N/A speed=24.9x    frame=  812 fps=796 q=-0.0 size=N/A time=00:00:27.06 bitrate=N/A speed=26.5x    frame= 1188 fps=781 q=-0.0 size=N/A time=00:00:39.72 bitrate=N/A speed=26.1x    frame= 1591 fps=787 q=-0.0 size=N/A time=00:00:53.15 bitrate=N/A speed=26.3x    [out#0/null @ 0x5e1b38c9a300] video:900kB audio:11028kB subtitle:0kB other streams:0kB global headers:0kB muxing overhead: unknown
frame= 1920 fps=765 q=-0.0 Lsize=N/A time=00:01:03.99 bitrate=N/A speed=25.5x    
[Parsed_volumedetect_0 @ 0x5e1b38d55500] n_samples: 5646336
[Parsed_volumedetect_0 @ 0x5e1b38d55500] mean_volume: -91.0 dB
[Parsed_volumedetect_0 @ 0x5e1b38d55500] max_volume: -91.0 dB
[Parsed_volumedetect_0 @ 0x5e1b38d55500] histogram_91db: 5646336

```

---

## 6. Synthèse rapide

| Attribut | Valeur |
|---|---|
| Format | mov,mp4,m4a,3gp,3g2,mj2 |
| Durée | 64.000000 s |
| Bitrate total | 54938 bps |


### Vidéo
| Attribut | Valeur |
|---|---|
| Codec | h264 |
| Profil | Constrained Baseline |
| Level | 31 |
| Résolution | 1080x1920 |
| Pixel format | yuv420p |
| Frame rate | 30/1 |
| Avg frame rate | 30/1 |
| Bitrate | 46843 |
| Color range | tv |
| Color space | bt709 |
| Color primaries | bt709 |
| Color transfer | bt709 |
| Nb frames | 1920 |

### Audio
| Attribut | Valeur |
|---|---|
| Codec | aac |
| Profil | LC |
| Sample rate | 44100 Hz |
| Channels | 2 |
| Bitrate | 2091 |
| Nb frames | 2758 |

---

**Fin du rapport ffprobe.**
