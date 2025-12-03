from __future__ import annotations

from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent.parent
MANIFEST_PATH = (
    BASE_DIR / "academia_app" / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
)


def patch_manifest() -> None:
  text = MANIFEST_PATH.read_text(encoding="utf-8")

  if "android.permission.INTERNET" in text:
    print("INTERNET permission already present in main AndroidManifest.xml")
    return

  anchor = '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
  if anchor not in text:
    raise SystemExit("Manifest <manifest> anchor not found in main AndroidManifest.xml")

  replacement = anchor + '    <uses-permission android:name="android.permission.INTERNET"/>\n'
  new_text = text.replace(anchor, replacement)
  MANIFEST_PATH.write_text(new_text, encoding="utf-8")
  print("Added INTERNET permission to main AndroidManifest.xml for release builds")


def main() -> int:
  patch_manifest()
  return 0


if __name__ == "__main__":
  raise SystemExit(main())
