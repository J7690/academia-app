#!/usr/bin/env python3
"""Convertit une vidéo vers un MP4 compatible web + Android pour les héros Academia.

Objectif :
- Conteneur : MP4
- Vidéo   : H.264 / AVC, profil standard, yuv420p, <= 1080p
- Audio   : AAC 128 kbps

Pré-requis :
- Avoir `ffmpeg` installé localement et accessible dans le PATH.

Usage :

  python .windsurf/hero_video_convert.py chemin/vers/entree.(mp4|mov|...) [chemin/vers/sortie.mp4]

Si le chemin de sortie n'est pas fourni, le script crée un fichier
`<nom_fichier>.normalized.mp4` à côté de la vidéo d'entrée.

Ce script NE touche PAS à la base Supabase ni au code Flutter :
il sert uniquement à préparer un fichier propre à uploader via l'admin.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path


def main(argv: list[str]) -> int:
  if len(argv) < 2 or len(argv) > 3:
    print("Usage : python .windsurf/hero_video_convert.py input_video [output.mp4]")
    return 1

  input_path = Path(argv[1]).expanduser().resolve()
  if not input_path.exists():
    print(f"[ERROR] Fichier d'entrée introuvable : {input_path}")
    return 1

  if len(argv) == 3:
    output_path = Path(argv[2]).expanduser().resolve()
  else:
    # ex : pub.mov -> pub.normalized.mp4
    output_path = input_path.with_suffix(".normalized.mp4")

  # Commande ffmpeg pour produire un MP4 H.264/AAC compatible Chrome + Android.
  cmd = [
    "ffmpeg",
    "-y",               # overwrite sans demander
    "-i",
    str(input_path),
    # Limite à 1920px de large, préserve le ratio, hauteur multiple de 2
    "-vf",
    "scale='min(1920,iw)':-2",
    # Vidéo H.264
    "-c:v",
    "libx264",
    "-preset",
    "veryfast",
    "-profile:v",
    "high",
    "-pix_fmt",
    "yuv420p",
    # Audio AAC
    "-c:a",
    "aac",
    "-b:a",
    "128k",
    str(output_path),
  ]

  print("[INFO] Conversion vidéo vers MP4 H.264/AAC compatible web+Android")
  print("[INFO] Entrée :", input_path)
  print("[INFO] Sortie :", output_path)
  print("[INFO] Commande :", " ".join(cmd))

  try:
    completed = subprocess.run(cmd, check=True)
  except FileNotFoundError:
    print("[ERROR] ffmpeg introuvable. Installe `ffmpeg` et assure-toi qu'il est dans le PATH.")
    return 1
  except subprocess.CalledProcessError as exc:
    print(f"[ERROR] ffmpeg a échoué avec le code {exc.returncode}")
    return exc.returncode

  if completed.returncode == 0:
    print("[OK] Fichier converti avec succès :", output_path)
  return completed.returncode


if __name__ == "__main__":  # pragma: no cover
  raise SystemExit(main(sys.argv))
