#!/usr/bin/env python3
"""Audit complet du flux de publication: état des données en DB après tentative de publication."""

import requests
import json
from datetime import datetime

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {"apikey": KEY, "Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}

def q(sql):
    r = requests.post(f"{URL}/rest/v1/rpc/execute_sql", headers=HEADERS, json={"sql_query": sql}, timeout=30)
    if r.status_code == 200:
        return r.json()
    return f"ERR {r.status_code}: {r.text[:500]}"

def show(label, rows):
    print(f"\n{'='*70}")
    print(f"  {label}")
    print(f"{'='*70}")
    if isinstance(rows, list):
        if not rows:
            print("  (aucune ligne)")
        for r in rows:
            if isinstance(r, dict):
                print(f"  {json.dumps(r, indent=2, ensure_ascii=False, default=str)}")
            else:
                print(f"  {r}")
    elif isinstance(rows, dict):
        print(f"  {json.dumps(rows, indent=2, ensure_ascii=False, default=str)}")
    else:
        print(f"  {rows}")

# ══════════════════════════════════════════════════════════════════════
# 1) FREE VIDEOS récentes (les 10 dernières)
# ══════════════════════════════════════════════════════════════════════
show("1. FREE VIDEOS récentes (10 dernières)", q("""
    SELECT fv.id, fv.user_id, fv.title, fv.description, fv.is_active,
           fv.moderation_status, fv.video_asset_id,
           fv.created_at, fv.updated_at
    FROM app.free_videos fv
    ORDER BY fv.created_at DESC
    LIMIT 10
"""))

# ══════════════════════════════════════════════════════════════════════
# 2) CHALLENGE PARTICIPATIONS récentes (les 10 dernières)
# ══════════════════════════════════════════════════════════════════════
show("2. CHALLENGE PARTICIPATIONS récentes (10 dernières)", q("""
    SELECT cp.id, cp.user_id, cp.challenge_id, cp.video_asset_id,
           cp.is_active, cp.moderation_status,
           cp.started_at, cp.submitted_at
    FROM app.challenge_participations cp
    ORDER BY cp.started_at DESC
    LIMIT 10
"""))

# ══════════════════════════════════════════════════════════════════════
# 3) VIDEO ASSETS récents (les 10 derniers)
# ══════════════════════════════════════════════════════════════════════
show("3. VIDEO ASSETS récents (10 derniers)", q("""
    SELECT va.id, va.owner_user_id, va.origin, va.status,
           va.has_audio, va.duration_ms, va.width, va.height,
           va.created_at
    FROM app.video_assets va
    ORDER BY va.created_at DESC
    LIMIT 10
"""))

# ══════════════════════════════════════════════════════════════════════
# 4) VIDEO RENDITIONS récentes (les 10 dernières)
# ══════════════════════════════════════════════════════════════════════
show("4. VIDEO RENDITIONS récentes (10 dernières)", q("""
    SELECT vr.id, vr.video_asset_id, vr.rendition_key, vr.status,
           vr.public_url_hint, vr.storage_path, vr.storage_bucket,
           vr.created_at
    FROM app.video_renditions vr
    ORDER BY vr.created_at DESC
    LIMIT 10
"""))

# ══════════════════════════════════════════════════════════════════════
# 5) FREE VIDEO OVERLAYS récents
# ══════════════════════════════════════════════════════════════════════
show("5. FREE VIDEO OVERLAYS récents (10 derniers)", q("""
    SELECT fo.id, fo.free_video_id, fo.updated_at,
           LEFT(fo.layers::TEXT, 200) AS layers_preview
    FROM app.free_video_overlays fo
    ORDER BY fo.updated_at DESC
    LIMIT 10
"""))

# ══════════════════════════════════════════════════════════════════════
# 6) CHALLENGE VIDEO OVERLAYS récents
# ══════════════════════════════════════════════════════════════════════
show("6. CHALLENGE VIDEO OVERLAYS récents (10 derniers)", q("""
    SELECT co.id, co.participation_id, co.updated_at,
           LEFT(co.layers::TEXT, 200) AS layers_preview
    FROM app.challenge_video_overlays co
    ORDER BY co.updated_at DESC
    LIMIT 10
"""))

# ══════════════════════════════════════════════════════════════════════
# 7) Lister les RPCs liées à la publication
# ══════════════════════════════════════════════════════════════════════
show("7. RPCs de publication existantes", q("""
    SELECT routine_name, routine_schema
    FROM information_schema.routines
    WHERE routine_type = 'FUNCTION'
      AND (
        routine_name LIKE '%free_video%'
        OR routine_name LIKE '%submit%'
        OR routine_name LIKE '%create_free%'
        OR routine_name LIKE '%publish%'
        OR routine_name LIKE '%challenge_video%'
      )
    ORDER BY routine_name
"""))

# ══════════════════════════════════════════════════════════════════════
# 8) Free videos sans video_asset_id (problème potentiel)
# ══════════════════════════════════════════════════════════════════════
show("8. Free videos SANS video_asset_id", q("""
    SELECT fv.id, fv.user_id, fv.is_active, fv.moderation_status,
           fv.created_at
    FROM app.free_videos fv
    WHERE fv.video_asset_id IS NULL
    ORDER BY fv.created_at DESC
"""))

# ══════════════════════════════════════════════════════════════════════
# 9) Free videos actives avec video_asset_id MAIS sans rendition
# ══════════════════════════════════════════════════════════════════════
show("9. Free videos actives AVEC asset MAIS SANS rendition", q("""
    SELECT fv.id, fv.video_asset_id, fv.is_active, fv.moderation_status
    FROM app.free_videos fv
    WHERE fv.is_active = TRUE
      AND fv.video_asset_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM app.video_renditions vr
        WHERE vr.video_asset_id = fv.video_asset_id
          AND vr.status = 'ready'
      )
"""))

# ══════════════════════════════════════════════════════════════════════
# 10) Vérifier le feed RPC: combien de vidéos retournées
# ══════════════════════════════════════════════════════════════════════
show("10. Comptage feed unifié (challenge + free avec renditions ready)", q("""
    SELECT
        (SELECT COUNT(*) FROM app.challenge_participations cp
         WHERE cp.is_active = TRUE AND cp.video_asset_id IS NOT NULL
           AND EXISTS (SELECT 1 FROM app.video_renditions vr WHERE vr.video_asset_id = cp.video_asset_id AND vr.status='ready')
        ) AS challenge_with_rendition,
        (SELECT COUNT(*) FROM app.free_videos fv
         WHERE fv.is_active = TRUE AND fv.video_asset_id IS NOT NULL
           AND EXISTS (SELECT 1 FROM app.video_renditions vr WHERE vr.video_asset_id = fv.video_asset_id AND vr.status='ready')
        ) AS free_with_rendition,
        (SELECT COUNT(*) FROM app.free_videos WHERE is_active = TRUE) AS free_active_total,
        (SELECT COUNT(*) FROM app.free_videos WHERE is_active = TRUE AND video_asset_id IS NOT NULL) AS free_with_asset,
        (SELECT COUNT(*) FROM app.challenge_participations WHERE is_active = TRUE) AS challenge_active_total
"""))

# ══════════════════════════════════════════════════════════════════════
# 11) Fichiers dans le bucket challenge-media (derniers uploads)
# ══════════════════════════════════════════════════════════════════════
show("11. Derniers objets storage.objects dans challenge-media (10 derniers)", q("""
    SELECT id, name, bucket_id, created_at, updated_at,
           metadata->>'size' AS size_bytes,
           metadata->>'mimetype' AS mimetype
    FROM storage.objects
    WHERE bucket_id = 'challenge-media'
    ORDER BY created_at DESC
    LIMIT 10
"""))

print("\n\n" + "="*70)
print("  AUDIT TERMINÉ")
print("="*70)
