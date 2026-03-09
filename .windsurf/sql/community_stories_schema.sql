-- ============================================================
-- Campus Stories: tables + RPCs + RLS
-- ============================================================

-- 1) Table des stories
CREATE TABLE IF NOT EXISTS app.community_stories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id UUID NOT NULL REFERENCES app.communities(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES app.students(id) ON DELETE CASCADE,
    type TEXT NOT NULL DEFAULT 'image' CHECK (type IN ('image', 'text', 'video')),
    media_url TEXT,
    caption TEXT,
    bg_color TEXT,
    text_content TEXT,
    category TEXT CHECK (category IS NULL OR category IN ('cours', 'campus', 'evenement', 'tips')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '24 hours'),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

-- 2) Table des vues de stories
CREATE TABLE IF NOT EXISTS app.community_story_views (
    story_id UUID NOT NULL REFERENCES app.community_stories(id) ON DELETE CASCADE,
    viewer_id UUID NOT NULL REFERENCES app.students(id) ON DELETE CASCADE,
    viewed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (story_id, viewer_id)
);

-- 3) Index pour performance
CREATE INDEX IF NOT EXISTS idx_community_stories_community_expires
    ON app.community_stories(community_id, expires_at)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_community_stories_author
    ON app.community_stories(author_id);

CREATE INDEX IF NOT EXISTS idx_community_story_views_story
    ON app.community_story_views(story_id);

-- 4) RLS sur community_stories
ALTER TABLE app.community_stories ENABLE ROW LEVEL SECURITY;

CREATE POLICY student_select_community_stories ON app.community_stories
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM app.community_memberships m
            WHERE m.community_id = community_stories.community_id
              AND m.user_id = auth.uid()
              AND m.is_active = TRUE
        )
    );

CREATE POLICY student_insert_own_community_stories ON app.community_stories
    FOR INSERT WITH CHECK (author_id = auth.uid());

CREATE POLICY student_delete_own_community_stories ON app.community_stories
    FOR DELETE USING (author_id = auth.uid());

CREATE POLICY student_update_own_community_stories ON app.community_stories
    FOR UPDATE USING (author_id = auth.uid());

-- 5) RLS sur community_story_views
ALTER TABLE app.community_story_views ENABLE ROW LEVEL SECURITY;

CREATE POLICY student_select_own_story_views ON app.community_story_views
    FOR SELECT USING (
        viewer_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM app.community_stories s
            WHERE s.id = community_story_views.story_id
              AND s.author_id = auth.uid()
        )
    );

CREATE POLICY student_insert_own_story_views ON app.community_story_views
    FOR INSERT WITH CHECK (viewer_id = auth.uid());
