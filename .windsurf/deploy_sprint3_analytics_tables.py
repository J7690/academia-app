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

print("=== DEPLOY SPRINT 3 — ANALYTICS TABLES ===\n")

# 1. Create video_views table for tracking individual view events
q(m, "1. CREATE VIDEO_VIEWS TABLE", """
CREATE TABLE IF NOT EXISTS app.video_views (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    video_type TEXT NOT NULL DEFAULT 'challenge',
    video_id TEXT NOT NULL,
    participation_id TEXT,
    watch_duration_ms INTEGER NOT NULL DEFAULT 0,
    total_duration_ms INTEGER NOT NULL DEFAULT 0,
    completion_percent NUMERIC(5,2) DEFAULT 0,
    quality_selected TEXT,
    source TEXT DEFAULT 'feed',
    created_at TIMESTAMPTZ DEFAULT NOW()
)
""")

# 2. Create video_heatmap_events for tracking seek/watch patterns
q(m, "2. CREATE VIDEO_HEATMAP_EVENTS TABLE", """
CREATE TABLE IF NOT EXISTS app.video_heatmap_events (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    video_id TEXT NOT NULL,
    position_ms INTEGER NOT NULL,
    event_type TEXT NOT NULL DEFAULT 'watch',
    created_at TIMESTAMPTZ DEFAULT NOW()
)
""")

# 3. Create video_engagement_daily for aggregated daily stats
q(m, "3. CREATE VIDEO_ENGAGEMENT_DAILY TABLE", """
CREATE TABLE IF NOT EXISTS app.video_engagement_daily (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    video_id TEXT NOT NULL,
    day DATE NOT NULL DEFAULT CURRENT_DATE,
    views_count INTEGER DEFAULT 0,
    unique_viewers INTEGER DEFAULT 0,
    total_watch_ms BIGINT DEFAULT 0,
    avg_completion_percent NUMERIC(5,2) DEFAULT 0,
    likes_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    shares_count INTEGER DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(video_id, day)
)
""")

# 4. Create indexes for performance
q(m, "4. INDEX VIDEO_VIEWS", """
CREATE INDEX IF NOT EXISTS idx_video_views_video_id ON app.video_views(video_id)
""")

q(m, "5. INDEX VIDEO_VIEWS USER", """
CREATE INDEX IF NOT EXISTS idx_video_views_user_id ON app.video_views(user_id)
""")

q(m, "6. INDEX VIDEO_VIEWS CREATED", """
CREATE INDEX IF NOT EXISTS idx_video_views_created_at ON app.video_views(created_at)
""")

q(m, "7. INDEX HEATMAP VIDEO", """
CREATE INDEX IF NOT EXISTS idx_video_heatmap_video_id ON app.video_heatmap_events(video_id)
""")

q(m, "8. INDEX ENGAGEMENT DAILY", """
CREATE INDEX IF NOT EXISTS idx_video_engagement_daily_video ON app.video_engagement_daily(video_id, day)
""")

# 5. Create RPC to log video view
q(m, "9. CREATE RPC LOG_VIDEO_VIEW", """
CREATE OR REPLACE FUNCTION public.app_student_log_video_view(
    p_video_id TEXT,
    p_video_type TEXT DEFAULT 'challenge',
    p_participation_id TEXT DEFAULT NULL,
    p_watch_duration_ms INTEGER DEFAULT 0,
    p_total_duration_ms INTEGER DEFAULT 0,
    p_quality_selected TEXT DEFAULT NULL,
    p_source TEXT DEFAULT 'feed'
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_completion NUMERIC(5,2) := 0;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    IF p_total_duration_ms > 0 THEN
        v_completion := LEAST(100, (p_watch_duration_ms::NUMERIC / p_total_duration_ms) * 100);
    END IF;

    INSERT INTO app.video_views (user_id, video_type, video_id, participation_id, watch_duration_ms, total_duration_ms, completion_percent, quality_selected, source)
    VALUES (v_user_id, p_video_type, p_video_id, p_participation_id, p_watch_duration_ms, p_total_duration_ms, v_completion, p_quality_selected, p_source);

    -- Update daily engagement
    INSERT INTO app.video_engagement_daily (video_id, day, views_count, unique_viewers, total_watch_ms, avg_completion_percent)
    VALUES (p_video_id, CURRENT_DATE, 1, 1, p_watch_duration_ms, v_completion)
    ON CONFLICT (video_id, day)
    DO UPDATE SET
        views_count = app.video_engagement_daily.views_count + 1,
        total_watch_ms = app.video_engagement_daily.total_watch_ms + EXCLUDED.total_watch_ms,
        avg_completion_percent = (app.video_engagement_daily.avg_completion_percent * app.video_engagement_daily.views_count + v_completion) / (app.video_engagement_daily.views_count + 1),
        updated_at = NOW();

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$
""")

# 6. Create RPC to log heatmap event
q(m, "10. CREATE RPC LOG_HEATMAP_EVENT", """
CREATE OR REPLACE FUNCTION public.app_student_log_heatmap_event(
    p_video_id TEXT,
    p_position_ms INTEGER,
    p_event_type TEXT DEFAULT 'watch'
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    INSERT INTO app.video_heatmap_events (user_id, video_id, position_ms, event_type)
    VALUES (v_user_id, p_video_id, p_position_ms, p_event_type);

    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$$
""")

# 7. Create RPC to get video analytics
q(m, "11. CREATE RPC GET_VIDEO_ANALYTICS", """
CREATE OR REPLACE FUNCTION public.app_student_get_video_analytics(
    p_video_id TEXT
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_total_views INTEGER;
    v_unique_viewers INTEGER;
    v_avg_completion NUMERIC(5,2);
    v_total_watch_ms BIGINT;
    v_heatmap JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT COUNT(*), COUNT(DISTINCT user_id),
           COALESCE(AVG(completion_percent), 0),
           COALESCE(SUM(watch_duration_ms), 0)
    INTO v_total_views, v_unique_viewers, v_avg_completion, v_total_watch_ms
    FROM app.video_views
    WHERE video_id = p_video_id;

    -- Aggregate heatmap: 10-second buckets
    SELECT COALESCE(JSONB_AGG(
        JSONB_BUILD_OBJECT('bucket_ms', bucket, 'count', cnt)
        ORDER BY bucket
    ), '[]'::JSONB)
    INTO v_heatmap
    FROM (
        SELECT (position_ms / 10000) * 10000 AS bucket, COUNT(*) AS cnt
        FROM app.video_heatmap_events
        WHERE video_id = p_video_id
        GROUP BY bucket
    ) sub;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'video_id', p_video_id,
        'total_views', v_total_views,
        'unique_viewers', v_unique_viewers,
        'avg_completion_percent', v_avg_completion,
        'total_watch_ms', v_total_watch_ms,
        'heatmap', v_heatmap
    );
END;
$$
""")

# 8. RLS policies
q(m, "12. RLS VIDEO_VIEWS", """
ALTER TABLE app.video_views ENABLE ROW LEVEL SECURITY
""")

q(m, "13. RLS POLICY INSERT VIDEO_VIEWS", """
DO $$ BEGIN
CREATE POLICY video_views_insert_own ON app.video_views
    FOR INSERT WITH CHECK (user_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$
""")

q(m, "14. RLS HEATMAP_EVENTS", """
ALTER TABLE app.video_heatmap_events ENABLE ROW LEVEL SECURITY
""")

q(m, "15. RLS POLICY INSERT HEATMAP", """
DO $$ BEGIN
CREATE POLICY heatmap_insert_own ON app.video_heatmap_events
    FOR INSERT WITH CHECK (user_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$
""")
