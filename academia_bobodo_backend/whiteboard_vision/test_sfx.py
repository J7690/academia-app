"""Banc d'essai du sound design (vague G) : mixe une narration factice."""
import json
import logging
import subprocess
import sys
from pathlib import Path

logging.basicConfig(level=logging.INFO)

from whiteboard_page_builder import plan, INTRO_SEC
from whiteboard_sound_design import build_full_mix

sb = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
planned, _, total, _, _ = plan(sb, None)

# Narration factice : ton doux continu, pour entendre le ducking et les sfx.
fake = Path("/tmp/fake_narration.wav")
subprocess.run(
    ["ffmpeg", "-y", "-v", "error", "-f", "lavfi",
     "-i", f"sine=frequency=330:duration={total:.1f}",
     "-af", "volume=0.25", "-ar", "44100", "-ac", "2", str(fake)],
    check=True,
)

out = build_full_mix(sb, planned, INTRO_SEC, total, fake, Path("/tmp"))
print("RESULT:", out)
if out:
    p = subprocess.run(["ffprobe", "-v", "error", "-show_entries",
                        "format=duration", "-of", "csv=p=0", str(out)],
                       capture_output=True, text=True)
    print("duree:", p.stdout.strip(), "s (attendu ~", round(total, 1), ")")
