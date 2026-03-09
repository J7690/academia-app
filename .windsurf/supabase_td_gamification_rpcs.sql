-- ═══════════════════════════════════════════════════════════════════
-- TD Gamification RPCs — Functions for the gamified TD module
-- Covers: student dashboard, catalog, XP, streaks, resources,
--         leaderboard, teacher management, admin analytics
-- ═══════════════════════════════════════════════════════════════════

-- ─── STUDENT RPCs ────────────────────────────────────────────────

-- 1. Student dashboard home data
CREATE OR REPLACE FUNCTION public.app_td_student_get_home()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_streak record;
  v_goal record;
  v_next_session record;
  v_active_count integer;
  v_total_xp integer;
  v_level integer;
  v_result jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  -- Streak
  SELECT current_streak, longest_streak, last_active_date, total_active_days
  INTO v_streak FROM app.td_streaks WHERE student_id = v_uid;

  -- Daily goal
  SELECT target_xp, earned_xp, completed
  INTO v_goal FROM app.td_daily_goals
  WHERE student_id = v_uid AND goal_date = CURRENT_DATE;

  -- Active enrollments count
  SELECT count(*) INTO v_active_count
  FROM app.td_enrollments WHERE student_id = v_uid AND access_status = 'active';

  -- Total XP & level from student_progress
  SELECT COALESCE(sum(total_xp), 0), COALESCE(max(level), 1)
  INTO v_total_xp, v_level
  FROM app.td_student_progress WHERE student_id = v_uid;

  -- Next session
  SELECT so.scheduled_at, so.location, so.meeting_url, so.duration_minutes,
         s.title as session_title, p.title as program_title
  INTO v_next_session
  FROM app.td_session_occurrences so
  JOIN app.td_sessions s ON s.id = so.session_id
  JOIN app.td_collections c ON c.id = s.collection_id
  JOIN app.td_programs p ON p.id = c.program_id
  JOIN app.td_enrollments e ON e.id = so.enrollment_id
  WHERE e.student_id = v_uid
    AND so.status IN ('scheduled', 'confirmed')
    AND so.scheduled_at > now()
  ORDER BY so.scheduled_at ASC
  LIMIT 1;

  v_result := jsonb_build_object(
    'success', true,
    'streak', jsonb_build_object(
      'current', COALESCE(v_streak.current_streak, 0),
      'longest', COALESCE(v_streak.longest_streak, 0),
      'last_active_date', v_streak.last_active_date,
      'total_active_days', COALESCE(v_streak.total_active_days, 0)
    ),
    'daily_goal', jsonb_build_object(
      'target_xp', COALESCE(v_goal.target_xp, 50),
      'earned_xp', COALESCE(v_goal.earned_xp, 0),
      'completed', COALESCE(v_goal.completed, false)
    ),
    'active_enrollments', v_active_count,
    'total_xp', v_total_xp,
    'level', v_level,
    'next_session', CASE WHEN v_next_session.scheduled_at IS NOT NULL THEN
      jsonb_build_object(
        'scheduled_at', v_next_session.scheduled_at,
        'session_title', v_next_session.session_title,
        'program_title', v_next_session.program_title,
        'location', v_next_session.location,
        'meeting_url', v_next_session.meeting_url,
        'duration_minutes', v_next_session.duration_minutes
      )
    ELSE NULL END
  );

  RETURN v_result;
END;
$$;

