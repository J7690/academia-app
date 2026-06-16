#!/usr/bin/env python3
"""
AUDIT — Preuves techniques FFmpeg et videoasset_worker.
Aucune modification.  Lecture seule.

Vérifie :
  1. FFmpeg installé sur le VPS Kamatera 185.167.97.144
  2. Processus videoasset_worker.py actif
  3. Renditions réelles (240p, 480p, 720p) dans Supabase
"""
import json
import paramiko
import requests

# ── Kamatera VPS ──
SERVER_IP = "185.167.97.144"
SERVER_USER = "root"
SERVER_PASS = "Nexiomgroup@Academia0"

# ── Supabase ──
SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SUPABASE_SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

def section(title):
    print("\n" + "=" * 70)
    print(f" {title}")
    print("=" * 70)

def ssh_exec(client, cmd):
    print(f"\nroot@{SERVER_IP}:~# {cmd}")
    stdin, stdout, stderr = client.exec_command(cmd, timeout=30)
    stdout.channel.recv_exit_status()
    out = stdout.read().decode("utf-8", errors="replace").strip()
    err = stderr.read().decode("utf-8", errors="replace").strip()
    if out:
        print(out)
    if err:
        print(f"(stderr) {err}")
    return out

def main():
    # ================================================================
    # PARTIE 1 : VPS — FFmpeg + worker
    # ================================================================
    section("1. CONNEXION SSH AU VPS KAMATERA")

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        client.connect(SERVER_IP, username=SERVER_USER, password=SERVER_PASS, timeout=15)
        print(f"Connexion SSH établie vers {SERVER_IP}")
    except Exception as e:
        print(f"ÉCHEC connexion SSH: {e}")
        return

    # ── 1.1 which ffmpeg ──
    section("2. FFMPEG — LOCALISATION ET VERSION")
    ssh_exec(client, "which ffmpeg")
    ssh_exec(client, "ffmpeg -version 2>&1 | head -5")
    ssh_exec(client, "which ffprobe")

    # ── 1.2 videoasset_worker.py — processus actif ? ──
    section("3. PROCESSUS videoasset_worker.py")
    ssh_exec(client, "ps aux | grep -i videoasset_worker | grep -v grep")
    ssh_exec(client, "ps aux | grep -i 'python.*worker' | grep -v grep")

    # ── 1.3 systemd / cron / supervisor ? ──
    section("4. SERVICE / CRON / SUPERVISOR POUR LE WORKER")
    ssh_exec(client, "systemctl list-units --all | grep -i video")
    ssh_exec(client, "systemctl list-units --all | grep -i worker")
    ssh_exec(client, "crontab -l 2>&1 | grep -i video || echo 'Aucun cron video trouvé'")
    ssh_exec(client, "crontab -l 2>&1 | grep -i worker || echo 'Aucun cron worker trouvé'")
    ssh_exec(client, "ls -la /etc/supervisor/conf.d/ 2>/dev/null || echo 'Pas de supervisor conf.d'")

    # ── 1.4 Fichiers du worker sur le VPS ──
    section("5. FICHIERS DU WORKER SUR LE VPS")
    ssh_exec(client, "find / -name 'videoasset_worker.py' -type f 2>/dev/null || echo 'videoasset_worker.py non trouvé sur le VPS'")
    ssh_exec(client, "find / -name 'studio_video_renderer.py' -type f 2>/dev/null || echo 'studio_video_renderer.py non trouvé sur le VPS'")

    # ── 1.5 Backend dir (Railway / local ?) ──
    section("6. RÉPERTOIRE BACKEND SUR LE VPS")
    ssh_exec(client, "ls -la /opt/academia* 2>/dev/null || echo 'Pas de /opt/academia*'")
    ssh_exec(client, "ls -la /root/academia* 2>/dev/null || echo 'Pas de /root/academia*'")
    ssh_exec(client, "ls -la /home/*/academia* 2>/dev/null || echo 'Pas de /home/*/academia*'")
    ssh_exec(client, "docker ps -a --format '{{.Names}} {{.Image}} {{.Status}}' 2>/dev/null")

    # ── 1.6 Systemd video-worker service ──
    section("6b. SERVICE SYSTEMD video-worker")
    ssh_exec(client, "systemctl status video-worker --no-pager 2>&1 || echo 'Service video-worker non trouvé'")
    ssh_exec(client, "cat /etc/systemd/system/video-worker.service 2>/dev/null || echo 'Fichier service non trouvé'")
    ssh_exec(client, "cat /opt/video-worker/worker.py 2>/dev/null | head -30 || echo 'worker.py non trouvé dans /opt/video-worker/'")
    ssh_exec(client, "journalctl -u video-worker --no-pager -n 20 2>&1 || echo 'Pas de journal video-worker'")
    ssh_exec(client, "apt list --installed 2>/dev/null | grep ffmpeg || echo 'ffmpeg non dans apt list'")
    ssh_exec(client, "dpkg -l | grep ffmpeg || echo 'ffmpeg non dans dpkg'")
    ssh_exec(client, "find / -name ffmpeg -type f 2>/dev/null | head -5 || echo 'Aucun binaire ffmpeg trouvé'")

    client.close()

    # ================================================================
    # PARTIE 2 : SUPABASE — Renditions réelles
    # ================================================================
    section("7. SUPABASE — video_processing_jobs (derniers jobs)")

    headers = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Accept": "application/json",
        "Accept-Profile": "app",
    }

    # Derniers jobs de traitement vidéo
    try:
        r = requests.get(
            f"{SUPABASE_URL}/rest/v1/video_processing_jobs",
            headers=headers,
            params={
                "order": "created_at.desc",
                "limit": "10",
                "select": "id,video_asset_id,job_type,status,error,created_at,locked_by",
            },
            timeout=15,
        )
        print(f"HTTP {r.status_code}")
        if r.status_code < 400:
            jobs = r.json()
            print(f"Nombre de jobs retournés: {len(jobs)}")
            for j in jobs:
                print(f"  - {j.get('id','?')[:8]}.. | asset={str(j.get('video_asset_id','?'))[:8]}.. | type={j.get('job_type')} | status={j.get('status')} | locked_by={j.get('locked_by')} | created={j.get('created_at')}")
                if j.get('error'):
                    print(f"    error: {str(j['error'])[:200]}")
        else:
            print(f"Erreur: {r.text[:500]}")
    except Exception as e:
        print(f"Erreur requête: {e}")

    # ── Renditions existantes ──
    section("8. SUPABASE — video_renditions (dernières renditions)")

    try:
        r = requests.get(
            f"{SUPABASE_URL}/rest/v1/video_renditions",
            headers=headers,
            params={
                "order": "created_at.desc",
                "limit": "20",
                "select": "id,video_asset_id,rendition_key,kind,status,width,height,bitrate_kbps,storage_path,public_url_hint,created_at",
            },
            timeout=15,
        )
        print(f"HTTP {r.status_code}")
        if r.status_code < 400:
            renditions = r.json()
            print(f"Nombre de renditions retournées: {len(renditions)}")

            # Group by video_asset_id
            by_asset = {}
            for rd in renditions:
                aid = str(rd.get('video_asset_id', '?'))[:12]
                by_asset.setdefault(aid, []).append(rd)

            for aid, rds in by_asset.items():
                print(f"\n  VideoAsset {aid}..:")
                for rd in rds:
                    print(f"    - key={rd.get('rendition_key')} | kind={rd.get('kind')} | status={rd.get('status')} | w={rd.get('width')} h={rd.get('height')} | bitrate={rd.get('bitrate_kbps')}kbps | created={rd.get('created_at')}")
                    url_hint = rd.get('public_url_hint', '')
                    if url_hint:
                        print(f"      url={url_hint[:100]}...")
        else:
            print(f"Erreur: {r.text[:500]}")
    except Exception as e:
        print(f"Erreur requête: {e}")

    # ── Video assets récents ──
    section("9. SUPABASE — video_assets (5 derniers)")

    try:
        r = requests.get(
            f"{SUPABASE_URL}/rest/v1/video_assets",
            headers=headers,
            params={
                "order": "created_at.desc",
                "limit": "5",
                "select": "id,status,created_at,updated_at",
            },
            timeout=15,
        )
        print(f"HTTP {r.status_code}")
        if r.status_code < 400:
            assets = r.json()
            print(f"Nombre d'assets retournés: {len(assets)}")
            for a in assets:
                print(f"  - id={str(a.get('id','?'))[:12]}.. | status={a.get('status')} | created={a.get('created_at')} | updated={a.get('updated_at')}")
        else:
            print(f"Erreur: {r.text[:500]}")
    except Exception as e:
        print(f"Erreur requête: {e}")

    # ── Railway backend check ──
    section("10. RAILWAY BACKEND — Vérification si le worker tourne sur Railway")

    for endpoint in ["/health", "/", "/api/health"]:
        try:
            r = requests.get(
                f"https://academia-app-production.up.railway.app{endpoint}",
                timeout=10,
            )
            print(f"Railway {endpoint}: HTTP {r.status_code} — {r.text[:200]}")
        except Exception as e:
            print(f"Railway {endpoint}: {e}")

    # ── Check if worker runs via Railway or locally ──
    section("11. SUPABASE — video_processing_jobs par status")
    try:
        # Count by status
        for status in ['queued', 'running', 'done', 'failed']:
            r = requests.get(
                f"{SUPABASE_URL}/rest/v1/video_processing_jobs",
                headers=headers,
                params={
                    "status": f"eq.{status}",
                    "select": "id",
                    "limit": "1",
                },
                timeout=15,
            )
            if r.status_code < 400:
                # Use HEAD or Prefer: count=exact
                pass
        # Get count with Prefer: count=exact
        for status in ['queued', 'running', 'done', 'failed']:
            r = requests.get(
                f"{SUPABASE_URL}/rest/v1/video_processing_jobs",
                headers={**headers, 'Prefer': 'count=exact'},
                params={
                    "status": f"eq.{status}",
                    "select": "id",
                    "limit": "0",
                },
                timeout=15,
            )
            count = r.headers.get('content-range', '?')
            print(f"  Jobs '{status}': {count}")
    except Exception as e:
        print(f"Erreur: {e}")

    print("\n" + "=" * 70)
    print(" AUDIT TERMINÉ")
    print("=" * 70)


if __name__ == "__main__":
    main()
