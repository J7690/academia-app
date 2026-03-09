#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import time
import uuid
from typing import Any, Dict

from videoasset_worker_step8 import get_supabase_service_config, process_one_job


def main() -> int:
    """Boucle de fond pour traiter en continu les jobs VideoAsset.

    - Utilise la même logique que videoasset_worker_step8, mais en mode "daemon".
    - Se connecte à Supabase via la Service Key (SupabaseAutoManager ou variables d'environnement).
    - Boucle indéfiniment jusqu'à interruption manuelle (Ctrl+C).

    Comportement :
      * Tant qu'il y a des jobs en file (queued), on les traite immédiatement.
      * Quand il n'y a plus de travail, on dort quelques secondes puis on re-tente.

    Les paramètres se règlent via variables d'environnement :
      * STEP8_DAEMON_IDLE_SLEEP_S : pause (en secondes) entre deux vérifications quand la file est vide (défaut: 5s).
      * STEP8_DAEMON_LOG_EVERY_N  : fréquence des logs de synthèse (défaut: toutes les 20 tâches).
    """

    cfg = get_supabase_service_config()
    worker_id = f"step8-daemon-{uuid.uuid4().hex[:8]}"

    idle_sleep_s = float(os.environ.get("STEP8_DAEMON_IDLE_SLEEP_S") or "5")
    log_every_n = int(os.environ.get("STEP8_DAEMON_LOG_EVERY_N") or "20")

    print(
        f"[daemon] starting VideoAsset worker daemon worker_id={worker_id} "
        f"idle_sleep_s={idle_sleep_s} log_every_n={log_every_n}"
    )

    processed_count = 0
    idle_loops = 0

    try:
        while True:
            ev: Dict[str, Any] = process_one_job(cfg, worker_id)

            if ev.get("did_work"):
                processed_count += 1
                idle_loops = 0

                # Log périodique pour suivre l'activité sans spammer.
                if processed_count % log_every_n == 0:
                    print(
                        "[daemon] processed jobs=", processed_count,
                        "last_event=",
                        json.dumps(ev, ensure_ascii=False)[:400],
                    )
                continue

            # Aucun job pour l'instant : on se met en veille un court instant.
            idle_loops += 1
            time.sleep(idle_sleep_s)

    except KeyboardInterrupt:
        print(
            f"[daemon] interrupted by user. processed_jobs={processed_count} "
            f"idle_loops={idle_loops}"
        )
        return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