-- 2. Catalog: list programs with enriched data
CREATE OR REPLACE FUNCTION public.app_td_student_list_catalog(
  p_field_id uuid DEFAULT NULL,
  p_level text DEFAULT NULL,
  p_modality text DEFAULT NULL,
  p_search text DEFAULT NULL,
  p_sort text DEFAULT 'popular'  -- 'popular','price_asc','price_desc','newest'
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_programs jsonb;
BEGIN
  SELECT jsonb_agg(row_to_json(t)::jsonb ORDER BY
    CASE WHEN p_sort = 'popular' THEN -COALESCE(t.enrollment_count, 0) END,
    CASE WHEN p_sort = 'price_asc' THEN t.price END,
    CASE WHEN p_sort = 'price_desc' THEN -t.price END,
    CASE WHEN p_sort = 'newest' THEN t.created_at END DESC
  )
  INTO v_programs
  FROM (
    SELECT p.id, p.title, p.description, p.level, p.modality::text,
           p.price, p.currency, p.status::text, p.cover_image_url,
           p.enrollment_count, p.avg_rating, p.tags, p.is_featured,
           p.created_at,
           f.name as field_name, f.color_hex as field_color, f.icon_name as field_icon,
           (SELECT count(*) FROM app.td_resources r WHERE r.program_id = p.id) as resource_count
    FROM app.td_programs p
    LEFT JOIN app.td_fields f ON f.id = p.field_id
    WHERE p.status = 'published'
      AND (p_field_id IS NULL OR p.field_id = p_field_id)
      AND (p_level IS NULL OR p.level ILIKE '%' || p_level || '%')
      AND (p_modality IS NULL OR p.modality::text = p_modality)
      AND (p_search IS NULL OR p.title ILIKE '%' || p_search || '%'
           OR p.description ILIKE '%' || p_search || '%')
  ) t;

  RETURN jsonb_build_object('success', true, 'programs', COALESCE(v_programs, '[]'::jsonb));
END;
$$;

-- 3. List fields/disciplines with colors
CREATE OR REPLACE FUNCTION public.app_td_student_list_fields()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_fields jsonb;
BEGIN
  SELECT jsonb_agg(jsonb_build_object(
    'id', f.id, 'name', f.name, 'status', f.status,
    'color_hex', COALESCE(f.color_hex, '#4F46E5'),
    'icon_name', COALESCE(f.icon_name, 'school'),
    'description', f.description,
    'program_count', (SELECT count(*) FROM app.td_programs p WHERE p.field_id = f.id AND p.status = 'published')
  ) ORDER BY f.name)
  INTO v_fields
  FROM app.td_fields f WHERE f.status = 'active';

  RETURN jsonb_build_object('success', true, 'fields', COALESCE(v_fields, '[]'::jsonb));
END;
$$;

-- 4. Student: record XP gain + update streak
CREATE OR REPLACE FUNCTION public.app_td_student_earn_xp(
  p_amount integer,
  p_reason text,
  p_ref_type text DEFAULT NULL,
  p_ref_id uuid DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_today date := CURRENT_DATE;
  v_streak record;
  v_new_streak integer;
  v_new_longest integer;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'amount_must_be_positive');
  END IF;

  -- Log XP
  INSERT INTO app.td_xp_log (student_id, amount, reason, ref_type, ref_id)
  VALUES (v_uid, p_amount, p_reason, p_ref_type, p_ref_id);

  -- Update daily goal
  INSERT INTO app.td_daily_goals (student_id, goal_date, earned_xp)
  VALUES (v_uid, v_today, p_amount)
  ON CONFLICT (student_id, goal_date)
  DO UPDATE SET earned_xp = app.td_daily_goals.earned_xp + p_amount,
                completed = (app.td_daily_goals.earned_xp + p_amount) >= app.td_daily_goals.target_xp;

  -- Update streak
  SELECT current_streak, longest_streak, last_active_date
  INTO v_streak FROM app.td_streaks WHERE student_id = v_uid;

  IF v_streak IS NULL THEN
    INSERT INTO app.td_streaks (student_id, current_streak, longest_streak, last_active_date, total_active_days)
    VALUES (v_uid, 1, 1, v_today, 1);
    v_new_streak := 1;
    v_new_longest := 1;
  ELSE
    IF v_streak.last_active_date = v_today THEN
      -- Already active today, no streak change
      v_new_streak := v_streak.current_streak;
      v_new_longest := v_streak.longest_streak;
    ELSIF v_streak.last_active_date = v_today - 1 THEN
      -- Consecutive day
      v_new_streak := v_streak.current_streak + 1;
      v_new_longest := GREATEST(v_streak.longest_streak, v_new_streak);
      UPDATE app.td_streaks SET
        current_streak = v_new_streak,
        longest_streak = v_new_longest,
        last_active_date = v_today,
        total_active_days = total_active_days + 1,
        updated_at = now()
      WHERE student_id = v_uid;
    ELSE
      -- Streak broken
      v_new_streak := 1;
      v_new_longest := v_streak.longest_streak;
      UPDATE app.td_streaks SET
        current_streak = 1,
        last_active_date = v_today,
        total_active_days = total_active_days + 1,
        updated_at = now()
      WHERE student_id = v_uid;
    END IF;
  END IF;

  -- Update student_progress total_xp
  INSERT INTO app.td_student_progress (student_id, total_xp, current_streak, longest_streak, last_activity_date, level)
  VALUES (v_uid, p_amount, v_new_streak, v_new_longest, v_today, 1)
  ON CONFLICT (student_id) WHERE subject IS NULL
  DO UPDATE SET
    total_xp = app.td_student_progress.total_xp + p_amount,
    current_streak = v_new_streak,
    longest_streak = v_new_longest,
    last_activity_date = v_today,
    level = GREATEST(1, (app.td_student_progress.total_xp + p_amount) / 100 + 1),
    updated_at = now();

  RETURN jsonb_build_object(
    'success', true,
    'xp_earned', p_amount,
    'new_streak', v_new_streak,
    'longest_streak', v_new_longest
  );
END;
$$;

-- 5. Student: list resources for a program/enrollment
CREATE OR REPLACE FUNCTION public.app_td_student_list_resources(
  p_program_id uuid DEFAULT NULL,
  p_enrollment_id uuid DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_pid uuid;
  v_resources jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  -- Resolve program_id from enrollment if needed
  v_pid := p_program_id;
  IF v_pid IS NULL AND p_enrollment_id IS NOT NULL THEN
    SELECT program_id INTO v_pid FROM app.td_enrollments WHERE id = p_enrollment_id AND student_id = v_uid;
  END IF;

  SELECT jsonb_agg(jsonb_build_object(
    'id', r.id, 'title', r.title, 'description', r.description,
    'kind', r.kind::text, 'url', r.url, 'is_required', r.is_required,
    'position', r.position, 'thumbnail_url', r.thumbnail_url,
    'duration_seconds', r.duration_seconds, 'file_size_bytes', r.file_size_bytes,
    'download_count', r.download_count,
    'progress', (SELECT jsonb_build_object(
      'status', COALESCE(rp.status, 'not_started'),
      'progress_pct', COALESCE(rp.progress_pct, 0),
      'time_spent_seconds', COALESCE(rp.time_spent_seconds, 0)
    ) FROM app.td_resource_progress rp WHERE rp.resource_id = r.id AND rp.student_id = v_uid)
  ) ORDER BY r.position, r.created_at)
  INTO v_resources
  FROM app.td_resources r
  WHERE (v_pid IS NULL OR r.program_id = v_pid);

  RETURN jsonb_build_object('success', true, 'resources', COALESCE(v_resources, '[]'::jsonb));
END;
$$;

-- 6. Student: update resource progress
CREATE OR REPLACE FUNCTION public.app_td_student_update_resource_progress(
  p_resource_id uuid,
  p_status text DEFAULT NULL,
  p_progress_pct integer DEFAULT NULL,
  p_last_position text DEFAULT NULL,
  p_time_spent_seconds integer DEFAULT 0
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_xp integer := 0;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  INSERT INTO app.td_resource_progress (student_id, resource_id, status, progress_pct, last_position, time_spent_seconds, started_at)
  VALUES (v_uid, p_resource_id, COALESCE(p_status, 'in_progress'), COALESCE(p_progress_pct, 0), p_last_position, p_time_spent_seconds, now())
  ON CONFLICT (student_id, resource_id)
  DO UPDATE SET
    status = COALESCE(p_status, app.td_resource_progress.status),
    progress_pct = COALESCE(p_progress_pct, app.td_resource_progress.progress_pct),
    last_position = COALESCE(p_last_position, app.td_resource_progress.last_position),
    time_spent_seconds = app.td_resource_progress.time_spent_seconds + p_time_spent_seconds,
    completed_at = CASE WHEN COALESCE(p_status, app.td_resource_progress.status) = 'completed' THEN now() ELSE app.td_resource_progress.completed_at END,
    updated_at = now();

  -- Award XP on completion
  IF p_status = 'completed' THEN
    v_xp := 15;
    PERFORM public.app_td_student_earn_xp(v_xp, 'resource_completed', 'resource', p_resource_id);
  END IF;

  RETURN jsonb_build_object('success', true, 'xp_earned', v_xp);
END;
$$;

-- 7. Student: get leaderboard
CREATE OR REPLACE FUNCTION public.app_td_student_get_leaderboard(
  p_program_id uuid DEFAULT NULL,
  p_limit integer DEFAULT 20
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_week_start date := date_trunc('week', CURRENT_DATE)::date;
  v_entries jsonb;
  v_my_rank integer;
BEGIN
  -- Build live leaderboard from xp_log for current week
  SELECT jsonb_agg(jsonb_build_object(
    'student_id', t.student_id,
    'xp_earned', t.xp_earned,
    'rank', t.rn,
    'is_me', t.student_id = v_uid
  ) ORDER BY t.rn)
  INTO v_entries
  FROM (
    SELECT xl.student_id, sum(xl.amount) as xp_earned,
           row_number() OVER (ORDER BY sum(xl.amount) DESC) as rn
    FROM app.td_xp_log xl
    WHERE xl.created_at >= v_week_start
      AND (p_program_id IS NULL OR xl.ref_id = p_program_id)
    GROUP BY xl.student_id
    ORDER BY xp_earned DESC
    LIMIT p_limit
  ) t;

  -- My rank
  SELECT rn INTO v_my_rank FROM (
    SELECT xl.student_id, row_number() OVER (ORDER BY sum(xl.amount) DESC) as rn
    FROM app.td_xp_log xl
    WHERE xl.created_at >= v_week_start
    GROUP BY xl.student_id
  ) sub WHERE sub.student_id = v_uid;

  RETURN jsonb_build_object(
    'success', true,
    'entries', COALESCE(v_entries, '[]'::jsonb),
    'my_rank', v_my_rank,
    'week_start', v_week_start
  );
END;
$$;

-- 8. Student: get stats & badges
CREATE OR REPLACE FUNCTION public.app_td_student_get_stats()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_progress jsonb;
  v_badges jsonb;
  v_xp_history jsonb;
  v_total_time integer;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  -- Progress summary
  SELECT jsonb_build_object(
    'total_xp', COALESCE(sum(total_xp), 0),
    'level', COALESCE(max(level), 1),
    'current_streak', COALESCE(max(current_streak), 0),
    'longest_streak', COALESCE(max(longest_streak), 0),
    'total_quizzes', COALESCE(sum(total_quizzes_completed), 0),
    'total_questions', COALESCE(sum(total_questions_answered), 0),
    'correct_count', COALESCE(sum(correct_count), 0),
    'total_flashcards', COALESCE(sum(total_flashcards_reviewed), 0)
  ) INTO v_progress
  FROM app.td_student_progress WHERE student_id = v_uid;

  -- Earned badges
  SELECT jsonb_agg(jsonb_build_object(
    'badge_id', b.id, 'code', b.code, 'title', b.title,
    'emoji', b.emoji, 'description', b.description,
    'xp_reward', b.xp_reward, 'earned_at', sb.earned_at
  ) ORDER BY sb.earned_at DESC)
  INTO v_badges
  FROM app.td_student_badges sb
  JOIN app.td_badges b ON b.id = sb.badge_id
  WHERE sb.student_id = v_uid;

  -- XP history (last 30 days, grouped by day)
  SELECT jsonb_agg(jsonb_build_object('date', d, 'xp', xp) ORDER BY d)
  INTO v_xp_history
  FROM (
    SELECT date_trunc('day', created_at)::date as d, sum(amount) as xp
    FROM app.td_xp_log
    WHERE student_id = v_uid AND created_at > now() - interval '30 days'
    GROUP BY d
  ) sub;

  -- Total study time from resource progress
  SELECT COALESCE(sum(time_spent_seconds), 0) INTO v_total_time
  FROM app.td_resource_progress WHERE student_id = v_uid;

  RETURN jsonb_build_object(
    'success', true,
    'progress', COALESCE(v_progress, '{}'::jsonb),
    'badges', COALESCE(v_badges, '[]'::jsonb),
    'xp_history', COALESCE(v_xp_history, '[]'::jsonb),
    'total_study_time_seconds', v_total_time
  );
END;
$$;

-- 9. Student: get my enrollments with progress
CREATE OR REPLACE FUNCTION public.app_td_student_get_my_enrollments()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_enrollments jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT jsonb_agg(jsonb_build_object(
    'id', e.id, 'program_id', e.program_id,
    'access_status', e.access_status::text,
    'progress_pct', COALESCE(e.progress_pct, 0),
    'completed_sessions', COALESCE(e.completed_sessions, 0),
    'total_sessions', COALESCE(e.total_sessions, 0),
    'created_at', e.created_at, 'activated_at', e.activated_at,
    'program_title', p.title, 'program_level', p.level,
    'program_modality', p.modality::text,
    'field_name', f.name, 'field_color', COALESCE(f.color_hex, '#4F46E5'),
    'field_icon', COALESCE(f.icon_name, 'school'),
    'next_session', (
      SELECT jsonb_build_object('scheduled_at', so.scheduled_at, 'title', s.title)
      FROM app.td_session_occurrences so
      JOIN app.td_sessions s ON s.id = so.session_id
      WHERE so.enrollment_id = e.id AND so.status IN ('scheduled','confirmed')
        AND so.scheduled_at > now()
      ORDER BY so.scheduled_at LIMIT 1
    ),
    'resource_count', (SELECT count(*) FROM app.td_resources r WHERE r.program_id = e.program_id),
    'unread_messages', (SELECT count(*) FROM app.td_messages m
      WHERE m.td_enrollment_id = e.id AND m.read_at IS NULL AND m.sender_user_id != v_uid)
  ) ORDER BY e.access_status::text, e.created_at DESC)
  INTO v_enrollments
  FROM app.td_enrollments e
  JOIN app.td_programs p ON p.id = e.program_id
  LEFT JOIN app.td_fields f ON f.id = p.field_id
  WHERE e.student_id = v_uid;

  RETURN jsonb_build_object('success', true, 'enrollments', COALESCE(v_enrollments, '[]'::jsonb));
END;
$$;

-- ─── TEACHER RPCs ────────────────────────────────────────────────

-- 10. Teacher: list students with progress for their enrollments
CREATE OR REPLACE FUNCTION public.app_td_teacher_list_students()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_teacher_id uuid;
  v_students jsonb;
BEGIN
  SELECT id INTO v_teacher_id FROM app.td_teachers WHERE user_id = v_uid;
  IF v_teacher_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_a_teacher');
  END IF;

  SELECT jsonb_agg(jsonb_build_object(
    'enrollment_id', e.id,
    'student_id', e.student_id,
    'program_title', p.title,
    'access_status', e.access_status::text,
    'progress_pct', COALESCE(e.progress_pct, 0),
    'completed_sessions', COALESCE(e.completed_sessions, 0),
    'total_sessions', COALESCE(e.total_sessions, 0),
    'student_xp', COALESCE(sp.total_xp, 0),
    'student_level', COALESCE(sp.level, 1),
    'student_streak', COALESCE(sp.current_streak, 0),
    'unread_messages', (SELECT count(*) FROM app.td_messages m
      WHERE m.td_enrollment_id = e.id AND m.read_at IS NULL AND m.sender_role = 'student')
  ) ORDER BY e.access_status::text, p.title)
  INTO v_students
  FROM app.td_enrollments e
  JOIN app.td_programs p ON p.id = e.program_id
  LEFT JOIN app.td_student_progress sp ON sp.student_id = e.student_id AND sp.subject IS NULL
  WHERE e.assigned_teacher_id = v_teacher_id
    AND e.access_status IN ('active', 'completed');

  RETURN jsonb_build_object('success', true, 'students', COALESCE(v_students, '[]'::jsonb));
END;
$$;

-- 11. Teacher: add a resource to a program
CREATE OR REPLACE FUNCTION public.app_td_teacher_add_resource(
  p_program_id uuid,
  p_title text,
  p_kind text,
  p_url text,
  p_description text DEFAULT NULL,
  p_is_required boolean DEFAULT false,
  p_position integer DEFAULT 0,
  p_thumbnail_url text DEFAULT NULL,
  p_duration_seconds integer DEFAULT NULL,
  p_file_size_bytes bigint DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_id uuid;
BEGIN
  INSERT INTO app.td_resources (program_id, title, description, kind, url, is_required, position,
    thumbnail_url, duration_seconds, file_size_bytes, created_by)
  VALUES (p_program_id, p_title, p_description, p_kind::app.td_resource_kind, p_url, p_is_required, p_position,
    p_thumbnail_url, p_duration_seconds, p_file_size_bytes, v_uid)
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('success', true, 'resource_id', v_id);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- 12. Teacher: list resources for a program
CREATE OR REPLACE FUNCTION public.app_td_teacher_list_resources(p_program_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_resources jsonb;
BEGIN
  SELECT jsonb_agg(jsonb_build_object(
    'id', r.id, 'title', r.title, 'description', r.description,
    'kind', r.kind::text, 'url', r.url, 'is_required', r.is_required,
    'position', r.position, 'thumbnail_url', r.thumbnail_url,
    'duration_seconds', r.duration_seconds, 'download_count', r.download_count,
    'created_at', r.created_at
  ) ORDER BY r.position, r.created_at)
  INTO v_resources
  FROM app.td_resources r WHERE r.program_id = p_program_id;

  RETURN jsonb_build_object('success', true, 'resources', COALESCE(v_resources, '[]'::jsonb));
END;
$$;

-- 13. Teacher: delete a resource
CREATE OR REPLACE FUNCTION public.app_td_teacher_delete_resource(p_resource_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  DELETE FROM app.td_resources WHERE id = p_resource_id;
  RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ─── ADMIN RPCs ──────────────────────────────────────────────────

-- 14. Admin: TD analytics dashboard
CREATE OR REPLACE FUNCTION public.app_td_admin_get_analytics()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_role text;
  v_total_students integer;
  v_active_enrollments integer;
  v_total_programs integer;
  v_total_resources integer;
  v_total_xp_distributed integer;
  v_total_messages integer;
  v_pending_requests integer;
  v_top_programs jsonb;
  v_recent_xp jsonb;
BEGIN
  SELECT app.app_td_get_current_role() INTO v_role;
  IF v_role != 'admin' THEN
    RETURN jsonb_build_object('success', false, 'error', 'admin_only');
  END IF;

  SELECT count(DISTINCT student_id) INTO v_total_students FROM app.td_enrollments;
  SELECT count(*) INTO v_active_enrollments FROM app.td_enrollments WHERE access_status = 'active';
  SELECT count(*) INTO v_total_programs FROM app.td_programs;
  SELECT count(*) INTO v_total_resources FROM app.td_resources;
  SELECT COALESCE(sum(amount), 0) INTO v_total_xp_distributed FROM app.td_xp_log;
  SELECT count(*) INTO v_total_messages FROM app.td_messages;
  SELECT count(*) INTO v_pending_requests FROM app.td_student_requests WHERE status = 'pending';

  -- Top programs by enrollment
  SELECT jsonb_agg(jsonb_build_object(
    'program_id', p.id, 'title', p.title,
    'enrollment_count', COALESCE(p.enrollment_count, 0),
    'field_name', f.name
  ) ORDER BY COALESCE(p.enrollment_count, 0) DESC)
  INTO v_top_programs
  FROM app.td_programs p
  LEFT JOIN app.td_fields f ON f.id = p.field_id
  LIMIT 10;

  -- Recent XP activity (last 7 days by day)
  SELECT jsonb_agg(jsonb_build_object('date', d, 'total_xp', xp, 'unique_students', students) ORDER BY d)
  INTO v_recent_xp
  FROM (
    SELECT date_trunc('day', created_at)::date as d, sum(amount) as xp, count(DISTINCT student_id) as students
    FROM app.td_xp_log WHERE created_at > now() - interval '7 days'
    GROUP BY d
  ) sub;

  RETURN jsonb_build_object(
    'success', true,
    'total_students', v_total_students,
    'active_enrollments', v_active_enrollments,
    'total_programs', v_total_programs,
    'total_resources', v_total_resources,
    'total_xp_distributed', v_total_xp_distributed,
    'total_messages', v_total_messages,
    'pending_requests', v_pending_requests,
    'top_programs', COALESCE(v_top_programs, '[]'::jsonb),
    'recent_xp', COALESCE(v_recent_xp, '[]'::jsonb)
  );
END;
$$;

-- 15. Admin: manage badges (upsert)
CREATE OR REPLACE FUNCTION public.app_td_admin_upsert_badge(
  p_code text,
  p_title text,
  p_description text DEFAULT NULL,
  p_emoji text DEFAULT NULL,
  p_xp_reward integer DEFAULT 0,
  p_condition_type text DEFAULT NULL,
  p_condition_value integer DEFAULT 0,
  p_is_active boolean DEFAULT true
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_role text;
  v_id uuid;
BEGIN
  SELECT app.app_td_get_current_role() INTO v_role;
  IF v_role != 'admin' THEN
    RETURN jsonb_build_object('success', false, 'error', 'admin_only');
  END IF;

  INSERT INTO app.td_badges (code, title, description, emoji, xp_reward, condition_type, condition_value, is_active)
  VALUES (p_code, p_title, p_description, p_emoji, p_xp_reward, p_condition_type, p_condition_value, p_is_active)
  ON CONFLICT (code) DO UPDATE SET
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    emoji = EXCLUDED.emoji,
    xp_reward = EXCLUDED.xp_reward,
    condition_type = EXCLUDED.condition_type,
    condition_value = EXCLUDED.condition_value,
    is_active = EXCLUDED.is_active
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('success', true, 'badge_id', v_id);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- 16. Admin: manage discipline colors
CREATE OR REPLACE FUNCTION public.app_td_admin_upsert_discipline_color(
  p_field_name text,
  p_color_hex text,
  p_gradient_start text,
  p_gradient_end text,
  p_icon_name text DEFAULT 'school',
  p_field_id uuid DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_role text;
  v_id uuid;
BEGIN
  SELECT app.app_td_get_current_role() INTO v_role;
  IF v_role != 'admin' THEN
    RETURN jsonb_build_object('success', false, 'error', 'admin_only');
  END IF;

  INSERT INTO app.td_discipline_colors (field_id, field_name, color_hex, gradient_start, gradient_end, icon_name)
  VALUES (p_field_id, p_field_name, p_color_hex, p_gradient_start, p_gradient_end, p_icon_name)
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('success', true, 'id', v_id);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- 17. Admin: grant XP to a student manually
CREATE OR REPLACE FUNCTION public.app_td_admin_grant_xp(
  p_student_id uuid,
  p_amount integer,
  p_reason text DEFAULT 'admin_grant'
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_role text;
BEGIN
  SELECT app.app_td_get_current_role() INTO v_role;
  IF v_role != 'admin' THEN
    RETURN jsonb_build_object('success', false, 'error', 'admin_only');
  END IF;

  -- Use service_role context to insert XP for the student
  INSERT INTO app.td_xp_log (student_id, amount, reason, ref_type)
  VALUES (p_student_id, p_amount, p_reason, 'admin');

  -- Update student_progress
  INSERT INTO app.td_student_progress (student_id, total_xp, last_activity_date, level)
  VALUES (p_student_id, p_amount, CURRENT_DATE, 1)
  ON CONFLICT (student_id) WHERE subject IS NULL
  DO UPDATE SET
    total_xp = app.td_student_progress.total_xp + p_amount,
    last_activity_date = CURRENT_DATE,
    level = GREATEST(1, (app.td_student_progress.total_xp + p_amount) / 100 + 1),
    updated_at = now();

  RETURN jsonb_build_object('success', true, 'xp_granted', p_amount);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- 18. Admin: list all badges
CREATE OR REPLACE FUNCTION public.app_td_admin_list_badges()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_badges jsonb;
BEGIN
  SELECT jsonb_agg(jsonb_build_object(
    'id', b.id, 'code', b.code, 'title', b.title,
    'description', b.description, 'emoji', b.emoji,
    'xp_reward', b.xp_reward, 'condition_type', b.condition_type,
    'condition_value', b.condition_value, 'is_active', b.is_active,
    'earned_count', (SELECT count(*) FROM app.td_student_badges sb WHERE sb.badge_id = b.id)
  ) ORDER BY b.code)
  INTO v_badges
  FROM app.td_badges b;

  RETURN jsonb_build_object('success', true, 'badges', COALESCE(v_badges, '[]'::jsonb));
END;
$$;

-- ─── GRANTS for new RPCs ────────────────────────────────────────
GRANT EXECUTE ON FUNCTION public.app_td_student_get_home() TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_td_student_list_catalog(uuid, text, text, text, text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.app_td_student_list_fields() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.app_td_student_earn_xp(integer, text, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_td_student_list_resources(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_td_student_update_resource_progress(uuid, text, integer, text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_td_student_get_leaderboard(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_td_student_get_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_td_student_get_my_enrollments() TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_td_teacher_list_students() TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_td_teacher_add_resource(uuid, text, text, text, text, boolean, integer, text, integer, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_td_teacher_list_resources(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_td_teacher_delete_resource(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_td_admin_get_analytics() TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_td_admin_upsert_badge(text, text, text, text, integer, text, integer, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_td_admin_upsert_discipline_color(text, text, text, text, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_td_admin_grant_xp(uuid, integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_td_admin_list_badges() TO authenticated;
