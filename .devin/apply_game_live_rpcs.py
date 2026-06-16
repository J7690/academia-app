#!/usr/bin/env python3
"""Applique les 3 RPCs challenge_game_live via admin_execute_sql."""

import requests
import json
import sys

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}

def run_sql(label, sql):
    print(f"\n{'='*60}")
    print(f"[{label}]")
    try:
        r = requests.post(
            f"{URL}/rest/v1/rpc/admin_execute_sql",
            headers=HEADERS,
            json={"p_sql": sql},
            timeout=30,
        )
        data = r.json() if r.status_code == 200 else r.text
        print(f"  Status: {r.status_code}")
        print(f"  Response: {json.dumps(data, indent=2) if isinstance(data, (dict,list)) else data}")
        return r.status_code == 200 and (isinstance(data, dict) and data.get("ok", False))
    except Exception as e:
        print(f"  ERROR: {e}")
        return False

# ── RPC 1: challenge_game_start_live ──
SQL_START = """
CREATE OR REPLACE FUNCTION public.challenge_game_start_live(
  p_game_type TEXT DEFAULT 'unknown',
  p_mode      TEXT DEFAULT 'solo'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $fn$
DECLARE
  v_user_id UUID;
  v_session_id UUID;
  v_room_name TEXT;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Non authentifie.');
  END IF;
  UPDATE app.challenge_game_live_sessions
  SET status = 'cancelled', ended_at = now()
  WHERE user_id = v_user_id AND status = 'live';
  v_session_id := gen_random_uuid();
  v_room_name := 'game_' || v_session_id::TEXT;
  INSERT INTO app.challenge_game_live_sessions (id, user_id, game_type, mode, status, livekit_room_name)
  VALUES (v_session_id, v_user_id, p_game_type, p_mode, 'live', v_room_name);
  RETURN jsonb_build_object('success', true, 'session_id', v_session_id, 'room_name', v_room_name);
END;
$fn$;
"""

SQL_START_GRANT = "GRANT EXECUTE ON FUNCTION public.challenge_game_start_live(TEXT, TEXT) TO authenticated;"

# ── RPC 2: challenge_game_end_live ──
SQL_END = """
CREATE OR REPLACE FUNCTION public.challenge_game_end_live(
  p_session_id          UUID,
  p_score_final         INT DEFAULT 0,
  p_replay_video_asset_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $fn$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Non authentifie.');
  END IF;
  UPDATE app.challenge_game_live_sessions
  SET status = 'ended',
      score_final = p_score_final,
      replay_video_asset_id = p_replay_video_asset_id,
      ended_at = now()
  WHERE id = p_session_id
    AND user_id = v_user_id
    AND status = 'live';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Session introuvable ou deja terminee.');
  END IF;
  RETURN jsonb_build_object('success', true);
END;
$fn$;
"""

SQL_END_GRANT = "GRANT EXECUTE ON FUNCTION public.challenge_game_end_live(UUID, INT, UUID) TO authenticated;"

# ── RPC 3: challenge_game_list_live ──
SQL_LIST = """
CREATE OR REPLACE FUNCTION public.challenge_game_list_live()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $fn$
DECLARE
  v_sessions JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.started_at DESC), '[]'::jsonb)
  INTO v_sessions
  FROM (
    SELECT
      s.id AS session_id,
      s.user_id,
      s.game_type,
      s.mode,
      s.livekit_room_name,
      s.started_at,
      COALESCE(st.full_name, '') AS player_name,
      COALESCE(st.avatar_url, '') AS player_avatar
    FROM app.challenge_game_live_sessions s
    LEFT JOIN app.students st ON st.id = s.user_id
    WHERE s.status = 'live'
      AND s.started_at > now() - INTERVAL '4 hours'
  ) t;
  RETURN jsonb_build_object('success', true, 'sessions', v_sessions);
END;
$fn$;
"""

SQL_LIST_GRANT = "GRANT EXECUTE ON FUNCTION public.challenge_game_list_live() TO authenticated;"

# ── RLS policies (idempotent) ──
SQL_RLS = """
DO $$ BEGIN
  ALTER TABLE app.challenge_game_live_sessions ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY cgls_select_all ON app.challenge_game_live_sessions FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY cgls_insert_own ON app.challenge_game_live_sessions FOR INSERT WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY cgls_update_own ON app.challenge_game_live_sessions FOR UPDATE USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
"""

def main():
    results = []
    results.append(("RPC start_live", run_sql("RPC challenge_game_start_live", SQL_START)))
    results.append(("GRANT start_live", run_sql("GRANT start_live", SQL_START_GRANT)))
    results.append(("RPC end_live", run_sql("RPC challenge_game_end_live", SQL_END)))
    results.append(("GRANT end_live", run_sql("GRANT end_live", SQL_END_GRANT)))
    results.append(("RPC list_live", run_sql("RPC challenge_game_list_live", SQL_LIST)))
    results.append(("GRANT list_live", run_sql("GRANT list_live", SQL_LIST_GRANT)))
    results.append(("RLS policies", run_sql("RLS policies", SQL_RLS)))

    print(f"\n{'='*60}")
    print("SUMMARY:")
    all_ok = True
    for label, ok in results:
        status = "OK" if ok else "FAILED"
        print(f"  {label}: {status}")
        if not ok:
            all_ok = False

    if all_ok:
        print("\nAll RPCs applied successfully!")
    else:
        print("\nSome steps failed. Check output above.")

    # Verify
    print(f"\n{'='*60}")
    print("VERIFICATION: checking RPCs exist...")
    run_sql("VERIFY RPCs", "SELECT routine_name FROM information_schema.routines WHERE routine_schema = 'public' AND routine_name IN ('challenge_game_start_live','challenge_game_end_live','challenge_game_list_live')")

    return 0 if all_ok else 1

if __name__ == "__main__":
    sys.exit(main())
