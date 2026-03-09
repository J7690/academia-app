-- ============================================================
-- COMMUNITIES ENHANCEMENT MIGRATION
-- Adds: edited_at column, edit/pin/list_members RPCs,
--        direct messages tables + RPCs
-- ============================================================

-- 1. ADD edited_at column to community_posts
ALTER TABLE app.community_posts
  ADD COLUMN IF NOT EXISTS edited_at TIMESTAMPTZ DEFAULT NULL;

-- ============================================================
-- 2. app_student_edit_community_post
--    Allows author to edit their own post within 15 minutes
-- ============================================================
CREATE OR REPLACE FUNCTION public.app_student_edit_community_post(
  p_post_id UUID,
  p_new_content TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_post RECORD;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT id, author_id, created_at, is_deleted, community_id
    INTO v_post
    FROM app.community_posts
   WHERE id = p_post_id;

  IF v_post IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'post_not_found');
  END IF;

  IF v_post.author_id != v_uid THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_author');
  END IF;

  IF v_post.is_deleted THEN
    RETURN jsonb_build_object('success', false, 'error', 'post_deleted');
  END IF;

  IF (NOW() - v_post.created_at) > INTERVAL '15 minutes' THEN
    RETURN jsonb_build_object('success', false, 'error', 'edit_window_expired');
  END IF;

  IF TRIM(COALESCE(p_new_content, '')) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'empty_content');
  END IF;

  UPDATE app.community_posts
     SET content = TRIM(p_new_content),
         edited_at = NOW(),
         updated_at = NOW()
   WHERE id = p_post_id;

  RETURN jsonb_build_object('success', true, 'post_id', p_post_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_edit_community_post(UUID, TEXT) TO authenticated;

-- ============================================================
-- 3. app_student_pin_community_post
--    Allows community creator or admin/moderator to pin/unpin
-- ============================================================
CREATE OR REPLACE FUNCTION public.app_student_pin_community_post(
  p_post_id UUID,
  p_is_pinned BOOLEAN DEFAULT true
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_post RECORD;
  v_membership RECORD;
  v_community RECORD;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT id, community_id, is_deleted
    INTO v_post
    FROM app.community_posts
   WHERE id = p_post_id;

  IF v_post IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'post_not_found');
  END IF;

  IF v_post.is_deleted THEN
    RETURN jsonb_build_object('success', false, 'error', 'post_deleted');
  END IF;

  -- Check if user is community creator
  SELECT created_by_user_id INTO v_community
    FROM app.communities
   WHERE id = v_post.community_id;

  -- Check membership role
  SELECT role INTO v_membership
    FROM app.community_memberships
   WHERE community_id = v_post.community_id
     AND user_id = v_uid
     AND is_active = true;

  IF v_community.created_by_user_id != v_uid
     AND (v_membership.role IS NULL OR v_membership.role NOT IN ('admin', 'moderator')) THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authorized');
  END IF;

  -- Unpin all other posts in this community first (only one pinned at a time)
  IF p_is_pinned THEN
    UPDATE app.community_posts
       SET is_pinned = false
     WHERE community_id = v_post.community_id
       AND is_pinned = true
       AND id != p_post_id;
  END IF;

  UPDATE app.community_posts
     SET is_pinned = p_is_pinned,
         updated_at = NOW()
   WHERE id = p_post_id;

  RETURN jsonb_build_object('success', true, 'post_id', p_post_id, 'is_pinned', p_is_pinned);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_pin_community_post(UUID, BOOLEAN) TO authenticated;

-- ============================================================
-- 4. app_student_list_community_members
--    Returns members of a community (for @mentions, member list)
-- ============================================================
CREATE OR REPLACE FUNCTION public.app_student_list_community_members(
  p_community_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_is_member BOOLEAN;
  v_result JSONB;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  -- Check caller is a member
  SELECT EXISTS(
    SELECT 1 FROM app.community_memberships
     WHERE community_id = p_community_id
       AND user_id = v_uid
       AND is_active = true
  ) INTO v_is_member;

  IF NOT v_is_member THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_member');
  END IF;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'user_id', m.user_id,
      'role', m.role,
      'joined_at', m.joined_at,
      'is_banned', m.is_banned,
      'display_name', COALESCE(s.first_name || ' ' || s.last_name, u.email),
      'email', u.email
    ) ORDER BY m.role DESC, m.joined_at ASC
  ), '[]'::jsonb)
  INTO v_result
  FROM app.community_memberships m
  LEFT JOIN auth.users u ON u.id = m.user_id
  LEFT JOIN app.students s ON s.user_id = m.user_id
  WHERE m.community_id = p_community_id
    AND m.is_active = true
    AND m.is_banned = false;

  RETURN jsonb_build_object('success', true, 'members', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_list_community_members(UUID) TO authenticated;

-- ============================================================
-- 5. DIRECT MESSAGES — Tables
-- ============================================================

-- 5a. Direct conversations (1-to-1 between two users)
CREATE TABLE IF NOT EXISTS app.direct_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_a UUID NOT NULL REFERENCES auth.users(id),
  user_b UUID NOT NULL REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_message_at TIMESTAMPTZ,
  CONSTRAINT direct_conversations_users_unique UNIQUE (user_a, user_b),
  CONSTRAINT direct_conversations_order CHECK (user_a < user_b)
);

