"""
Agent de capture distant — Vision v2 (parallélisation multi-machines, 28/07/2026)

CONTEXTE : `record_page_parallel` (whiteboard_video_capture.py) découpe un cours en
tranches filmées en parallèle sur les cœurs D'UNE SEULE machine (3-4 cœurs sur le VPS
LWS actuel). Les plateformes qui rendent vite (Remotion Lambda, etc.) ne filment pas
plus vite qu'en temps réel non plus : elles distribuent les tranches sur BEAUCOUP PLUS
de machines en parallèle. Cet agent permet exactement ça : une machine supplémentaire
(VPS classique, même profil que le worker actuel) expose une capture de tranche par
HTTP, que `record_page_parallel` peut appeler au lieu de tourner en local.

INACTIF PAR DÉFAUT : tant qu'aucune machine n'est déclarée dans
`WHITEBOARD_REMOTE_WORKERS` sur le worker principal, ce fichier n'est jamais appelé et
rien ne change au comportement actuel.

DÉPLOIEMENT : voir docs/PARALLELISATION_MULTI_MACHINES_2026-07-28.md pour la procédure
complète (paquets à installer, arborescence à répliquer, service systemd, activation).

SÉCURITÉ : ce serveur écoute sur un port entrant (contrairement au worker principal qui
ne fait que sortir vers Supabase) — c'est le SEUL composant de l'infra Smart Whiteboard
à en avoir besoin. Protégé par une clé partagée (`CAPTURE_AGENT_KEY`) ; à combiner avec
un pare-feu qui n'autorise que l'IP du worker principal.
"""

from __future__ import annotations

import json
import logging
import os
import tempfile
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from whiteboard_video_capture import record_page

logger = logging.getLogger("capture_agent")
if not logging.getLogger().handlers:
    logging.basicConfig(level=logging.INFO)

PORT = int(os.getenv("CAPTURE_AGENT_PORT", "8077") or "8077")
# Clé partagée : le worker principal doit l'envoyer dans l'en-tête X-Capture-Key.
# Vide par défaut = agent inutilisable (on refuse tout plutôt que d'accepter sans clé).
AGENT_KEY = os.getenv("CAPTURE_AGENT_KEY", "").strip()

TMP_DIR = Path(tempfile.gettempdir()) / "capture_agent"
TMP_DIR.mkdir(parents=True, exist_ok=True)


class Handler(BaseHTTPRequestHandler):
    server_version = "CaptureAgent/1.0"

    def log_message(self, fmt, *args):  # noqa: A003 - override stdlib signature
        logger.info("[capture_agent] %s", fmt % args)

    def _reject(self, code: int, message: str) -> None:
        body = json.dumps({"error": message}).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):  # noqa: N802 - nom impose par BaseHTTPRequestHandler
        if self.path == "/health":
            body = json.dumps({"status": "ok"}).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        self._reject(404, "not_found")

    def do_POST(self):  # noqa: N802
        if self.path != "/capture":
            self._reject(404, "not_found")
            return

        if not AGENT_KEY:
            self._reject(503, "agent_key_non_configuree")
            return
        if self.headers.get("X-Capture-Key", "") != AGENT_KEY:
            self._reject(401, "cle_invalide")
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(length)
            payload = json.loads(raw.decode("utf-8"))
            html = payload["html"]
            duration_sec = float(payload["duration_sec"])
            fps = int(payload.get("fps", 25))
            start_sec = float(payload.get("start_sec", 0.0))
        except (KeyError, ValueError, json.JSONDecodeError) as exc:
            self._reject(400, f"requete_invalide: {exc}")
            return

        job_id = uuid.uuid4().hex
        html_path = TMP_DIR / f"{job_id}.html"
        output_path = TMP_DIR / f"{job_id}.mp4"
        try:
            html_path.write_text(html, encoding="utf-8")
            record_page(html_path, output_path, duration_sec, fps, strict=True, start_sec=start_sec)
            data = output_path.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "video/mp4")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        except Exception as exc:  # noqa: BLE001 - on renvoie l'erreur au lieu de crasher l'agent
            logger.exception("[capture_agent] echec capture job %s", job_id)
            self._reject(500, str(exc)[:500])
        finally:
            html_path.unlink(missing_ok=True)
            output_path.unlink(missing_ok=True)
            output_path.with_suffix(".raw.webm").unlink(missing_ok=True)


def main() -> None:
    if not AGENT_KEY:
        logger.warning(
            "[capture_agent] CAPTURE_AGENT_KEY non definie : l'agent refusera toutes "
            "les requetes tant qu'elle n'est pas configuree dans /opt/capture-agent/.env"
        )
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    logger.info("[capture_agent] a l'ecoute sur :%d", PORT)
    server.serve_forever()


if __name__ == "__main__":
    main()
