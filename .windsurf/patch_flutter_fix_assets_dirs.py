from __future__ import annotations

from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
FLUTTER_DIR = BASE_DIR / "academia_app"
ASSETS_IMAGES = FLUTTER_DIR / "assets" / "images"
ASSETS_ICONS = FLUTTER_DIR / "assets" / "icons"


def ensure_dir(path: Path) -> None:
  if not path.exists():
    path.mkdir(parents=True, exist_ok=True)
    print("Created directory", path)
  gitkeep = path / ".gitkeep"
  if not gitkeep.exists():
    gitkeep.write_text("", encoding="utf-8")
    print("Created", gitkeep)


def main() -> int:
  ensure_dir(ASSETS_IMAGES)
  ensure_dir(ASSETS_ICONS)
  return 0


if __name__ == "__main__":
  raise SystemExit(main())
