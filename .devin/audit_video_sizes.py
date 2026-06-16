#!/usr/bin/env python3
"""
AUDIT — Taille, résolution et durée réelles des vidéos du feed Challenge.
Aucune modification. Lecture seule.

Stratégie :
1. Récupère les 20 dernières vidéos via video_sources + video_renditions
2. HEAD request pour obtenir Content-Length
3. Tente ffprobe localement pour résolution/durée (si disponible)
4. Sinon, télécharge les premiers 32KB pour parser le moov atom basique
"""
import json
import struct
import subprocess
import sys
import requests

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Accept": "application/json",
    "Accept-Profile": "app",
}


def section(title):
    print("\n" + "=" * 70)
    print(f" {title}")
    print("=" * 70)


def get_video_urls():
    """Get the last 20 video sources from Supabase."""
    # Try video_sources first (primary raw uploads)
    r = requests.get(
        f"{SUPABASE_URL}/rest/v1/video_sources",
        headers=HEADERS,
        params={
            "order": "created_at.desc",
            "limit": "20",
            "select": "id,video_asset_id,storage_bucket,storage_path,created_at",
        },
        timeout=15,
    )
    if r.status_code < 400:
        sources = r.json()
        if sources:
            urls = []
            for s in sources:
                bucket = s.get("storage_bucket", "")
                path = s.get("storage_path", "")
                if bucket and path:
                    public_url = f"{SUPABASE_URL}/storage/v1/object/public/{bucket}/{path}"
                    urls.append({
                        "video_asset_id": s.get("video_asset_id"),
                        "url": public_url,
                        "created_at": s.get("created_at"),
                        "source": "video_sources",
                    })
            return urls

    # Fallback: try challenge_participations with video_url
    r = requests.get(
        f"{SUPABASE_URL}/rest/v1/challenge_participations",
        headers=HEADERS,
        params={
            "order": "created_at.desc",
            "limit": "20",
            "select": "id,video_url,video_asset_id,created_at",
            "video_url": "not.is.null",
        },
        timeout=15,
    )
    if r.status_code < 400:
        parts = r.json()
        urls = []
        for p in parts:
            video_url = p.get("video_url", "")
            if video_url:
                urls.append({
                    "video_asset_id": p.get("video_asset_id"),
                    "url": video_url,
                    "created_at": p.get("created_at"),
                    "source": "challenge_participations",
                })
        return urls

    return []


def get_also_free_videos():
    """Get free_videos URLs."""
    r = requests.get(
        f"{SUPABASE_URL}/rest/v1/free_videos",
        headers=HEADERS,
        params={
            "order": "created_at.desc",
            "limit": "20",
            "select": "id,video_url,video_asset_id,created_at",
            "video_url": "not.is.null",
        },
        timeout=15,
    )
    if r.status_code < 400:
        vids = r.json()
        urls = []
        for v in vids:
            video_url = v.get("video_url", "")
            if video_url:
                urls.append({
                    "video_asset_id": v.get("video_asset_id"),
                    "url": video_url,
                    "created_at": v.get("created_at"),
                    "source": "free_videos",
                })
        return urls
    return []


def head_video(url):
    """Get Content-Length via HEAD request."""
    try:
        r = requests.head(url, timeout=15, allow_redirects=True)
        if r.status_code < 400:
            cl = r.headers.get("Content-Length")
            ct = r.headers.get("Content-Type", "")
            return {
                "status": r.status_code,
                "content_length": int(cl) if cl else None,
                "content_type": ct,
            }
        return {"status": r.status_code, "content_length": None, "content_type": ""}
    except Exception as e:
        return {"status": -1, "content_length": None, "content_type": "", "error": str(e)}


def check_ffprobe_available():
    """Check if ffprobe is available locally."""
    try:
        result = subprocess.run(
            ["ffprobe", "-version"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=5,
        )
        return result.returncode == 0
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


def ffprobe_url(url):
    """Use ffprobe to get video metadata from URL."""
    try:
        cmd = [
            "ffprobe",
            "-v", "quiet",
            "-print_format", "json",
            "-show_format",
            "-show_streams",
            url,
        ]
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=30,
        )
        if result.returncode == 0:
            data = json.loads(result.stdout.decode("utf-8", errors="replace"))
            return data
    except (FileNotFoundError, subprocess.TimeoutExpired, json.JSONDecodeError):
        pass
    return None


