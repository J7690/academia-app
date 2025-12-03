#!/usr/bin/env python3
"""Patch Flutter: mettre à jour la dépendance video_player dans pubspec.yaml.

Ce script:
- Ouvre academia_app/pubspec.yaml
- Remplace la ligne "video_player: ^2.8.2" par "video_player: ^2.10.1".

Aucune autre modification n'est effectuée.
"""

from __future__ import annotations

from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent.parent
PUBSPEC = BASE_DIR / "academia_app" / "pubspec.yaml"


def patch_pubspec() -> None:
    if not PUBSPEC.is_file():
        raise SystemExit(f"Fichier introuvable: {PUBSPEC}")

    text = PUBSPEC.read_text(encoding="utf-8")

    old_line = "  video_player: ^2.8.2\n"
    new_line = "  video_player: ^2.10.1\n"

    if new_line.strip() in text:
        print("video_player est déjà en ^2.10.1, aucun changement")
        return

    if old_line not in text:
        raise SystemExit("Ligne video_player attendue introuvable dans pubspec.yaml")

    text = text.replace(old_line, new_line)
    PUBSPEC.write_text(text, encoding="utf-8")
    print("Mise à jour de video_player vers ^2.10.1 dans pubspec.yaml effectuée")


def main() -> int:
    patch_pubspec()
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
