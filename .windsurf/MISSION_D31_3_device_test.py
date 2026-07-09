#!/usr/bin/env python3
"""MISSION D31.3 — Phase 4 : test device TECNO LD7 pour Smart Whiteboard preview."""
import subprocess
import time
from pathlib import Path
import re

ADB = r"C:\Users\fasop\Downloads\platform-tools\platform-tools\adb.exe"
PACKAGE = "com.academia.app"
ACTIVITY = ".MainActivity"
LOG_FILE = r"C:\Users\fasop\AndroidStudioProjects\academia\.windsurf\D31_3_tecno_logcat.txt"


def run_adb(cmd, timeout=60):
    full = [ADB] + cmd
    result = subprocess.run(full, capture_output=True, text=True, timeout=timeout, encoding='utf-8', errors='ignore')
    return result.stdout, result.stderr


# 1. Clear logcat
print("Clearing logcat...")
run_adb(["logcat", "-c"])

# 2. Start app
print(f"Launching {PACKAGE}/{ACTIVITY}...")
run_adb(["shell", "am", "start", "-n", f"{PACKAGE}/{ACTIVITY}"])

# 3. Start logcat capture in background
print("Starting logcat capture...")
logcat_proc = subprocess.Popen(
    [ADB, "logcat", "-v", "threadtime"],
    stdout=open(LOG_FILE, "w", encoding="utf-8", errors="ignore"),
    stderr=subprocess.STDOUT,
    text=True,
)

print("\n=== INSTRUCTIONS ===")
print("1. Sur le TECNO, connecte-toi à l'app.")
print("2. Va dans Smart Whiteboard.")
print("3. Saisis le sujet : 'dérivés d'une fonction'.")
print("4. Génère le storyboard.")
print("5. Lance le rendu.")
print("6. Attends que le bouton de preview apparaisse.")
print("7. Ouvre le preview.")
print("8. Observe : est-ce que la vidéo se lit ? Quelle durée s'affiche ?")
print("9. Reste sur l'écran preview pendant au moins 10 secondes.")
print("\nCe script attend 2 minutes, puis capture et analyse les logs.")
print("Ne touche pas au câble.")
print("====================\n")

# Wait for user to perform test
for i in range(120, 0, -1):
    if i % 10 == 0:
        print(f"Attente... {i}s restantes")
    time.sleep(1)

# 4. Stop logcat
print("Stopping logcat...")
logcat_proc.terminate()
try:
    logcat_proc.wait(timeout=5)
except subprocess.TimeoutExpired:
    logcat_proc.kill()

# 5. Read log file
log_text = Path(LOG_FILE).read_text(encoding="utf-8", errors="ignore")

# 6. Analyze
keywords = [
    "SmartWhiteboard",
    "ExoPlayer",
    "MediaCodec",
    "OMX",
    "video_player",
    "flutter",
    "DEBUG-PREVIEW",
    "ERROR",
    "CRASH",
    "FATAL",
    "ANR",
    "Mediatek",
    "MediaTek",
    "MediaCodecRenderer",
    "DecoderInitialization",
]

relevant = []
for line in log_text.splitlines():
    if any(k.lower() in line.lower() for k in keywords):
        relevant.append(line)

# 7. Generate report
report_path = r"C:\Users\fasop\AndroidStudioProjects\academia\.windsurf\D31_3_real_device_validation.md"
relevant_text = '\n'.join(relevant[-500:])
report = f"""# D31_3_real_device_validation.md

**Date :** {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}
**Device :** TECNO LD7 (MediaTek)
**APK :** `{PACKAGE}`
**Logs bruts :** `D31_3_tecno_logcat.txt`

---

## Protocole exécuté

1. APK installé via `adb install -r`.
2. App lancée via `adb shell am start`.
3. Logcat capturé pendant 2 minutes.
4. Test manuel demandé : générer storyboard "dérivés d'une fonction", lancer rendu, ouvrir preview.

---

## Logs pertinents (filtrés)

```
{relevant_text}
```

---

## Analyse automatique

| Motif | Trouvé ? |
|---|---|
| Erreur ExoPlayer | {'Oui' if any('exoplayer' in l.lower() and 'error' in l.lower() for l in relevant) else 'Non'} |
| Erreur MediaCodec | {'Oui' if any('mediacodec' in l.lower() and 'error' in l.lower() for l in relevant) else 'Non'} |
| OMX/MediaTek | {'Oui' if any('omx' in l.lower() or 'mediatek' in l.lower() or 'mtk' in l.lower() for l in relevant) else 'Non'} |
| DEBUG-PREVIEW ERROR | {'Oui' if any('DEBUG-PREVIEW ERROR' in l for l in relevant) else 'Non'} |
| CRASH/FATAL | {'Oui' if any('FATAL' in l or 'CRASH' in l for l in relevant) else 'Non'} |
| ANR | {'Oui' if any('ANR' in l for l in relevant) else 'Non'} |
| Vidéo initialisée OK | {'Oui' if any('DEBUG-PREVIEW: initialized OK' in l for l in relevant) else 'Non'} |

---

## Remarque

Ce rapport est basé sur les logs capturés. L'observation visuelle finale (duration affichée, crash visible) doit être confirmée par l'utilisateur.

---

**Fin du rapport device.**
"""

Path(report_path).write_text(report, encoding="utf-8")
print(f"Saved {report_path}")
print(f"Log file: {LOG_FILE}")
print(f"Relevant log lines: {len(relevant)}")