def extract_metadata(probe_data):
    """Extract resolution, duration, bitrate from ffprobe output."""
    if not probe_data:
        return None

    info = {
        "width": None,
        "height": None,
        "duration_s": None,
        "bitrate_kbps": None,
        "codec": None,
    }

    # From format
    fmt = probe_data.get("format", {})
    duration = fmt.get("duration")
    if duration:
        info["duration_s"] = float(duration)
    bitrate = fmt.get("bit_rate")
    if bitrate:
        info["bitrate_kbps"] = int(bitrate) // 1000

    # From video stream
    streams = probe_data.get("streams", [])
    for s in streams:
        if s.get("codec_type") == "video":
            info["width"] = s.get("width")
            info["height"] = s.get("height")
            info["codec"] = s.get("codec_name")
            if not info["duration_s"]:
                d = s.get("duration")
                if d:
                    info["duration_s"] = float(d)
            break

    return info


def main():
    section("1. COLLECTE DES URLS VIDÉO")

    videos = get_video_urls()
    free = get_also_free_videos()
    
    print(f"  video_sources: {len(videos)} URLs récupérées")
    print(f"  free_videos:   {len(free)} URLs récupérées")

    # Combine, deduplicate, take first 20
    all_videos = videos + free
    seen_urls = set()
    unique_videos = []
    for v in all_videos:
        if v["url"] not in seen_urls:
            seen_urls.add(v["url"])
            unique_videos.append(v)
    unique_videos = unique_videos[:20]
    print(f"  Total unique:  {len(unique_videos)} vidéos à analyser")

    section("2. TAILLE DES FICHIERS (HTTP HEAD)")

    sizes = []
    for i, v in enumerate(unique_videos):
        head = head_video(v["url"])
        v["head"] = head
        size_mb = head["content_length"] / (1024 * 1024) if head["content_length"] else None
        sizes.append(head["content_length"])
        status = f"HTTP {head['status']}"
        size_str = f"{size_mb:.2f} MB" if size_mb else "N/A"
        print(f"  [{i+1:2d}] {size_str:>10}  {status}  {v['source']}  {v.get('created_at', '?')[:10]}")
        if size_mb:
            print(f"       URL: {v['url'][:90]}...")

    valid_sizes = [s for s in sizes if s is not None and s > 0]
    if valid_sizes:
        avg_size = sum(valid_sizes) / len(valid_sizes)
        min_size = min(valid_sizes)
        max_size = max(valid_sizes)
        total_size = sum(valid_sizes)
        print(f"\n  Résumé tailles:")
        print(f"    Vidéos avec taille connue: {len(valid_sizes)}/{len(unique_videos)}")
        print(f"    Taille moyenne:  {avg_size / (1024*1024):.2f} MB")
        print(f"    Taille minimum:  {min_size / (1024*1024):.2f} MB")
        print(f"    Taille maximum:  {max_size / (1024*1024):.2f} MB")
        print(f"    Taille totale:   {total_size / (1024*1024):.1f} MB")

    section("3. RÉSOLUTION ET DURÉE (ffprobe)")

    has_ffprobe = check_ffprobe_available()
    print(f"  ffprobe disponible localement: {'OUI' if has_ffprobe else 'NON'}")

    if has_ffprobe:
        metadata_list = []
        # Probe first 10 videos (ffprobe can be slow on remote URLs)
        probe_count = min(10, len(unique_videos))
        print(f"  Analyse de {probe_count} vidéos via ffprobe (peut prendre ~30s)...")

        for i in range(probe_count):
            v = unique_videos[i]
            url = v["url"]
            print(f"  [{i+1:2d}] Probing...", end="", flush=True)
            probe = ffprobe_url(url)
            meta = extract_metadata(probe)
            if meta:
                v["metadata"] = meta
                metadata_list.append(meta)
                print(f"  {meta['width']}x{meta['height']}  {meta['duration_s']:.1f}s  {meta['bitrate_kbps']}kbps  codec={meta['codec']}")
            else:
                print(f"  ÉCHEC (timeout ou inaccessible)")

        if metadata_list:
            section("4. STATISTIQUES AGRÉGÉES")

            widths = [m["width"] for m in metadata_list if m["width"]]
            heights = [m["height"] for m in metadata_list if m["height"]]
            durations = [m["duration_s"] for m in metadata_list if m["duration_s"]]
            bitrates = [m["bitrate_kbps"] for m in metadata_list if m["bitrate_kbps"]]

            if heights:
                print(f"  Résolutions:")
                from collections import Counter
                res_counter = Counter(f"{w}x{h}" for w, h in zip(widths, heights))
                for res, count in res_counter.most_common():
                    print(f"    {res}: {count} vidéos")
                print(f"    Hauteur moyenne: {sum(heights)/len(heights):.0f}px")

            if durations:
                print(f"\n  Durées:")
                print(f"    Moyenne:  {sum(durations)/len(durations):.1f}s")
                print(f"    Min:      {min(durations):.1f}s")
                print(f"    Max:      {max(durations):.1f}s")

            if bitrates:
                print(f"\n  Bitrates:")
                print(f"    Moyen:    {sum(bitrates)/len(bitrates):.0f} kbps")
                print(f"    Min:      {min(bitrates)} kbps")
                print(f"    Max:      {max(bitrates)} kbps")

            section("5. ESTIMATIONS MULTI-RÉSOLUTION")

            if durations and bitrates:
                avg_duration = sum(durations) / len(durations)
                avg_bitrate = sum(bitrates) / len(bitrates)
                avg_size_bytes = sum(valid_sizes) / len(valid_sizes) if valid_sizes else avg_bitrate * 1000 * avg_duration / 8

                # Target bitrates for each resolution (standard values)
                targets = {
                    "720p": 1500,  # kbps
                    "480p": 800,   # kbps
                    "240p": 400,   # kbps
                }

                print(f"  Taille actuelle moyenne: {avg_size_bytes/(1024*1024):.2f} MB")
                print(f"  Durée moyenne: {avg_duration:.1f}s")
                print(f"  Bitrate actuel moyen: {avg_bitrate:.0f} kbps\n")

                for label, target_kbps in targets.items():
                    estimated_size = (target_kbps * 1000 * avg_duration) / 8
                    reduction = (1 - estimated_size / avg_size_bytes) * 100 if avg_size_bytes > 0 else 0
                    print(f"  {label} ({target_kbps} kbps):")
                    print(f"    Taille estimée: {estimated_size/(1024*1024):.2f} MB")
                    print(f"    Réduction vs original: {reduction:.0f}%")
                    print(f"    Temps chargement @4G (10 Mbps): {estimated_size*8/(10*1000*1000):.1f}s")
                    print(f"    Temps chargement @3G (2 Mbps):  {estimated_size*8/(2*1000*1000):.1f}s")
                    print()

    else:
        # Estimate from file sizes only
        section("4. ESTIMATIONS (sans ffprobe — basées sur tailles)")

        if valid_sizes:
            avg_size_bytes = sum(valid_sizes) / len(valid_sizes)
            # Assume typical phone recording: 1080p, 30fps, ~15-45s
            # Typical bitrate for 1080p phone: ~8000-12000 kbps
            # Estimate duration from size assuming ~10 Mbps bitrate
            assumed_bitrate_kbps = 10000  # typical 1080p phone recording
            estimated_avg_duration = (avg_size_bytes * 8) / (assumed_bitrate_kbps * 1000)

            print(f"  Taille moyenne: {avg_size_bytes/(1024*1024):.2f} MB")
            print(f"  Bitrate présumé (1080p téléphone): ~{assumed_bitrate_kbps} kbps")
            print(f"  Durée estimée: ~{estimated_avg_duration:.0f}s")
            print(f"\n  Bande passante requise pour lecture fluide:")
            print(f"    Minimum (1x):     {assumed_bitrate_kbps/1000:.1f} Mbps")
            print(f"    Recommandé (1.5x): {assumed_bitrate_kbps*1.5/1000:.1f} Mbps")

            section("5. ESTIMATIONS MULTI-RÉSOLUTION")

            targets = {
                "720p": 1500,
                "480p": 800,
                "240p": 400,
            }

            for label, target_kbps in targets.items():
                ratio = target_kbps / assumed_bitrate_kbps
                estimated_size = avg_size_bytes * ratio
                reduction = (1 - ratio) * 100
                print(f"\n  {label} ({target_kbps} kbps):")
                print(f"    Taille estimée: {estimated_size/(1024*1024):.2f} MB")
                print(f"    Réduction vs original: {reduction:.0f}%")
                print(f"    Temps chargement @4G (10 Mbps): {estimated_size*8/(10*1000*1000):.1f}s")
                print(f"    Temps chargement @3G (2 Mbps):  {estimated_size*8/(2*1000*1000):.1f}s")
                print(f"    Bande passante requise: {target_kbps/1000:.1f} Mbps")

    print("\n" + "=" * 70)
    print(" AUDIT TERMINÉ")
    print("=" * 70)


if __name__ == "__main__":
    main()
