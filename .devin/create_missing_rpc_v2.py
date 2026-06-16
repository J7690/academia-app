"""
Create missing RPCs for LiveKit integration using correct parameter name
"""
import requests
import json

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
}

def exec_sql(sql, label=""):
    """Execute SQL via RPC with correct param name"""
    if label:
        print(f"\n  {label}")
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/execute_sql",
        headers=HEADERS,
        json={"sql_query": sql}
    )
    if r.status_code == 200:
        data = r.json()
        if isinstance(data, list):
            for row in data[:20]:
                print(f"    {row}")
        elif isinstance(data, str):
            print(f"    {data[:300]}")
        else:
            print(f"    {str(data)[:300]}")
    else:
        print(f"    HTTP {r.status_code}: {r.text[:300]}")
    return r

# Step 1: Check existing live-session RPCs
print("=" * 50)
print("Step 1: Check existing live-session RPCs...")
exec_sql("""
SELECT routine_name, routine_schema 
FROM information_schema.routines 
WHERE routine_name LIKE '%live%' OR routine_name LIKE '%session%'
ORDER BY routine_name
""")

# Step 2: Check online_course_live_sessions table structure
print("\n" + "=" * 50)
print("Step 2: Check online_course_live_sessions...")
exec_sql("""
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'online_course_live_sessions'
ORDER BY ordinal_position
""")

# Step 3: Check for participants tables
print("\n" + "=" * 50)
print("Step 3: Check participant/live tables...")
exec_sql("""
SELECT table_schema, table_name 
FROM information_schema.tables 
WHERE table_name LIKE '%participant%' OR table_name LIKE '%live_session%'
ORDER BY table_schema, table_name
""")

# Step 4: Create the missing RPC
print("\n" + "=" * 50)
print("Step 4: Create app_register_online_course_live_session_participant...")
exec_sql("""
CREATE OR REPLACE FUNCTION public.app_register_online_course_live_session_participant(
    p_session_id UUID,
    p_user_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check if participants table exists, if so insert
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'online_course_live_session_participants'
    ) THEN
        INSERT INTO online_course_live_session_participants (session_id, user_id, joined_at)
        VALUES (p_session_id, p_user_id, NOW())
        ON CONFLICT (session_id, user_id) DO UPDATE SET joined_at = NOW();
    END IF;
    
    -- Update participant count on the session if column exists
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'online_course_live_sessions' 
        AND column_name = 'participant_count'
    ) THEN
        UPDATE online_course_live_sessions 
        SET participant_count = COALESCE(participant_count, 0) + 1
        WHERE id = p_session_id;
    END IF;
END;
$$;
""")

# Step 5: Verify
print("\n" + "=" * 50)
print("Step 5: Verify RPC creation...")
exec_sql("""
SELECT routine_name, routine_schema 
FROM information_schema.routines 
WHERE routine_name = 'app_register_online_course_live_session_participant'
""")

# Step 6: Check app_prep_student_join_live_session
print("\n" + "=" * 50)
print("Step 6: Check app_prep_student_join_live_session...")
exec_sql("""
SELECT routine_name, routine_schema 
FROM information_schema.routines 
WHERE routine_name = 'app_prep_student_join_live_session'
""")

print("\n🏁 Done.")
