#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Audit CIBLE Kamatera pour le pipeline video Challenge (LECTURE SEULE).
Verifie: ports en ecoute (8001 compress, worker), services systemd video,
processus ffmpeg/worker, docker, ffmpeg dispo, scripts worker presents."""
import paramiko

HOST = "185.167.97.144"
USER = "root"
PASSWORD = "Nexiomgroup@Academia0"

CMDS = [
    ("PORTS en ecoute", "ss -tulpn 2>/dev/null | grep LISTEN | sort -t: -k2 -n"),
    ("Service academia-compress", "systemctl status academia-compress --no-pager 2>&1 | head -15 || echo NOT_FOUND"),
    ("Services academia-*", "systemctl list-units --type=service --all --no-pager 2>/dev/null | grep -iE 'academia|video|transcode|compress|worker|ffmpeg' || echo NONE"),
    ("Processus video/worker", "ps aux | grep -iE 'ffmpeg|worker|transcode|compress|poll|video' | grep -v grep | head -20"),
    ("Docker containers", "docker ps -a --format '{{.Names}} | {{.Image}} | {{.Status}} | {{.Ports}}' 2>/dev/null || echo NO_DOCKER"),
    ("ffmpeg version", "ffmpeg -version 2>/dev/null | head -1 || echo FFMPEG_NOT_FOUND"),
    ("Test HTTP local :8001", "curl -s -m 5 -o /dev/null -w '%{http_code}' http://127.0.0.1:8001/ 2>&1 || echo CURL_FAIL_8001"),
    ("Test HTTP local :8000", "curl -s -m 5 -o /dev/null -w '%{http_code}' http://127.0.0.1:8000/ 2>&1 || echo CURL_FAIL_8000"),
    ("Scripts worker /root /opt", "find /root /opt /srv -maxdepth 3 -type f \\( -name '*.py' -o -name '*.js' -o -name '*.ts' \\) 2>/dev/null | grep -iE 'worker|transcode|compress|video|poll' | head -20"),
    ("Cron / timers", "crontab -l 2>/dev/null | grep -iE 'video|worker|transcode|compress' || echo NO_CRON; systemctl list-timers --no-pager 2>/dev/null | head -10"),
    ("Charge & RAM", "uptime; free -h | head -2; nproc"),
    ("Logs worker (journal recents)", "journalctl --no-pager -n 5 -u 'academia-*' 2>&1 | tail -20 || echo NO_JOURNAL"),
]


def main():
    cli = paramiko.SSHClient()
    cli.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        cli.connect(HOST, username=USER, password=PASSWORD, timeout=20,
                    banner_timeout=15, auth_timeout=15)
    except Exception as e:
        print(f"CONNEXION SSH ECHOUEE: {e}")
        return
    print("=" * 80)
    print(f"AUDIT KAMATERA VIDEO PIPELINE - {HOST}")
    print("=" * 80)
    for label, cmd in CMDS:
        print(f"\n--- {label} ---")
        try:
            _in, out, err = cli.exec_command(cmd, timeout=30)
            o = out.read().decode("utf-8", "replace").strip()
            e = err.read().decode("utf-8", "replace").strip()
            if o:
                print(o[:2500])
            if e:
                print(f"[stderr] {e[:600]}")
        except Exception as ex:
            print(f"ERROR: {ex}")
    cli.close()
    print("\n" + "=" * 80)
    print("FIN AUDIT KAMATERA")
    print("=" * 80)


if __name__ == "__main__":
    main()
