#!/usr/bin/env python3
"""
Fix app_student_list_user_videos RPC to use correct schema (app.*),
correct column names (user_id, not student_id), and resolve video URLs
via video_renditions (same pattern as app_student_unified_video_feed).
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from supabase_auto_manager import SupabaseAutoManager
import requests

manager = SupabaseAutoManager()

SQL = """
CREATE OR REPLACE FUNCTION public.app_student_list_user_videos(
  p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_videos JSONB;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'user_id requis');
  END IF;

  WITH all_videos AS (
    -- Challenge participations
    SELECT
      cp.id AS video_id,
      'challenge' AS video_type,
      cp.id AS participation_id,
      c.title AS challenge_title,
      c.challenge_type,
      c.difficulty,
      c.points,
      (
        SELECT vr.public_url_hint
        FROM app.video_renditions vr
        WHERE vr.video_asset_id = cp.video_asset_id
          AND vr.status = 'ready'
        ORDER BY vr.created_at DESC
        LIMIT 1
      ) AS video_url,
      (
        SELECT JSONB_BUILD_OBJECT('best_url',
          COALESCE(
            (SELECT vr2.public_url_hint FROM app.video_renditions vr2
             WHERE vr2.video_asset_id = cp.video_asset_id AND vr2.status = 'ready'
             ORDER BY vr2.created_at DESC LIMIT 1),
            ''
          )
        )
      ) AS playback,
      (
        SELECT cvo.layers
        FROM app.challenge_video_overlays cvo
        WHERE cvo.participation_id = cp.id
        ORDER BY cvo.updated_at DESC
        LIMIT 1
      ) AS overlays,
      COALESCE(cp.submitted_at, cp.started_at) AS created_at,
      cp.user_id,
      COALESCE(
        (SELECT count(*) FROM app.video_likes vl
         WHERE vl.video_type = 'challenge' AND vl.video_id = cp.id),
        0
      )::int AS likes_count,
      COALESCE(
        (SELECT count(*) FROM app.video_comments vc
         WHERE vc.video_type = 'challenge' AND vc.video_id = cp.id
           AND vc.is_deleted = FALSE),
        0
      )::int AS comments_count,
      NULL::TEXT AS poster_url
    FROM app.challenge_participations cp
    JOIN app.challenges c ON c.id = cp.challenge_id
    WHERE cp.user_id = p_user_id
      AND cp.is_active = TRUE
      AND cp.video_asset_id IS NOT NULL

    UNION ALL

    -- Free videos
    SELECT
      fv.id AS video_id,
      'free' AS video_type,
      NULL::UUID AS participation_id,
      fv.title AS challenge_title,
      NULL::TEXT AS challenge_type,
      NULL::TEXT AS difficulty,
      NULL::INT AS points,
      (
        SELECT vr.public_url_hint
        FROM app.video_renditions vr
        WHERE vr.video_asset_id = fv.video_asset_id
          AND vr.status = 'ready'
        ORDER BY vr.created_at DESC
        LIMIT 1
      ) AS video_url,
      (
        SELECT JSONB_BUILD_OBJECT('best_url',
          COALESCE(
            (SELECT vr2.public_url_hint FROM app.video_renditions vr2
             WHERE vr2.video_asset_id = fv.video_asset_id AND vr2.status = 'ready'
             ORDER BY vr2.created_at DESC LIMIT 1),
            ''
          )
        )
      ) AS playback,
      (
        SELECT fvo.layers
        FROM app.free_video_overlays fvo
        WHERE fvo.free_video_id = fv.id
        ORDER BY fvo.updated_at DESC
        LIMIT 1
      ) AS overlays,
      fv.created_at,
      fv.user_id,
      COALESCE(
        (SELECT count(*) FROM app.video_likes vl
         WHERE vl.video_type = 'free' AND vl.video_id = fv.id),
        0
      )::int AS likes_count,
      COALESCE(
        (SELECT count(*) FROM app.video_comments vc
         WHERE vc.video_type = 'free' AND vc.video_id = fv.id
           AND vc.is_deleted = FALSE),
        0
      )::int AS comments_count,
      NULL::TEXT AS poster_url
    FROM app.free_videos fv
    WHERE fv.user_id = p_user_id
      AND fv.is_active = TRUE
      AND fv.video_asset_id IS NOT NULL
  )
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'video_id', av.video_id,
      'video_type', av.video_type,
      'participation_id', av.participation_id,
      'challenge_title', av.challenge_title,
      'challenge_type', av.challenge_type,
      'difficulty', av.difficulty,
      'points', av.points,
      'video_url', av.video_url,
      'playback', av.playback,
      'overlays', av.overlays,
      'likes_count', av.likes_count,
      'comments_count', av.comments_count,
      'poster_url', av.poster_url,
      'user_id', av.user_id,
      'created_at', av.created_at
    ) ORDER BY av.created_at DESC
  ), '[]'::jsonb)
  INTO v_videos
  FROM all_videos av;

  RETURN jsonb_build_object(
    'success', true,
    'videos', v_videos
  );
END;
$$
"""

print("=" * 70)
print("Deploying FIXED app_student_list_user_videos")
print("=" * 70)

url = f"{manager.url}/rest/v1/rpc/admin_execute_sql"
r = requests.post(url, headers=manager.headers, json={"p_sql": SQL}, timeout=30)
print(f"Status: {r.status_code}")
print(f"Response: {r.text[:500]}")

# Also fix the GRANT
print("\nGranting EXECUTE to authenticated...")
r2 = requests.post(url, headers=manager.headers,
    json={"p_sql": "GRANT EXECUTE ON FUNCTION public.app_student_list_user_videos(UUID) TO authenticated"},
    timeout=15)
print(f"Status: {r2.status_code}")
print(f"Response: {r2.text[:300]}")

# Verify
print("\nVerifying function signature...")
r3 = requests.post(url, headers=manager.headers,
    json={"p_sql": "SELECT pg_get_function_arguments(p.oid) as args FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'public' AND p.proname = 'app_student_list_user_videos'"},
    timeout=15)
print(f"Verification: {r3.text[:300]}")
