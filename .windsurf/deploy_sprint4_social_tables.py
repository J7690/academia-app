import json, requests
from supabase_auto_manager import SupabaseAutoManager

def q(m, label, sql):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=60)
    d = r.json() if r.text else {}
    print(f"\n=== {label} ===")
    if isinstance(d, list):
        for row in d:
            print(row)
    else:
        print(json.dumps(d, indent=2))

m = SupabaseAutoManager()

print("=== DEPLOY SPRINT 4 — SOCIAL TABLES ===\n")

# 1. video_reactions (emoji reactions on videos)
q(m, "1. CREATE VIDEO_REACTIONS", """
CREATE TABLE IF NOT EXISTS app.video_reactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    video_id TEXT NOT NULL,
    participation_id TEXT,
    reaction_type TEXT NOT NULL DEFAULT 'like',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, video_id, reaction_type)
)
""")

# 2. video_shares
q(m, "2. CREATE VIDEO_SHARES", """
CREATE TABLE IF NOT EXISTS app.video_shares (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    video_id TEXT NOT NULL,
    participation_id TEXT,
    share_target TEXT NOT NULL DEFAULT 'native',
    created_at TIMESTAMPTZ DEFAULT NOW()
)
""")

# 3. Indexes
q(m, "3. INDEX REACTIONS VIDEO", """
CREATE INDEX IF NOT EXISTS idx_video_reactions_video ON app.video_reactions(video_id)
""")
q(m, "4. INDEX REACTIONS USER", """
CREATE INDEX IF NOT EXISTS idx_video_reactions_user ON app.video_reactions(user_id)
""")
q(m, "5. INDEX SHARES VIDEO", """
CREATE INDEX IF NOT EXISTS idx_video_shares_video ON app.video_shares(video_id)
""")

# 4. RPC toggle reaction
q(m, "6. CREATE RPC TOGGLE_VIDEO_REACTION", """
CREATE OR REPLACE FUNCTION public.app_student_toggle_video_reaction(
    p_video_id TEXT,
    p_reaction_type TEXT DEFAULT 'like',
    p_participation_id TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_existing UUID;
    v_action TEXT;
    v_count INTEGER;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT id INTO v_existing
    FROM app.video_reactions
    WHERE user_id = v_user_id AND video_id = p_video_id AND reaction_type = p_reaction_type;

    IF v_existing IS NOT NULL THEN
        DELETE FROM app.video_reactions WHERE id = v_existing;
        v_action := 'removed';
    ELSE
        INSERT INTO app.video_reactions (user_id, video_id, participation_id, reaction_type)
        VALUES (v_user_id, p_video_id, p_participation_id, p_reaction_type);
        v_action := 'added';
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM app.video_reactions
    WHERE video_id = p_video_id AND reaction_type = p_reaction_type;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'action', v_action, 'count', v_count, 'reaction_type', p_reaction_type);
END;
$$
""")

# 5. RPC get video reactions
q(m, "7. CREATE RPC GET_VIDEO_REACTIONS", """
CREATE OR REPLACE FUNCTION public.app_student_get_video_reactions(
    p_video_id TEXT
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_reactions JSONB;
    v_my_reactions JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT COALESCE(JSONB_OBJECT_AGG(reaction_type, cnt), '{}'::JSONB)
    INTO v_reactions
    FROM (
        SELECT reaction_type, COUNT(*) AS cnt
        FROM app.video_reactions
        WHERE video_id = p_video_id
        GROUP BY reaction_type
    ) sub;

    SELECT COALESCE(JSONB_AGG(reaction_type), '[]'::JSONB)
    INTO v_my_reactions
    FROM app.video_reactions
    WHERE video_id = p_video_id AND user_id = v_user_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'reactions', v_reactions, 'my_reactions', v_my_reactions);
END;
$$
""")

# 6. RPC log share
q(m, "8. CREATE RPC LOG_VIDEO_SHARE", """
CREATE OR REPLACE FUNCTION public.app_student_log_video_share(
    p_video_id TEXT,
    p_participation_id TEXT DEFAULT NULL,
    p_share_target TEXT DEFAULT 'native'
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    INSERT INTO app.video_shares (user_id, video_id, participation_id, share_target)
    VALUES (v_user_id, p_video_id, p_participation_id, p_share_target);

    -- Update daily engagement
    INSERT INTO app.video_engagement_daily (video_id, day, shares_count)
    VALUES (p_video_id, CURRENT_DATE, 1)
    ON CONFLICT (video_id, day)
    DO UPDATE SET shares_count = app.video_engagement_daily.shares_count + 1, updated_at = NOW();

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$
""")

# 7. RLS
q(m, "9. RLS VIDEO_REACTIONS", """
ALTER TABLE app.video_reactions ENABLE ROW LEVEL SECURITY
""")
q(m, "10. RLS POLICY REACTIONS", """
DO $$ BEGIN
CREATE POLICY video_reactions_own ON app.video_reactions
    FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$
""")
q(m, "11. RLS VIDEO_SHARES", """
ALTER TABLE app.video_shares ENABLE ROW LEVEL SECURITY
""")
q(m, "12. RLS POLICY SHARES", """
DO $$ BEGIN
CREATE POLICY video_shares_insert_own ON app.video_shares
    FOR INSERT WITH CHECK (user_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$
""")
