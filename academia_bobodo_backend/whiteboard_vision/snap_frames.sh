#!/bin/bash
# Capture d'images fixes d'une page bâtie, aux instants donnés (ms).
# Usage: snap_frames.sh <page.html> <t1_ms> [t2_ms...]
set -e
HTML="$1"; shift
cd /opt/whiteboard-worker/vision_engine
for t in "$@"; do
  node snap_still.js "$HTML" "/tmp/v3_$t.png" "$t"
done