-- 5b. Direct messages
CREATE TABLE IF NOT EXISTS app.direct_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES app.direct_conversations(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES auth.users(id),
  content TEXT,
  type TEXT NOT NULL DEFAULT 'text',
  media_url TEXT,
  reply_to_message_id UUID REFERENCES app.direct_messages(id),
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  edited_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_direct_messages_conversation
  ON app.direct_messages(conversation_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_direct_conversations_user_a
  ON app.direct_conversations(user_a);

CREATE INDEX IF NOT EXISTS idx_direct_conversations_user_b
  ON app.direct_conversations(user_b);

-- 5c. Direct message read states
CREATE TABLE IF NOT EXISTS app.direct_message_read_states (
  conversation_id UUID NOT NULL REFERENCES app.direct_conversations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  last_read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (conversation_id, user_id)
);

-- 5d. RLS policies for direct messages
ALTER TABLE app.direct_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.direct_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.direct_message_read_states ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'dm_conv_select_own' AND tablename = 'direct_conversations') THEN
    CREATE POLICY dm_conv_select_own ON app.direct_conversations
      FOR SELECT USING (user_a = auth.uid() OR user_b = auth.uid());
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'dm_conv_insert_own' AND tablename = 'direct_conversations') THEN
    CREATE POLICY dm_conv_insert_own ON app.direct_conversations
      FOR INSERT WITH CHECK (user_a = auth.uid() OR user_b = auth.uid());
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'dm_msg_select_own' AND tablename = 'direct_messages') THEN
    CREATE POLICY dm_msg_select_own ON app.direct_messages
      FOR SELECT USING (
        EXISTS (
          SELECT 1 FROM app.direct_conversations c
           WHERE c.id = direct_messages.conversation_id
             AND (c.user_a = auth.uid() OR c.user_b = auth.uid())
        )
      );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'dm_msg_insert_own' AND tablename = 'direct_messages') THEN
    CREATE POLICY dm_msg_insert_own ON app.direct_messages
      FOR INSERT WITH CHECK (sender_id = auth.uid());
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'dm_read_select_own' AND tablename = 'direct_message_read_states') THEN
    CREATE POLICY dm_read_select_own ON app.direct_message_read_states
      FOR SELECT USING (user_id = auth.uid());
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'dm_read_upsert_own' AND tablename = 'direct_message_read_states') THEN
    CREATE POLICY dm_read_upsert_own ON app.direct_message_read_states
      FOR INSERT WITH CHECK (user_id = auth.uid());
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'dm_read_update_own' AND tablename = 'direct_message_read_states') THEN
    CREATE POLICY dm_read_update_own ON app.direct_message_read_states
      FOR UPDATE USING (user_id = auth.uid());
  END IF;
END $$;

-- ============================================================
-- 6. DIRECT MESSAGES — RPC Functions
-- ============================================================

-- 6a. Start or get a direct conversation
CREATE OR REPLACE FUNCTION public.app_student_get_or_create_dm_conversation(
  p_other_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_ua UUID;
  v_ub UUID;
  v_conv_id UUID;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  IF v_uid = p_other_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'cannot_dm_self');
  END IF;

  -- Ensure ordering (user_a < user_b)
  IF v_uid < p_other_user_id THEN
    v_ua := v_uid; v_ub := p_other_user_id;
  ELSE
    v_ua := p_other_user_id; v_ub := v_uid;
  END IF;

  -- Try to find existing conversation
  SELECT id INTO v_conv_id
    FROM app.direct_conversations
   WHERE user_a = v_ua AND user_b = v_ub;

  IF v_conv_id IS NULL THEN
    INSERT INTO app.direct_conversations (user_a, user_b)
    VALUES (v_ua, v_ub)
    RETURNING id INTO v_conv_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'conversation_id', v_conv_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_get_or_create_dm_conversation(UUID) TO authenticated;

-- 6b. Send a direct message
CREATE OR REPLACE FUNCTION public.app_student_send_direct_message(
  p_conversation_id UUID,
  p_content TEXT,
  p_type TEXT DEFAULT 'text',
  p_media_url TEXT DEFAULT NULL,
  p_reply_to_message_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_conv RECORD;
  v_msg_id UUID;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT id, user_a, user_b INTO v_conv
    FROM app.direct_conversations
   WHERE id = p_conversation_id;

  IF v_conv IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'conversation_not_found');
  END IF;

  IF v_uid != v_conv.user_a AND v_uid != v_conv.user_b THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_participant');
  END IF;

  IF TRIM(COALESCE(p_content, '')) = '' AND TRIM(COALESCE(p_media_url, '')) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'empty_message');
  END IF;

  INSERT INTO app.direct_messages (conversation_id, sender_id, content, type, media_url, reply_to_message_id)
  VALUES (p_conversation_id, v_uid, TRIM(p_content), COALESCE(p_type, 'text'), p_media_url, p_reply_to_message_id)
  RETURNING id INTO v_msg_id;

  UPDATE app.direct_conversations
     SET last_message_at = NOW()
   WHERE id = p_conversation_id;

  RETURN jsonb_build_object('success', true, 'message_id', v_msg_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_send_direct_message(UUID, TEXT, TEXT, TEXT, UUID) TO authenticated;

-- 6c. List direct messages in a conversation
CREATE OR REPLACE FUNCTION public.app_student_list_direct_messages(
  p_conversation_id UUID,
  p_limit INTEGER DEFAULT 50,
  p_before TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_conv RECORD;
  v_result JSONB;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT id, user_a, user_b INTO v_conv
    FROM app.direct_conversations
   WHERE id = p_conversation_id;

  IF v_conv IS NULL OR (v_uid != v_conv.user_a AND v_uid != v_conv.user_b) THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_participant');
  END IF;

  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at ASC), '[]'::jsonb)
  INTO v_result
  FROM (
    SELECT dm.id, dm.sender_id, dm.content, dm.type, dm.media_url,
           dm.reply_to_message_id, dm.is_deleted, dm.edited_at, dm.created_at,
           COALESCE(s.first_name || ' ' || s.last_name, u.email) AS sender_display_name
      FROM app.direct_messages dm
      LEFT JOIN auth.users u ON u.id = dm.sender_id
      LEFT JOIN app.students s ON s.user_id = dm.sender_id
     WHERE dm.conversation_id = p_conversation_id
       AND dm.is_deleted = false
       AND (p_before IS NULL OR dm.created_at < p_before)
     ORDER BY dm.created_at DESC
     LIMIT LEAST(p_limit, 100)
  ) t;

  RETURN jsonb_build_object('success', true, 'messages', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_list_direct_messages(UUID, INTEGER, TIMESTAMPTZ) TO authenticated;

-- 6d. List all conversations for current user
CREATE OR REPLACE FUNCTION public.app_student_list_dm_conversations()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_result JSONB;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.last_message_at DESC NULLS LAST), '[]'::jsonb)
  INTO v_result
  FROM (
    SELECT c.id AS conversation_id,
           c.last_message_at,
           c.created_at,
           CASE WHEN c.user_a = v_uid THEN c.user_b ELSE c.user_a END AS other_user_id,
           COALESCE(s.first_name || ' ' || s.last_name, u.email) AS other_display_name,
           u.email AS other_email,
           (SELECT dm.content FROM app.direct_messages dm
             WHERE dm.conversation_id = c.id AND dm.is_deleted = false
             ORDER BY dm.created_at DESC LIMIT 1) AS last_message_content,
           (SELECT dm.sender_id FROM app.direct_messages dm
             WHERE dm.conversation_id = c.id AND dm.is_deleted = false
             ORDER BY dm.created_at DESC LIMIT 1) AS last_message_sender_id,
           COALESCE(
             (SELECT COUNT(*) FROM app.direct_messages dm
               WHERE dm.conversation_id = c.id
                 AND dm.is_deleted = false
                 AND dm.sender_id != v_uid
                 AND dm.created_at > COALESCE(
                   (SELECT rs.last_read_at FROM app.direct_message_read_states rs
                     WHERE rs.conversation_id = c.id AND rs.user_id = v_uid),
                   '1970-01-01'::timestamptz
                 )
             ), 0
           )::int AS unread_count
      FROM app.direct_conversations c
      LEFT JOIN auth.users u ON u.id = (CASE WHEN c.user_a = v_uid THEN c.user_b ELSE c.user_a END)
      LEFT JOIN app.students s ON s.user_id = (CASE WHEN c.user_a = v_uid THEN c.user_b ELSE c.user_a END)
     WHERE c.user_a = v_uid OR c.user_b = v_uid
  ) t;

  RETURN jsonb_build_object('success', true, 'conversations', v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_list_dm_conversations() TO authenticated;

-- 6e. Mark DM conversation as read
CREATE OR REPLACE FUNCTION public.app_student_mark_dm_read(
  p_conversation_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  INSERT INTO app.direct_message_read_states (conversation_id, user_id, last_read_at)
  VALUES (p_conversation_id, v_uid, NOW())
  ON CONFLICT (conversation_id, user_id)
  DO UPDATE SET last_read_at = NOW();

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_mark_dm_read(UUID) TO authenticated;

-- ============================================================
-- 7. Enable Realtime for direct_messages
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE app.direct_messages;
