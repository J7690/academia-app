


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "app";


ALTER SCHEMA "app" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_admin_bobodo_cache_stats"() RETURNS TABLE("total_entries" bigint, "total_hits" bigint, "active_entries" bigint, "expired_entries" bigint, "top_questions" "jsonb")
    LANGUAGE "sql" SECURITY DEFINER
    AS $$
  SELECT
    COUNT(*)                                                   AS total_entries,
    COALESCE(SUM(hit_count), 0)                               AS total_hits,
    COUNT(*) FILTER (WHERE expires_at > now())                AS active_entries,
    COUNT(*) FILTER (WHERE expires_at <= now())               AS expired_entries,
    (
      SELECT jsonb_agg(row_to_json(top))
      FROM (
        SELECT question_text, hit_count, category
        FROM app.bobodo_answer_cache
        ORDER BY hit_count DESC
        LIMIT 10
      ) AS top
    )                                                          AS top_questions
  FROM app.bobodo_answer_cache;
$$;


ALTER FUNCTION "app"."app_admin_bobodo_cache_stats"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_admin_tv_delete_overlay"("p_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app', 'public'
    AS $$
begin
  if not exists (
    select 1 from app.hero_overlays_tv ho
    where ho.id = p_id
  ) then
    return jsonb_build_object(
      'success', false,
      'error', 'OVERLAY_NOT_FOUND'
    );
  end if;

  delete from app.hero_overlays_tv
  where id = p_id;

  return jsonb_build_object(
    'success', true
  );
end;
$$;


ALTER FUNCTION "app"."app_admin_tv_delete_overlay"("p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_admin_tv_get_timeline"("p_playlist_item_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app', 'public'
    AS $$
declare
  v_overlays jsonb;
begin
  -- s+®curit+® minimale : v+®rifier que lÔÇÖ+®l+®ment existe
  if not exists (
    select 1 from app.hero_playlist hp
    where hp.id = p_playlist_item_id
  ) then
    return jsonb_build_object(
      'success', false,
      'error', 'PLAYLIST_ITEM_NOT_FOUND'
    );
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', ho.id,
        'overlay_type', ho.overlay_type,
        'config', ho.config,
        'start_at_seconds', ho.start_at_seconds,
        'end_at_seconds', ho.end_at_seconds,
        'sort_order', ho.sort_order,
        'created_at', ho.created_at,
        'updated_at', ho.updated_at
      )
      order by ho.start_at_seconds, ho.sort_order, ho.created_at
    ),
    '[]'::jsonb
  )
  into v_overlays
  from app.hero_overlays_tv ho
  where ho.playlist_item_id = p_playlist_item_id;

  return jsonb_build_object(
    'success', true,
    'overlays', v_overlays
  );
end;
$$;


ALTER FUNCTION "app"."app_admin_tv_get_timeline"("p_playlist_item_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_admin_tv_request_render"("p_playlist_item_id" "uuid", "p_meta" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app', 'public'
    AS $$
declare
  v_id uuid;
begin
  if not exists (
    select 1 from app.hero_playlist hp
    where hp.id = p_playlist_item_id
  ) then
    return jsonb_build_object(
      'success', false,
      'error', 'PLAYLIST_ITEM_NOT_FOUND'
    );
  end if;

  insert into app.hero_renders_tv (
    playlist_item_id,
    status,
    meta
  )
  values (
    p_playlist_item_id,
    'pending',
    coalesce(p_meta, '{}'::jsonb)
  )
  returning id into v_id;

  return jsonb_build_object(
    'success', true,
    'render_id', v_id
  );
end;
$$;


ALTER FUNCTION "app"."app_admin_tv_request_render"("p_playlist_item_id" "uuid", "p_meta" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_admin_tv_upsert_overlay"("p_id" "uuid", "p_playlist_item_id" "uuid", "p_overlay_type" "text", "p_config" "jsonb", "p_start_at_seconds" numeric, "p_end_at_seconds" numeric, "p_sort_order" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app', 'public'
    AS $$
declare
  v_id uuid;
begin
  if p_overlay_type not in ('text', 'image', 'banner', 'ticker', 'shape') then
    return jsonb_build_object(
      'success', false,
      'error', 'INVALID_OVERLAY_TYPE'
    );
  end if;

  if p_end_at_seconds < p_start_at_seconds then
    return jsonb_build_object(
      'success', false,
      'error', 'INVALID_TIMELINE_RANGE'
    );
  end if;

  if not exists (
    select 1 from app.hero_playlist hp
    where hp.id = p_playlist_item_id
  ) then
    return jsonb_build_object(
      'success', false,
      'error', 'PLAYLIST_ITEM_NOT_FOUND'
    );
  end if;

  if p_id is null then
    insert into app.hero_overlays_tv (
      playlist_item_id,
      overlay_type,
      config,
      start_at_seconds,
      end_at_seconds,
      sort_order
    )
    values (
      p_playlist_item_id,
      p_overlay_type,
      coalesce(p_config, '{}'::jsonb),
      p_start_at_seconds,
      p_end_at_seconds,
      coalesce(p_sort_order, 0)
    )
    returning id into v_id;
  else
    update app.hero_overlays_tv
    set
      overlay_type     = p_overlay_type,
      config           = coalesce(p_config, '{}'::jsonb),
      start_at_seconds = p_start_at_seconds,
      end_at_seconds   = p_end_at_seconds,
      sort_order       = coalesce(p_sort_order, 0)
    where id = p_id
    returning id into v_id;

    if v_id is null then
      return jsonb_build_object(
        'success', false,
        'error', 'OVERLAY_NOT_FOUND'
      );
    end if;
  end if;

  return jsonb_build_object(
    'success', true,
    'id', v_id
  );
end;
$$;


ALTER FUNCTION "app"."app_admin_tv_upsert_overlay"("p_id" "uuid", "p_playlist_item_id" "uuid", "p_overlay_type" "text", "p_config" "jsonb", "p_start_at_seconds" numeric, "p_end_at_seconds" numeric, "p_sort_order" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_bobodo_cache_hit"("p_cache_id" "uuid") RETURNS "void"
    LANGUAGE "sql" SECURITY DEFINER
    AS $$
  UPDATE app.bobodo_answer_cache
  SET hit_count   = hit_count + 1,
      last_hit_at = now(),
      expires_at  = GREATEST(expires_at, now() + interval '30 days')
  WHERE id = p_cache_id;
$$;


ALTER FUNCTION "app"."app_bobodo_cache_hit"("p_cache_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_get_or_create_bobodo_session"("p_title" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_student_id UUID;
    v_existing_session_id UUID;
    v_new_session_id UUID;
BEGIN
    -- R+®cup+®rer l'+®tudiant connect+® via RLS
    v_student_id := auth.uid();

    IF v_student_id IS NULL THEN
        RAISE EXCEPTION 'Utilisateur non authentifi+®';
    END IF;

    -- Chercher une session existante pour cet +®tudiant cr+®+®e r+®cemment (par ex. < 7 jours)
    SELECT s.id INTO v_existing_session_id
    FROM app.bobodo_sessions s
    WHERE s.student_id = v_student_id
      AND s.created_at >= NOW() - INTERVAL '7 days'
    ORDER BY s.created_at DESC
    LIMIT 1;

    IF v_existing_session_id IS NOT NULL THEN
        RETURN v_existing_session_id;
    END IF;

    -- Sinon, cr+®er une nouvelle session
    INSERT INTO app.bobodo_sessions (student_id, title)
    VALUES (v_student_id, COALESCE(p_title, 'Conversation Bobodo'))
    RETURNING id INTO v_new_session_id;

    RETURN v_new_session_id;
END;
$$;


ALTER FUNCTION "app"."app_get_or_create_bobodo_session"("p_title" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_get_or_create_bobodo_session_admin"("p_student_id" "uuid", "p_title" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_existing_session_id UUID;
    v_new_session_id UUID;
BEGIN
    -- Chercher une session existante pour cet +®tudiant cr+®+®e r+®cemment (par ex. < 7 jours)
    SELECT s.id INTO v_existing_session_id
    FROM app.bobodo_sessions s
    WHERE s.student_id = p_student_id
      AND s.created_at >= NOW() - INTERVAL '7 days'
    ORDER BY s.created_at DESC
    LIMIT 1;

    IF v_existing_session_id IS NOT NULL THEN
        RETURN v_existing_session_id;
    END IF;

    -- Sinon, cr+®er une nouvelle session
    INSERT INTO app.bobodo_sessions (student_id, title)
    VALUES (p_student_id, COALESCE(p_title, 'Conversation Bobodo'))
    RETURNING id INTO v_new_session_id;

    RETURN v_new_session_id;
END;
$$;


ALTER FUNCTION "app"."app_get_or_create_bobodo_session_admin"("p_student_id" "uuid", "p_title" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_insert_bobodo_answer_cache"("p_question_text" "text", "p_question_embedding" "extensions"."vector", "p_answer_text" "text", "p_category" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "sql" SECURITY DEFINER
    AS $$
  INSERT INTO app.bobodo_answer_cache
    (question_text, question_embedding, answer_text, category)
  VALUES
    (p_question_text, p_question_embedding, p_answer_text, p_category)
  ON CONFLICT DO NOTHING;
$$;


ALTER FUNCTION "app"."app_insert_bobodo_answer_cache"("p_question_text" "text", "p_question_embedding" "extensions"."vector", "p_answer_text" "text", "p_category" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_notify_td_group_member_joined"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE v_group RECORD; v_member RECORD; v_name TEXT;
BEGIN
  SELECT * INTO v_group FROM app.td_local_groups WHERE id = NEW.group_id;
  SELECT full_name INTO v_name FROM app.students WHERE id = NEW.student_id;
  FOR v_member IN SELECT student_id FROM app.td_local_group_members WHERE group_id = NEW.group_id AND student_id != NEW.student_id LOOP
    INSERT INTO app.notification_events (user_id, domain, event_type, payload)
    VALUES (v_member.student_id, 'td_local_groups', 'member_joined',
      jsonb_build_object('group_id', NEW.group_id, 'subject', v_group.subject, 'member_name', v_name));
  END LOOP;
  RETURN NEW;
END; $$;


ALTER FUNCTION "app"."app_notify_td_group_member_joined"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_notify_td_group_status_change"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE v_member RECORD;
BEGIN
  IF NEW.status != OLD.status AND NEW.status IN ('confirmed', 'active') THEN
    FOR v_member IN SELECT student_id FROM app.td_local_group_members WHERE group_id = NEW.id LOOP
      INSERT INTO app.notification_events (user_id, domain, event_type, payload)
      VALUES (v_member.student_id, 'td_local_groups', 'group_' || NEW.status,
        jsonb_build_object('group_id', NEW.id, 'subject', NEW.subject, 'neighborhood', NEW.neighborhood, 'status', NEW.status));
    END LOOP;
  END IF;
  RETURN NEW;
END; $$;


ALTER FUNCTION "app"."app_notify_td_group_status_change"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_notify_td_group_teacher_assigned"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  IF NEW.assigned_teacher_id IS NOT NULL AND (OLD.assigned_teacher_id IS NULL OR OLD.assigned_teacher_id != NEW.assigned_teacher_id) THEN
    INSERT INTO app.notification_events (user_id, domain, event_type, payload)
    VALUES (NEW.assigned_teacher_id, 'td_local_groups', 'teacher_assigned',
      jsonb_build_object('group_id', NEW.id, 'subject', NEW.subject, 'neighborhood', NEW.neighborhood, 'members', NEW.current_members));
  END IF;
  RETURN NEW;
END; $$;


ALTER FUNCTION "app"."app_notify_td_group_teacher_assigned"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_admin_get_stats"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ DECLARE v_result JSONB; BEGIN SELECT jsonb_build_object( 'total_questions', (SELECT COUNT(*) FROM app.prep_questions), 'total_banks', (SELECT COUNT(*) FROM app.prep_question_banks), 'total_quiz_attempts', (SELECT COUNT(*) FROM app.prep_quiz_attempts), 'total_students_active', (SELECT COUNT(DISTINCT student_id) FROM app.prep_quiz_attempts), 'total_exam_papers', (SELECT COUNT(*) FROM app.prep_exam_papers), 'total_flashcard_decks', (SELECT COUNT(*) FROM app.prep_flashcard_decks), 'total_ai_conversations', (SELECT COUNT(*) FROM app.prep_ai_conversations), 'total_ai_messages', (SELECT COUNT(*) FROM app.prep_ai_messages), 'badges_config', (SELECT COALESCE(jsonb_agg(row_to_json(b)::jsonb), '[]'::jsonb) FROM app.prep_badges b WHERE b.is_active), 'avg_score', (SELECT ROUND(AVG(score)) FROM app.prep_quiz_attempts WHERE status = 'completed') ) INTO v_result; RETURN v_result; END; $$;


ALTER FUNCTION "app"."app_prep_admin_get_stats"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_admin_list_ai_conversations"("p_limit" integer DEFAULT 50) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ DECLARE v_result JSONB; BEGIN SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.updated_at DESC), '[]'::jsonb) INTO v_result FROM ( SELECT c.*, s.full_name AS student_name FROM app.prep_ai_conversations c LEFT JOIN app.students s ON s.id = c.student_id LIMIT p_limit ) t; RETURN v_result; END; $$;


ALTER FUNCTION "app"."app_prep_admin_list_ai_conversations"("p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_admin_list_questions"("p_bank_id" "uuid" DEFAULT NULL::"uuid", "p_subject" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ DECLARE v_result JSONB; BEGIN SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb) INTO v_result FROM ( SELECT q.id, q.content, q.question, q.options, q.correct_index, q.explanation, q.difficulty, q.subject, q.is_active, q.is_published, q.created_at, b.title AS bank_title FROM app.prep_questions q LEFT JOIN app.prep_question_banks b ON b.id = q.bank_id WHERE (p_bank_id IS NULL OR q.bank_id = p_bank_id) AND (p_subject IS NULL OR q.subject = p_subject) ORDER BY q.created_at DESC LIMIT p_limit OFFSET p_offset ) t; RETURN v_result; END; $$;


ALTER FUNCTION "app"."app_prep_admin_list_questions"("p_bank_id" "uuid", "p_subject" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_admin_toggle_question"("p_question_id" "uuid", "p_is_active" boolean) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ BEGIN UPDATE app.prep_questions SET is_active = p_is_active, is_published = p_is_active, updated_at = now() WHERE id = p_question_id; RETURN jsonb_build_object('success', true); END; $$;


ALTER FUNCTION "app"."app_prep_admin_toggle_question"("p_question_id" "uuid", "p_is_active" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_admin_update_live_session_status"("p_session_id" "uuid", "p_status" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ BEGIN UPDATE app.prep_live_sessions SET status=p_status WHERE id=p_session_id; RETURN jsonb_build_object('success',true); END; $$;


ALTER FUNCTION "app"."app_prep_admin_update_live_session_status"("p_session_id" "uuid", "p_status" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_admin_upsert_badge"("p_code" "text", "p_title" "text", "p_description" "text" DEFAULT NULL::"text", "p_emoji" "text" DEFAULT '­ƒÅà'::"text", "p_xp_reward" integer DEFAULT 0, "p_condition_type" "text" DEFAULT NULL::"text", "p_condition_value" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ DECLARE v_id UUID; BEGIN INSERT INTO app.prep_badges (code, title, description, emoji, xp_reward, condition_type, condition_value) VALUES (p_code, p_title, p_description, p_emoji, p_xp_reward, p_condition_type, p_condition_value) ON CONFLICT (code) DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description, emoji = EXCLUDED.emoji, xp_reward = EXCLUDED.xp_reward, condition_type = EXCLUDED.condition_type, condition_value = EXCLUDED.condition_value RETURNING id INTO v_id; RETURN jsonb_build_object('success', true, 'id', v_id); END; $$;


ALTER FUNCTION "app"."app_prep_admin_upsert_badge"("p_code" "text", "p_title" "text", "p_description" "text", "p_emoji" "text", "p_xp_reward" integer, "p_condition_type" "text", "p_condition_value" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_create_ai_conversation"("p_title" "text" DEFAULT NULL::"text", "p_subject" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ DECLARE v_id UUID; BEGIN INSERT INTO app.prep_ai_conversations (student_id, title, subject) VALUES (auth.uid(), COALESCE(p_title, 'Tuteur IA'), p_subject) RETURNING id INTO v_id; RETURN jsonb_build_object('success', true, 'conversation_id', v_id); END; $$;


ALTER FUNCTION "app"."app_prep_create_ai_conversation"("p_title" "text", "p_subject" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_create_exam_paper"("p_title" "text", "p_concours_type" "text", "p_year" "text" DEFAULT NULL::"text", "p_subject" "text" DEFAULT NULL::"text", "p_paper_url" "text" DEFAULT NULL::"text", "p_correction_url" "text" DEFAULT NULL::"text", "p_difficulty" integer DEFAULT 1, "p_is_official" boolean DEFAULT false, "p_has_correction" boolean DEFAULT false) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ DECLARE v_id UUID; BEGIN INSERT INTO app.prep_exam_papers ( title, concours_type, year, subject, paper_url, correction_url, difficulty, is_official, has_correction, uploaded_by ) VALUES ( p_title, p_concours_type, p_year, p_subject, p_paper_url, p_correction_url, p_difficulty, p_is_official, p_has_correction, auth.uid() ) RETURNING id INTO v_id; RETURN jsonb_build_object('success', true, 'id', v_id); END; $$;


ALTER FUNCTION "app"."app_prep_create_exam_paper"("p_title" "text", "p_concours_type" "text", "p_year" "text", "p_subject" "text", "p_paper_url" "text", "p_correction_url" "text", "p_difficulty" integer, "p_is_official" boolean, "p_has_correction" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_create_flashcard"("p_deck_id" "uuid", "p_front_text" "text", "p_back_text" "text", "p_subject" "text" DEFAULT NULL::"text", "p_tags" "text"[] DEFAULT '{}'::"text"[]) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ DECLARE v_id UUID; BEGIN INSERT INTO app.prep_flashcards (deck_id, front_text, back_text, subject, tags, created_by) VALUES (p_deck_id, p_front_text, p_back_text, p_subject, p_tags, auth.uid()) RETURNING id INTO v_id; UPDATE app.prep_flashcard_decks SET card_count = ( SELECT COUNT(*) FROM app.prep_flashcards WHERE deck_id = p_deck_id AND is_active ) WHERE id = p_deck_id; RETURN jsonb_build_object('success', true, 'id', v_id); END; $$;


ALTER FUNCTION "app"."app_prep_create_flashcard"("p_deck_id" "uuid", "p_front_text" "text", "p_back_text" "text", "p_subject" "text", "p_tags" "text"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_create_flashcard_deck"("p_title" "text", "p_description" "text" DEFAULT NULL::"text", "p_subject" "text" DEFAULT NULL::"text", "p_concours_type" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ DECLARE v_id UUID; BEGIN INSERT INTO app.prep_flashcard_decks (title, description, subject, concours_type, created_by) VALUES (p_title, p_description, p_subject, p_concours_type, auth.uid()) RETURNING id INTO v_id; RETURN jsonb_build_object('success', true, 'id', v_id); END; $$;


ALTER FUNCTION "app"."app_prep_create_flashcard_deck"("p_title" "text", "p_description" "text", "p_subject" "text", "p_concours_type" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_create_question"("p_bank_id" "uuid", "p_content" "text", "p_options" "jsonb", "p_correct_index" integer, "p_explanation" "text" DEFAULT NULL::"text", "p_difficulty" integer DEFAULT 1, "p_subject" "text" DEFAULT NULL::"text", "p_image_url" "text" DEFAULT NULL::"text", "p_points" integer DEFAULT 10, "p_time_limit_seconds" integer DEFAULT 60) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ DECLARE v_id UUID; v_i INTEGER; v_text TEXT; v_label TEXT; BEGIN INSERT INTO app.prep_questions ( bank_id, question, content, options, correct_index, explanation, difficulty, subject, image_url, points, time_limit_seconds, question_type, level, source, is_published, is_active, created_by ) VALUES ( p_bank_id, p_content, p_content, p_options, p_correct_index, p_explanation, p_difficulty, p_subject, p_image_url, p_points, p_time_limit_seconds, 'mcq', 'beginner', 'manual', true, true, auth.uid() ) RETURNING id INTO v_id; IF p_options IS NOT NULL AND jsonb_typeof(p_options) = 'array' THEN FOR v_i IN 0 .. jsonb_array_length(p_options) - 1 LOOP v_text := p_options ->> v_i; v_label := chr(65 + v_i); INSERT INTO app.prep_question_choices (question_id, choice_label, choice_text, is_correct, sort_order) VALUES (v_id, v_label, v_text, v_i = p_correct_index, v_i); END LOOP; END IF; RETURN jsonb_build_object('success', true, 'id', v_id); END; $$;


ALTER FUNCTION "app"."app_prep_create_question"("p_bank_id" "uuid", "p_content" "text", "p_options" "jsonb", "p_correct_index" integer, "p_explanation" "text", "p_difficulty" integer, "p_subject" "text", "p_image_url" "text", "p_points" integer, "p_time_limit_seconds" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_create_question"("p_bank_id" "uuid", "p_content" "text", "p_options" "jsonb", "p_correct_index" integer, "p_explanation" "text" DEFAULT NULL::"text", "p_difficulty" integer DEFAULT 1, "p_subject" "text" DEFAULT NULL::"text", "p_tags" "text"[] DEFAULT '{}'::"text"[], "p_question_type" "text" DEFAULT 'qcm'::"text", "p_points" integer DEFAULT 10, "p_time_limit_seconds" integer DEFAULT 60, "p_image_url" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_question_id UUID;
BEGIN
  INSERT INTO app.td_questions (
    bank_id, question_type, content, options, correct_index,
    explanation, difficulty, subject, tags, points,
    time_limit_seconds, image_url, created_by
  ) VALUES (
    p_bank_id, p_question_type, p_content, p_options, p_correct_index,
    p_explanation, p_difficulty, p_subject, p_tags, p_points,
    p_time_limit_seconds, p_image_url, auth.uid()
  )
  RETURNING id INTO v_question_id;

  RETURN jsonb_build_object('success', true, 'question_id', v_question_id);
END;
$$;


ALTER FUNCTION "app"."app_prep_create_question"("p_bank_id" "uuid", "p_content" "text", "p_options" "jsonb", "p_correct_index" integer, "p_explanation" "text", "p_difficulty" integer, "p_subject" "text", "p_tags" "text"[], "p_question_type" "text", "p_points" integer, "p_time_limit_seconds" integer, "p_image_url" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_create_question_bank"("p_title" "text", "p_description" "text" DEFAULT NULL::"text", "p_concours_type" "text" DEFAULT NULL::"text", "p_subject" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ DECLARE v_id UUID; BEGIN INSERT INTO app.prep_question_banks (title, description, concours_type, subject, created_by) VALUES (p_title, p_description, p_concours_type, p_subject, auth.uid()) RETURNING id INTO v_id; RETURN jsonb_build_object('success', true, 'id', v_id); END; $$;


ALTER FUNCTION "app"."app_prep_create_question_bank"("p_title" "text", "p_description" "text", "p_concours_type" "text", "p_subject" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_create_quiz_template"("p_title" "text", "p_bank_id" "uuid" DEFAULT NULL::"uuid", "p_concours_type" "text" DEFAULT NULL::"text", "p_subject" "text" DEFAULT NULL::"text", "p_question_count" integer DEFAULT 10, "p_time_limit_minutes" integer DEFAULT NULL::integer, "p_shuffle" boolean DEFAULT true, "p_is_exam_mode" boolean DEFAULT false, "p_passing_score" integer DEFAULT 60, "p_description" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ DECLARE v_id UUID; BEGIN INSERT INTO app.prep_quiz_templates ( title, description, bank_id, concours_type, subject, question_count, time_limit_minutes, shuffle_questions, is_exam_mode, passing_score, created_by ) VALUES ( p_title, p_description, p_bank_id, p_concours_type, p_subject, p_question_count, p_time_limit_minutes, p_shuffle, p_is_exam_mode, p_passing_score, auth.uid() ) RETURNING id INTO v_id; RETURN jsonb_build_object('success', true, 'id', v_id); END; $$;


ALTER FUNCTION "app"."app_prep_create_quiz_template"("p_title" "text", "p_bank_id" "uuid", "p_concours_type" "text", "p_subject" "text", "p_question_count" integer, "p_time_limit_minutes" integer, "p_shuffle" boolean, "p_is_exam_mode" boolean, "p_passing_score" integer, "p_description" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_get_adaptive_quiz"("p_count" integer DEFAULT 10, "p_concours_type" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app', 'public'
    AS $$
DECLARE
    v_student_id uuid;
    v_questions jsonb := '[]'::jsonb;
BEGIN
    v_student_id := auth.uid();
    IF v_student_id IS NULL THEN
        RAISE EXCEPTION 'Non authentifi+®';
    END IF;
    
    -- Version simplifi+®e pour le test initial
    WITH quiz_questions AS (
        SELECT 
            q.id, q.question, 
            jsonb_build_array(q.choice_a, q.choice_b, q.choice_c, q.choice_d) AS options,
            q.correct_answer - 1 AS correct_index,
            q.explanation, q.difficulty, 
            s.title AS subject, q.subject_id
        FROM app.prep_questions q
        JOIN app.prep_subjects s ON s.id = q.subject_id
        WHERE q.is_published = true
          AND (p_concours_type IS NULL OR q.concours_type = p_concours_type)
        ORDER BY RANDOM()
        LIMIT p_count
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', id,
            'question', question,
            'options', options,
            'correct_index', correct_index,
            'explanation', explanation,
            'difficulty', difficulty,
            'subject', subject,
            'subject_id', subject_id
        )
    ) INTO v_questions FROM quiz_questions;
    
    RETURN jsonb_build_object(
        'adaptive_mode', false,
        'weakness_ratio', 0,
        'total_questions', jsonb_array_length(COALESCE(v_questions, '[]'::jsonb)),
        'questions', COALESCE(v_questions, '[]'::jsonb)
    );
END;
$$;


ALTER FUNCTION "app"."app_prep_get_adaptive_quiz"("p_count" integer, "p_concours_type" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_get_ai_config"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ DECLARE v_result JSONB := '{}'::jsonb; r RECORD; BEGIN FOR r IN SELECT config_key, config_value FROM app.prep_ai_config LOOP v_result := v_result || jsonb_build_object(r.config_key, r.config_value); END LOOP; RETURN v_result; END; $$;


ALTER FUNCTION "app"."app_prep_get_ai_config"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_get_leaderboard"("p_limit" integer DEFAULT 20) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ DECLARE v_result JSONB; BEGIN SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb) INTO v_result FROM ( SELECT p.student_id, s.full_name AS student_name, p.total_xp, p.current_streak, p.total_correct, p.total_answered, ROW_NUMBER() OVER (ORDER BY p.total_xp DESC) AS rank FROM app.prep_student_progress p LEFT JOIN app.students s ON s.id = p.student_id ORDER BY p.total_xp DESC LIMIT p_limit ) t; RETURN v_result; END; $$;


ALTER FUNCTION "app"."app_prep_get_leaderboard"("p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_get_student_progress"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ DECLARE v_result JSONB; BEGIN SELECT row_to_json(t)::jsonb INTO v_result FROM ( SELECT COALESCE(p.total_xp, 0) AS total_xp, COALESCE(p.current_streak, 0) AS current_streak, COALESCE(p.longest_streak, 0) AS longest_streak, COALESCE(p.total_correct, 0) AS total_correct, COALESCE(p.total_answered, 0) AS total_answered, p.last_activity_date, (SELECT COUNT(*) FROM app.prep_quiz_attempts qa WHERE qa.student_id = auth.uid()) AS quiz_count, (SELECT COUNT(*) FROM app.prep_student_badges sb WHERE sb.student_id = auth.uid()) AS badge_count FROM app.prep_student_progress p WHERE p.student_id = auth.uid() ) t; IF v_result IS NULL THEN v_result := jsonb_build_object( 'total_xp', 0, 'current_streak', 0, 'longest_streak', 0, 'total_correct', 0, 'total_answered', 0, 'last_activity_date', NULL, 'quiz_count', 0, 'badge_count', 0 ); END IF; RETURN v_result; END; $$;


ALTER FUNCTION "app"."app_prep_get_student_progress"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_get_subject_stats"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ DECLARE v_result JSONB; BEGIN SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb) INTO v_result FROM ( SELECT q.subject, COUNT(a.id) AS total, SUM(CASE WHEN a.is_correct THEN 1 ELSE 0 END) AS correct, CASE WHEN COUNT(a.id) > 0 THEN ROUND((SUM(CASE WHEN a.is_correct THEN 1 ELSE 0 END)::numeric / COUNT(a.id)) * 100, 1) ELSE 0 END AS accuracy, ROUND(AVG(a.time_spent_sec), 1) AS avg_time_sec FROM app.prep_attempts a JOIN app.prep_questions q ON q.id = a.question_id WHERE a.student_id = auth.uid() GROUP BY q.subject ORDER BY total DESC ) t; RETURN v_result; END; $$;


ALTER FUNCTION "app"."app_prep_get_subject_stats"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_get_weakness_analysis"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app', 'public'
    AS $$
DECLARE
    v_student_id uuid;
BEGIN
    v_student_id := auth.uid();
    IF v_student_id IS NULL THEN
        RAISE EXCEPTION 'Non authentifi+®';
    END IF;
    
    RETURN jsonb_build_object(
        'weakest_subjects', COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object(
                    'subject_id', w.subject_id,
                    'subject_name', s.title,
                    'success_rate', ROUND(w.success_rate, 1),
                    'total_questions', w.total_questions,
                    'needs_practice', w.needs_practice,
                    'recommended_difficulty', w.recommended_difficulty
                ) ORDER BY w.weakness_score DESC
            )
            FROM app.prep_student_weaknesses w
            JOIN app.prep_subjects s ON s.id = w.subject_id
            WHERE w.student_id = v_student_id
              AND w.needs_practice = true
            LIMIT 5
        ), '[]'::jsonb),
        'progress_summary', (
            SELECT jsonb_build_object(
                'total_subjects_practiced', COUNT(DISTINCT subject_id),
                'subjects_needing_practice', COUNT(*) FILTER (WHERE needs_practice),
                'overall_success_rate', ROUND(AVG(success_rate), 1),
                'total_questions_answered', SUM(total_questions)
            )
            FROM app.prep_student_weaknesses
            WHERE student_id = v_student_id
        )
    );
END;
$$;


ALTER FUNCTION "app"."app_prep_get_weakness_analysis"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_list_ai_conversations"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ DECLARE v_result JSONB; BEGIN SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.updated_at DESC), '[]'::jsonb) INTO v_result FROM ( SELECT * FROM app.prep_ai_conversations WHERE student_id = auth.uid() ) t; RETURN v_result; END; $$;


ALTER FUNCTION "app"."app_prep_list_ai_conversations"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_list_ai_messages"("p_conversation_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ DECLARE v_result JSONB; BEGIN SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at), '[]'::jsonb) INTO v_result FROM ( SELECT * FROM app.prep_ai_messages WHERE conversation_id = p_conversation_id ) t; RETURN v_result; END; $$;


ALTER FUNCTION "app"."app_prep_list_ai_messages"("p_conversation_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_list_exam_papers"("p_concours_type" "text" DEFAULT NULL::"text", "p_year" "text" DEFAULT NULL::"text", "p_subject" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ DECLARE v_result JSONB; BEGIN SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at DESC), '[]'::jsonb) INTO v_result FROM ( SELECT * FROM app.prep_exam_papers WHERE is_active = true AND (p_concours_type IS NULL OR concours_type = p_concours_type) AND (p_year IS NULL OR year = p_year) AND (p_subject IS NULL OR subject = p_subject) ) t; RETURN v_result; END; $$;


ALTER FUNCTION "app"."app_prep_list_exam_papers"("p_concours_type" "text", "p_year" "text", "p_subject" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_list_flashcard_decks"("p_subject" "text" DEFAULT NULL::"text", "p_concours_type" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ DECLARE v_result JSONB; BEGIN SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at DESC), '[]'::jsonb) INTO v_result FROM ( SELECT d.*, (SELECT COUNT(*) FROM app.prep_flashcards f WHERE f.deck_id = d.id AND f.is_active) AS card_count FROM app.prep_flashcard_decks d WHERE d.is_active = true AND (p_subject IS NULL OR d.subject = p_subject) AND (p_concours_type IS NULL OR d.concours_type = p_concours_type) ) t; RETURN v_result; END; $$;


ALTER FUNCTION "app"."app_prep_list_flashcard_decks"("p_subject" "text", "p_concours_type" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_list_flashcards"("p_deck_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ DECLARE v_result JSONB; BEGIN SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at), '[]'::jsonb) INTO v_result FROM ( SELECT f.*, fp.ease_factor, fp.interval_days, fp.repetitions, fp.next_review_at, fp.last_reviewed_at FROM app.prep_flashcards f LEFT JOIN app.prep_flashcard_progress fp ON fp.flashcard_id = f.id AND fp.student_id = auth.uid() WHERE f.deck_id = p_deck_id AND f.is_active = true ) t; RETURN v_result; END; $$;


ALTER FUNCTION "app"."app_prep_list_flashcards"("p_deck_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_list_question_banks"("p_concours_type" "text" DEFAULT NULL::"text", "p_subject" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ DECLARE v_result JSONB; BEGIN SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at DESC), '[]'::jsonb) INTO v_result FROM ( SELECT b.id, b.title, b.description, b.concours_type, b.subject, b.is_active, b.created_at, (SELECT COUNT(*) FROM app.prep_questions q WHERE q.bank_id = b.id) AS question_count FROM app.prep_question_banks b WHERE b.is_active = true AND (p_concours_type IS NULL OR b.concours_type = p_concours_type) AND (p_subject IS NULL OR b.subject = p_subject) ) t; RETURN v_result; END; $$;


ALTER FUNCTION "app"."app_prep_list_question_banks"("p_concours_type" "text", "p_subject" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_list_questions"("p_bank_id" "uuid" DEFAULT NULL::"uuid", "p_concours_type" "text" DEFAULT NULL::"text", "p_subject" "text" DEFAULT NULL::"text", "p_difficulty" integer DEFAULT NULL::integer, "p_limit" integer DEFAULT 20) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ DECLARE v_result JSONB; BEGIN SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb) INTO v_result FROM ( SELECT q.id, q.bank_id, q.question_type, q.content, q.question, q.options, q.correct_index, q.explanation, q.difficulty, q.subject, q.tags, q.points, q.time_limit_seconds, q.image_url, q.is_active, q.is_published, q.created_at, b.title AS bank_title FROM app.prep_questions q LEFT JOIN app.prep_question_banks b ON b.id = q.bank_id WHERE (p_bank_id IS NULL OR q.bank_id = p_bank_id) AND (p_concours_type IS NULL OR q.concours_type = p_concours_type) AND (p_subject IS NULL OR q.subject = p_subject) AND (p_difficulty IS NULL OR q.difficulty = p_difficulty) ORDER BY q.created_at DESC LIMIT p_limit ) t; RETURN v_result; END; $$;


ALTER FUNCTION "app"."app_prep_list_questions"("p_bank_id" "uuid", "p_concours_type" "text", "p_subject" "text", "p_difficulty" integer, "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_list_quiz_templates"("p_concours_type" "text" DEFAULT NULL::"text", "p_subject" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ DECLARE v_result JSONB; BEGIN SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at DESC), '[]'::jsonb) INTO v_result FROM ( SELECT qt.*, b.title AS bank_title FROM app.prep_quiz_templates qt LEFT JOIN app.prep_question_banks b ON b.id = qt.bank_id WHERE qt.is_active = true AND (p_concours_type IS NULL OR qt.concours_type = p_concours_type) AND (p_subject IS NULL OR qt.subject = p_subject) ) t; RETURN v_result; END; $$;


ALTER FUNCTION "app"."app_prep_list_quiz_templates"("p_concours_type" "text", "p_subject" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_save_ai_message"("p_conversation_id" "uuid", "p_role" "text", "p_content" "text", "p_tokens_used" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ DECLARE v_id UUID; BEGIN INSERT INTO app.prep_ai_messages (conversation_id, role, content, tokens_used) VALUES (p_conversation_id, p_role, p_content, p_tokens_used) RETURNING id INTO v_id; UPDATE app.prep_ai_conversations SET message_count = message_count + 1, total_tokens_used = total_tokens_used + p_tokens_used, updated_at = now() WHERE id = p_conversation_id; RETURN jsonb_build_object('success', true, 'id', v_id); END; $$;


ALTER FUNCTION "app"."app_prep_save_ai_message"("p_conversation_id" "uuid", "p_role" "text", "p_content" "text", "p_tokens_used" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_save_flashcard_review"("p_flashcard_id" "uuid", "p_quality" integer, "p_ease_factor" numeric DEFAULT 2.5, "p_interval_days" integer DEFAULT 1, "p_repetitions" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ BEGIN INSERT INTO app.prep_flashcard_progress (flashcard_id, student_id, ease_factor, interval_days, repetitions, next_review_at, last_reviewed_at, quality_history) VALUES (p_flashcard_id, auth.uid(), p_ease_factor, p_interval_days, p_repetitions, now() + (p_interval_days || ' days')::interval, now(), ARRAY[p_quality]) ON CONFLICT (flashcard_id, student_id) DO UPDATE SET ease_factor = EXCLUDED.ease_factor, interval_days = EXCLUDED.interval_days, repetitions = EXCLUDED.repetitions, next_review_at = now() + (p_interval_days || ' days')::interval, last_reviewed_at = now(), quality_history = array_append(app.prep_flashcard_progress.quality_history, p_quality); RETURN jsonb_build_object('success', true); END; $$;


ALTER FUNCTION "app"."app_prep_save_flashcard_review"("p_flashcard_id" "uuid", "p_quality" integer, "p_ease_factor" numeric, "p_interval_days" integer, "p_repetitions" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_save_quiz_attempt"("p_template_id" "uuid" DEFAULT NULL::"uuid", "p_questions_json" "jsonb" DEFAULT NULL::"jsonb", "p_answers_json" "jsonb" DEFAULT NULL::"jsonb", "p_score" integer DEFAULT 0, "p_total_points" integer DEFAULT 0, "p_correct_count" integer DEFAULT 0, "p_question_count" integer DEFAULT 0, "p_time_spent_seconds" integer DEFAULT 0, "p_status" "text" DEFAULT 'completed'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ DECLARE v_id UUID; BEGIN INSERT INTO app.prep_quiz_attempts ( template_id, student_id, questions_json, answers_json, score, total_points, correct_count, question_count, time_spent_seconds, status ) VALUES ( p_template_id, auth.uid(), p_questions_json, p_answers_json, p_score, p_total_points, p_correct_count, p_question_count, p_time_spent_seconds, p_status ) RETURNING id INTO v_id; RETURN jsonb_build_object('success', true, 'id', v_id); END; $$;


ALTER FUNCTION "app"."app_prep_save_quiz_attempt"("p_template_id" "uuid", "p_questions_json" "jsonb", "p_answers_json" "jsonb", "p_score" integer, "p_total_points" integer, "p_correct_count" integer, "p_question_count" integer, "p_time_spent_seconds" integer, "p_status" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_save_quiz_attempt"("p_template_id" "uuid" DEFAULT NULL::"uuid", "p_questions_json" "jsonb" DEFAULT '[]'::"jsonb", "p_answers_json" "jsonb" DEFAULT '[]'::"jsonb", "p_score" numeric DEFAULT 0, "p_total_points" integer DEFAULT 0, "p_correct_count" integer DEFAULT 0, "p_question_count" integer DEFAULT 0, "p_time_spent_seconds" integer DEFAULT 0, "p_status" "text" DEFAULT 'completed'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_attempt_id UUID;
  v_student_id UUID := auth.uid();
  v_xp_earned INTEGER := 0;
  v_pct NUMERIC;
BEGIN
  INSERT INTO app.td_quiz_attempts (
    template_id, student_id, questions_json, answers_json,
    score, total_points, correct_count, question_count,
    time_spent_seconds, status, finished_at
  ) VALUES (
    p_template_id, v_student_id, p_questions_json, p_answers_json,
    p_score, p_total_points, p_correct_count, p_question_count,
    p_time_spent_seconds, p_status,
    CASE WHEN p_status = 'completed' THEN now() ELSE NULL END
  )
  RETURNING id INTO v_attempt_id;

  -- Calculate XP
  v_pct := CASE WHEN p_question_count > 0 THEN (p_correct_count::numeric / p_question_count) * 100 ELSE 0 END;
  v_xp_earned := 20; -- base XP
  IF v_pct >= 100 THEN v_xp_earned := v_xp_earned + 25; END IF;
  IF v_pct >= 80 THEN v_xp_earned := v_xp_earned + 10; END IF;

  -- Update progress (global)
  INSERT INTO app.td_student_progress (student_id, subject, total_questions_answered, correct_count, total_quizzes_completed, total_xp, last_activity_date)
  VALUES (v_student_id, 'global', p_question_count, p_correct_count, 1, v_xp_earned, CURRENT_DATE)
  ON CONFLICT (student_id, subject) DO UPDATE SET
    total_questions_answered = app.td_student_progress.total_questions_answered + p_question_count,
    correct_count = app.td_student_progress.correct_count + p_correct_count,
    total_quizzes_completed = app.td_student_progress.total_quizzes_completed + 1,
    total_xp = app.td_student_progress.total_xp + v_xp_earned,
    level = (app.td_student_progress.total_xp + v_xp_earned) / 100 + 1,
    current_streak = CASE
      WHEN app.td_student_progress.last_activity_date = CURRENT_DATE THEN app.td_student_progress.current_streak
      WHEN app.td_student_progress.last_activity_date = CURRENT_DATE - 1 THEN app.td_student_progress.current_streak + 1
      ELSE 1
    END,
    longest_streak = GREATEST(
      app.td_student_progress.longest_streak,
      CASE
        WHEN app.td_student_progress.last_activity_date = CURRENT_DATE THEN app.td_student_progress.current_streak
        WHEN app.td_student_progress.last_activity_date = CURRENT_DATE - 1 THEN app.td_student_progress.current_streak + 1
        ELSE 1
      END
    ),
    last_activity_date = CURRENT_DATE,
    updated_at = now();

  RETURN jsonb_build_object(
    'success', true,
    'attempt_id', v_attempt_id,
    'xp_earned', v_xp_earned,
    'score_pct', v_pct
  );
END;
$$;


ALTER FUNCTION "app"."app_prep_save_quiz_attempt"("p_template_id" "uuid", "p_questions_json" "jsonb", "p_answers_json" "jsonb", "p_score" numeric, "p_total_points" integer, "p_correct_count" integer, "p_question_count" integer, "p_time_spent_seconds" integer, "p_status" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_teacher_end_live_session"("p_session_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ BEGIN UPDATE app.prep_live_sessions SET status='ended' WHERE id=p_session_id AND teacher_id=auth.uid() AND status='running'; RETURN jsonb_build_object('success',true); END; $$;


ALTER FUNCTION "app"."app_prep_teacher_end_live_session"("p_session_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_teacher_grade_submission"("p_submission_id" "uuid", "p_score" integer, "p_comment" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ BEGIN UPDATE app.prep_assignment_submissions SET teacher_score = p_score, teacher_comment = p_comment, teacher_graded_at = now(), status = 'graded' WHERE id = p_submission_id AND EXISTS (SELECT 1 FROM app.prep_assignments a WHERE a.id = assignment_id AND a.teacher_id = auth.uid()); RETURN jsonb_build_object('success', true); END; $$;


ALTER FUNCTION "app"."app_prep_teacher_grade_submission"("p_submission_id" "uuid", "p_score" integer, "p_comment" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_teacher_list_assignments"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ DECLARE v_result JSONB; BEGIN SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at DESC), '[]'::jsonb) INTO v_result FROM ( SELECT a.*, (SELECT COUNT(*) FROM app.prep_assignment_submissions s WHERE s.assignment_id = a.id) AS submission_count, (SELECT COUNT(*) FROM app.prep_assignment_submissions s WHERE s.assignment_id = a.id AND s.status = 'graded') AS graded_count FROM app.prep_assignments a WHERE a.teacher_id = auth.uid() ) t; RETURN v_result; END; $$;


ALTER FUNCTION "app"."app_prep_teacher_list_assignments"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_teacher_list_live_sessions"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ DECLARE v_result JSONB; BEGIN SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.start_at DESC), '[]'::jsonb) INTO v_result FROM (SELECT s.*, (SELECT COUNT(*) FROM app.prep_live_participants p WHERE p.session_id=s.id) AS participant_count FROM app.prep_live_sessions s WHERE s.teacher_id=auth.uid()) t; RETURN v_result; END; $$;


ALTER FUNCTION "app"."app_prep_teacher_list_live_sessions"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_teacher_list_submissions"("p_assignment_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ DECLARE v_result JSONB; BEGIN IF NOT EXISTS (SELECT 1 FROM app.prep_assignments WHERE id = p_assignment_id AND teacher_id = auth.uid()) THEN RETURN jsonb_build_object('success', false, 'error', 'not_owner'); END IF; SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.submitted_at DESC), '[]'::jsonb) INTO v_result FROM ( SELECT s.*, st.full_name AS student_name FROM app.prep_assignment_submissions s LEFT JOIN app.students st ON st.id = s.student_id WHERE s.assignment_id = p_assignment_id ) t; RETURN jsonb_build_object('success', true, 'submissions', v_result); END; $$;


ALTER FUNCTION "app"."app_prep_teacher_list_submissions"("p_assignment_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_teacher_start_live_session"("p_session_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ BEGIN UPDATE app.prep_live_sessions SET status='running' WHERE id=p_session_id AND teacher_id=auth.uid() AND status IN ('draft','approved'); RETURN jsonb_build_object('success',true); END; $$;


ALTER FUNCTION "app"."app_prep_teacher_start_live_session"("p_session_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_teacher_upsert_assignment"("p_assignment_id" "uuid" DEFAULT NULL::"uuid", "p_title" "text" DEFAULT NULL::"text", "p_description" "text" DEFAULT NULL::"text", "p_concours_type" "text" DEFAULT NULL::"text", "p_subject_name" "text" DEFAULT NULL::"text", "p_assignment_type" "text" DEFAULT 'qcm'::"text", "p_content" "jsonb" DEFAULT NULL::"jsonb", "p_attachments" "jsonb" DEFAULT '[]'::"jsonb", "p_deadline" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_max_score" integer DEFAULT 20, "p_is_published" boolean DEFAULT false, "p_target_group" "text" DEFAULT 'all'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ DECLARE v_id UUID; BEGIN IF p_assignment_id IS NOT NULL THEN UPDATE app.prep_assignments SET title = COALESCE(p_title, title), description = COALESCE(p_description, description), concours_type = COALESCE(p_concours_type, concours_type), subject_name = COALESCE(p_subject_name, subject_name), assignment_type = COALESCE(p_assignment_type, assignment_type), content = COALESCE(p_content, content), attachments = COALESCE(p_attachments, attachments), deadline = COALESCE(p_deadline, deadline), max_score = COALESCE(p_max_score, max_score), is_published = COALESCE(p_is_published, is_published), target_group = COALESCE(p_target_group, target_group), updated_at = now() WHERE id = p_assignment_id AND teacher_id = auth.uid() RETURNING id INTO v_id; ELSE INSERT INTO app.prep_assignments (teacher_id, title, description, concours_type, subject_name, assignment_type, content, attachments, deadline, max_score, is_published, target_group) VALUES (auth.uid(), p_title, p_description, p_concours_type, p_subject_name, p_assignment_type, p_content, p_attachments, p_deadline, p_max_score, p_is_published, p_target_group) RETURNING id INTO v_id; END IF; RETURN jsonb_build_object('success', true, 'id', v_id); END; $$;


ALTER FUNCTION "app"."app_prep_teacher_upsert_assignment"("p_assignment_id" "uuid", "p_title" "text", "p_description" "text", "p_concours_type" "text", "p_subject_name" "text", "p_assignment_type" "text", "p_content" "jsonb", "p_attachments" "jsonb", "p_deadline" timestamp with time zone, "p_max_score" integer, "p_is_published" boolean, "p_target_group" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_teacher_upsert_live_session"("p_session_id" "uuid" DEFAULT NULL::"uuid", "p_title" "text" DEFAULT NULL::"text", "p_description" "text" DEFAULT NULL::"text", "p_session_type" "text" DEFAULT 'revision'::"text", "p_concours_type" "text" DEFAULT NULL::"text", "p_subject_name" "text" DEFAULT NULL::"text", "p_provider" "text" DEFAULT 'livekit'::"text", "p_join_url" "text" DEFAULT NULL::"text", "p_start_at" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_end_at" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_replay_url" "text" DEFAULT NULL::"text", "p_max_participants" integer DEFAULT 100, "p_quiz_template_id" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ DECLARE v_id UUID; BEGIN IF p_session_id IS NOT NULL THEN UPDATE app.prep_live_sessions SET title=COALESCE(p_title,title), description=COALESCE(p_description,description), session_type=COALESCE(p_session_type,session_type), concours_type=COALESCE(p_concours_type,concours_type), subject_name=COALESCE(p_subject_name,subject_name), provider=COALESCE(p_provider,provider), join_url=COALESCE(p_join_url,join_url), start_at=COALESCE(p_start_at,start_at), end_at=p_end_at, replay_url=p_replay_url, max_participants=COALESCE(p_max_participants,max_participants), quiz_template_id=p_quiz_template_id WHERE id=p_session_id AND teacher_id=auth.uid() RETURNING id INTO v_id; ELSE INSERT INTO app.prep_live_sessions (teacher_id,title,description,session_type,concours_type,subject_name,provider,join_url,start_at,end_at,replay_url,max_participants,quiz_template_id) VALUES (auth.uid(),p_title,p_description,p_session_type,p_concours_type,p_subject_name,p_provider,p_join_url,p_start_at,p_end_at,p_replay_url,p_max_participants,p_quiz_template_id) RETURNING id INTO v_id; END IF; RETURN jsonb_build_object('success',true,'id',v_id); END; $$;


ALTER FUNCTION "app"."app_prep_teacher_upsert_live_session"("p_session_id" "uuid", "p_title" "text", "p_description" "text", "p_session_type" "text", "p_concours_type" "text", "p_subject_name" "text", "p_provider" "text", "p_join_url" "text", "p_start_at" timestamp with time zone, "p_end_at" timestamp with time zone, "p_replay_url" "text", "p_max_participants" integer, "p_quiz_template_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_prep_update_ai_config"("p_key" "text", "p_value" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'app'
    AS $$ BEGIN INSERT INTO app.prep_ai_config (config_key, config_value, updated_by) VALUES (p_key, p_value, auth.uid()) ON CONFLICT (config_key) DO UPDATE SET config_value = EXCLUDED.config_value, updated_by = auth.uid(), updated_at = now(); RETURN jsonb_build_object('success', true); END; $$;


ALTER FUNCTION "app"."app_prep_update_ai_config"("p_key" "text", "p_value" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_run_send_push_notifications"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- pg_net returns a request id; we ignore it.
  PERFORM net.http_post(
    url := 'https://thevdfcwlcqzdoybfvgs.supabase.co/functions/v1/send-push-notifications',
    headers := '{"Content-Type":"application/json"}'::jsonb,
    body := '{}'::jsonb,
    timeout_milliseconds := 15000
  );
END;
$$;


ALTER FUNCTION "app"."app_run_send_push_notifications"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_search_bobodo_answer_cache"("p_query_embedding" "extensions"."vector", "p_threshold" double precision DEFAULT 0.92) RETURNS TABLE("cache_id" "uuid", "answer" "text", "category" "text", "hit_count" integer, "similarity" double precision)
    LANGUAGE "sql" SECURITY DEFINER
    AS $$
  SELECT
    c.id                                              AS cache_id,
    c.answer_text                                     AS answer,
    c.category                                        AS category,
    c.hit_count                                       AS hit_count,
    (1 - (c.question_embedding <=> p_query_embedding))::float AS similarity
  FROM app.bobodo_answer_cache c
  WHERE
    c.expires_at > now()
    AND c.question_embedding IS NOT NULL
    AND (1 - (c.question_embedding <=> p_query_embedding)) >= p_threshold
  ORDER BY c.question_embedding <=> p_query_embedding
  LIMIT 1;
$$;


ALTER FUNCTION "app"."app_search_bobodo_answer_cache"("p_query_embedding" "extensions"."vector", "p_threshold" double precision) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."app_td_get_current_role"() RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_claims  JSONB;
  v_role    TEXT;
  v_user_id UUID;
BEGIN
  -- 1) Essayer de lire le r+¦le applicatif dans les claims JWT
  BEGIN
    v_claims := current_setting('request.jwt.claims', true)::jsonb;
  EXCEPTION WHEN OTHERS THEN
    v_claims := NULL;
  END;

  IF v_claims IS NOT NULL THEN
    -- R+¦le applicatif typique c+¦t+® Supabase: user_metadata.role ou app_metadata.role
    v_role := COALESCE(
      v_claims->'user_metadata'->>'role',
      v_claims->'app_metadata'->>'role'
    );

    IF v_role IS NOT NULL AND TRIM(v_role) <> '' THEN
      IF v_role = 'instructor' THEN
        RETURN 'teacher';
      END IF;
      RETURN v_role;
    END IF;
  END IF;

  -- 2) Fallback robuste: lire le r+¦le dans auth.users.raw_user_meta_data->>'role'
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT raw_user_meta_data->>'role'
  INTO v_role
  FROM auth.users
  WHERE id = v_user_id;

  IF v_role = 'instructor' THEN
    RETURN 'teacher';
  END IF;

  RETURN v_role;
END;
$$;


ALTER FUNCTION "app"."app_td_get_current_role"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."fn_check_commission_cap"("p_commercial_user_id" "uuid", "p_student_id" "uuid") RETURNS TABLE("allowed" boolean, "commission_number" integer, "adjusted_rate" numeric)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_max_cap INTEGER;
    v_existing_count INTEGER;
    v_base_rate NUMERIC;
    v_adjusted NUMERIC;
BEGIN
    SELECT max_commissions_per_prospect, commission_rate
    INTO v_max_cap, v_base_rate
    FROM app.commercial_profiles
    WHERE user_id = p_commercial_user_id;

    IF v_max_cap IS NULL THEN v_max_cap := 3; END IF;
    -- commission_rate in commercial_profiles is stored as PERCENTAGE (5.0 = 5%)
    -- Convert to fraction for consistency with commission_rules (0.05 = 5%)
    IF v_base_rate IS NULL THEN v_base_rate := 5.0; END IF;
    v_base_rate := v_base_rate / 100.0;

    SELECT COUNT(*) INTO v_existing_count
    FROM app.referral_commissions
    WHERE commercial_user_id = p_commercial_user_id
      AND student_id = p_student_id;

    IF v_existing_count >= v_max_cap THEN
        RETURN QUERY SELECT FALSE, v_existing_count + 1, 0::NUMERIC;
        RETURN;
    END IF;

    -- Degressive rate: base * 0.85^n (in fraction units now)
    v_adjusted := v_base_rate * POWER(0.85, v_existing_count);
    IF v_adjusted < 0.005 THEN v_adjusted := 0.005; END IF;

    RETURN QUERY SELECT TRUE, v_existing_count + 1, ROUND(v_adjusted, 4);
    RETURN;
END;
$$;


ALTER FUNCTION "app"."fn_check_commission_cap"("p_commercial_user_id" "uuid", "p_student_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."fn_enqueue_notification_event"("p_user_id" "uuid", "p_domain" "text", "p_event_type" "text", "p_payload" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO app.notification_events(user_id, domain, event_type, payload, created_at, processed_at, attempt_count, last_error)
  VALUES (
    p_user_id,
    p_domain,
    p_event_type,
    COALESCE(p_payload, '{}'::jsonb),
    now(),
    NULL,
    0,
    NULL
  );
END;
$$;


ALTER FUNCTION "app"."fn_enqueue_notification_event"("p_user_id" "uuid", "p_domain" "text", "p_event_type" "text", "p_payload" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."fn_hero_playlist_autofill_base_video_url_from_rendition"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_url text;
BEGIN
  IF NEW.status <> 'ready' THEN
    RETURN NEW;
  END IF;

  v_url := COALESCE(NULLIF(trim(NEW.public_url_hint), ''), NULL);
  IF v_url IS NULL THEN
    RETURN NEW;
  END IF;

  UPDATE app.hero_playlist p
  SET base_video_url = COALESCE(NULLIF(trim(p.base_video_url), ''), v_url),
      updated_at = NOW()
  WHERE p.video_asset_id = NEW.video_asset_id
    AND lower(p.media_type) = 'video'
    AND p.is_active = TRUE
    AND (p.base_video_url IS NULL OR length(trim(p.base_video_url)) = 0);

  RETURN NEW;
END;
$$;


ALTER FUNCTION "app"."fn_hero_playlist_autofill_base_video_url_from_rendition"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."fn_resolve_commission_rate"("p_payment_reason" "text", "p_degree_level" "text") RETURNS TABLE("resolved_rate" numeric, "resolved_max_amount" numeric, "resolved_currency" "text", "rule_id" "uuid")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_rule RECORD;
BEGIN
    -- Priority order: exact match > payment_reason match > degree_level match > wildcard
    SELECT cr.commission_rate, cr.max_amount, cr.currency, cr.id
    INTO v_rule
    FROM app.commission_rules cr
    WHERE cr.is_active = TRUE
      AND (cr.payment_reason = p_payment_reason OR cr.payment_reason = '*')
      AND (cr.degree_level = p_degree_level OR cr.degree_level = '*')
    ORDER BY
        CASE WHEN cr.payment_reason = p_payment_reason AND cr.degree_level = p_degree_level THEN 0
             WHEN cr.payment_reason = p_payment_reason AND cr.degree_level = '*' THEN 1
             WHEN cr.payment_reason = '*' AND cr.degree_level = p_degree_level THEN 2
             ELSE 3
        END,
        cr.priority DESC
    LIMIT 1;

    IF v_rule IS NULL THEN
        RETURN QUERY SELECT 0.08::NUMERIC, 10000::NUMERIC, 'XOF'::TEXT, NULL::UUID;
        RETURN;
    END IF;

    RETURN QUERY SELECT v_rule.commission_rate, v_rule.max_amount, v_rule.currency, v_rule.id;
    RETURN;
END;
$$;


ALTER FUNCTION "app"."fn_resolve_commission_rate"("p_payment_reason" "text", "p_degree_level" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."fn_update_commercial_tier"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_commercial_id UUID;
    v_distinct_students INTEGER;
    v_total_commissions INTEGER;
    v_new_tier TEXT;
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        v_commercial_id := NEW.commercial_user_id;
    ELSE
        v_commercial_id := OLD.commercial_user_id;
    END IF;

    -- Tier based on distinct students with commissions
    SELECT COUNT(DISTINCT student_id) INTO v_distinct_students
    FROM app.referral_commissions
    WHERE commercial_user_id = v_commercial_id
      AND status IN ('pending', 'approved', 'paid');

    -- Total commissions count (all statuses except rejected)
    SELECT COUNT(*) INTO v_total_commissions
    FROM app.referral_commissions
    WHERE commercial_user_id = v_commercial_id
      AND status IN ('pending', 'approved', 'paid');

    IF v_distinct_students >= 30 THEN v_new_tier := 'diamond';
    ELSIF v_distinct_students >= 15 THEN v_new_tier := 'gold';
    ELSIF v_distinct_students >= 5 THEN v_new_tier := 'silver';
    ELSE v_new_tier := 'bronze';
    END IF;

    UPDATE app.commercial_profiles
    SET tier = v_new_tier,
        total_confirmed_payments = v_total_commissions,
        updated_at = NOW()
    WHERE user_id = v_commercial_id;

    RETURN COALESCE(NEW, OLD);
END;
$$;


ALTER FUNCTION "app"."fn_update_commercial_tier"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."generate_tournament_bracket"("p_tournament_id" "uuid", "p_participant_count" integer) RETURNS TABLE("success" boolean, "message" "text", "bracket_data" "jsonb")
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    participant_count INTEGER;
    rounds_needed INTEGER;
    bracket_data JSONB := '[]';
BEGIN
    -- V+®rifier le tournoi
    SELECT COUNT(*) INTO participant_count
    FROM app.tournament_participants 
    WHERE tournament_id = p_tournament_id AND status = 'registered';
    
    IF participant_count = 0 THEN
        RETURN QUERY SELECT false, 'No registered participants', '[]'::JSONB;
    END IF;
    
    -- Calculer le nombre de rounds n+®cessaires
    rounds_needed := CEIL(LOG(participant_count, 2));
    
    -- G+®n+®rer le bracket (simplifi+® pour single elimination)
    bracket_data := json_build_object(
        'tournament_id', p_tournament_id,
        'participant_count', participant_count,
        'rounds_needed', rounds_needed,
        'matches', json_build_array()
    );
    
    RETURN QUERY SELECT true, 'Bracket generated successfully', bracket_data;
END;
$$;


ALTER FUNCTION "app"."generate_tournament_bracket"("p_tournament_id" "uuid", "p_participant_count" integer) OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "app"."hero_videos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "context" "text" NOT NULL,
    "duration" numeric,
    "resolution" "text",
    "fps" integer,
    "codec" "text",
    "audio_codec" "text",
    "parts_count" integer NOT NULL,
    "parts_urls" "text"[] NOT NULL,
    "total_size_bytes" bigint,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "hero_videos_context_check" CHECK (("context" = ANY (ARRAY['landing'::"text", 'student_home'::"text", 'minisite'::"text"])))
);


ALTER TABLE "app"."hero_videos" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."hero_get_video"("p_id" "uuid") RETURNS "app"."hero_videos"
    LANGUAGE "sql" STABLE
    AS $$
  SELECT * FROM app.hero_videos WHERE id = p_id;
$$;


ALTER FUNCTION "app"."hero_get_video"("p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."hero_list_videos"("p_context" "text") RETURNS TABLE("id" "uuid", "context" "text", "duration" numeric, "resolution" "text", "fps" integer, "codec" "text", "audio_codec" "text", "parts_count" integer, "parts_urls" "text"[], "total_size_bytes" bigint, "created_at" timestamp with time zone)
    LANGUAGE "sql" STABLE
    AS $$
  SELECT
    hv.id,
    hv.context,
    hv.duration,
    hv.resolution,
    hv.fps,
    hv.codec,
    hv.audio_codec,
    hv.parts_count,
    hv.parts_urls,
    hv.total_size_bytes,
    hv.created_at
  FROM app.hero_videos hv
  WHERE (p_context IS NULL OR hv.context = p_context)
  ORDER BY hv.created_at DESC;
$$;


ALTER FUNCTION "app"."hero_list_videos"("p_context" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."is_admin"() RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth', 'app'
    AS $$
DECLARE
  _is_admin boolean;
BEGIN
  SELECT (u.raw_user_meta_data->>'role' = 'admin')
  INTO _is_admin
  FROM auth.users u
  WHERE u.id = auth.uid();

  RETURN COALESCE(_is_admin, false);
END;
$$;


ALTER FUNCTION "app"."is_admin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."landing_media_public_url"("p_storage_path" "text") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE
    AS $$
  SELECT 'https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/public/landing-media/'
         || ltrim(COALESCE(p_storage_path, ''), '/');
$$;


ALTER FUNCTION "app"."landing_media_public_url"("p_storage_path" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."league_create"("p_name" character varying, "p_description" "text", "p_game_type" character varying, "p_division" character varying DEFAULT 'main'::character varying, "p_season_number" integer DEFAULT 1, "p_start_date" timestamp with time zone DEFAULT "now"(), "p_end_date" timestamp with time zone DEFAULT ("now"() + '3 mons'::interval)) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_league_id UUID;
BEGIN
    -- Cr+®er la ligue
    INSERT INTO app.leagues (
        name, description, game_type, division, season_number,
        start_date, end_date, status, created_by
    ) VALUES (
        p_name, p_description, p_game_type, p_division, p_season_number,
        p_start_date, p_end_date, 'active', auth.uid()
    ) RETURNING id INTO v_league_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'league_id', v_league_id,
        'message', 'League created successfully'
    );
END;
$$;


ALTER FUNCTION "app"."league_create"("p_name" character varying, "p_description" "text", "p_game_type" character varying, "p_division" character varying, "p_season_number" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."league_get_standings"("p_league_id" "uuid", "p_division" character varying DEFAULT NULL::character varying) RETURNS TABLE("rank_position" integer, "participant_id" "uuid", "participant_name" character varying, "division" character varying, "points" integer, "matches_played" integer, "matches_won" integer, "matches_lost" integer, "matches_drawn" integer, "win_rate" numeric, "elo_rating" integer, "elo_change" integer, "current_streak" integer, "best_streak" integer, "season_points" integer, "status" character varying)
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ROW_NUMBER() OVER (ORDER BY season_points DESC, points DESC, win_rate DESC, elo_rating DESC) as rank_position,
        lp.user_id as participant_id,
        COALESCECE(students.full_name, 'Player ' || SUBSTRING(lp.user_id::text, 1, 8)) as participant_name,
        lp.division,
        lp.points,
        lp.matches_played,
        lp.matches_won,
        lp.matches_lost,
        lp.matches_drawn,
        lp.win_rate,
        lp.elo_rating,
        lp.elo_change,
        lp.current_streak,
        lp.best_streak,
        lp.season_points,
        lp.status
    FROM app.league_participations lp
    LEFT JOIN auth.users u ON lp.user_id = u.id
    LEFT JOIN app.students students ON u.id = students.id
    WHERE lp.league_id = p_league_id
      AND (p_division IS NULL OR lp.division = p_division)
      AND lp.status IN ('active', 'promoted', 'relegated')
    ORDER BY season_points DESC, points DESC, win_rate DESC, elo_rating DESC;
END;
$$;


ALTER FUNCTION "app"."league_get_standings"("p_league_id" "uuid", "p_division" character varying) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."league_join"("p_league_id" "uuid") RETURNS TABLE("success" boolean, "message" "text")
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    league_info RECORD;
    user_elo INTEGER;
    existing_participation RECORD;
BEGIN
    -- V+®rifier la ligue
    SELECT * INTO league_info
    FROM app.leagues 
    WHERE id = p_league_id AND is_active = true;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT false, 'League not found or not active';
    END IF;
    
    -- V+®rifier si la ligue est pleine
    IF league_info.current_players >= league_info.max_players THEN
        RETURN QUERY SELECT false, 'League is full';
    END IF;
    
    -- V+®rifier les contraintes ELO
    SELECT COALESCE(elo_rating, 1000) INTO user_elo
    FROM app.game_multiplayer_leaderboards 
    WHERE user_id = auth.uid() AND game_type = league_info.game_type;
    
    IF user_elo < league_info.min_elo OR user_elo > league_info.max_elo THEN
        RETURN QUERY SELECT false, 'ELO rating not in allowed range';
    END IF;
    
    -- V+®rifier si d+®j+á participant
    SELECT * INTO existing_participation
    FROM app.league_participations 
    WHERE league_id = p_league_id AND user_id = auth.uid();
    
    IF FOUND THEN
        RETURN QUERY SELECT false, 'Already participating in this league';
    END IF;
    
    -- Rejoindre la ligue
    INSERT INTO app.league_participations (
        league_id, user_id, division, elo_rating, elo_rating_start
    ) VALUES (
        p_league_id, auth.uid(), league_info.division, user_elo, user_elo
    );
    
    -- Mettre +á jour le classement
    UPDATE app.league_participations 
    SET rank_position = (
        SELECT COUNT(*) + 1 
        FROM app.league_participations lp2 
        WHERE lp2.league_id = p_league_id 
          AND lp2.division = league_info.division
          AND lp2.points > (SELECT points FROM app.league_participations WHERE user_id = auth.uid() AND league_id = p_league_id)
    )
    WHERE league_id = p_league_id AND user_id = auth.uid();
    
    RETURN QUERY SELECT true, 'Successfully joined league';
END;
$$;


ALTER FUNCTION "app"."league_join"("p_league_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."league_list_available"("p_game_type" character varying DEFAULT NULL::character varying, "p_division" character varying DEFAULT NULL::character varying, "p_limit" integer DEFAULT 20) RETURNS TABLE("league_id" "uuid", "name" character varying, "description" "text", "game_type" character varying, "league_type" character varying, "division" character varying, "season_number" integer, "current_players" integer, "max_players" integer, "min_elo" integer, "max_elo" integer, "is_active" boolean, "season_start" timestamp with time zone, "season_end" timestamp with time zone, "created_at" timestamp with time zone)
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        l.id,
        l.name,
        l.description,
        l.game_type,
        l.league_type,
        l.division,
        l.season_number,
        l.current_players,
        l.max_players,
        l.min_elo,
        l.max_elo,
        l.is_active,
        l.season_start,
        l.season_end,
        l.created_at
    FROM app.leagues l
    WHERE l.is_active = true
      AND (p_game_type IS NULL OR l.game_type = p_game_type)
      AND (p_division IS NULL OR l.division = p_division)
      AND l.current_players < l.max_players
    ORDER BY l.division, l.season_number DESC
    LIMIT p_limit;
END;
$$;


ALTER FUNCTION "app"."league_list_available"("p_game_type" character varying, "p_division" character varying, "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."league_report_match_result"("p_match_id" "uuid", "p_winner_id" "uuid", "p_participant1_score" integer DEFAULT 0, "p_participant2_score" integer DEFAULT 0, "p_participant1_points" integer DEFAULT 0, "p_participant2_points" integer DEFAULT 0, "p_participant1_elo_change" integer DEFAULT 0, "p_participant2_elo_change" integer DEFAULT 0, "p_notes" "text" DEFAULT NULL::"text") RETURNS TABLE("success" boolean, "message" "text")
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    match_info RECORD;
    league_info RECORD;
BEGIN
    -- V+®rifier le match
    SELECT * INTO match_info
    FROM app.league_matches 
    WHERE id = p_match_id AND status = 'in_progress';
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT false, 'Match not found or not in progress';
    END IF;
    
    -- Obtenir les informations de la ligue
    SELECT * INTO league_info
    FROM app.leagues 
    WHERE id = match_info.league_id;
    
    -- Mettre +á jour le match
    UPDATE app.league_matches 
    SET 
        winner_id = p_winner_id,
        status = 'completed',
        completed_at = NOW(),
        participant1_score = p_participant1_score,
        participant2_score = p_participant2_score,
        participant1_points = p_participant1_points,
        participant2_points = p_participant2_points,
        participant1_elo_change = p_participant1_elo_change,
        participant2_elo_change = p_participant2_elo_change,
        notes = p_notes
    WHERE id = p_match_id;
    
    -- Mettre +á jour les participants
    UPDATE app.league_participations 
    SET 
        matches_played = matches_played + 1,
        matches_won = CASE 
            WHEN user_id = p_participant1_id AND p_participant1_id = p_winner_id THEN matches_won + 1
            WHEN user_id = p_participant2_id AND p_participant2_id = p_winner_id THEN matches_won + 1
            ELSE matches_won
        END,
        matches_lost = CASE 
            WHEN user_id = p_participant1_id AND p_participant1_id != p_winner_id THEN matches_lost + 1
            WHEN user_id = p_participant2_id AND p_participant2_id != p_winner_id THEN matches_lost + 1
            ELSE matches_lost
        END,
        points = points + CASE
            WHEN user_id = p_participant1_id THEN p_participant1_points
            WHEN user_id = p_participant2_id THEN p_participant2_points
            ELSE 0
        END,
        elo_rating = elo_rating + CASE
            WHEN user_id = p_participant1_id THEN p_participant1_elo_change
            WHEN user_id = p_participant2_id THEN p_participant2_elo_change
            ELSE 0
        END,
        elo_change = elo_change + CASE
            WHEN user_id = p_participant1_id THEN p_participant1_elo_change
            WHEN user_id = p_participant2_id THEN p_participant2_elo_change
            ELSE 0
        END,
        last_match_at = NOW()
    WHERE league_id = match_info.league_id
      AND user_id IN (p_participant1_id, p_participant2_id);
    
    -- Mettre +á jour les classements
    UPDATE app.league_participations 
    SET rank_position = (
        SELECT COUNT(*) + 1 
        FROM app.league_participations lp2 
        WHERE lp2.league_id = match_info.league_id 
          AND lp2.division = (
              SELECT division FROM app.leagues WHERE id = match_info.league_id
          )
          AND lp2.points > (SELECT points FROM app.league_participations WHERE user_id = auth.uid() AND league_id = match_info.league_id)
    )
    WHERE league_id = match_info.league_id
      AND user_id IN (p_participant1_id, p_participant2_id);
    
    RETURN QUERY SELECT true, 'League match result recorded successfully';
END;
$$;


ALTER FUNCTION "app"."league_report_match_result"("p_match_id" "uuid", "p_winner_id" "uuid", "p_participant1_score" integer, "p_participant2_score" integer, "p_participant1_points" integer, "p_participant2_points" integer, "p_participant1_elo_change" integer, "p_participant2_elo_change" integer, "p_notes" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."on_landing_media_object_insert"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_path TEXT;
  v_lower TEXT;
  v_config_id uuid;
  v_asset_id uuid;
  v_public_url TEXT;
  v_playlist_item_id uuid;
BEGIN
  IF NEW.bucket_id <> 'landing-media' THEN
    RETURN NEW;
  END IF;

  v_path := COALESCE(NEW.name, '');
  v_lower := LOWER(v_path);

  -- only hero-video uploads
  IF POSITION('/landing/hero-video/' IN v_lower) = 0 THEN
    RETURN NEW;
  END IF;

  -- only video files
  IF NOT (
    v_lower LIKE '%.mp4' OR v_lower LIKE '%.mov' OR v_lower LIKE '%.webm' OR v_lower LIKE '%.m4v'
  ) THEN
    RETURN NEW;
  END IF;

  SELECT id
  INTO v_config_id
  FROM app.landing_config
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_config_id IS NULL THEN
    RETURN NEW;
  END IF;

  v_asset_id := gen_random_uuid();
  v_public_url := app.landing_media_public_url(v_path);

  INSERT INTO app.video_assets (
    id,
    owner_user_id,
    origin,
    status,
    canonical_type,
    duration_ms,
    width,
    height,
    rotation,
    has_audio,
    created_at,
    updated_at
  ) VALUES (
    v_asset_id,
    NULL,
    'landing-media',
    'ready',
    'video',
    NULL,
    NULL,
    NULL,
    NULL,
    FALSE,
    NOW(),
    NOW()
  );

  INSERT INTO app.video_renditions (
    id,
    video_asset_id,
    rendition_key,
    kind,
    width,
    height,
    bitrate_kbps,
    fps,
    codec,
    storage_bucket,
    storage_path,
    public_url_hint,
    status,
    error,
    created_at
  ) VALUES (
    gen_random_uuid(),
    v_asset_id,
    'landing-media:' || v_path,
    'mp4',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    'landing-media',
    v_path,
    v_public_url,
    'ready',
    NULL,
    NOW()
  );

  UPDATE app.landing_config
  SET
    video_asset_id = v_asset_id,
    hero_storage_path = v_path,
    hero_video_url = v_public_url,
    updated_at = NOW()
  WHERE id = v_config_id;

  -- Also keep the landing hero playlist in sync (this is what AuthLandingScreen uses)
  SELECT p.id
  INTO v_playlist_item_id
  FROM app.hero_playlist p
  WHERE p.slot = 'landing_hero_main'
    AND p.is_active = TRUE
  ORDER BY p.sort_order, p.created_at
  LIMIT 1;

  IF v_playlist_item_id IS NULL THEN
    INSERT INTO app.hero_playlist (
      slot,
      title,
      subtitle,
      media_type,
      base_video_url,
      base_image_url,
      video_asset_id,
      sort_order,
      is_active,
      created_at,
      updated_at
    ) VALUES (
      'landing_hero_main',
      'media',
      NULL,
      'video',
      v_public_url,
      NULL,
      v_asset_id,
      1,
      TRUE,
      NOW(),
      NOW()
    )
    RETURNING id INTO v_playlist_item_id;
  ELSE
    UPDATE app.hero_playlist
    SET
      media_type = 'video',
      base_video_url = v_public_url,
      base_image_url = NULL,
      video_asset_id = v_asset_id,
      updated_at = NOW()
    WHERE id = v_playlist_item_id;
  END IF;

  INSERT INTO app.video_asset_contexts (id, video_asset_id, context_type, context_id, role, created_at)
  VALUES (
    gen_random_uuid(),
    v_asset_id,
    'landing_config',
    v_config_id,
    'hero',
    NOW()
  )
  ON CONFLICT (context_type, context_id, role) DO UPDATE
    SET video_asset_id = EXCLUDED.video_asset_id;

  -- Optional: context for the playlist item as well
  IF v_playlist_item_id IS NOT NULL THEN
    INSERT INTO app.video_asset_contexts (id, video_asset_id, context_type, context_id, role, created_at)
    VALUES (
      gen_random_uuid(),
      v_asset_id,
      'hero_playlist',
      v_playlist_item_id,
      'primary',
      NOW()
    )
    ON CONFLICT (context_type, context_id, role) DO UPDATE
      SET video_asset_id = EXCLUDED.video_asset_id;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "app"."on_landing_media_object_insert"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."payment_receipts_block_changes"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RAISE EXCEPTION 'payment_receipts are immutable';
  RETURN OLD;
END;
$$;


ALTER FUNCTION "app"."payment_receipts_block_changes"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."tg_block_legacy_video_writes"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_op TEXT := TG_OP;
  v_col TEXT;
  v_old JSONB;
  v_new JSONB;
  v_role TEXT := NULLIF(current_setting('request.jwt.claim.role', true), '');
  v_sub TEXT := NULLIF(current_setting('request.jwt.claim.sub', true), '');
  v_uid UUID := NULL;
BEGIN
  BEGIN
    v_uid := auth.uid();
  EXCEPTION WHEN OTHERS THEN
    v_uid := NULL;
  END;

  FOREACH v_col IN ARRAY TG_ARGV LOOP
    v_col := NULLIF(TRIM(v_col), '');
    IF v_col IS NULL THEN
      CONTINUE;
    END IF;

    v_new := to_jsonb(NEW) -> v_col;
    IF v_op = 'INSERT' THEN
      -- Block any non-null legacy column on insert
      IF v_new IS NOT NULL AND v_new <> 'null'::jsonb THEN
        INSERT INTO app.legacy_video_write_attempts (
          table_name, operation, column_name, old_value, new_value,
          actor_role, actor_sub, actor_uid, actor_current_user
        ) VALUES (
          TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME,
          v_op,
          v_col,
          NULL,
          v_new,
          v_role,
          v_sub,
          v_uid,
          current_user
        );

        RAISE EXCEPTION 'legacy_video_write_blocked: %.% column=%', TG_TABLE_SCHEMA, TG_TABLE_NAME, v_col
          USING ERRCODE = '42501';
      END IF;

    ELSE
      v_old := to_jsonb(OLD) -> v_col;
      -- Block any change (including nulling)
      IF v_new IS DISTINCT FROM v_old THEN
        INSERT INTO app.legacy_video_write_attempts (
          table_name, operation, column_name, old_value, new_value,
          actor_role, actor_sub, actor_uid, actor_current_user
        ) VALUES (
          TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME,
          v_op,
          v_col,
          v_old,
          v_new,
          v_role,
          v_sub,
          v_uid,
          current_user
        );

        RAISE EXCEPTION 'legacy_video_write_blocked: %.% column=%', TG_TABLE_SCHEMA, TG_TABLE_NAME, v_col
          USING ERRCODE = '42501';
      END IF;
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "app"."tg_block_legacy_video_writes"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."tg_hero_overlays_tv_set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at := now();
  return new;
end;
$$;


ALTER FUNCTION "app"."tg_hero_overlays_tv_set_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."tg_hero_renders_tv_set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at := now();
  return new;
end;
$$;


ALTER FUNCTION "app"."tg_hero_renders_tv_set_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."tg_video_assets_set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "app"."tg_video_assets_set_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."tg_video_processing_jobs_set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "app"."tg_video_processing_jobs_set_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."tournament_create"("p_name" character varying, "p_description" "text", "p_game_type" character varying, "p_tournament_type" character varying DEFAULT 'elimination'::character varying, "p_format" character varying DEFAULT 'single_elimination'::character varying, "p_max_participants" integer DEFAULT 16, "p_min_participants" integer DEFAULT 4, "p_registration_start" timestamp with time zone DEFAULT "now"(), "p_registration_end" timestamp with time zone DEFAULT ("now"() + '24:00:00'::interval), "p_start_date" timestamp with time zone DEFAULT ("now"() + '1 day'::interval), "p_end_date" timestamp with time zone DEFAULT ("now"() + '2 days'::interval), "p_prize_pool" integer DEFAULT 0, "p_entry_fee" integer DEFAULT 0, "p_is_featured" boolean DEFAULT false, "p_is_private" boolean DEFAULT false, "p_elo_min" integer DEFAULT 0, "p_elo_max" integer DEFAULT 3000, "p_auto_start" boolean DEFAULT true, "p_settings" "jsonb" DEFAULT '{}'::"jsonb") RETURNS TABLE("success" boolean, "tournament_id" "uuid", "message" "text")
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    new_tournament_id UUID;
BEGIN
    -- Cr+®er le tournoi
    INSERT INTO app.tournaments (
        name, description, game_type, tournament_type, format,
        max_participants, min_participants, registration_start, registration_end,
        start_date, end_date, prize_pool, entry_fee, is_featured, is_private,
        elo_min, elo_max, auto_start, settings, created_by
    ) VALUES (
        p_name, p_description, p_game_type, p_tournament_type, p_format,
        p_max_participants, p_min_participants, p_registration_start, p_registration_end,
        p_start_date, p_end_date, p_prize_pool, p_entry_fee, p_is_featured, p_is_private,
        p_elo_min, p_elo_max, p_auto_start, p_settings, auth.uid()
    ) RETURNING id INTO new_tournament_id;
    
    RETURN QUERY SELECT true, new_tournament_id, 'Tournament created successfully';
END;
$$;


ALTER FUNCTION "app"."tournament_create"("p_name" character varying, "p_description" "text", "p_game_type" character varying, "p_tournament_type" character varying, "p_format" character varying, "p_max_participants" integer, "p_min_participants" integer, "p_registration_start" timestamp with time zone, "p_registration_end" timestamp with time zone, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_prize_pool" integer, "p_entry_fee" integer, "p_is_featured" boolean, "p_is_private" boolean, "p_elo_min" integer, "p_elo_max" integer, "p_auto_start" boolean, "p_settings" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."tournament_get_details"("p_tournament_id" "uuid") RETURNS TABLE("tournament_id" "uuid", "name" character varying, "description" "text", "game_type" character varying, "tournament_type" character varying, "format" character varying, "max_participants" integer, "min_participants" integer, "current_participants" integer, "status" character varying, "registration_start" timestamp with time zone, "registration_end" timestamp with time zone, "start_date" timestamp with time zone, "end_date" timestamp with time zone, "prize_pool" integer, "entry_fee" integer, "created_by" character varying, "created_at" timestamp with time zone, "settings" "jsonb", "participant_count" integer, "current_round" integer, "total_matches" integer, "completed_matches" integer)
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    tournament_info RECORD;
BEGIN
    -- Obtenir les informations du tournoi
    SELECT * INTO tournament_info
    FROM app.tournaments 
    WHERE id = p_tournament_id;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT NULL::UUID, NULL::VARCHAR, NULL::TEXT, NULL::VARCHAR, NULL::VARCHAR, 
                         NULL::VARCHAR, NULL::INTEGER, NULL::INTEGER, NULL::INTEGER, NULL::VARCHAR,
                         NULL::TIMESTAMPTZ, NULL::TIMESTAMPTZ, NULL::TIMESTAMPTZ, NULL::TIMESTAMPTZ,
                         NULL::INTEGER, NULL::INTEGER, NULL::BOOLEAN, NULL::INTEGER, NULL::INTEGER,
                         NULL::VARCHAR, NULL::TIMESTAMPTZ, NULL::JSONB, NULL::INTEGER, NULL::INTEGER,
                         NULL::INTEGER, NULL::INTEGER;
    END IF;
    
    -- Calculer les statistiques
    RETURN QUERY
    SELECT 
        tournament_info.id,
        tournament_info.name,
        tournament_info.description,
        tournament_info.game_type,
        tournament_info.tournament_type,
        tournament_info.format,
        tournament_info.max_participants,
        tournament_info.min_participants,
        tournament_info.current_participants,
        tournament_info.status,
        tournament_info.registration_start,
        tournament_info.registration_end,
        tournament_info.start_date,
        tournament_info.end_date,
        tournament_info.prize_pool,
        tournament_info.entry_fee,
        COALESCE(students.full_name, 'Anonymous') as created_by,
        tournament_info.created_at,
        tournament_info.settings,
        (SELECT COUNT(*) FROM app.tournament_participants WHERE tournament_id = p_tournament_id) as participant_count,
        (SELECT COALESCE(MAX(round_number), 0) FROM app.tournament_matches WHERE tournament_id = p_tournament_id) as current_round,
        (SELECT COUNT(*) FROM app.tournament_matches WHERE tournament_id = p_tournament_id) as total_matches,
        (SELECT COUNT(*) FROM app.tournament_matches WHERE tournament_id = p_tournament_id AND status = 'completed') as completed_matches
    FROM app.tournaments tournament_info
    LEFT JOIN auth.users u ON tournament_info.created_by = u.id
    LEFT JOIN app.students students ON u.id = students.id
    WHERE tournament_info.id = p_tournament_id;
END;
$$;


ALTER FUNCTION "app"."tournament_get_details"("p_tournament_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."tournament_get_standings"("p_tournament_id" "uuid") RETURNS TABLE("rank_position" integer, "participant_id" "uuid", "participant_name" character varying, "status" character varying, "current_round" integer, "matches_played" integer, "matches_won" integer, "matches_lost" integer, "matches_drawn" integer, "points" integer, "elo_rating_before" integer, "elo_rating_after" integer, "prize_won" integer, "eliminated_by" character varying, "eliminated_at" timestamp with time zone)
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ROW_NUMBER() OVER (ORDER BY points DESC, matches_won DESC, matches_lost ASC, elo_rating_after DESC NULLS LAST) as rank_position,
        tp.user_id as participant_id,
        COALESCECE(students.full_name, 'Player ' || SUBSTRING(tp.user_id::text, 1, 8)) as participant_name,
        tp.status,
        tp.current_round,
        tp.matches_played,
        tp.matches_won,
        tp.matches_lost,
        tp.matches_drawn,
        tp.points,
        tp.elo_rating_before,
        tp.elo_rating_after,
        tp.prize_won,
        COALESCECE(eliminated_by.full_name, 'Unknown') as eliminated_by,
        tp.eliminated_at
    FROM app.tournament_participants tp
    LEFT JOIN auth.users u ON tp.user_id = u.id
    LEFT JOIN app.students students ON u.id = students.id
    LEFT JOIN auth.users eliminated_by_user ON tp.eliminated_by = eliminated_by_user.id
    LEFT JOIN app.students eliminated_by ON eliminated_by_user.id = eliminated_by.id
    WHERE tp.tournament_id = p_tournament_id
      AND tp.status IN ('active', 'eliminated', 'winner', 'withdrawn')
    ORDER BY points DESC, matches_won DESC, matches_lost ASC, elo_rating_after DESC NULLS LAST;
END;
$$;


ALTER FUNCTION "app"."tournament_get_standings"("p_tournament_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."tournament_list_available"("p_game_type" character varying DEFAULT NULL::character varying, "p_limit" integer DEFAULT 20) RETURNS TABLE("tournament_id" "uuid", "name" character varying, "description" "text", "game_type" character varying, "tournament_type" character varying, "format" character varying, "max_participants" integer, "current_participants" integer, "status" character varying, "registration_end" timestamp with time zone, "start_date" timestamp with time zone, "end_date" timestamp with time zone, "prize_pool" integer, "entry_fee" integer, "is_featured" boolean, "is_private" boolean, "elo_min" integer, "elo_max" integer, "created_by" character varying, "created_at" timestamp with time zone)
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id,
        t.name,
        t.description,
        t.game_type,
        t.tournament_type,
        t.format,
        t.max_participants,
        t.current_participants,
        t.status,
        t.registration_end,
        t.start_date,
        t.end_date,
        t.prize_pool,
        t.entry_fee,
        t.is_featured,
        t.is_private,
        t.elo_min,
        t.elo_max,
        COALESCE(students.full_name, 'Anonymous') as created_by,
        t.created_at
    FROM app.tournaments t
    LEFT JOIN auth.users u ON t.created_by = u.id
    LEFT JOIN app.students students ON u.id = students.id
    WHERE t.status IN ('registration', 'active')
      AND (p_game_type IS NULL OR t.game_type = p_game_type)
      AND (t.is_private = false OR t.created_by = auth.uid())
      AND t.current_participants < t.max_participants
      AND t.registration_end > NOW()
    ORDER BY t.is_featured DESC, t.created_at DESC
    LIMIT p_limit;
END;
$$;


ALTER FUNCTION "app"."tournament_list_available"("p_game_type" character varying, "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."tournament_register"("p_tournament_id" "uuid") RETURNS TABLE("success" boolean, "message" "text")
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    tournament_info RECORD;
    user_elo INTEGER;
    existing_registration RECORD;
BEGIN
    -- V+®rifier le tournoi
    SELECT * INTO tournament_info
    FROM app.tournaments 
    WHERE id = p_tournament_id AND status = 'registration';
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT false, 'Tournament not found or not in registration phase';
    END IF;
    
    -- V+®rifier si le tournoi est plein
    IF tournament_info.current_participants >= tournament_info.max_participants THEN
        RETURN QUERY SELECT false, 'Tournament is full';
    END IF;
    
    -- V+®rifier les contraintes ELO
    SELECT COALESCE(elo_rating, 1000) INTO user_elo
    FROM app.game_multiplayer_leaderboards 
    WHERE user_id = auth.uid() AND game_type = tournament_info.game_type;
    
    IF user_elo < tournament_info.elo_min OR user_elo > tournament_info.elo_max THEN
        RETURN QUERY SELECT false, 'ELO rating not in allowed range';
    END IF;
    
    -- V+®rifier si d+®j+á inscrit
    SELECT * INTO existing_registration
    FROM app.tournament_participants 
    WHERE tournament_id = p_tournament_id AND user_id = auth.uid();
    
    IF FOUND THEN
        RETURN QUERY SELECT false, 'Already registered for this tournament';
    END IF;
    
    -- S'inscrire
    INSERT INTO app.tournament_participants (
        tournament_id, user_id, elo_rating_before
    ) VALUES (
        p_tournament_id, auth.uid(), user_elo
    );
    
    RETURN QUERY SELECT true, 'Successfully registered for tournament';
END;
$$;


ALTER FUNCTION "app"."tournament_register"("p_tournament_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."tournament_report_match_result"("p_match_id" "uuid", "p_winner_id" "uuid", "p_player1_score" integer DEFAULT 0, "p_player2_score" integer DEFAULT 0, "p_match_data" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_match_status TEXT;
BEGIN
    -- Mettre +á jour le match
    UPDATE app.tournament_matches
    SET 
        winner_id = p_winner_id,
        player1_score = p_player1_score,
        player2_score = p_player2_score,
        status = 'completed',
        completed_at = NOW(),
        match_data = p_match_data
    WHERE id = p_match_id;
    
    -- V+®rifier si le match existe
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Match not found');
    END IF;
    
    RETURN jsonb_build_object('success', true, 'message', 'Match result reported');
END;
$$;


ALTER FUNCTION "app"."tournament_report_match_result"("p_match_id" "uuid", "p_winner_id" "uuid", "p_player1_score" integer, "p_player2_score" integer, "p_match_data" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."tournament_start"("p_tournament_id" "uuid") RETURNS TABLE("success" boolean, "message" "text")
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    tournament_info RECORD;
    participant_count INTEGER;
    bracket_data JSONB;
BEGIN
    -- V+®rifier le tournoi
    SELECT * INTO tournament_info
    FROM app.tournaments 
    WHERE id = p_tournament_id AND status = 'registration'
      AND created_by = auth.uid();
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT false, 'Tournament not found or not in registration phase';
    END IF;
    
    -- V+®rifier le nombre minimum de participants
    SELECT COUNT(*) INTO participant_count
    FROM app.tournament_participants 
    WHERE tournament_id = p_tournament_id AND status = 'registered';
    
    IF participant_count < tournament_info.min_participants THEN
        RETURN QUERY SELECT false, 'Not enough participants to start tournament';
    END IF;
    
    -- Mettre +á jour le statut
    UPDATE app.tournaments 
    SET status = 'active', start_date = NOW()
    WHERE id = p_tournament_id;
    
    -- Mettre +á jour le statut des participants
    UPDATE app.tournament_participants 
    SET status = 'active'
    WHERE tournament_id = p_tournament_id AND status = 'registered';
    
    -- G+®n+®rer le bracket
    SELECT * INTO bracket_data FROM app.generate_tournament_bracket(p_tournament_id, participant_count);
    
    -- Cr+®er les matchs du premier round
    INSERT INTO app.tournament_matches (
        tournament_id, round_number, match_number, participant1_id, participant2_id,
        status, scheduled_at
    )
    SELECT 
        p_tournament_id, 
        1, 
        ROW_NUMBER() OVER (ORDER BY seed_number),
        p1.id,
        p2.id,
        'scheduled',
        NOW()
    FROM (
        SELECT 
            tp.id,
            tp.seed_number,
            ROW_NUMBER() OVER (ORDER BY tp.seed_number) as rn
        FROM app.tournament_participants tp
        WHERE tp.tournament_id = p_tournament_id AND tp.status = 'active'
        ORDER BY tp.seed_number
    ) p1
    JOIN (
        SELECT 
            tp.id,
            tp.seed_number,
            ROW_NUMBER() OVER (ORDER BY tp.seed_number) as rn
        FROM app.tournament_participants tp
        WHERE tp.tournament_id = p_tournament_id AND tp.status = 'active'
        ORDER BY tp.seed_number
    ) p2 ON p1.rn = p2.rn + 1 AND p1.rn % 2 = 0
    WHERE p1.rn < participant_count / 2;
    
    RETURN QUERY SELECT true, 'Tournament started successfully';
END;
$$;


ALTER FUNCTION "app"."tournament_start"("p_tournament_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."trg_instant_push_notification"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- Fire-and-forget HTTP POST to Edge Function
  PERFORM net.http_post(
    url := 'https://thevdfcwlcqzdoybfvgs.supabase.co/functions/v1/send-push-notifications',
    headers := '{"Content-Type":"application/json"}'::jsonb,
    body := '{}'::jsonb,
    timeout_milliseconds := 5000
  );
  RETURN NEW;
END;
$$;


ALTER FUNCTION "app"."trg_instant_push_notification"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."trg_notify_inquiry_message"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_buyer UUID;
  v_merchant UUID;
  v_target UUID;
BEGIN
  SELECT buyer_id, merchant_id
  INTO v_buyer, v_merchant
  FROM app.opportunity_inquiries
  WHERE id = NEW.inquiry_id;

  IF v_buyer IS NULL OR v_merchant IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.sender_id = v_buyer THEN
    v_target := v_merchant;
  ELSE
    v_target := v_buyer;
  END IF;

  PERFORM app.fn_enqueue_notification_event(
    v_target,
    'marketplace_inquiries',
    'message',
    jsonb_build_object(
      'inquiry_id', NEW.inquiry_id,
      'sender_id', NEW.sender_id
    )
  );

  RETURN NEW;
END;
$$;


ALTER FUNCTION "app"."trg_notify_inquiry_message"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."trg_notify_opportunity_review"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_merchant UUID;
BEGIN
  IF NEW.merchant_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF OLD.review_status IS DISTINCT FROM NEW.review_status
     AND NEW.review_status IN ('approved', 'rejected') THEN
    v_merchant := NEW.merchant_id;

    PERFORM app.fn_enqueue_notification_event(
      v_merchant,
      'marketplace_opportunities',
      'review',
      jsonb_build_object(
        'opportunity_id', NEW.id,
        'review_status', NEW.review_status,
        'review_reason', NEW.review_reason
      )
    );
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "app"."trg_notify_opportunity_review"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."update_league_player_count"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE app.leagues 
        SET current_players = current_players + 1 
        WHERE id = NEW.league_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE app.leagues 
        SET current_players = GREATEST(current_players - 1, 0) 
        WHERE id = OLD.league_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$;


ALTER FUNCTION "app"."update_league_player_count"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."update_student_weaknesses_from_attempt"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_question_data jsonb;
    v_answer_data jsonb;
    v_is_correct boolean;
    v_subject_id uuid;
    v_difficulty integer;
    i integer;
BEGIN
    FOR i IN 0..jsonb_array_length(NEW.questions_json)-1 LOOP
        v_question_data := NEW.questions_json->i;
        v_answer_data := NEW.answers_json->i;
        v_is_correct := COALESCE((v_answer_data->>'is_correct')::boolean, false);
        v_subject_id := (v_question_data->>'subject_id')::uuid;
        v_difficulty := COALESCE((v_question_data->>'difficulty')::integer, 3);
        
        CONTINUE WHEN v_subject_id IS NULL;
        
        INSERT INTO app.prep_student_weaknesses (
            student_id, subject_id, total_questions,
            correct_answers, incorrect_answers,
            avg_difficulty_attempted
        ) VALUES (
            NEW.student_id, v_subject_id, 1,
            CASE WHEN v_is_correct THEN 1 ELSE 0 END,
            CASE WHEN v_is_correct THEN 0 ELSE 1 END,
            v_difficulty::decimal
        )
        ON CONFLICT (student_id, subject_id) DO UPDATE SET
            total_questions = prep_student_weaknesses.total_questions + 1,
            correct_answers = prep_student_weaknesses.correct_answers + 
                CASE WHEN v_is_correct THEN 1 ELSE 0 END,
            incorrect_answers = prep_student_weaknesses.incorrect_answers + 
                CASE WHEN v_is_correct THEN 0 ELSE 1 END,
            updated_at = now();
    END LOOP;
    
    UPDATE app.prep_student_weaknesses
    SET 
        success_rate = CASE 
            WHEN total_questions > 0 THEN (correct_answers::decimal / total_questions * 100)
            ELSE 0 
        END,
        needs_practice = CASE
            WHEN total_questions < 5 THEN true
            WHEN (correct_answers::decimal / total_questions * 100) < 70 THEN true
            ELSE false
        END,
        recommended_difficulty = 3
    WHERE student_id = NEW.student_id;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "app"."update_student_weaknesses_from_attempt"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."update_tournament_participant_count"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE app.tournaments 
        SET current_participants = current_participants + 1 
        WHERE id = NEW.tournament_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE app.tournaments 
        SET current_participants = GREATEST(current_participants - 1, 0) 
        WHERE id = OLD.tournament_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$;


ALTER FUNCTION "app"."update_tournament_participant_count"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "app"."update_updated_at_column"() OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."academic_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "event_type" "text" NOT NULL,
    "country" "text",
    "city" "text",
    "location" "text",
    "university_id" "uuid",
    "program_id" "uuid",
    "level" "text",
    "tags" "text"[],
    "is_all_day" boolean DEFAULT false NOT NULL,
    "start_at" timestamp with time zone,
    "end_at" timestamp with time zone,
    "registration_open_at" timestamp with time zone,
    "registration_deadline_at" timestamp with time zone,
    "is_published" boolean DEFAULT false NOT NULL,
    "is_highlighted" boolean DEFAULT false NOT NULL,
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."academic_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."actor_balances" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "actor_type" "text" NOT NULL,
    "actor_id" "uuid" NOT NULL,
    "available_balance" numeric DEFAULT 0 NOT NULL,
    "pending_balance" numeric DEFAULT 0 NOT NULL,
    "total_earned" numeric DEFAULT 0 NOT NULL,
    "total_withdrawn" numeric DEFAULT 0 NOT NULL,
    "currency" "text" DEFAULT 'XOF'::"text" NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."actor_balances" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."admin_user_action_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "performed_by" "uuid" NOT NULL,
    "target_user" "uuid" NOT NULL,
    "action" "text" NOT NULL,
    "reason" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "meta" "jsonb",
    CONSTRAINT "admin_user_action_logs_action_check" CHECK (("action" = ANY (ARRAY['suspend'::"text", 'reactivate'::"text", 'delete'::"text"])))
);


ALTER TABLE "app"."admin_user_action_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."admin_users" (
    "user_id" "uuid" NOT NULL
);


ALTER TABLE "app"."admin_users" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."application_files" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "application_id" "uuid" NOT NULL,
    "file_type" "text" NOT NULL,
    "storage_path" "text" NOT NULL,
    "uploaded_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."application_files" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."application_messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "application_id" "uuid" NOT NULL,
    "sender_role" "text" NOT NULL,
    "audience" "text" NOT NULL,
    "content" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."application_messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."application_payments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "application_id" "uuid",
    "student_id" "uuid" NOT NULL,
    "university_id" "uuid",
    "amount_due" numeric(12,2) NOT NULL,
    "amount_paid" numeric(12,2),
    "currency" "text" DEFAULT 'XOF'::"text" NOT NULL,
    "payment_reason" "public"."payment_reason" NOT NULL,
    "channel" "public"."payment_channel",
    "status" "public"."payment_status" DEFAULT 'pending'::"public"."payment_status" NOT NULL,
    "reference_code" "text" NOT NULL,
    "external_reference" "text",
    "student_note" "text",
    "created_by" "uuid",
    "verified_by" "uuid",
    "confirmed_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "verified_at" timestamp with time zone,
    "confirmed_at" timestamp with time zone,
    "declared_at" timestamp with time zone,
    "ligdicash_token" "text",
    "ligdicash_transaction_id" "text",
    "ligdicash_operator" "text",
    "payment_method" "text" DEFAULT 'manual'::"text",
    "phone_number" "text"
);


ALTER TABLE "app"."application_payments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."applications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "program_id" "uuid" NOT NULL,
    "status" "text" DEFAULT 'draft'::"text" NOT NULL,
    "motivation_text" "text",
    "submitted_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "last_message_at" timestamp with time zone,
    "last_student_read_at" timestamp with time zone,
    "last_admin_read_at" timestamp with time zone,
    "last_university_read_at" timestamp with time zone,
    "requested_degree_level" "text",
    "requested_study_mode" "text",
    "requested_schedule" "text",
    "discount_requested" boolean DEFAULT false NOT NULL,
    "discount_details" "text",
    "student_comment" "text",
    "sent_to_university" boolean DEFAULT false NOT NULL,
    "sent_to_university_at" timestamp with time zone,
    "admin_seen_at" timestamp with time zone,
    "university_seen_at" timestamp with time zone
);


ALTER TABLE "app"."applications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."bobodo_answer_cache" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "question_text" "text" NOT NULL,
    "question_embedding" "extensions"."vector"(1536),
    "answer_text" "text" NOT NULL,
    "category" "text",
    "hit_count" integer DEFAULT 1 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "last_hit_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "expires_at" timestamp with time zone DEFAULT ("now"() + '60 days'::interval) NOT NULL
);


ALTER TABLE "app"."bobodo_answer_cache" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."bobodo_detected_needs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "session_id" "uuid" NOT NULL,
    "question_text" "text" NOT NULL,
    "category" "text" NOT NULL,
    "need_summary" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."bobodo_detected_needs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."bobodo_feedback" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "session_id" "uuid" NOT NULL,
    "message_id" "uuid" NOT NULL,
    "student_id" "uuid" NOT NULL,
    "rating" "text" NOT NULL,
    "comment" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "bobodo_feedback_rating_check" CHECK (("rating" = ANY (ARRAY['up'::"text", 'down'::"text"])))
);


ALTER TABLE "app"."bobodo_feedback" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."bobodo_knowledge" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "category" "text" NOT NULL,
    "title" "text" NOT NULL,
    "content" "text" NOT NULL,
    "tags" "text"[],
    "language" "text" DEFAULT 'fr'::"text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "embedding" "extensions"."vector"(1536)
);


ALTER TABLE "app"."bobodo_knowledge" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."bobodo_messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "session_id" "uuid" NOT NULL,
    "sender" "text" NOT NULL,
    "content" "text" NOT NULL,
    "safety_flag" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."bobodo_messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."bobodo_sessions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "title" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."bobodo_sessions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."bobodo_unanswered_questions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "session_id" "uuid" NOT NULL,
    "question_text" "text" NOT NULL,
    "category" "text" NOT NULL,
    "status" "text" DEFAULT 'new'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."bobodo_unanswered_questions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."challenge_comments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "participation_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "content" "text" NOT NULL,
    "is_deleted" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."challenge_comments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."challenge_favorites" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "participation_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."challenge_favorites" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."challenge_likes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "participation_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."challenge_likes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."challenge_participation_videos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "participation_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "video_asset_id" "uuid"
);


ALTER TABLE "app"."challenge_participation_videos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."challenge_participations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "challenge_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "status" "text" DEFAULT 'joined'::"text" NOT NULL,
    "submission_text" "text",
    "score" integer,
    "rank" integer,
    "started_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "submitted_at" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "reviewed_at" timestamp with time zone,
    "reviewed_by_user_id" "uuid",
    "is_active" boolean DEFAULT true NOT NULL,
    "moderation_status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "moderation_flags" "jsonb",
    "moderated_by_admin_id" "uuid",
    "moderated_at" timestamp with time zone,
    "parent_participation_id" "uuid",
    "remix_type" "text" DEFAULT 'none'::"text" NOT NULL,
    "video_asset_id" "uuid",
    "is_deleted" boolean DEFAULT false NOT NULL,
    "deleted_at" timestamp with time zone,
    "allow_download" boolean DEFAULT false NOT NULL
);


ALTER TABLE "app"."challenge_participations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."challenge_reports" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "participation_id" "uuid" NOT NULL,
    "reporter_id" "uuid" NOT NULL,
    "reason" "text" NOT NULL,
    "details" "text",
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "handled_by_admin_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."challenge_reports" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."challenge_user_bans" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "reason" "text" NOT NULL,
    "banned_until" timestamp with time zone,
    "created_by_admin_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."challenge_user_bans" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."challenge_video_assets" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "category" "text" NOT NULL,
    "label" "text" NOT NULL,
    "asset_url" "text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."challenge_video_assets" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."challenge_video_overlays" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "participation_id" "uuid" NOT NULL,
    "layers" "jsonb" NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."challenge_video_overlays" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."challenge_video_render_jobs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "participation_id" "uuid" NOT NULL,
    "job_type" "text" NOT NULL,
    "status" "text" NOT NULL,
    "error_message" "text",
    "metadata" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "started_at" timestamp with time zone,
    "completed_at" timestamp with time zone
);


ALTER TABLE "app"."challenge_video_render_jobs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."challenges" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "slug" "text" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "challenge_type" "text" NOT NULL,
    "difficulty" "text",
    "points" integer DEFAULT 0 NOT NULL,
    "start_at" timestamp with time zone,
    "end_at" timestamp with time zone,
    "max_participants" integer,
    "requires_submission" boolean DEFAULT false NOT NULL,
    "requires_admin_review" boolean DEFAULT false NOT NULL,
    "is_featured" boolean DEFAULT false NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_by_user_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."challenges" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."commercial_milestone_claims" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "commercial_user_id" "uuid" NOT NULL,
    "milestone_id" "uuid" NOT NULL,
    "claimed_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "paid_at" timestamp with time zone
);


ALTER TABLE "app"."commercial_milestone_claims" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."commercial_milestones" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "threshold" integer NOT NULL,
    "bonus_amount" numeric DEFAULT 0 NOT NULL,
    "currency" "text" DEFAULT 'XOF'::"text" NOT NULL,
    "label" "text" NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."commercial_milestones" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."commercial_profiles" (
    "user_id" "uuid" NOT NULL,
    "ref_code" "text" NOT NULL,
    "ref_link" "text" NOT NULL,
    "commission_rate" numeric(5,2) DEFAULT 5.00 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "admin_notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deactivated_at" timestamp with time zone,
    "tier" "text" DEFAULT 'bronze'::"text" NOT NULL,
    "max_commissions_per_prospect" integer DEFAULT 3 NOT NULL,
    "total_confirmed_payments" integer DEFAULT 0 NOT NULL,
    "payout_phone" "text"
);


ALTER TABLE "app"."commercial_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."commission_rules" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "payment_reason" "text" DEFAULT '*'::"text" NOT NULL,
    "degree_level" "text" DEFAULT '*'::"text" NOT NULL,
    "commission_rate" numeric DEFAULT 0.10 NOT NULL,
    "max_amount" numeric DEFAULT 0 NOT NULL,
    "currency" "text" DEFAULT 'XOF'::"text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "description" "text",
    "priority" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."commission_rules" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."communities" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "slug" "text" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "category" "text",
    "visibility" "text" DEFAULT 'public'::"text" NOT NULL,
    "is_featured" boolean DEFAULT false NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_by_user_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "kind" "text" DEFAULT 'student_group'::"text" NOT NULL,
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
    "moderation_state" "text" DEFAULT 'clean'::"text" NOT NULL,
    "last_message_at" timestamp with time zone,
    "join_policy" "text" DEFAULT 'open'::"text" NOT NULL
);


ALTER TABLE "app"."communities" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."community_join_requests" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "community_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "handled_at" timestamp with time zone,
    "handled_by_user_id" "uuid"
);


ALTER TABLE "app"."community_join_requests" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."community_memberships" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "community_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "role" "text" DEFAULT 'member'::"text" NOT NULL,
    "joined_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "is_banned" boolean DEFAULT false NOT NULL
);


ALTER TABLE "app"."community_memberships" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."community_poll_votes" (
    "poll_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "option_index" integer NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."community_poll_votes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."community_polls" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "community_id" "uuid" NOT NULL,
    "question" "text" NOT NULL,
    "options" "text"[] NOT NULL,
    "is_multiple" boolean DEFAULT false NOT NULL,
    "is_closed" boolean DEFAULT false NOT NULL,
    "created_by_user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "closed_at" timestamp with time zone
);


ALTER TABLE "app"."community_polls" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."community_post_reactions" (
    "post_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "emoji" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."community_post_reactions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."community_posts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "community_id" "uuid" NOT NULL,
    "author_id" "uuid" NOT NULL,
    "content" "text" NOT NULL,
    "is_pinned" boolean DEFAULT false NOT NULL,
    "is_deleted" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "type" "text" DEFAULT 'text'::"text" NOT NULL,
    "media_url" "text",
    "reply_to_post_id" "uuid",
    "edited_at" timestamp with time zone
);


ALTER TABLE "app"."community_posts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."community_read_states" (
    "community_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "last_read_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."community_read_states" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."community_stories" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "community_id" "uuid" NOT NULL,
    "author_id" "uuid" NOT NULL,
    "type" "text" DEFAULT 'image'::"text" NOT NULL,
    "media_url" "text",
    "caption" "text",
    "bg_color" "text",
    "text_content" "text",
    "category" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "expires_at" timestamp with time zone DEFAULT ("now"() + '24:00:00'::interval) NOT NULL,
    "is_deleted" boolean DEFAULT false NOT NULL
);


ALTER TABLE "app"."community_stories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."community_story_views" (
    "story_id" "uuid" NOT NULL,
    "viewer_id" "uuid" NOT NULL,
    "viewed_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."community_story_views" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."competitive_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tournament_id" "uuid",
    "league_id" "uuid",
    "match_id" "uuid",
    "league_match_id" "uuid",
    "participant_id" "uuid",
    "event_type" character varying(30) NOT NULL,
    "event_data" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "app"."competitive_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."course_domains" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "sort_order" integer DEFAULT 0 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."course_domains" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."course_enrollments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "course_id" "uuid" NOT NULL,
    "enrolled_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."course_enrollments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."course_resources" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "unit_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "resource_type" "text" NOT NULL,
    "storage_bucket" "text",
    "storage_path" "text",
    "external_url" "text",
    "sort_order" integer DEFAULT 0 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."course_resources" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."course_units" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "domain_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "sort_order" integer DEFAULT 0 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."course_units" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."courses" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "program_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "credits" integer,
    "prerequisites" "text",
    "instructor" "text"
);


ALTER TABLE "app"."courses" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."direct_conversations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_a" "uuid" NOT NULL,
    "user_b" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "last_message_at" timestamp with time zone,
    CONSTRAINT "direct_conversations_order" CHECK (("user_a" < "user_b"))
);


ALTER TABLE "app"."direct_conversations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."direct_message_read_states" (
    "conversation_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "last_read_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."direct_message_read_states" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."direct_messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "conversation_id" "uuid" NOT NULL,
    "sender_id" "uuid" NOT NULL,
    "content" "text",
    "type" "text" DEFAULT 'text'::"text" NOT NULL,
    "media_url" "text",
    "reply_to_message_id" "uuid",
    "is_deleted" boolean DEFAULT false NOT NULL,
    "edited_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."direct_messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."exercises" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "course_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "resource_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."exercises" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."free_video_overlays" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "free_video_id" "uuid" NOT NULL,
    "layers" "jsonb" NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."free_video_overlays" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."free_video_render_jobs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "free_video_id" "uuid" NOT NULL,
    "job_type" "text" NOT NULL,
    "status" "text" NOT NULL,
    "error_message" "text",
    "metadata" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "started_at" timestamp with time zone,
    "completed_at" timestamp with time zone
);


ALTER TABLE "app"."free_video_render_jobs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."free_videos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "title" "text",
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "moderation_status" "text" DEFAULT 'published'::"text" NOT NULL,
    "moderation_flags" "jsonb",
    "moderated_by_admin_id" "uuid",
    "moderated_at" timestamp with time zone,
    "parent_video_type" "text",
    "parent_video_id" "uuid",
    "remix_type" "text" DEFAULT 'none'::"text" NOT NULL,
    "video_asset_id" "uuid",
    "is_deleted" boolean DEFAULT false NOT NULL,
    "deleted_at" timestamp with time zone,
    "allow_download" boolean DEFAULT false NOT NULL
);


ALTER TABLE "app"."free_videos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."hero_overlay_animations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "config" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."hero_overlay_animations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."hero_overlays" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "playlist_item_id" "uuid" NOT NULL,
    "layers" "jsonb" NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."hero_overlays" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."hero_overlays_tv" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "playlist_item_id" "uuid" NOT NULL,
    "overlay_type" "text" NOT NULL,
    "config" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "start_at_seconds" numeric(8,3) DEFAULT 0 NOT NULL,
    "end_at_seconds" numeric(8,3) DEFAULT 0 NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "hero_overlays_tv_overlay_type_check" CHECK (("overlay_type" = ANY (ARRAY['text'::"text", 'image'::"text", 'banner'::"text", 'ticker'::"text", 'shape'::"text"])))
);


ALTER TABLE "app"."hero_overlays_tv" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."hero_playlist" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "slot" "text" NOT NULL,
    "media_type" "text" DEFAULT 'video'::"text" NOT NULL,
    "base_video_url" "text",
    "base_image_url" "text",
    "title" "text",
    "subtitle" "text",
    "sort_order" integer,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "tv_timeline_duration_seconds" integer,
    "tv_timeline_version" integer,
    "video_asset_id" "uuid",
    CONSTRAINT "hero_playlist_media_type_check" CHECK (("media_type" = ANY (ARRAY['video'::"text", 'image'::"text"])))
);


ALTER TABLE "app"."hero_playlist" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."hero_renders" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "playlist_item_id" "uuid" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "render_url" "text",
    "logs" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "hero_renders_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'processing'::"text", 'done'::"text", 'failed'::"text"])))
);


ALTER TABLE "app"."hero_renders" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."hero_renders_tv" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "playlist_item_id" "uuid" NOT NULL,
    "status" "text" NOT NULL,
    "render_url" "text",
    "meta" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "error_message" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "started_at" timestamp with time zone,
    "finished_at" timestamp with time zone,
    CONSTRAINT "hero_renders_tv_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'processing'::"text", 'success'::"text", 'failed'::"text"])))
);


ALTER TABLE "app"."hero_renders_tv" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."hero_video_jobs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "context" "text" NOT NULL,
    "source_filename" "text",
    "source_size_bytes" bigint,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "log" "text",
    "hero_video_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "hero_video_jobs_context_check" CHECK (("context" = ANY (ARRAY['landing'::"text", 'student_home'::"text", 'minisite'::"text"]))),
    CONSTRAINT "hero_video_jobs_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'processing'::"text", 'success'::"text", 'error'::"text"])))
);


ALTER TABLE "app"."hero_video_jobs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."instructors" (
    "id" "uuid" NOT NULL,
    "full_name" "text",
    "bio" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "phone" "text",
    "payout_phone" "text",
    "payout_operator" "text",
    "speciality" "text"
);


ALTER TABLE "app"."instructors" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."landing_announcements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "text" "text" NOT NULL,
    "sort_order" integer,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."landing_announcements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."landing_config" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "hero_badge_text" "text",
    "hero_title" "text",
    "hero_subtitle" "text",
    "primary_color" "text",
    "secondary_color" "text",
    "accent_color" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "video_asset_id" "uuid",
    "hero_video_url" "text",
    "hero_storage_path" "text"
);


ALTER TABLE "app"."landing_config" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."landing_partners" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text",
    "logo_url" "text",
    "website_url" "text",
    "sort_order" integer,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."landing_partners" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."landing_videos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text",
    "sort_order" integer,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "media_type" "text" DEFAULT 'video'::"text" NOT NULL,
    "video_asset_id" "uuid"
);


ALTER TABLE "app"."landing_videos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."landing_why_cards" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "subtitle" "text",
    "icon_key" "text",
    "sort_order" integer,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."landing_why_cards" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."league_matches" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "league_id" "uuid" NOT NULL,
    "participant1_id" "uuid" NOT NULL,
    "participant2_id" "uuid" NOT NULL,
    "scheduled_at" timestamp with time zone,
    "started_at" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "status" character varying(20) DEFAULT 'scheduled'::character varying NOT NULL,
    "winner_id" "uuid",
    "participant1_score" integer DEFAULT 0,
    "participant2_score" integer DEFAULT 0,
    "participant1_elo_change" integer DEFAULT 0,
    "participant2_elo_change" integer DEFAULT 0,
    "participant1_points" integer DEFAULT 0,
    "participant2_points" integer DEFAULT 0,
    "notes" "text"
);


ALTER TABLE "app"."league_matches" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."league_participations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "league_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "division" character varying(20) DEFAULT 'main'::character varying NOT NULL,
    "rank_position" integer,
    "points" integer DEFAULT 0,
    "matches_played" integer DEFAULT 0,
    "matches_won" integer DEFAULT 0,
    "matches_lost" integer DEFAULT 0,
    "matches_drawn" integer DEFAULT 0,
    "win_rate" numeric(5,2) GENERATED ALWAYS AS (
CASE
    WHEN ("matches_played" > 0) THEN ((("matches_won")::numeric / ("matches_played")::numeric) * (100)::numeric)
    ELSE (0)::numeric
END) STORED,
    "elo_rating" integer DEFAULT 1000,
    "elo_rating_start" integer DEFAULT 1000,
    "elo_rating_end" integer,
    "elo_change" integer DEFAULT 0,
    "promotion_points" integer DEFAULT 0,
    "demotion_points" integer DEFAULT 0,
    "current_streak" integer DEFAULT 0,
    "best_streak" integer DEFAULT 0,
    "season_points" integer DEFAULT 0,
    "joined_at" timestamp with time zone DEFAULT "now"(),
    "last_match_at" timestamp with time zone,
    "status" character varying(20) DEFAULT 'active'::character varying NOT NULL
);


ALTER TABLE "app"."league_participations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."leagues" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" character varying(100) NOT NULL,
    "description" "text",
    "game_type" character varying(50) NOT NULL,
    "league_type" character varying(20) DEFAULT 'seasonal'::character varying NOT NULL,
    "division" character varying(20) DEFAULT 'main'::character varying NOT NULL,
    "season_number" integer DEFAULT 1,
    "season_start" timestamp with time zone DEFAULT "now"(),
    "season_end" timestamp with time zone,
    "max_players" integer DEFAULT 1000,
    "current_players" integer DEFAULT 0,
    "promotion_division" character varying(20),
    "relegation_division" character varying(20),
    "promotion_count" integer DEFAULT 2,
    "relegation_count" integer DEFAULT 2,
    "min_elo" integer DEFAULT 0,
    "max_elo" integer DEFAULT 3000,
    "is_active" boolean DEFAULT true,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "settings" "jsonb" DEFAULT '{}'::"jsonb"
);


ALTER TABLE "app"."leagues" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."legacy_video_write_attempts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "table_name" "text" NOT NULL,
    "operation" "text" NOT NULL,
    "column_name" "text" NOT NULL,
    "old_value" "jsonb",
    "new_value" "jsonb",
    "actor_role" "text",
    "actor_sub" "text",
    "actor_uid" "uuid",
    "actor_current_user" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."legacy_video_write_attempts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."marketplace_cart_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "cart_id" "uuid" NOT NULL,
    "listing_id" "uuid" NOT NULL,
    "quantity" integer NOT NULL,
    "unit_price" numeric,
    "currency" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "marketplace_cart_items_quantity_check" CHECK (("quantity" > 0))
);


ALTER TABLE "app"."marketplace_cart_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."marketplace_carts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "status" "text" DEFAULT 'open'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."marketplace_carts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."marketplace_categories" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "parent_id" "uuid",
    "code" "text" NOT NULL,
    "label" "text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."marketplace_categories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."marketplace_listing_bookmarks" (
    "user_id" "uuid" NOT NULL,
    "listing_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."marketplace_listing_bookmarks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."marketplace_listing_media" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "listing_id" "uuid" NOT NULL,
    "media_type" "text" DEFAULT 'image'::"text" NOT NULL,
    "title" "text",
    "description" "text",
    "storage_bucket" "text" DEFAULT 'marketplace-media'::"text" NOT NULL,
    "storage_path" "text",
    "external_url" "text",
    "sort_order" integer DEFAULT 0 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."marketplace_listing_media" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."marketplace_listings" (
    "id" "uuid" NOT NULL,
    "merchant_id" "uuid" NOT NULL,
    "review_status" "text" DEFAULT 'draft'::"text" NOT NULL,
    "review_reason" "text",
    "submitted_at" timestamp with time zone,
    "reviewed_at" timestamp with time zone,
    "reviewed_by" "uuid",
    "title" "text" NOT NULL,
    "short_description" "text" NOT NULL,
    "description" "text",
    "type" "text" NOT NULL,
    "category" "text",
    "organization_name" "text" NOT NULL,
    "organization_logo_url" "text",
    "country" "text" NOT NULL,
    "city" "text" NOT NULL,
    "price_from" numeric,
    "price_to" numeric,
    "currency" "text",
    "min_order_qty" integer,
    "lead_time_days" integer,
    "is_ready_to_ship" boolean DEFAULT false NOT NULL,
    "reactions_count" integer DEFAULT 0 NOT NULL,
    "comments_count" integer DEFAULT 0 NOT NULL,
    "status" "text" DEFAULT 'draft'::"text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "is_featured" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "category_id" "uuid",
    "sub_category_id" "uuid",
    "cover_url" "text",
    "video_url" "text",
    "rating_avg" numeric(2,1) DEFAULT 0 NOT NULL,
    "rating_count" integer DEFAULT 0 NOT NULL,
    "sales_count" integer DEFAULT 0 NOT NULL,
    "views_count" integer DEFAULT 0 NOT NULL,
    "tags" "text"[],
    "specifications" "jsonb",
    "variants" "jsonb"
);


ALTER TABLE "app"."marketplace_listings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."marketplace_merchant_balances" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "merchant_id" "uuid" NOT NULL,
    "available_balance" numeric DEFAULT 0 NOT NULL,
    "pending_balance" numeric DEFAULT 0 NOT NULL,
    "total_earned" numeric DEFAULT 0 NOT NULL,
    "total_commission" numeric DEFAULT 0 NOT NULL,
    "currency" "text" DEFAULT 'XOF'::"text" NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."marketplace_merchant_balances" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."marketplace_merchants" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "owner_user_id" "uuid",
    "name" "text" NOT NULL,
    "slug" "text",
    "logo_url" "text",
    "banner_url" "text",
    "description" "text",
    "country" "text",
    "city" "text",
    "address" "text",
    "contact_email" "text",
    "contact_phone" "text",
    "whatsapp_url" "text",
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "is_verified" boolean DEFAULT false NOT NULL,
    "verification_level" "text" DEFAULT 'none'::"text" NOT NULL,
    "bio" "text",
    "display_name" "text",
    "rating_avg" numeric(2,1) DEFAULT 0 NOT NULL,
    "total_sales" integer DEFAULT 0 NOT NULL,
    "total_products" integer DEFAULT 0 NOT NULL,
    "payout_phone" "text",
    "payout_operator" "text"
);


ALTER TABLE "app"."marketplace_merchants" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."marketplace_order_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "order_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "quantity" integer DEFAULT 1 NOT NULL,
    "unit_price" numeric,
    "currency" "text"
);


ALTER TABLE "app"."marketplace_order_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."marketplace_orders" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "merchant_id" "uuid" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "total_amount" numeric,
    "currency" "text",
    "delivery_mode" "text",
    "shipping_address" "text",
    "student_notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."marketplace_orders" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."marketplace_payments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "order_id" "uuid" NOT NULL,
    "buyer_id" "uuid" NOT NULL,
    "merchant_id" "uuid" NOT NULL,
    "gross_amount" numeric NOT NULL,
    "commission_rate" numeric DEFAULT 0.10 NOT NULL,
    "commission_amount" numeric DEFAULT 0 NOT NULL,
    "net_amount" numeric DEFAULT 0 NOT NULL,
    "currency" "text" DEFAULT 'XOF'::"text" NOT NULL,
    "payment_method" "text",
    "payment_provider" "text",
    "payment_provider_ref" "text",
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "escrow_released_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "ligdicash_token" "text",
    "ligdicash_transaction_id" "text",
    "phone_number" "text"
);


ALTER TABLE "app"."marketplace_payments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."marketplace_products" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "merchant_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "price" numeric,
    "currency" "text",
    "category" "text",
    "main_image_url" "text",
    "stock_status" "text",
    "status" "text" DEFAULT 'draft'::"text" NOT NULL,
    "is_featured" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."marketplace_products" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."marketplace_reviews" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "listing_id" "uuid" NOT NULL,
    "buyer_id" "uuid" NOT NULL,
    "order_id" "uuid",
    "rating" integer NOT NULL,
    "title" "text",
    "content" "text",
    "media_urls" "text"[],
    "is_verified_purchase" boolean DEFAULT false NOT NULL,
    "seller_reply" "text",
    "seller_replied_at" timestamp with time zone,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "marketplace_reviews_rating_check" CHECK ((("rating" >= 1) AND ("rating" <= 5)))
);


ALTER TABLE "app"."marketplace_reviews" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."merchant_profiles" (
    "user_id" "uuid" NOT NULL,
    "display_name" "text" NOT NULL,
    "logo_url" "text",
    "bio" "text",
    "country" "text",
    "city" "text",
    "is_verified" boolean DEFAULT false NOT NULL,
    "verification_level" "text" DEFAULT 'none'::"text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."merchant_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."moderation_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "entity_type" "text" NOT NULL,
    "entity_id" "uuid" NOT NULL,
    "source" "text" NOT NULL,
    "reason" "text",
    "details" "jsonb",
    "created_by_user_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "resolved_at" timestamp with time zone,
    "resolved_by_user_id" "uuid",
    "resolution" "text"
);


ALTER TABLE "app"."moderation_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."notification_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "domain" "text" NOT NULL,
    "event_type" "text" NOT NULL,
    "payload" "jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "processed_at" timestamp with time zone,
    "attempt_count" integer DEFAULT 0 NOT NULL,
    "last_error" "text"
);


ALTER TABLE "app"."notification_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."official_announcements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "body" "text" NOT NULL,
    "summary" "text",
    "urgency_level" "text" DEFAULT 'info'::"text" NOT NULL,
    "category" "text",
    "target_roles" "text"[] DEFAULT ARRAY['student'::"text"],
    "target_countries" "text"[],
    "target_study_levels" "text"[],
    "target_university_ids" "uuid"[],
    "is_published" boolean DEFAULT false NOT NULL,
    "visible_from" timestamp with time zone,
    "visible_until" timestamp with time zone,
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."official_announcements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."online_course_certificates" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "enrollment_id" "uuid" NOT NULL,
    "issued_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "verification_code" "text" NOT NULL,
    "pdf_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."online_course_certificates" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."online_course_enrollment_messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "enrollment_id" "uuid" NOT NULL,
    "sender_role" "text" NOT NULL,
    "audience" "text" NOT NULL,
    "content" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."online_course_enrollment_messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."online_course_enrollments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "course_id" "uuid" NOT NULL,
    "student_id" "uuid" NOT NULL,
    "access_type" "text" DEFAULT 'free'::"text" NOT NULL,
    "starts_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "expires_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "contact_phone" "text",
    "preferred_channel" "text",
    "payment_method" "text",
    "wants_invoice" boolean,
    "company_name" "text",
    "notes" "text",
    "last_message_at" timestamp with time zone,
    "student_last_read_at" timestamp with time zone,
    "admin_last_read_at" timestamp with time zone
);


ALTER TABLE "app"."online_course_enrollments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."online_course_forum_messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "thread_id" "uuid" NOT NULL,
    "student_id" "uuid",
    "sender_role" "text" NOT NULL,
    "content" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "instructor_id" "uuid"
);


ALTER TABLE "app"."online_course_forum_messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."online_course_forum_threads" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "course_id" "uuid" NOT NULL,
    "student_id" "uuid",
    "title" "text" NOT NULL,
    "is_pinned" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."online_course_forum_threads" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."online_course_instructors" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "course_id" "uuid" NOT NULL,
    "instructor_id" "uuid" NOT NULL,
    "role" "text" DEFAULT 'owner'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."online_course_instructors" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."online_course_lesson_media" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "lesson_id" "uuid" NOT NULL,
    "media_type" "text" NOT NULL,
    "title" "text",
    "description" "text",
    "storage_bucket" "text",
    "storage_path" "text",
    "external_url" "text",
    "duration_seconds" integer,
    "sort_order" integer,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."online_course_lesson_media" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."online_course_lesson_progress" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "enrollment_id" "uuid" NOT NULL,
    "lesson_id" "uuid" NOT NULL,
    "last_position_seconds" integer DEFAULT 0,
    "completed_at" timestamp with time zone,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."online_course_lesson_progress" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."online_course_lessons" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "section_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "lesson_type" "text" DEFAULT 'video'::"text" NOT NULL,
    "sort_order" integer,
    "is_published" boolean DEFAULT true NOT NULL,
    "estimated_minutes" integer,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."online_course_lessons" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."online_course_live_session_participants" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "session_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "role" "text" NOT NULL,
    "livekit_identity" "text",
    "joined_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "left_at" timestamp with time zone,
    "is_banned" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "online_course_live_session_participants_role_check" CHECK (("role" = ANY (ARRAY['student'::"text", 'instructor'::"text", 'admin'::"text"])))
);


ALTER TABLE "app"."online_course_live_session_participants" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."online_course_live_sessions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "course_id" "uuid" NOT NULL,
    "lesson_id" "uuid",
    "title" "text" NOT NULL,
    "description" "text",
    "provider" "text",
    "join_url" "text",
    "start_at" timestamp with time zone NOT NULL,
    "end_at" timestamp with time zone,
    "replay_video_url" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "status" "text" DEFAULT 'draft'::"text" NOT NULL,
    "host_id" "uuid",
    "livekit_room_name" "text",
    "started_at" timestamp with time zone,
    "ended_at" timestamp with time zone,
    "approved_by_admin_id" "uuid",
    "replay_video_asset_id" "uuid"
);


ALTER TABLE "app"."online_course_live_sessions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."online_course_sections" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "course_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "sort_order" integer,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."online_course_sections" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."online_courses" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "short_description" "text",
    "full_description" "text",
    "category" "text",
    "level" "text",
    "language" "text",
    "estimated_hours" integer,
    "cover_image_url" "text",
    "price" numeric,
    "is_published" boolean DEFAULT false NOT NULL,
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "contact_phone" "text",
    "contact_whatsapp" "text",
    "contact_email" "text",
    "contact_website" "text",
    "contact_notes" "text"
);


ALTER TABLE "app"."online_courses" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."opportunities" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "short_description" "text" NOT NULL,
    "description" "text",
    "type" "text" NOT NULL,
    "category" "text",
    "organization_name" "text" NOT NULL,
    "organization_logo_url" "text",
    "country" "text" NOT NULL,
    "city" "text" NOT NULL,
    "is_remote_possible" boolean DEFAULT false NOT NULL,
    "contract_type" "text",
    "duration_months" integer,
    "start_date" "date",
    "application_deadline" "date",
    "status" "text" DEFAULT 'draft'::"text" NOT NULL,
    "is_featured" boolean DEFAULT false NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_by_user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "price" numeric(12,2) DEFAULT NULL::numeric,
    "reactions_count" integer DEFAULT 0 NOT NULL,
    "comments_count" integer DEFAULT 0 NOT NULL,
    "merchant_id" "uuid",
    "review_status" "text" DEFAULT 'draft'::"text" NOT NULL,
    "review_reason" "text",
    "submitted_at" timestamp with time zone,
    "reviewed_at" timestamp with time zone,
    "reviewed_by" "uuid",
    "price_from" numeric,
    "price_to" numeric,
    "currency" "text",
    "min_order_qty" integer,
    "lead_time_days" integer,
    "is_ready_to_ship" boolean DEFAULT false NOT NULL
);


ALTER TABLE "app"."opportunities" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."opportunity_applications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "opportunity_id" "uuid" NOT NULL,
    "student_id" "uuid" NOT NULL,
    "message" "text",
    "cv_url" "text",
    "extra_data" "jsonb",
    "status" "text" DEFAULT 'submitted'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "admin_notes" "text",
    "reviewed_at" timestamp with time zone,
    "reviewed_by" "uuid"
);


ALTER TABLE "app"."opportunity_applications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."opportunity_bookmarks" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "opportunity_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "listing_id" "uuid"
);


ALTER TABLE "app"."opportunity_bookmarks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."opportunity_comments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "opportunity_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "content" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "listing_id" "uuid"
);


ALTER TABLE "app"."opportunity_comments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."opportunity_inquiries" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "opportunity_id" "uuid" NOT NULL,
    "buyer_id" "uuid" NOT NULL,
    "merchant_id" "uuid" NOT NULL,
    "message" "text" NOT NULL,
    "quantity" integer,
    "budget" numeric,
    "status" "text" DEFAULT 'open'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "last_message_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "listing_id" "uuid"
);


ALTER TABLE "app"."opportunity_inquiries" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."opportunity_inquiry_messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "inquiry_id" "uuid" NOT NULL,
    "sender_id" "uuid" NOT NULL,
    "content" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."opportunity_inquiry_messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."opportunity_reactions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "opportunity_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "reaction_type" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "listing_id" "uuid",
    CONSTRAINT "opportunity_reactions_reaction_type_check" CHECK (("reaction_type" = ANY (ARRAY['like'::"text", 'love'::"text"])))
);


ALTER TABLE "app"."opportunity_reactions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."opportunity_types" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "code" "text" NOT NULL,
    "label" "text" NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."opportunity_types" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."opportunity_views" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "last_viewed_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."opportunity_views" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."payment_proofs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "payment_id" "uuid" NOT NULL,
    "proof_type" "text" NOT NULL,
    "file_path" "text" NOT NULL,
    "uploaded_by" "uuid" NOT NULL,
    "uploaded_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "note" "text"
);


ALTER TABLE "app"."payment_proofs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."payment_receipts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "payment_id" "uuid" NOT NULL,
    "receipt_number" "text" NOT NULL,
    "issued_by" "uuid" NOT NULL,
    "issued_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "snapshot" "jsonb" NOT NULL
);


ALTER TABLE "app"."payment_receipts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."payout_queue" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "beneficiary_type" "text" NOT NULL,
    "beneficiary_user_id" "uuid",
    "beneficiary_phone" "text",
    "amount" numeric NOT NULL,
    "currency" "text" DEFAULT 'XOF'::"text" NOT NULL,
    "reason" "text",
    "source_payment_id" "uuid",
    "source_marketplace_payment_id" "uuid",
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "ligdicash_token" "text",
    "ligdicash_transaction_id" "text",
    "processed_at" timestamp with time zone,
    "error_message" "text",
    "retry_count" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."payout_queue" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."platform_ledger" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "transaction_type" "text" NOT NULL,
    "amount" numeric NOT NULL,
    "currency" "text" DEFAULT 'XOF'::"text" NOT NULL,
    "direction" "text" NOT NULL,
    "counterpart_type" "text",
    "counterpart_id" "uuid",
    "reference_id" "uuid",
    "description" "text",
    "balance_after" numeric,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."platform_ledger" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_ai_config" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "config_key" "text" NOT NULL,
    "config_value" "text",
    "description" "text",
    "updated_by" "uuid",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."prep_ai_config" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_ai_conversations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "title" "text",
    "subject" "text",
    "message_count" integer DEFAULT 0 NOT NULL,
    "total_tokens_used" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."prep_ai_conversations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_ai_corrections" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "question_id" "uuid",
    "student_answer" "text" NOT NULL,
    "is_correct" boolean,
    "ai_correction" "text" NOT NULL,
    "ai_explanation" "text",
    "source_chunks" "uuid"[],
    "confidence_score" double precision,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."prep_ai_corrections" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_ai_generations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_by" "uuid",
    "subject_id" "uuid",
    "generation_type" "text" DEFAULT 'mcq'::"text" NOT NULL,
    "input_params" "jsonb",
    "output_json" "jsonb",
    "status" "text" DEFAULT 'proposed'::"text" NOT NULL,
    "error_message" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."prep_ai_generations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_ai_messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "conversation_id" "uuid" NOT NULL,
    "role" "text" DEFAULT 'user'::"text" NOT NULL,
    "content" "text" NOT NULL,
    "tokens_used" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."prep_ai_messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_ai_usage_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "generation_id" "uuid",
    "subject_id" "uuid",
    "endpoint" "text" DEFAULT 'ai/prep/generate'::"text" NOT NULL,
    "input_hash" "text",
    "status" "text" DEFAULT 'started'::"text" NOT NULL,
    "duration_ms" integer,
    "metadata" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."prep_ai_usage_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_assignment_submissions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "assignment_id" "uuid" NOT NULL,
    "student_id" "uuid" NOT NULL,
    "answer_content" "jsonb",
    "attachments" "jsonb" DEFAULT '[]'::"jsonb",
    "submitted_at" timestamp with time zone DEFAULT "now"(),
    "status" "text" DEFAULT 'submitted'::"text" NOT NULL,
    "teacher_score" integer,
    "teacher_comment" "text",
    "teacher_graded_at" timestamp with time zone,
    "ai_score" integer,
    "ai_correction" "text",
    "ai_explanation" "text",
    "ai_source_chunks" "uuid"[],
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."prep_assignment_submissions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_assignments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "teacher_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "concours_type" "text",
    "subject_name" "text",
    "assignment_type" "text" DEFAULT 'qcm'::"text" NOT NULL,
    "content" "jsonb",
    "attachments" "jsonb" DEFAULT '[]'::"jsonb",
    "deadline" timestamp with time zone,
    "max_score" integer DEFAULT 20,
    "is_published" boolean DEFAULT false NOT NULL,
    "target_group" "text" DEFAULT 'all'::"text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."prep_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_attempts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "question_id" "uuid" NOT NULL,
    "attempt_type" "text" DEFAULT 'training'::"text" NOT NULL,
    "selected_answer" "text",
    "is_correct" boolean,
    "time_spent_sec" integer,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."prep_attempts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_badges" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "code" "text" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "emoji" "text" DEFAULT '­ƒÅà'::"text",
    "xp_reward" integer DEFAULT 0 NOT NULL,
    "condition_type" "text",
    "condition_value" integer DEFAULT 0,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."prep_badges" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_chapters" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "subject_id" "uuid" NOT NULL,
    "slug" "text" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "sort_order" integer,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."prep_chapters" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_chunks" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "subject_id" "uuid",
    "bank_id" "uuid",
    "content" "text" NOT NULL,
    "concours_type" "text",
    "year" "text",
    "source" "text" DEFAULT 'existing_questions'::"text",
    "embedding" "extensions"."vector"(1536),
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "app"."prep_chunks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_doc_chunks" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "source_document_id" "uuid" NOT NULL,
    "chunk_index" integer NOT NULL,
    "content" "text" NOT NULL,
    "metadata" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "embedding" "extensions"."vector"(1536),
    "chunk_type" "text" DEFAULT 'content'::"text",
    "concours_type" "text",
    "subject_name" "text",
    "year" "text",
    "question_number" integer,
    "is_correction" boolean DEFAULT false,
    "token_count" integer
);


ALTER TABLE "app"."prep_doc_chunks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_exam_blanc_attempts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "exam_blanc_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "score" integer,
    "total_questions" integer,
    "percentage" numeric(5,2),
    "answers" "jsonb" DEFAULT '[]'::"jsonb",
    "started_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "finished_at" timestamp with time zone,
    "duration_seconds" integer
);


ALTER TABLE "app"."prep_exam_blanc_attempts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_exam_blancs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "concours_type" "text" DEFAULT 'TOUS'::"text" NOT NULL,
    "total_questions" integer DEFAULT 50 NOT NULL,
    "duration_minutes" integer DEFAULT 120 NOT NULL,
    "sections" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "is_published" boolean DEFAULT false NOT NULL,
    "generation_status" "text" DEFAULT 'ready'::"text" NOT NULL,
    "generated_by" "text" DEFAULT 'system'::"text",
    "times_taken" integer DEFAULT 0 NOT NULL,
    "avg_score" numeric(5,2),
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."prep_exam_blancs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_exam_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "exam_id" "uuid" NOT NULL,
    "question_id" "uuid" NOT NULL,
    "sort_order" integer,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."prep_exam_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_exam_papers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "concours_type" "text" NOT NULL,
    "year" "text",
    "subject" "text",
    "paper_url" "text",
    "correction_url" "text",
    "difficulty" integer DEFAULT 1,
    "is_official" boolean DEFAULT false NOT NULL,
    "has_correction" boolean DEFAULT false NOT NULL,
    "uploaded_by" "uuid",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."prep_exam_papers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_exams" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_by" "uuid",
    "student_id" "uuid",
    "title" "text",
    "subject_id" "uuid",
    "level" "text",
    "mode" "text" DEFAULT 'practice'::"text" NOT NULL,
    "duration_sec" integer,
    "is_published" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."prep_exams" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_flashcard_decks" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "subject" "text",
    "concours_type" "text",
    "card_count" integer DEFAULT 0 NOT NULL,
    "created_by" "uuid",
    "is_public" boolean DEFAULT true NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."prep_flashcard_decks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_flashcard_progress" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "flashcard_id" "uuid" NOT NULL,
    "student_id" "uuid" NOT NULL,
    "ease_factor" numeric(4,2) DEFAULT 2.50 NOT NULL,
    "interval_days" integer DEFAULT 1 NOT NULL,
    "repetitions" integer DEFAULT 0 NOT NULL,
    "next_review_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "last_reviewed_at" timestamp with time zone,
    "quality_history" integer[] DEFAULT '{}'::integer[],
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."prep_flashcard_progress" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_flashcards" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "deck_id" "uuid" NOT NULL,
    "front_text" "text" NOT NULL,
    "back_text" "text" NOT NULL,
    "subject" "text",
    "tags" "text"[] DEFAULT '{}'::"text"[],
    "image_url" "text",
    "created_by" "uuid",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."prep_flashcards" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_live_participants" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "session_id" "uuid" NOT NULL,
    "student_id" "uuid" NOT NULL,
    "joined_at" timestamp with time zone DEFAULT "now"(),
    "left_at" timestamp with time zone,
    "quiz_score" integer
);


ALTER TABLE "app"."prep_live_participants" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_live_sessions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "teacher_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "session_type" "text" DEFAULT 'revision'::"text" NOT NULL,
    "concours_type" "text",
    "subject_name" "text",
    "provider" "text" DEFAULT 'livekit'::"text",
    "join_url" "text",
    "start_at" timestamp with time zone NOT NULL,
    "end_at" timestamp with time zone,
    "replay_url" "text",
    "max_participants" integer DEFAULT 100,
    "status" "text" DEFAULT 'draft'::"text" NOT NULL,
    "quiz_template_id" "uuid",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."prep_live_sessions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_news_articles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "source_id" "uuid" NOT NULL,
    "article_url" "text" NOT NULL,
    "title" "text" NOT NULL,
    "summary" "text",
    "content" "text",
    "categories" "text"[] DEFAULT '{}'::"text"[],
    "published_at" timestamp with time zone,
    "fetched_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "injected_at" timestamp with time zone,
    "chunk_id" "uuid",
    "source_document_id" "uuid",
    "is_injected" boolean DEFAULT false NOT NULL,
    "content_length" integer DEFAULT 0
);


ALTER TABLE "app"."prep_news_articles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_news_sources" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "slug" "text" NOT NULL,
    "feed_url" "text" NOT NULL,
    "website_url" "text",
    "source_type" "text" DEFAULT 'rss'::"text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "categories_filter" "text"[] DEFAULT '{}'::"text"[],
    "last_fetched_at" timestamp with time zone,
    "articles_count" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."prep_news_sources" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_psychotech_profiles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "scores_by_type" "jsonb" DEFAULT '{}'::"jsonb",
    "total_tests" integer DEFAULT 0,
    "total_correct" integer DEFAULT 0,
    "avg_time_ms" integer,
    "weak_areas" "text"[] DEFAULT '{}'::"text"[],
    "strong_areas" "text"[] DEFAULT '{}'::"text"[],
    "current_difficulty" integer DEFAULT 1,
    "predicted_score" integer,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."prep_psychotech_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_psychotech_results" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "test_type" "text" NOT NULL,
    "difficulty" integer DEFAULT 1 NOT NULL,
    "is_correct" boolean NOT NULL,
    "time_spent_ms" integer,
    "question_data" "jsonb",
    "student_answer" "jsonb",
    "correct_answer" "jsonb",
    "explanation" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."prep_psychotech_results" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_question_banks" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "concours_type" "text",
    "subject" "text",
    "created_by" "uuid",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."prep_question_banks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_question_choices" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "question_id" "uuid" NOT NULL,
    "choice_label" "text",
    "choice_text" "text" NOT NULL,
    "is_correct" boolean DEFAULT false NOT NULL,
    "sort_order" integer,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."prep_question_choices" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_question_topics" (
    "question_id" "uuid" NOT NULL,
    "topic_id" "uuid" NOT NULL
);


ALTER TABLE "app"."prep_question_topics" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_questions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "subject_id" "uuid" NOT NULL,
    "chapter_id" "uuid",
    "source" "text" DEFAULT 'manual'::"text" NOT NULL,
    "question_type" "text" DEFAULT 'mcq'::"text" NOT NULL,
    "level" "text" DEFAULT 'beginner'::"text" NOT NULL,
    "mechanism" "text",
    "prompt_context" "text",
    "question" "text" NOT NULL,
    "explanation" "text",
    "correct_answer" "text",
    "estimated_time_sec" integer,
    "is_published" boolean DEFAULT false NOT NULL,
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "bank_id" "uuid",
    "content" "text",
    "options" "jsonb",
    "correct_index" integer,
    "difficulty" integer DEFAULT 1,
    "subject" "text",
    "tags" "text"[] DEFAULT '{}'::"text"[],
    "points" integer DEFAULT 10,
    "time_limit_seconds" integer DEFAULT 60,
    "image_url" "text",
    "is_active" boolean DEFAULT true,
    "concours_type" "text"
);


ALTER TABLE "app"."prep_questions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_quiz_attempts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "template_id" "uuid",
    "student_id" "uuid" NOT NULL,
    "questions_json" "jsonb",
    "answers_json" "jsonb",
    "score" integer DEFAULT 0 NOT NULL,
    "total_points" integer DEFAULT 0 NOT NULL,
    "correct_count" integer DEFAULT 0 NOT NULL,
    "question_count" integer DEFAULT 0 NOT NULL,
    "time_spent_seconds" integer DEFAULT 0 NOT NULL,
    "status" "text" DEFAULT 'completed'::"text" NOT NULL,
    "started_at" timestamp with time zone DEFAULT "now"(),
    "finished_at" timestamp with time zone DEFAULT "now"(),
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."prep_quiz_attempts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_quiz_templates" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "bank_id" "uuid",
    "concours_type" "text",
    "subject" "text",
    "question_count" integer DEFAULT 10 NOT NULL,
    "time_limit_minutes" integer,
    "shuffle_questions" boolean DEFAULT true NOT NULL,
    "is_exam_mode" boolean DEFAULT false NOT NULL,
    "passing_score" integer DEFAULT 60 NOT NULL,
    "created_by" "uuid",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."prep_quiz_templates" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_scan_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "extracted_text" "text",
    "answers" "text",
    "concours_type" "text",
    "image_size_bytes" integer,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "app"."prep_scan_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_source_documents" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_by" "uuid",
    "subject_id" "uuid",
    "year" integer,
    "doc_type" "text",
    "source_type" "text" DEFAULT 'pdf'::"text" NOT NULL,
    "storage_bucket" "text",
    "storage_path" "text",
    "extracted_text" "text",
    "status" "text" DEFAULT 'received'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "concours_type" "text",
    "subject_name" "text",
    "original_filename" "text",
    "page_count" integer,
    "extraction_method" "text" DEFAULT 'pdf-text'::"text",
    "has_correction" boolean DEFAULT false
);


ALTER TABLE "app"."prep_source_documents" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_student_badges" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "badge_id" "uuid" NOT NULL,
    "earned_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."prep_student_badges" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_student_progress" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "total_xp" integer DEFAULT 0 NOT NULL,
    "current_streak" integer DEFAULT 0 NOT NULL,
    "longest_streak" integer DEFAULT 0 NOT NULL,
    "total_correct" integer DEFAULT 0 NOT NULL,
    "total_answered" integer DEFAULT 0 NOT NULL,
    "last_activity_date" "date",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."prep_student_progress" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_student_weaknesses" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "subject_id" "uuid" NOT NULL,
    "total_questions" integer DEFAULT 0,
    "correct_answers" integer DEFAULT 0,
    "incorrect_answers" integer DEFAULT 0,
    "success_rate" numeric(5,2) DEFAULT 0.00,
    "avg_difficulty_attempted" numeric(3,2) DEFAULT 2.50,
    "avg_difficulty_failed" numeric(3,2) DEFAULT 2.50,
    "weakness_score" numeric(5,2) DEFAULT 50.00,
    "recommended_difficulty" integer DEFAULT 2,
    "priority_weight" numeric(3,2) DEFAULT 1.00,
    "needs_practice" boolean DEFAULT false,
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "app"."prep_student_weaknesses" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_subjects" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "slug" "text" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "sort_order" integer,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."prep_subjects" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_topic_predictions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "topic_id" "uuid" NOT NULL,
    "concours_type" "text" NOT NULL,
    "target_year" "text" NOT NULL,
    "probability_score" integer,
    "frequency_count" integer,
    "last_appeared_year" "text",
    "cycle_years" numeric(3,1),
    "reasoning" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."prep_topic_predictions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."prep_topics" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "category" "text",
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."prep_topics" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."programs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "university_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "degree_level" "text",
    "mode" "text",
    "duration_months" integer,
    "tuition_fees" numeric,
    "highlighted" boolean DEFAULT false NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "structure" "text",
    "career_outcomes" "text"
);


ALTER TABLE "app"."programs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."referral_commissions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "commercial_user_id" "uuid" NOT NULL,
    "student_id" "uuid" NOT NULL,
    "payment_id" "uuid" NOT NULL,
    "commission_rate" numeric(5,2) NOT NULL,
    "commission_amount" numeric(12,2) NOT NULL,
    "currency" "text" DEFAULT 'XOF'::"text" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "approved_at" timestamp with time zone,
    "paid_at" timestamp with time zone,
    "admin_note" "text"
);


ALTER TABLE "app"."referral_commissions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."revenue_split_rules" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "payment_reason" "text" NOT NULL,
    "beneficiary_type" "text" NOT NULL,
    "percentage" numeric NOT NULL,
    "max_amount" numeric,
    "min_amount" numeric DEFAULT 0,
    "is_active" boolean DEFAULT true NOT NULL,
    "description" "text",
    "priority" integer DEFAULT 10 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."revenue_split_rules" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."short_training_messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "registration_id" "uuid" NOT NULL,
    "sender_role" "text" NOT NULL,
    "sender_id" "uuid" NOT NULL,
    "content" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "short_training_messages_sender_role_check" CHECK (("sender_role" = ANY (ARRAY['student'::"text", 'admin'::"text"])))
);


ALTER TABLE "app"."short_training_messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."short_training_registration_messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "registration_id" "uuid" NOT NULL,
    "sender_role" "text" NOT NULL,
    "audience" "text" NOT NULL,
    "content" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."short_training_registration_messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."short_training_registrations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "session_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "status" "text" DEFAULT 'registered'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "contact_phone" "text",
    "preferred_channel" "text",
    "payment_method" "text",
    "wants_invoice" boolean,
    "company_name" "text",
    "notes" "text",
    "last_message_at" timestamp with time zone,
    "student_last_read_at" timestamp with time zone,
    "admin_last_read_at" timestamp with time zone,
    "payment_status" "text" DEFAULT 'pending'::"text",
    "payment_id" "uuid",
    "amount_due" numeric DEFAULT 0
);


ALTER TABLE "app"."short_training_registrations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."short_training_sessions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "training_id" "uuid" NOT NULL,
    "start_at" timestamp with time zone NOT NULL,
    "end_at" timestamp with time zone,
    "location" "text",
    "capacity" integer,
    "status" "text" DEFAULT 'open'::"text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."short_training_sessions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."short_trainings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "short_description" "text",
    "full_description" "text",
    "category" "text",
    "modality" "text",
    "duration_days" integer,
    "price" numeric,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."short_trainings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."student_dossier_documents" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "document_type" "text" NOT NULL,
    "storage_path" "text" NOT NULL,
    "status" "text" DEFAULT 'uploaded'::"text" NOT NULL,
    "uploaded_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "validated_at" timestamp with time zone,
    "validated_by" "uuid"
);


ALTER TABLE "app"."student_dossier_documents" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."student_home_announcements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "text" "text" NOT NULL,
    "sort_order" integer,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."student_home_announcements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."student_home_slots" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "domain" "text" NOT NULL,
    "object_id" "uuid" NOT NULL,
    "slot" "text" NOT NULL,
    "sort_order" integer,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "student_home_slots_domain_check" CHECK (("domain" = ANY (ARRAY['program'::"text", 'short_training_session'::"text", 'online_course'::"text", 'opportunity'::"text"])))
);


ALTER TABLE "app"."student_home_slots" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."student_home_videos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text",
    "sort_order" integer,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "media_type" "text" DEFAULT 'video'::"text" NOT NULL,
    "video_asset_id" "uuid"
);


ALTER TABLE "app"."student_home_videos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."students" (
    "id" "uuid" NOT NULL,
    "full_name" "text" NOT NULL,
    "phone" "text",
    "country" "text",
    "city" "text",
    "date_of_birth" "date",
    "avatar_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "bepc_year" integer,
    "bepc_institution" "text",
    "bepc_country" "text",
    "bepc_mention" "text",
    "bac_year" integer,
    "bac_series" "text",
    "bac_mention" "text",
    "bac_institution" "text",
    "bac_country" "text",
    "study_project_text" "text",
    "timezone" "text",
    "geo_latitude" numeric(9,6),
    "geo_longitude" numeric(9,6),
    "bio" "text",
    "website_url" "text"
);


ALTER TABLE "app"."students" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."subscription_plans" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "price" numeric NOT NULL,
    "currency" "text" DEFAULT 'XOF'::"text" NOT NULL,
    "duration_days" integer NOT NULL,
    "features" "jsonb" DEFAULT '[]'::"jsonb",
    "is_active" boolean DEFAULT true NOT NULL,
    "promo_percent" integer DEFAULT 0 NOT NULL,
    "promo_expires_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."subscription_plans" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."subscriptions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "plan_id" "uuid" NOT NULL,
    "status" "text" DEFAULT 'pending_payment'::"text" NOT NULL,
    "started_at" timestamp with time zone,
    "expires_at" timestamp with time zone,
    "payment_id" "uuid",
    "auto_renew" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."subscriptions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."support_conversations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "requester_user_id" "uuid" NOT NULL,
    "requester_role" "text" NOT NULL,
    "requester_display_name" "text" DEFAULT ''::"text" NOT NULL,
    "requester_email" "text" DEFAULT ''::"text" NOT NULL,
    "status" "text" DEFAULT 'open'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "last_message_at" timestamp with time zone,
    CONSTRAINT "support_conversations_status_check" CHECK (("status" = ANY (ARRAY['open'::"text", 'closed'::"text"])))
);


ALTER TABLE "app"."support_conversations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."support_messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "conversation_id" "uuid" NOT NULL,
    "sender_user_id" "uuid" NOT NULL,
    "sender_side" "text" NOT NULL,
    "content" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "type" "text" DEFAULT 'text'::"text" NOT NULL,
    "media_url" "text",
    CONSTRAINT "support_messages_sender_side_check" CHECK (("sender_side" = ANY (ARRAY['requester'::"text", 'admin'::"text"])))
);


ALTER TABLE "app"."support_messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."support_read_states" (
    "conversation_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "last_read_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."support_read_states" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_ai_config" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "config_key" "text" NOT NULL,
    "config_value" "text",
    "description" "text",
    "updated_by" "uuid",
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "app"."td_ai_config" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_ai_conversations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "title" "text",
    "subject" "text",
    "message_count" integer DEFAULT 0,
    "total_tokens_used" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "app"."td_ai_conversations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_ai_messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "conversation_id" "uuid",
    "role" "text" NOT NULL,
    "content" "text" NOT NULL,
    "tokens_used" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "app"."td_ai_messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_assignment_submissions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "assignment_id" "uuid" NOT NULL,
    "student_id" "uuid" NOT NULL,
    "answer_content" "jsonb",
    "attachments" "jsonb" DEFAULT '[]'::"jsonb",
    "submitted_at" timestamp with time zone DEFAULT "now"(),
    "status" "text" DEFAULT 'submitted'::"text" NOT NULL,
    "teacher_score" integer,
    "teacher_comment" "text",
    "teacher_graded_at" timestamp with time zone,
    "ai_score" integer,
    "ai_correction" "text",
    "ai_explanation" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."td_assignment_submissions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_assignments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "teacher_id" "uuid" NOT NULL,
    "enrollment_id" "uuid",
    "title" "text" NOT NULL,
    "description" "text",
    "subject" "text",
    "assignment_type" "text" DEFAULT 'exercise'::"text" NOT NULL,
    "content" "jsonb",
    "attachments" "jsonb" DEFAULT '[]'::"jsonb",
    "deadline" timestamp with time zone,
    "max_score" integer DEFAULT 20,
    "is_published" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."td_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_attendance" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "occurrence_id" "uuid" NOT NULL,
    "student_id" "uuid" NOT NULL,
    "status" "public"."td_attendance_status" NOT NULL,
    "joined_at" timestamp with time zone,
    "left_at" timestamp with time zone,
    "comment" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_by" "uuid"
);


ALTER TABLE "app"."td_attendance" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_badges" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "code" "text" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "emoji" "text",
    "xp_reward" integer DEFAULT 0,
    "condition_type" "text",
    "condition_value" integer DEFAULT 0,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "app"."td_badges" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_collections" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "program_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "position" integer,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."td_collections" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_daily_goals" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "goal_date" "date" DEFAULT CURRENT_DATE NOT NULL,
    "target_xp" integer DEFAULT 50 NOT NULL,
    "earned_xp" integer DEFAULT 0 NOT NULL,
    "completed" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."td_daily_goals" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_discipline_colors" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "field_id" "uuid",
    "field_name" "text" NOT NULL,
    "color_hex" "text" DEFAULT '#4F46E5'::"text" NOT NULL,
    "gradient_start" "text" DEFAULT '#4F46E5'::"text" NOT NULL,
    "gradient_end" "text" DEFAULT '#6366F1'::"text" NOT NULL,
    "icon_name" "text" DEFAULT 'school'::"text" NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."td_discipline_colors" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_doc_chunks" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "source_document_id" "uuid" NOT NULL,
    "chunk_index" integer,
    "content" "text",
    "metadata" "jsonb",
    "embedding" "extensions"."vector"(1536),
    "chunk_type" "text" DEFAULT 'content'::"text",
    "subject" "text",
    "university" "text",
    "study_year" "text",
    "token_count" integer,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."td_doc_chunks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_enrollments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "program_id" "uuid" NOT NULL,
    "collection_id" "uuid",
    "access_scope" "text" DEFAULT 'program'::"text" NOT NULL,
    "payment_id" "uuid",
    "access_status" "public"."td_enrollment_status" DEFAULT 'pending_payment'::"public"."td_enrollment_status" NOT NULL,
    "assignment_status" "public"."td_assignment_status" DEFAULT 'unassigned'::"public"."td_assignment_status" NOT NULL,
    "assigned_teacher_id" "uuid",
    "student_notes" "text",
    "admin_notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "activated_at" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "progress_pct" integer DEFAULT 0,
    "completed_sessions" integer DEFAULT 0,
    "total_sessions" integer DEFAULT 0
);


ALTER TABLE "app"."td_enrollments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_exam_papers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "concours_type" "text" NOT NULL,
    "year" "text",
    "subject" "text" NOT NULL,
    "paper_url" "text",
    "correction_url" "text",
    "difficulty" integer DEFAULT 1,
    "is_official" boolean DEFAULT false,
    "has_correction" boolean DEFAULT false,
    "uploaded_by" "uuid",
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "td_exam_papers_difficulty_check" CHECK ((("difficulty" >= 1) AND ("difficulty" <= 5)))
);


ALTER TABLE "app"."td_exam_papers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_fields" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_by" "uuid",
    "color_hex" "text" DEFAULT '#4F46E5'::"text",
    "icon_name" "text" DEFAULT 'school'::"text",
    "description" "text"
);


ALTER TABLE "app"."td_fields" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_flashcard_decks" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "subject" "text",
    "concours_type" "text",
    "card_count" integer DEFAULT 0,
    "created_by" "uuid",
    "is_public" boolean DEFAULT true,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "app"."td_flashcard_decks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_flashcard_progress" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "flashcard_id" "uuid",
    "student_id" "uuid" NOT NULL,
    "ease_factor" numeric(4,2) DEFAULT 2.50,
    "interval_days" integer DEFAULT 1,
    "repetitions" integer DEFAULT 0,
    "next_review_at" timestamp with time zone DEFAULT "now"(),
    "last_reviewed_at" timestamp with time zone,
    "quality_history" "jsonb" DEFAULT '[]'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "app"."td_flashcard_progress" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_flashcards" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "deck_id" "uuid",
    "front_text" "text" NOT NULL,
    "back_text" "text" NOT NULL,
    "subject" "text",
    "tags" "text"[] DEFAULT '{}'::"text"[],
    "image_url" "text",
    "created_by" "uuid",
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "app"."td_flashcards" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_generated_assignments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid",
    "title" "text" NOT NULL,
    "subject" "text" NOT NULL,
    "field" "text",
    "study_year" "text",
    "semester" "text",
    "mode" "text" DEFAULT 'exam'::"text",
    "question_count" integer DEFAULT 10,
    "total_points" integer DEFAULT 20,
    "duration_minutes" integer DEFAULT 60,
    "questions_json" "jsonb",
    "status" "text" DEFAULT 'generated'::"text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "app"."td_generated_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_leaderboard_cache" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "program_id" "uuid",
    "period_start" "date" NOT NULL,
    "period_end" "date" NOT NULL,
    "xp_earned" integer DEFAULT 0 NOT NULL,
    "rank" integer,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."td_leaderboard_cache" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_local_group_members" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "group_id" "uuid" NOT NULL,
    "student_id" "uuid" NOT NULL,
    "joined_at" timestamp with time zone DEFAULT "now"(),
    "status" "text" DEFAULT 'active'::"text"
);


ALTER TABLE "app"."td_local_group_members" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_local_groups" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "subject" "text" NOT NULL,
    "level" "text",
    "city" "text" DEFAULT 'Ouagadougou'::"text",
    "neighborhood" "text",
    "lat" numeric(10,7),
    "lng" numeric(10,7),
    "max_members" integer DEFAULT 8,
    "current_members" integer DEFAULT 0,
    "status" "text" DEFAULT 'forming'::"text" NOT NULL,
    "assigned_teacher_id" "uuid",
    "session_date" "date",
    "session_time" "text",
    "location_type" "text" DEFAULT 'to_define'::"text",
    "location_address" "text",
    "price_per_student" integer,
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."td_local_groups" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "td_enrollment_id" "uuid",
    "thread_type" "text" NOT NULL,
    "student_user_id" "uuid",
    "teacher_user_id" "uuid",
    "admin_user_id" "uuid",
    "sender_role" "text" NOT NULL,
    "sender_user_id" "uuid" NOT NULL,
    "content" "text" NOT NULL,
    "attachment_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "read_at" timestamp with time zone,
    CONSTRAINT "td_messages_sender_role_check" CHECK (("sender_role" = ANY (ARRAY['admin'::"text", 'student'::"text", 'teacher'::"text"]))),
    CONSTRAINT "td_messages_thread_type_check" CHECK (("thread_type" = ANY (ARRAY['student_admin'::"text", 'teacher_admin'::"text"])))
);


ALTER TABLE "app"."td_messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_physical_sessions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "group_id" "uuid" NOT NULL,
    "teacher_id" "uuid",
    "session_date" "date" NOT NULL,
    "start_time" "text",
    "end_time" "text",
    "location" "text",
    "status" "text" DEFAULT 'planned'::"text",
    "notes" "text",
    "attendance" "jsonb" DEFAULT '[]'::"jsonb",
    "teacher_rating" numeric(3,2),
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."td_physical_sessions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_programs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "field_id" "uuid" NOT NULL,
    "level" "text" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "modality" "public"."td_modality" DEFAULT 'online'::"public"."td_modality" NOT NULL,
    "price" numeric(12,2) NOT NULL,
    "currency" "text" DEFAULT 'XOF'::"text" NOT NULL,
    "status" "public"."td_program_status" DEFAULT 'draft'::"public"."td_program_status" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_by" "uuid",
    "cover_image_url" "text",
    "enrollment_count" integer DEFAULT 0,
    "avg_rating" numeric DEFAULT 0,
    "tags" "text"[] DEFAULT '{}'::"text"[],
    "is_featured" boolean DEFAULT false
);


ALTER TABLE "app"."td_programs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_question_banks" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "concours_type" "text",
    "subject" "text" NOT NULL,
    "created_by" "uuid",
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "app"."td_question_banks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_questions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "bank_id" "uuid",
    "question_type" "text" DEFAULT 'qcm'::"text" NOT NULL,
    "content" "text" NOT NULL,
    "options" "jsonb" DEFAULT '[]'::"jsonb",
    "correct_index" integer DEFAULT 0,
    "explanation" "text",
    "difficulty" integer DEFAULT 1,
    "subject" "text",
    "tags" "text"[] DEFAULT '{}'::"text"[],
    "points" integer DEFAULT 10,
    "time_limit_seconds" integer DEFAULT 60,
    "image_url" "text",
    "created_by" "uuid",
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "study_year" "text",
    "semester" "text",
    "field" "text",
    "generation_mode" "text",
    "generated_by" "uuid",
    CONSTRAINT "td_questions_difficulty_check" CHECK ((("difficulty" >= 1) AND ("difficulty" <= 5)))
);


ALTER TABLE "app"."td_questions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_quiz_attempts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "template_id" "uuid",
    "student_id" "uuid" NOT NULL,
    "questions_json" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "answers_json" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "score" numeric(5,2) DEFAULT 0,
    "total_points" integer DEFAULT 0,
    "correct_count" integer DEFAULT 0,
    "question_count" integer DEFAULT 0,
    "time_spent_seconds" integer DEFAULT 0,
    "status" "text" DEFAULT 'in_progress'::"text",
    "started_at" timestamp with time zone DEFAULT "now"(),
    "finished_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "app"."td_quiz_attempts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_quiz_templates" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "bank_id" "uuid",
    "concours_type" "text",
    "subject" "text",
    "question_count" integer DEFAULT 10,
    "time_limit_minutes" integer,
    "shuffle_questions" boolean DEFAULT true,
    "is_exam_mode" boolean DEFAULT false,
    "passing_score" integer DEFAULT 60,
    "created_by" "uuid",
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "app"."td_quiz_templates" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_resource_progress" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "resource_id" "uuid" NOT NULL,
    "status" "text" DEFAULT 'not_started'::"text" NOT NULL,
    "progress_pct" integer DEFAULT 0 NOT NULL,
    "last_position" "text",
    "started_at" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "time_spent_seconds" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."td_resource_progress" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_resources" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "program_id" "uuid",
    "collection_id" "uuid",
    "session_id" "uuid",
    "title" "text" NOT NULL,
    "description" "text",
    "kind" "public"."td_resource_kind" NOT NULL,
    "url" "text" NOT NULL,
    "is_required" boolean DEFAULT false NOT NULL,
    "position" integer,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_by" "uuid",
    "thumbnail_url" "text",
    "duration_seconds" integer,
    "file_size_bytes" bigint,
    "download_count" integer DEFAULT 0
);


ALTER TABLE "app"."td_resources" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_scan_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "extracted_text" "text",
    "solutions" "text",
    "field_name" "text",
    "level" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "app"."td_scan_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_session_occurrences" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "session_id" "uuid" NOT NULL,
    "enrollment_id" "uuid" NOT NULL,
    "teacher_id" "uuid",
    "scheduled_at" timestamp with time zone NOT NULL,
    "duration_minutes" integer NOT NULL,
    "status" "public"."td_session_occurrence_status" DEFAULT 'planned'::"public"."td_session_occurrence_status" NOT NULL,
    "location" "text",
    "meeting_url" "text",
    "student_notes" "text",
    "teacher_notes" "text",
    "admin_notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_by" "uuid"
);


ALTER TABLE "app"."td_session_occurrences" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_sessions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "collection_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "document_url" "text",
    "is_preview" boolean DEFAULT false NOT NULL,
    "position" integer,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "scheduled_at" timestamp with time zone,
    "duration_minutes" integer
);


ALTER TABLE "app"."td_sessions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_source_documents" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_by" "uuid",
    "subject" "text",
    "university" "text",
    "faculty" "text",
    "study_year" "text",
    "year" integer,
    "doc_type" "text",
    "source_type" "text" DEFAULT 'pdf'::"text",
    "storage_bucket" "text" DEFAULT 'prep-documents'::"text",
    "storage_path" "text",
    "extracted_text" "text",
    "status" "text" DEFAULT 'received'::"text",
    "concours_type" "text",
    "subject_name" "text",
    "original_filename" "text",
    "page_count" integer,
    "extraction_method" "text" DEFAULT 'pdf-text'::"text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."td_source_documents" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_streaks" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "current_streak" integer DEFAULT 0 NOT NULL,
    "longest_streak" integer DEFAULT 0 NOT NULL,
    "last_active_date" "date",
    "streak_frozen_until" "date",
    "total_active_days" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."td_streaks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_student_badges" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "badge_id" "uuid",
    "earned_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "app"."td_student_badges" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_student_profiles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "university" "text",
    "faculty" "text",
    "study_year" "text",
    "subjects_needed" "text"[] DEFAULT '{}'::"text"[],
    "neighborhood" "text",
    "availability_days" "text"[] DEFAULT '{}'::"text"[],
    "availability_times" "text"[] DEFAULT '{}'::"text"[],
    "max_group_size" integer DEFAULT 6,
    "is_seeking_group" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."td_student_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_student_progress" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "subject" "text",
    "total_questions_answered" integer DEFAULT 0,
    "correct_count" integer DEFAULT 0,
    "total_quizzes_completed" integer DEFAULT 0,
    "total_flashcards_reviewed" integer DEFAULT 0,
    "current_streak" integer DEFAULT 0,
    "longest_streak" integer DEFAULT 0,
    "total_xp" integer DEFAULT 0,
    "level" integer DEFAULT 1,
    "last_activity_date" "date",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "app"."td_student_progress" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_student_requests" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "field_id" "uuid",
    "level" "text",
    "subject" "text" NOT NULL,
    "description" "text",
    "preferred_modality" "public"."td_modality",
    "preferred_schedule" "text",
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "created_program_id" "uuid",
    "handled_by_admin_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."td_student_requests" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_teacher_availability" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "teacher_id" "uuid" NOT NULL,
    "weekday" smallint NOT NULL,
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "timezone" "text" DEFAULT 'Africa/Abidjan'::"text" NOT NULL,
    "is_recurring" boolean DEFAULT true NOT NULL,
    "valid_from" "date",
    "valid_until" "date",
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "td_teacher_availability_weekday_check" CHECK ((("weekday" >= 0) AND ("weekday" <= 6)))
);


ALTER TABLE "app"."td_teacher_availability" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_teacher_profiles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "teacher_id" "uuid" NOT NULL,
    "specialties" "text"[] DEFAULT '{}'::"text"[],
    "universities" "text"[] DEFAULT '{}'::"text"[],
    "neighborhoods" "text"[] DEFAULT '{}'::"text"[],
    "max_distance_km" integer DEFAULT 10,
    "hourly_rate" integer,
    "availability_days" "text"[] DEFAULT '{}'::"text"[],
    "availability_times" "text"[] DEFAULT '{}'::"text"[],
    "rating" numeric(3,2) DEFAULT 0,
    "total_sessions" integer DEFAULT 0,
    "total_reviews" integer DEFAULT 0,
    "is_available" boolean DEFAULT true,
    "bio" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."td_teacher_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_teachers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "full_name" "text" NOT NULL,
    "discipline" "text",
    "zone" "text",
    "levels" "text"[] DEFAULT ARRAY[]::"text"[],
    "availability" "text",
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "phone" "text",
    "payout_phone" "text",
    "payout_operator" "text"
);


ALTER TABLE "app"."td_teachers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."td_xp_log" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "amount" integer NOT NULL,
    "reason" "text" NOT NULL,
    "ref_type" "text",
    "ref_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."td_xp_log" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."tournament_matches" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tournament_id" "uuid" NOT NULL,
    "round_number" integer NOT NULL,
    "match_number" integer NOT NULL,
    "participant1_id" "uuid",
    "participant2_id" "uuid",
    "participant3_id" "uuid",
    "participant4_id" "uuid",
    "winner_id" "uuid",
    "status" character varying(20) DEFAULT 'scheduled'::character varying NOT NULL,
    "scheduled_at" timestamp with time zone,
    "started_at" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "best_of" integer DEFAULT 1,
    "participant1_score" integer DEFAULT 0,
    "participant2_score" integer DEFAULT 0,
    "participant3_score" integer DEFAULT 0,
    "participant4_score" integer DEFAULT 0,
    "next_match_id" "uuid",
    "bracket_position" character varying(20),
    "stream_url" "text",
    "notes" "text"
);


ALTER TABLE "app"."tournament_matches" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."tournament_participants" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tournament_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "registration_date" timestamp with time zone DEFAULT "now"(),
    "status" character varying(20) DEFAULT 'registered'::character varying NOT NULL,
    "seed_number" integer,
    "current_round" integer DEFAULT 0,
    "current_position" integer DEFAULT 0,
    "matches_played" integer DEFAULT 0,
    "matches_won" integer DEFAULT 0,
    "matches_lost" integer DEFAULT 0,
    "matches_drawn" integer DEFAULT 0,
    "points" integer DEFAULT 0,
    "elo_rating_before" integer DEFAULT 1000,
    "elo_rating_after" integer,
    "prize_won" integer DEFAULT 0,
    "eliminated_by" "uuid",
    "eliminated_at" timestamp with time zone,
    "notes" "text"
);


ALTER TABLE "app"."tournament_participants" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."tournament_rewards" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tournament_id" "uuid",
    "league_id" "uuid",
    "rank_from" integer NOT NULL,
    "rank_to" integer NOT NULL,
    "reward_type" character varying(20) NOT NULL,
    "reward_value" integer NOT NULL,
    "reward_name" character varying(100),
    "reward_description" "text",
    "reward_icon" character varying(50),
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "app"."tournament_rewards" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."tournaments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" character varying(100) NOT NULL,
    "description" "text",
    "game_type" character varying(50) NOT NULL,
    "tournament_type" character varying(20) DEFAULT 'elimination'::character varying NOT NULL,
    "format" character varying(20) DEFAULT 'single_elimination'::character varying NOT NULL,
    "max_participants" integer DEFAULT 16 NOT NULL,
    "min_participants" integer DEFAULT 4 NOT NULL,
    "current_participants" integer DEFAULT 0 NOT NULL,
    "status" character varying(20) DEFAULT 'draft'::character varying NOT NULL,
    "registration_start" timestamp with time zone DEFAULT "now"(),
    "registration_end" timestamp with time zone,
    "start_date" timestamp with time zone,
    "end_date" timestamp with time zone,
    "prize_pool" integer DEFAULT 0,
    "entry_fee" integer DEFAULT 0,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "settings" "jsonb" DEFAULT '{}'::"jsonb",
    "is_featured" boolean DEFAULT false,
    "is_private" boolean DEFAULT false,
    "elo_min" integer DEFAULT 0,
    "elo_max" integer DEFAULT 3000,
    "auto_start" boolean DEFAULT true
);


ALTER TABLE "app"."tournaments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."universities" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "slug" "text",
    "logo_url" "text",
    "country" "text",
    "city" "text",
    "website_url" "text",
    "description" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "tagline" "text",
    "banner_image_url" "text",
    "contact_email" "text",
    "contact_phone" "text",
    "address" "text",
    "social_links" "jsonb",
    "mission" "text",
    "vision" "text",
    "key_figures" "jsonb",
    "payout_phone" "text",
    "payout_operator" "text",
    "bank_name" "text",
    "bank_account" "text"
);


ALTER TABLE "app"."universities" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."university_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "university_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "event_type" "text",
    "start_at" timestamp with time zone,
    "end_at" timestamp with time zone,
    "location" "text",
    "is_highlighted" boolean DEFAULT false NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."university_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."university_media" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "university_id" "uuid" NOT NULL,
    "media_type" "text" NOT NULL,
    "title" "text",
    "description" "text",
    "url" "text",
    "storage_path" "text",
    "sort_order" integer DEFAULT 0,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "video_asset_id" "uuid"
);


ALTER TABLE "app"."university_media" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."university_news" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "university_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "slug" "text",
    "summary" "text",
    "content" "text",
    "published_at" timestamp with time zone,
    "hero_media_id" "uuid",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."university_news" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."university_site_banners" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "university_id" "uuid" NOT NULL,
    "position" "text" NOT NULL,
    "title" "text" NOT NULL,
    "subtitle" "text",
    "media_id" "uuid",
    "sort_order" integer DEFAULT 0,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."university_site_banners" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."university_site_blocks" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "university_id" "uuid" NOT NULL,
    "key" "text" NOT NULL,
    "title" "text",
    "content" "text",
    "sort_order" integer DEFAULT 0,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."university_site_blocks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."university_site_config" (
    "university_id" "uuid" NOT NULL,
    "hero_title" "text" NOT NULL,
    "hero_subtitle" "text",
    "hero_primary_color" "text",
    "hero_secondary_color" "text",
    "hero_poster_media_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."university_site_config" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."university_staff" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "university_id" "uuid" NOT NULL,
    "full_name" "text" NOT NULL,
    "role" "text",
    "bio" "text",
    "photo_media_id" "uuid",
    "email" "text",
    "phone" "text",
    "sort_order" integer DEFAULT 0,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."university_staff" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."user_admin_status" (
    "user_id" "uuid" NOT NULL,
    "is_suspended" boolean DEFAULT false NOT NULL,
    "suspended_reason" "text",
    "suspended_at" timestamp with time zone,
    "reactivated_at" timestamp with time zone,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "is_deleted" boolean DEFAULT false NOT NULL,
    "deleted_reason" "text",
    "deleted_at" timestamp with time zone
);


ALTER TABLE "app"."user_admin_status" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."user_announcement_reads" (
    "user_id" "uuid" NOT NULL,
    "announcement_id" "uuid" NOT NULL,
    "first_read_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "last_read_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "is_pinned" boolean DEFAULT false NOT NULL
);


ALTER TABLE "app"."user_announcement_reads" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."user_device_tokens" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "platform" "text" NOT NULL,
    "fcm_token" "text" NOT NULL,
    "device_info" "jsonb",
    "is_active" boolean DEFAULT true NOT NULL,
    "last_seen_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."user_device_tokens" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."user_event_follows" (
    "user_id" "uuid" NOT NULL,
    "event_id" "uuid" NOT NULL,
    "follow_mode" "text" DEFAULT 'normal'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."user_event_follows" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."user_feature_entitlements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "feature_key" "text" NOT NULL,
    "granted_by" "uuid",
    "granted_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "expires_at" timestamp with time zone,
    "is_active" boolean DEFAULT true NOT NULL,
    "metadata" "jsonb"
);


ALTER TABLE "app"."user_feature_entitlements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."user_invitations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "token" "text" NOT NULL,
    "email" "text" NOT NULL,
    "role" "text" NOT NULL,
    "university_id" "uuid",
    "full_name" "text",
    "notes" "text",
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "created_by_admin_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "used_at" timestamp with time zone,
    "expires_at" timestamp with time zone,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."user_invitations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."user_notification_state" (
    "user_id" "uuid" NOT NULL,
    "domain" "text" NOT NULL,
    "last_seen_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."user_notification_state" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."user_presence" (
    "user_id" "uuid" NOT NULL,
    "last_activity_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."user_presence" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."user_referrals" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "commercial_user_id" "uuid" NOT NULL,
    "ref_code" "text" NOT NULL,
    "source" "text" DEFAULT 'link'::"text" NOT NULL,
    "attributed_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "expires_at" timestamp with time zone,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL
);


ALTER TABLE "app"."user_referrals" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."video_asset_contexts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "video_asset_id" "uuid" NOT NULL,
    "context_type" "text" NOT NULL,
    "context_id" "uuid" NOT NULL,
    "role" "text" DEFAULT 'primary'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."video_asset_contexts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."video_asset_legacy_map" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "context_type" "text" NOT NULL,
    "context_id" "uuid" NOT NULL,
    "role" "text" DEFAULT 'primary'::"text" NOT NULL,
    "video_asset_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."video_asset_legacy_map" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."video_assets" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "owner_user_id" "uuid",
    "origin" "text" DEFAULT 'unknown'::"text" NOT NULL,
    "status" "text" DEFAULT 'draft'::"text" NOT NULL,
    "canonical_type" "text" DEFAULT 'video'::"text" NOT NULL,
    "duration_ms" integer,
    "width" integer,
    "height" integer,
    "rotation" integer,
    "has_audio" boolean DEFAULT true NOT NULL,
    "checksum_sha256" "text",
    "content_warning_flags" "jsonb",
    "deleted_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "video_assets_status_check" CHECK (("status" = ANY (ARRAY['draft'::"text", 'uploaded'::"text", 'processing'::"text", 'ready'::"text", 'failed'::"text", 'deleted'::"text"])))
);


ALTER TABLE "app"."video_assets" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."video_comments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "video_type" "text" NOT NULL,
    "video_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "content" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "is_deleted" boolean DEFAULT false NOT NULL,
    CONSTRAINT "video_comments_video_type_check" CHECK (("lower"("video_type") = ANY (ARRAY['challenge'::"text", 'free'::"text"])))
);


ALTER TABLE "app"."video_comments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."video_engagement_daily" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "video_id" "text" NOT NULL,
    "day" "date" DEFAULT CURRENT_DATE NOT NULL,
    "views_count" integer DEFAULT 0,
    "unique_viewers" integer DEFAULT 0,
    "total_watch_ms" bigint DEFAULT 0,
    "avg_completion_percent" numeric(5,2) DEFAULT 0,
    "likes_count" integer DEFAULT 0,
    "comments_count" integer DEFAULT 0,
    "shares_count" integer DEFAULT 0,
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "app"."video_engagement_daily" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."video_favorites" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "video_type" "text" NOT NULL,
    "video_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "video_favorites_video_type_check" CHECK (("lower"("video_type") = ANY (ARRAY['challenge'::"text", 'free'::"text"])))
);


ALTER TABLE "app"."video_favorites" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."video_heatmap_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "video_id" "text" NOT NULL,
    "position_ms" integer NOT NULL,
    "event_type" "text" DEFAULT 'watch'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "app"."video_heatmap_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."video_likes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "video_type" "text" NOT NULL,
    "video_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "video_likes_video_type_check" CHECK (("lower"("video_type") = ANY (ARRAY['challenge'::"text", 'free'::"text"])))
);


ALTER TABLE "app"."video_likes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."video_moderation_history" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "video_type" "text" NOT NULL,
    "video_id" "uuid" NOT NULL,
    "previous_status" "text",
    "new_status" "text" NOT NULL,
    "reason" "text",
    "flags" "jsonb",
    "moderated_by_admin_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."video_moderation_history" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."video_playback_errors" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "device_model" "text",
    "platform" "text",
    "os_version" "text",
    "app_version" "text",
    "rendition_key" "text",
    "error_message" "text" NOT NULL,
    "raw_error" "jsonb"
);


ALTER TABLE "app"."video_playback_errors" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."video_processing_jobs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "video_asset_id" "uuid" NOT NULL,
    "job_type" "text" NOT NULL,
    "status" "text" DEFAULT 'queued'::"text" NOT NULL,
    "attempts" integer DEFAULT 0 NOT NULL,
    "locked_at" timestamp with time zone,
    "locked_by" "text",
    "payload" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "error" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "video_processing_jobs_status_check" CHECK (("status" = ANY (ARRAY['queued'::"text", 'running'::"text", 'done'::"text", 'failed'::"text"])))
);


ALTER TABLE "app"."video_processing_jobs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."video_reactions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "video_id" "text" NOT NULL,
    "participation_id" "text",
    "reaction_type" "text" DEFAULT 'like'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "app"."video_reactions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."video_renditions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "video_asset_id" "uuid" NOT NULL,
    "rendition_key" "text" NOT NULL,
    "kind" "text" NOT NULL,
    "width" integer,
    "height" integer,
    "bitrate_kbps" integer,
    "fps" integer,
    "codec" "text",
    "storage_bucket" "text" NOT NULL,
    "storage_path" "text" NOT NULL,
    "public_url_hint" "text",
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "error" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "video_renditions_kind_check" CHECK (("kind" = ANY (ARRAY['hls'::"text", 'mp4'::"text", 'thumbnail'::"text", 'poster'::"text"]))),
    CONSTRAINT "video_renditions_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'ready'::"text", 'failed'::"text"])))
);


ALTER TABLE "app"."video_renditions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."video_reports" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "video_type" "text" NOT NULL,
    "video_id" "uuid" NOT NULL,
    "reporter_id" "uuid" NOT NULL,
    "reason" "text" NOT NULL,
    "details" "text",
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "handled_by_admin_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "handled_at" timestamp with time zone,
    CONSTRAINT "video_reports_status_check" CHECK (("lower"("status") = ANY (ARRAY['pending'::"text", 'resolved'::"text", 'rejected'::"text"]))),
    CONSTRAINT "video_reports_video_type_check" CHECK (("lower"("video_type") = ANY (ARRAY['challenge'::"text", 'free'::"text"])))
);


ALTER TABLE "app"."video_reports" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."video_shares" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "video_id" "text" NOT NULL,
    "participation_id" "text",
    "share_target" "text" DEFAULT 'native'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "app"."video_shares" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."video_sources" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "video_asset_id" "uuid" NOT NULL,
    "storage_bucket" "text" NOT NULL,
    "storage_path" "text" NOT NULL,
    "mime_type" "text",
    "file_size_bytes" bigint,
    "ingest_profile" "text" DEFAULT 'unknown'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "ingested_at" timestamp with time zone,
    "validation_report" "jsonb"
);


ALTER TABLE "app"."video_sources" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."video_upload_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "video_type" "text" NOT NULL,
    "challenge_id" "uuid",
    "participation_id" "uuid",
    "video_id" "uuid" NOT NULL,
    "source" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "app"."video_upload_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "app"."video_views" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "video_type" "text" DEFAULT 'challenge'::"text" NOT NULL,
    "video_id" "text" NOT NULL,
    "participation_id" "text",
    "watch_duration_ms" integer DEFAULT 0 NOT NULL,
    "total_duration_ms" integer DEFAULT 0 NOT NULL,
    "completion_percent" numeric(5,2) DEFAULT 0,
    "quality_selected" "text",
    "source" "text" DEFAULT 'feed'::"text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "app"."video_views" OWNER TO "postgres";


ALTER TABLE ONLY "app"."academic_events"
    ADD CONSTRAINT "academic_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."actor_balances"
    ADD CONSTRAINT "actor_balances_actor_type_actor_id_key" UNIQUE ("actor_type", "actor_id");



ALTER TABLE ONLY "app"."actor_balances"
    ADD CONSTRAINT "actor_balances_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."admin_user_action_logs"
    ADD CONSTRAINT "admin_user_action_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."admin_users"
    ADD CONSTRAINT "admin_users_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "app"."application_files"
    ADD CONSTRAINT "application_files_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."application_messages"
    ADD CONSTRAINT "application_messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."application_payments"
    ADD CONSTRAINT "application_payments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."applications"
    ADD CONSTRAINT "applications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."bobodo_answer_cache"
    ADD CONSTRAINT "bobodo_answer_cache_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."bobodo_detected_needs"
    ADD CONSTRAINT "bobodo_detected_needs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."bobodo_feedback"
    ADD CONSTRAINT "bobodo_feedback_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."bobodo_knowledge"
    ADD CONSTRAINT "bobodo_knowledge_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."bobodo_messages"
    ADD CONSTRAINT "bobodo_messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."bobodo_sessions"
    ADD CONSTRAINT "bobodo_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."bobodo_unanswered_questions"
    ADD CONSTRAINT "bobodo_unanswered_questions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."challenge_comments"
    ADD CONSTRAINT "challenge_comments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."challenge_favorites"
    ADD CONSTRAINT "challenge_favorites_participation_id_user_id_key" UNIQUE ("participation_id", "user_id");



ALTER TABLE ONLY "app"."challenge_favorites"
    ADD CONSTRAINT "challenge_favorites_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."challenge_likes"
    ADD CONSTRAINT "challenge_likes_participation_id_user_id_key" UNIQUE ("participation_id", "user_id");



ALTER TABLE ONLY "app"."challenge_likes"
    ADD CONSTRAINT "challenge_likes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."challenge_participation_videos"
    ADD CONSTRAINT "challenge_participation_videos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."challenge_participations"
    ADD CONSTRAINT "challenge_participations_challenge_id_user_id_key" UNIQUE ("challenge_id", "user_id");



ALTER TABLE ONLY "app"."challenge_participations"
    ADD CONSTRAINT "challenge_participations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."challenge_reports"
    ADD CONSTRAINT "challenge_reports_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."challenge_user_bans"
    ADD CONSTRAINT "challenge_user_bans_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."challenge_user_bans"
    ADD CONSTRAINT "challenge_user_bans_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "app"."challenge_video_assets"
    ADD CONSTRAINT "challenge_video_assets_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."challenge_video_overlays"
    ADD CONSTRAINT "challenge_video_overlays_participation_id_key" UNIQUE ("participation_id");



ALTER TABLE ONLY "app"."challenge_video_overlays"
    ADD CONSTRAINT "challenge_video_overlays_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."challenge_video_render_jobs"
    ADD CONSTRAINT "challenge_video_render_jobs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."challenges"
    ADD CONSTRAINT "challenges_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."challenges"
    ADD CONSTRAINT "challenges_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "app"."commercial_milestone_claims"
    ADD CONSTRAINT "commercial_milestone_claims_commercial_user_id_milestone_id_key" UNIQUE ("commercial_user_id", "milestone_id");



ALTER TABLE ONLY "app"."commercial_milestone_claims"
    ADD CONSTRAINT "commercial_milestone_claims_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."commercial_milestones"
    ADD CONSTRAINT "commercial_milestones_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."commercial_profiles"
    ADD CONSTRAINT "commercial_profiles_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "app"."commercial_profiles"
    ADD CONSTRAINT "commercial_profiles_ref_code_key" UNIQUE ("ref_code");



ALTER TABLE ONLY "app"."commission_rules"
    ADD CONSTRAINT "commission_rules_payment_reason_degree_level_key" UNIQUE ("payment_reason", "degree_level");



ALTER TABLE ONLY "app"."commission_rules"
    ADD CONSTRAINT "commission_rules_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."communities"
    ADD CONSTRAINT "communities_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."communities"
    ADD CONSTRAINT "communities_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "app"."community_join_requests"
    ADD CONSTRAINT "community_join_requests_community_id_user_id_key" UNIQUE ("community_id", "user_id");



ALTER TABLE ONLY "app"."community_join_requests"
    ADD CONSTRAINT "community_join_requests_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."community_memberships"
    ADD CONSTRAINT "community_memberships_community_id_user_id_key" UNIQUE ("community_id", "user_id");



ALTER TABLE ONLY "app"."community_memberships"
    ADD CONSTRAINT "community_memberships_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."community_poll_votes"
    ADD CONSTRAINT "community_poll_votes_pkey" PRIMARY KEY ("poll_id", "user_id");



ALTER TABLE ONLY "app"."community_polls"
    ADD CONSTRAINT "community_polls_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."community_post_reactions"
    ADD CONSTRAINT "community_post_reactions_pkey" PRIMARY KEY ("post_id", "user_id", "emoji");



ALTER TABLE ONLY "app"."community_posts"
    ADD CONSTRAINT "community_posts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."community_read_states"
    ADD CONSTRAINT "community_read_states_pkey" PRIMARY KEY ("community_id", "user_id");



ALTER TABLE ONLY "app"."community_stories"
    ADD CONSTRAINT "community_stories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."community_story_views"
    ADD CONSTRAINT "community_story_views_pkey" PRIMARY KEY ("story_id", "viewer_id");



ALTER TABLE ONLY "app"."competitive_events"
    ADD CONSTRAINT "competitive_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."course_domains"
    ADD CONSTRAINT "course_domains_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."course_enrollments"
    ADD CONSTRAINT "course_enrollments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."course_enrollments"
    ADD CONSTRAINT "course_enrollments_student_id_course_id_key" UNIQUE ("student_id", "course_id");



ALTER TABLE ONLY "app"."course_resources"
    ADD CONSTRAINT "course_resources_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."course_units"
    ADD CONSTRAINT "course_units_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."courses"
    ADD CONSTRAINT "courses_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."direct_conversations"
    ADD CONSTRAINT "direct_conversations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."direct_conversations"
    ADD CONSTRAINT "direct_conversations_users_unique" UNIQUE ("user_a", "user_b");



ALTER TABLE ONLY "app"."direct_message_read_states"
    ADD CONSTRAINT "direct_message_read_states_pkey" PRIMARY KEY ("conversation_id", "user_id");



ALTER TABLE ONLY "app"."direct_messages"
    ADD CONSTRAINT "direct_messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."exercises"
    ADD CONSTRAINT "exercises_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."free_video_overlays"
    ADD CONSTRAINT "free_video_overlays_free_video_id_key" UNIQUE ("free_video_id");



ALTER TABLE ONLY "app"."free_video_overlays"
    ADD CONSTRAINT "free_video_overlays_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."free_video_render_jobs"
    ADD CONSTRAINT "free_video_render_jobs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."free_videos"
    ADD CONSTRAINT "free_videos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."hero_overlay_animations"
    ADD CONSTRAINT "hero_overlay_animations_code_key" UNIQUE ("code");



ALTER TABLE ONLY "app"."hero_overlay_animations"
    ADD CONSTRAINT "hero_overlay_animations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."hero_overlays"
    ADD CONSTRAINT "hero_overlays_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."hero_overlays"
    ADD CONSTRAINT "hero_overlays_playlist_item_id_key" UNIQUE ("playlist_item_id");



ALTER TABLE ONLY "app"."hero_overlays_tv"
    ADD CONSTRAINT "hero_overlays_tv_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."hero_playlist"
    ADD CONSTRAINT "hero_playlist_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."hero_renders"
    ADD CONSTRAINT "hero_renders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."hero_renders_tv"
    ADD CONSTRAINT "hero_renders_tv_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."hero_video_jobs"
    ADD CONSTRAINT "hero_video_jobs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."hero_videos"
    ADD CONSTRAINT "hero_videos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."instructors"
    ADD CONSTRAINT "instructors_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."landing_announcements"
    ADD CONSTRAINT "landing_announcements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."landing_config"
    ADD CONSTRAINT "landing_config_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."landing_partners"
    ADD CONSTRAINT "landing_partners_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."landing_videos"
    ADD CONSTRAINT "landing_videos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."landing_why_cards"
    ADD CONSTRAINT "landing_why_cards_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."league_matches"
    ADD CONSTRAINT "league_matches_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."league_participations"
    ADD CONSTRAINT "league_participations_league_id_user_id_key" UNIQUE ("league_id", "user_id");



ALTER TABLE ONLY "app"."league_participations"
    ADD CONSTRAINT "league_participations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."leagues"
    ADD CONSTRAINT "leagues_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."legacy_video_write_attempts"
    ADD CONSTRAINT "legacy_video_write_attempts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."marketplace_cart_items"
    ADD CONSTRAINT "marketplace_cart_items_cart_id_listing_id_key" UNIQUE ("cart_id", "listing_id");



ALTER TABLE ONLY "app"."marketplace_cart_items"
    ADD CONSTRAINT "marketplace_cart_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."marketplace_carts"
    ADD CONSTRAINT "marketplace_carts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."marketplace_categories"
    ADD CONSTRAINT "marketplace_categories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."marketplace_listing_bookmarks"
    ADD CONSTRAINT "marketplace_listing_bookmarks_pkey" PRIMARY KEY ("user_id", "listing_id");



ALTER TABLE ONLY "app"."marketplace_listing_media"
    ADD CONSTRAINT "marketplace_listing_media_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."marketplace_listings"
    ADD CONSTRAINT "marketplace_listings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."marketplace_merchant_balances"
    ADD CONSTRAINT "marketplace_merchant_balances_merchant_id_key" UNIQUE ("merchant_id");



ALTER TABLE ONLY "app"."marketplace_merchant_balances"
    ADD CONSTRAINT "marketplace_merchant_balances_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."marketplace_merchants"
    ADD CONSTRAINT "marketplace_merchants_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."marketplace_merchants"
    ADD CONSTRAINT "marketplace_merchants_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "app"."marketplace_order_items"
    ADD CONSTRAINT "marketplace_order_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."marketplace_orders"
    ADD CONSTRAINT "marketplace_orders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."marketplace_payments"
    ADD CONSTRAINT "marketplace_payments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."marketplace_products"
    ADD CONSTRAINT "marketplace_products_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."marketplace_reviews"
    ADD CONSTRAINT "marketplace_reviews_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."merchant_profiles"
    ADD CONSTRAINT "merchant_profiles_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "app"."moderation_events"
    ADD CONSTRAINT "moderation_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."notification_events"
    ADD CONSTRAINT "notification_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."official_announcements"
    ADD CONSTRAINT "official_announcements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."online_course_certificates"
    ADD CONSTRAINT "online_course_certificates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."online_course_enrollment_messages"
    ADD CONSTRAINT "online_course_enrollment_messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."online_course_enrollments"
    ADD CONSTRAINT "online_course_enrollments_course_id_student_id_key" UNIQUE ("course_id", "student_id");



ALTER TABLE ONLY "app"."online_course_enrollments"
    ADD CONSTRAINT "online_course_enrollments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."online_course_forum_messages"
    ADD CONSTRAINT "online_course_forum_messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."online_course_forum_threads"
    ADD CONSTRAINT "online_course_forum_threads_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."online_course_instructors"
    ADD CONSTRAINT "online_course_instructors_course_id_instructor_id_key" UNIQUE ("course_id", "instructor_id");



ALTER TABLE ONLY "app"."online_course_instructors"
    ADD CONSTRAINT "online_course_instructors_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."online_course_lesson_media"
    ADD CONSTRAINT "online_course_lesson_media_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."online_course_lesson_progress"
    ADD CONSTRAINT "online_course_lesson_progress_enrollment_id_lesson_id_key" UNIQUE ("enrollment_id", "lesson_id");



ALTER TABLE ONLY "app"."online_course_lesson_progress"
    ADD CONSTRAINT "online_course_lesson_progress_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."online_course_lessons"
    ADD CONSTRAINT "online_course_lessons_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."online_course_live_session_participants"
    ADD CONSTRAINT "online_course_live_session_participants_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."online_course_live_sessions"
    ADD CONSTRAINT "online_course_live_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."online_course_sections"
    ADD CONSTRAINT "online_course_sections_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."online_courses"
    ADD CONSTRAINT "online_courses_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."opportunities"
    ADD CONSTRAINT "opportunities_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."opportunity_applications"
    ADD CONSTRAINT "opportunity_applications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."opportunity_bookmarks"
    ADD CONSTRAINT "opportunity_bookmarks_opportunity_id_user_id_key" UNIQUE ("opportunity_id", "user_id");



ALTER TABLE ONLY "app"."opportunity_bookmarks"
    ADD CONSTRAINT "opportunity_bookmarks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."opportunity_comments"
    ADD CONSTRAINT "opportunity_comments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."opportunity_inquiries"
    ADD CONSTRAINT "opportunity_inquiries_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."opportunity_inquiry_messages"
    ADD CONSTRAINT "opportunity_inquiry_messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."opportunity_reactions"
    ADD CONSTRAINT "opportunity_reactions_opportunity_id_user_id_key" UNIQUE ("opportunity_id", "user_id");



ALTER TABLE ONLY "app"."opportunity_reactions"
    ADD CONSTRAINT "opportunity_reactions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."opportunity_types"
    ADD CONSTRAINT "opportunity_types_code_key" UNIQUE ("code");



ALTER TABLE ONLY "app"."opportunity_types"
    ADD CONSTRAINT "opportunity_types_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."opportunity_views"
    ADD CONSTRAINT "opportunity_views_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."opportunity_views"
    ADD CONSTRAINT "opportunity_views_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "app"."payment_proofs"
    ADD CONSTRAINT "payment_proofs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."payment_receipts"
    ADD CONSTRAINT "payment_receipts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."payout_queue"
    ADD CONSTRAINT "payout_queue_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."platform_ledger"
    ADD CONSTRAINT "platform_ledger_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_ai_config"
    ADD CONSTRAINT "prep_ai_config_config_key_key" UNIQUE ("config_key");



ALTER TABLE ONLY "app"."prep_ai_config"
    ADD CONSTRAINT "prep_ai_config_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_ai_conversations"
    ADD CONSTRAINT "prep_ai_conversations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_ai_corrections"
    ADD CONSTRAINT "prep_ai_corrections_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_ai_generations"
    ADD CONSTRAINT "prep_ai_generations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_ai_messages"
    ADD CONSTRAINT "prep_ai_messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_ai_usage_logs"
    ADD CONSTRAINT "prep_ai_usage_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_assignment_submissions"
    ADD CONSTRAINT "prep_assignment_submissions_assignment_id_student_id_key" UNIQUE ("assignment_id", "student_id");



ALTER TABLE ONLY "app"."prep_assignment_submissions"
    ADD CONSTRAINT "prep_assignment_submissions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_assignments"
    ADD CONSTRAINT "prep_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_attempts"
    ADD CONSTRAINT "prep_attempts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_badges"
    ADD CONSTRAINT "prep_badges_code_key" UNIQUE ("code");



ALTER TABLE ONLY "app"."prep_badges"
    ADD CONSTRAINT "prep_badges_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_chapters"
    ADD CONSTRAINT "prep_chapters_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_chapters"
    ADD CONSTRAINT "prep_chapters_subject_id_slug_key" UNIQUE ("subject_id", "slug");



ALTER TABLE ONLY "app"."prep_chunks"
    ADD CONSTRAINT "prep_chunks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_doc_chunks"
    ADD CONSTRAINT "prep_doc_chunks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_doc_chunks"
    ADD CONSTRAINT "prep_doc_chunks_source_document_id_chunk_index_key" UNIQUE ("source_document_id", "chunk_index");



ALTER TABLE ONLY "app"."prep_exam_blanc_attempts"
    ADD CONSTRAINT "prep_exam_blanc_attempts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_exam_blancs"
    ADD CONSTRAINT "prep_exam_blancs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_exam_items"
    ADD CONSTRAINT "prep_exam_items_exam_id_sort_order_key" UNIQUE ("exam_id", "sort_order");



ALTER TABLE ONLY "app"."prep_exam_items"
    ADD CONSTRAINT "prep_exam_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_exam_papers"
    ADD CONSTRAINT "prep_exam_papers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_exams"
    ADD CONSTRAINT "prep_exams_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_flashcard_decks"
    ADD CONSTRAINT "prep_flashcard_decks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_flashcard_progress"
    ADD CONSTRAINT "prep_flashcard_progress_flashcard_id_student_id_key" UNIQUE ("flashcard_id", "student_id");



ALTER TABLE ONLY "app"."prep_flashcard_progress"
    ADD CONSTRAINT "prep_flashcard_progress_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_flashcards"
    ADD CONSTRAINT "prep_flashcards_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_live_participants"
    ADD CONSTRAINT "prep_live_participants_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_live_participants"
    ADD CONSTRAINT "prep_live_participants_session_id_student_id_key" UNIQUE ("session_id", "student_id");



ALTER TABLE ONLY "app"."prep_live_sessions"
    ADD CONSTRAINT "prep_live_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_news_articles"
    ADD CONSTRAINT "prep_news_articles_article_url_key" UNIQUE ("article_url");



ALTER TABLE ONLY "app"."prep_news_articles"
    ADD CONSTRAINT "prep_news_articles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_news_sources"
    ADD CONSTRAINT "prep_news_sources_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_news_sources"
    ADD CONSTRAINT "prep_news_sources_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "app"."prep_psychotech_profiles"
    ADD CONSTRAINT "prep_psychotech_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_psychotech_profiles"
    ADD CONSTRAINT "prep_psychotech_profiles_student_id_key" UNIQUE ("student_id");



ALTER TABLE ONLY "app"."prep_psychotech_results"
    ADD CONSTRAINT "prep_psychotech_results_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_question_banks"
    ADD CONSTRAINT "prep_question_banks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_question_choices"
    ADD CONSTRAINT "prep_question_choices_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_question_choices"
    ADD CONSTRAINT "prep_question_choices_question_id_sort_order_key" UNIQUE ("question_id", "sort_order");



ALTER TABLE ONLY "app"."prep_question_topics"
    ADD CONSTRAINT "prep_question_topics_pkey" PRIMARY KEY ("question_id", "topic_id");



ALTER TABLE ONLY "app"."prep_questions"
    ADD CONSTRAINT "prep_questions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_quiz_attempts"
    ADD CONSTRAINT "prep_quiz_attempts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_quiz_templates"
    ADD CONSTRAINT "prep_quiz_templates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_scan_logs"
    ADD CONSTRAINT "prep_scan_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_source_documents"
    ADD CONSTRAINT "prep_source_documents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_student_badges"
    ADD CONSTRAINT "prep_student_badges_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_student_badges"
    ADD CONSTRAINT "prep_student_badges_student_id_badge_id_key" UNIQUE ("student_id", "badge_id");



ALTER TABLE ONLY "app"."prep_student_progress"
    ADD CONSTRAINT "prep_student_progress_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_student_progress"
    ADD CONSTRAINT "prep_student_progress_student_id_key" UNIQUE ("student_id");



ALTER TABLE ONLY "app"."prep_student_weaknesses"
    ADD CONSTRAINT "prep_student_weaknesses_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_student_weaknesses"
    ADD CONSTRAINT "prep_student_weaknesses_student_id_subject_id_key" UNIQUE ("student_id", "subject_id");



ALTER TABLE ONLY "app"."prep_subjects"
    ADD CONSTRAINT "prep_subjects_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_subjects"
    ADD CONSTRAINT "prep_subjects_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "app"."prep_topic_predictions"
    ADD CONSTRAINT "prep_topic_predictions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."prep_topic_predictions"
    ADD CONSTRAINT "prep_topic_predictions_topic_id_concours_type_target_year_key" UNIQUE ("topic_id", "concours_type", "target_year");



ALTER TABLE ONLY "app"."prep_topics"
    ADD CONSTRAINT "prep_topics_name_key" UNIQUE ("name");



ALTER TABLE ONLY "app"."prep_topics"
    ADD CONSTRAINT "prep_topics_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."programs"
    ADD CONSTRAINT "programs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."referral_commissions"
    ADD CONSTRAINT "referral_commissions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."revenue_split_rules"
    ADD CONSTRAINT "revenue_split_rules_payment_reason_beneficiary_type_key" UNIQUE ("payment_reason", "beneficiary_type");



ALTER TABLE ONLY "app"."revenue_split_rules"
    ADD CONSTRAINT "revenue_split_rules_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."short_training_messages"
    ADD CONSTRAINT "short_training_messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."short_training_registration_messages"
    ADD CONSTRAINT "short_training_registration_messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."short_training_registrations"
    ADD CONSTRAINT "short_training_registrations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."short_training_registrations"
    ADD CONSTRAINT "short_training_registrations_session_id_user_id_key" UNIQUE ("session_id", "user_id");



ALTER TABLE ONLY "app"."short_training_sessions"
    ADD CONSTRAINT "short_training_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."short_trainings"
    ADD CONSTRAINT "short_trainings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."student_dossier_documents"
    ADD CONSTRAINT "student_dossier_documents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."student_home_announcements"
    ADD CONSTRAINT "student_home_announcements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."student_home_slots"
    ADD CONSTRAINT "student_home_slots_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."student_home_videos"
    ADD CONSTRAINT "student_home_videos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."students"
    ADD CONSTRAINT "students_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."subscription_plans"
    ADD CONSTRAINT "subscription_plans_code_key" UNIQUE ("code");



ALTER TABLE ONLY "app"."subscription_plans"
    ADD CONSTRAINT "subscription_plans_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."subscriptions"
    ADD CONSTRAINT "subscriptions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."support_conversations"
    ADD CONSTRAINT "support_conversations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."support_messages"
    ADD CONSTRAINT "support_messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."support_read_states"
    ADD CONSTRAINT "support_read_states_pkey" PRIMARY KEY ("conversation_id", "user_id");



ALTER TABLE ONLY "app"."td_ai_config"
    ADD CONSTRAINT "td_ai_config_config_key_key" UNIQUE ("config_key");



ALTER TABLE ONLY "app"."td_ai_config"
    ADD CONSTRAINT "td_ai_config_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_ai_conversations"
    ADD CONSTRAINT "td_ai_conversations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_ai_messages"
    ADD CONSTRAINT "td_ai_messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_assignment_submissions"
    ADD CONSTRAINT "td_assignment_submissions_assignment_id_student_id_key" UNIQUE ("assignment_id", "student_id");



ALTER TABLE ONLY "app"."td_assignment_submissions"
    ADD CONSTRAINT "td_assignment_submissions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_assignments"
    ADD CONSTRAINT "td_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_attendance"
    ADD CONSTRAINT "td_attendance_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_badges"
    ADD CONSTRAINT "td_badges_code_key" UNIQUE ("code");



ALTER TABLE ONLY "app"."td_badges"
    ADD CONSTRAINT "td_badges_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_collections"
    ADD CONSTRAINT "td_collections_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_daily_goals"
    ADD CONSTRAINT "td_daily_goals_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_daily_goals"
    ADD CONSTRAINT "td_daily_goals_student_id_goal_date_key" UNIQUE ("student_id", "goal_date");



ALTER TABLE ONLY "app"."td_discipline_colors"
    ADD CONSTRAINT "td_discipline_colors_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_doc_chunks"
    ADD CONSTRAINT "td_doc_chunks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_enrollments"
    ADD CONSTRAINT "td_enrollments_payment_id_key" UNIQUE ("payment_id");



ALTER TABLE ONLY "app"."td_enrollments"
    ADD CONSTRAINT "td_enrollments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_exam_papers"
    ADD CONSTRAINT "td_exam_papers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_fields"
    ADD CONSTRAINT "td_fields_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_flashcard_decks"
    ADD CONSTRAINT "td_flashcard_decks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_flashcard_progress"
    ADD CONSTRAINT "td_flashcard_progress_flashcard_id_student_id_key" UNIQUE ("flashcard_id", "student_id");



ALTER TABLE ONLY "app"."td_flashcard_progress"
    ADD CONSTRAINT "td_flashcard_progress_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_flashcards"
    ADD CONSTRAINT "td_flashcards_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_generated_assignments"
    ADD CONSTRAINT "td_generated_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_leaderboard_cache"
    ADD CONSTRAINT "td_leaderboard_cache_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_leaderboard_cache"
    ADD CONSTRAINT "td_leaderboard_cache_student_id_program_id_period_start_key" UNIQUE ("student_id", "program_id", "period_start");



ALTER TABLE ONLY "app"."td_local_group_members"
    ADD CONSTRAINT "td_local_group_members_group_id_student_id_key" UNIQUE ("group_id", "student_id");



ALTER TABLE ONLY "app"."td_local_group_members"
    ADD CONSTRAINT "td_local_group_members_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_local_groups"
    ADD CONSTRAINT "td_local_groups_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_messages"
    ADD CONSTRAINT "td_messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_physical_sessions"
    ADD CONSTRAINT "td_physical_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_programs"
    ADD CONSTRAINT "td_programs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_question_banks"
    ADD CONSTRAINT "td_question_banks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_questions"
    ADD CONSTRAINT "td_questions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_quiz_attempts"
    ADD CONSTRAINT "td_quiz_attempts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_quiz_templates"
    ADD CONSTRAINT "td_quiz_templates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_resource_progress"
    ADD CONSTRAINT "td_resource_progress_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_resource_progress"
    ADD CONSTRAINT "td_resource_progress_student_id_resource_id_key" UNIQUE ("student_id", "resource_id");



ALTER TABLE ONLY "app"."td_resources"
    ADD CONSTRAINT "td_resources_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_scan_logs"
    ADD CONSTRAINT "td_scan_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_session_occurrences"
    ADD CONSTRAINT "td_session_occurrences_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_sessions"
    ADD CONSTRAINT "td_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_source_documents"
    ADD CONSTRAINT "td_source_documents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_streaks"
    ADD CONSTRAINT "td_streaks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_streaks"
    ADD CONSTRAINT "td_streaks_student_id_key" UNIQUE ("student_id");



ALTER TABLE ONLY "app"."td_student_badges"
    ADD CONSTRAINT "td_student_badges_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_student_badges"
    ADD CONSTRAINT "td_student_badges_student_id_badge_id_key" UNIQUE ("student_id", "badge_id");



ALTER TABLE ONLY "app"."td_student_profiles"
    ADD CONSTRAINT "td_student_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_student_profiles"
    ADD CONSTRAINT "td_student_profiles_student_id_key" UNIQUE ("student_id");



ALTER TABLE ONLY "app"."td_student_progress"
    ADD CONSTRAINT "td_student_progress_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_student_progress"
    ADD CONSTRAINT "td_student_progress_student_id_subject_key" UNIQUE ("student_id", "subject");



ALTER TABLE ONLY "app"."td_student_requests"
    ADD CONSTRAINT "td_student_requests_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_teacher_availability"
    ADD CONSTRAINT "td_teacher_availability_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_teacher_profiles"
    ADD CONSTRAINT "td_teacher_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_teacher_profiles"
    ADD CONSTRAINT "td_teacher_profiles_teacher_id_key" UNIQUE ("teacher_id");



ALTER TABLE ONLY "app"."td_teachers"
    ADD CONSTRAINT "td_teachers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_xp_log"
    ADD CONSTRAINT "td_xp_log_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."tournament_matches"
    ADD CONSTRAINT "tournament_matches_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."tournament_participants"
    ADD CONSTRAINT "tournament_participants_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."tournament_participants"
    ADD CONSTRAINT "tournament_participants_tournament_id_user_id_key" UNIQUE ("tournament_id", "user_id");



ALTER TABLE ONLY "app"."tournament_rewards"
    ADD CONSTRAINT "tournament_rewards_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."tournaments"
    ADD CONSTRAINT "tournaments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."universities"
    ADD CONSTRAINT "universities_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."universities"
    ADD CONSTRAINT "universities_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "app"."university_events"
    ADD CONSTRAINT "university_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."university_media"
    ADD CONSTRAINT "university_media_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."university_news"
    ADD CONSTRAINT "university_news_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."university_news"
    ADD CONSTRAINT "university_news_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "app"."university_site_banners"
    ADD CONSTRAINT "university_site_banners_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."university_site_blocks"
    ADD CONSTRAINT "university_site_blocks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."university_site_config"
    ADD CONSTRAINT "university_site_config_pkey" PRIMARY KEY ("university_id");



ALTER TABLE ONLY "app"."university_staff"
    ADD CONSTRAINT "university_staff_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."td_teachers"
    ADD CONSTRAINT "uq_td_teachers_user" UNIQUE ("user_id");



ALTER TABLE ONLY "app"."user_admin_status"
    ADD CONSTRAINT "user_admin_status_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "app"."user_announcement_reads"
    ADD CONSTRAINT "user_announcement_reads_pkey" PRIMARY KEY ("user_id", "announcement_id");



ALTER TABLE ONLY "app"."user_device_tokens"
    ADD CONSTRAINT "user_device_tokens_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."user_device_tokens"
    ADD CONSTRAINT "user_device_tokens_user_id_fcm_token_key" UNIQUE ("user_id", "fcm_token");



ALTER TABLE ONLY "app"."user_event_follows"
    ADD CONSTRAINT "user_event_follows_pkey" PRIMARY KEY ("user_id", "event_id");



ALTER TABLE ONLY "app"."user_feature_entitlements"
    ADD CONSTRAINT "user_feature_entitlements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."user_feature_entitlements"
    ADD CONSTRAINT "user_feature_entitlements_user_id_feature_key_key" UNIQUE ("user_id", "feature_key");



ALTER TABLE ONLY "app"."user_invitations"
    ADD CONSTRAINT "user_invitations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."user_invitations"
    ADD CONSTRAINT "user_invitations_token_key" UNIQUE ("token");



ALTER TABLE ONLY "app"."user_notification_state"
    ADD CONSTRAINT "user_notification_state_pkey" PRIMARY KEY ("user_id", "domain");



ALTER TABLE ONLY "app"."user_presence"
    ADD CONSTRAINT "user_presence_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "app"."user_referrals"
    ADD CONSTRAINT "user_referrals_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."video_asset_contexts"
    ADD CONSTRAINT "video_asset_contexts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."video_asset_contexts"
    ADD CONSTRAINT "video_asset_contexts_unique" UNIQUE ("context_type", "context_id", "role");



ALTER TABLE ONLY "app"."video_asset_legacy_map"
    ADD CONSTRAINT "video_asset_legacy_map_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."video_asset_legacy_map"
    ADD CONSTRAINT "video_asset_legacy_map_unique" UNIQUE ("context_type", "context_id", "role");



ALTER TABLE ONLY "app"."video_assets"
    ADD CONSTRAINT "video_assets_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."video_comments"
    ADD CONSTRAINT "video_comments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."video_engagement_daily"
    ADD CONSTRAINT "video_engagement_daily_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."video_engagement_daily"
    ADD CONSTRAINT "video_engagement_daily_video_id_day_key" UNIQUE ("video_id", "day");



ALTER TABLE ONLY "app"."video_favorites"
    ADD CONSTRAINT "video_favorites_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."video_favorites"
    ADD CONSTRAINT "video_favorites_unique_per_user" UNIQUE ("video_type", "video_id", "user_id");



ALTER TABLE ONLY "app"."video_heatmap_events"
    ADD CONSTRAINT "video_heatmap_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."video_likes"
    ADD CONSTRAINT "video_likes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."video_likes"
    ADD CONSTRAINT "video_likes_unique_per_user" UNIQUE ("video_type", "video_id", "user_id");



ALTER TABLE ONLY "app"."video_moderation_history"
    ADD CONSTRAINT "video_moderation_history_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."video_playback_errors"
    ADD CONSTRAINT "video_playback_errors_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."video_processing_jobs"
    ADD CONSTRAINT "video_processing_jobs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."video_reactions"
    ADD CONSTRAINT "video_reactions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."video_reactions"
    ADD CONSTRAINT "video_reactions_user_id_video_id_reaction_type_key" UNIQUE ("user_id", "video_id", "reaction_type");



ALTER TABLE ONLY "app"."video_renditions"
    ADD CONSTRAINT "video_renditions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."video_renditions"
    ADD CONSTRAINT "video_renditions_unique_key" UNIQUE ("video_asset_id", "rendition_key");



ALTER TABLE ONLY "app"."video_reports"
    ADD CONSTRAINT "video_reports_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."video_shares"
    ADD CONSTRAINT "video_shares_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."video_sources"
    ADD CONSTRAINT "video_sources_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."video_upload_events"
    ADD CONSTRAINT "video_upload_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "app"."video_views"
    ADD CONSTRAINT "video_views_pkey" PRIMARY KEY ("id");



CREATE INDEX "application_payments_application_id_idx" ON "app"."application_payments" USING "btree" ("application_id");



CREATE UNIQUE INDEX "application_payments_external_reference_key" ON "app"."application_payments" USING "btree" ("external_reference") WHERE ("external_reference" IS NOT NULL);



CREATE UNIQUE INDEX "application_payments_reference_code_key" ON "app"."application_payments" USING "btree" ("reference_code");



CREATE INDEX "application_payments_status_idx" ON "app"."application_payments" USING "btree" ("status");



CREATE INDEX "application_payments_student_id_idx" ON "app"."application_payments" USING "btree" ("student_id");



CREATE INDEX "application_payments_university_id_idx" ON "app"."application_payments" USING "btree" ("university_id");



CREATE INDEX "idx_ab_actor" ON "app"."actor_balances" USING "btree" ("actor_type", "actor_id");



CREATE INDEX "idx_academic_events_published_start" ON "app"."academic_events" USING "btree" ("is_published", "start_at");



CREATE INDEX "idx_academic_events_type_country" ON "app"."academic_events" USING "btree" ("event_type", "country");



CREATE INDEX "idx_application_payments_ligdicash_token" ON "app"."application_payments" USING "btree" ("ligdicash_token") WHERE ("ligdicash_token" IS NOT NULL);



CREATE INDEX "idx_application_payments_method" ON "app"."application_payments" USING "btree" ("payment_method");



CREATE INDEX "idx_bobodo_answer_cache_embedding" ON "app"."bobodo_answer_cache" USING "ivfflat" ("question_embedding" "extensions"."vector_cosine_ops") WITH ("lists"='10');



CREATE INDEX "idx_bobodo_answer_cache_expires" ON "app"."bobodo_answer_cache" USING "btree" ("expires_at");



CREATE INDEX "idx_challenge_participation_videos_video_asset_id" ON "app"."challenge_participation_videos" USING "btree" ("video_asset_id");



CREATE INDEX "idx_challenge_participations_video_asset_id" ON "app"."challenge_participations" USING "btree" ("video_asset_id");



CREATE INDEX "idx_community_stories_author" ON "app"."community_stories" USING "btree" ("author_id");



CREATE INDEX "idx_community_stories_community_expires" ON "app"."community_stories" USING "btree" ("community_id", "expires_at") WHERE ("is_deleted" = false);



CREATE INDEX "idx_community_story_views_story" ON "app"."community_story_views" USING "btree" ("story_id");



CREATE INDEX "idx_competitive_events_created" ON "app"."competitive_events" USING "btree" ("created_at");



CREATE INDEX "idx_competitive_events_league" ON "app"."competitive_events" USING "btree" ("league_id");



CREATE INDEX "idx_competitive_events_tournament" ON "app"."competitive_events" USING "btree" ("tournament_id");



CREATE INDEX "idx_competitive_events_type" ON "app"."competitive_events" USING "btree" ("event_type");



CREATE INDEX "idx_direct_conversations_user_a" ON "app"."direct_conversations" USING "btree" ("user_a");



CREATE INDEX "idx_direct_conversations_user_b" ON "app"."direct_conversations" USING "btree" ("user_b");



CREATE INDEX "idx_direct_messages_conversation" ON "app"."direct_messages" USING "btree" ("conversation_id", "created_at" DESC);



CREATE INDEX "idx_free_videos_user" ON "app"."free_videos" USING "btree" ("user_id");



CREATE INDEX "idx_free_videos_video_asset_id" ON "app"."free_videos" USING "btree" ("video_asset_id");



CREATE INDEX "idx_hero_overlays_tv_playlist" ON "app"."hero_overlays_tv" USING "btree" ("playlist_item_id");



CREATE INDEX "idx_hero_overlays_tv_timeline" ON "app"."hero_overlays_tv" USING "btree" ("playlist_item_id", "start_at_seconds", "end_at_seconds");



CREATE INDEX "idx_hero_playlist_video_asset_id" ON "app"."hero_playlist" USING "btree" ("video_asset_id");



CREATE INDEX "idx_hero_renders_tv_playlist" ON "app"."hero_renders_tv" USING "btree" ("playlist_item_id");



CREATE INDEX "idx_hero_renders_tv_status" ON "app"."hero_renders_tv" USING "btree" ("status");



CREATE INDEX "idx_landing_config_video_asset_id" ON "app"."landing_config" USING "btree" ("video_asset_id");



CREATE INDEX "idx_landing_videos_video_asset_id" ON "app"."landing_videos" USING "btree" ("video_asset_id");



CREATE INDEX "idx_league_matches_league" ON "app"."league_matches" USING "btree" ("league_id");



CREATE INDEX "idx_league_matches_participants" ON "app"."league_matches" USING "btree" ("participant1_id", "participant2_id");



CREATE INDEX "idx_league_matches_scheduled" ON "app"."league_matches" USING "btree" ("scheduled_at");



CREATE INDEX "idx_league_matches_status" ON "app"."league_matches" USING "btree" ("status");



CREATE INDEX "idx_league_participations_division" ON "app"."league_participations" USING "btree" ("division");



CREATE INDEX "idx_league_participations_league" ON "app"."league_participations" USING "btree" ("league_id");



CREATE INDEX "idx_league_participations_rank" ON "app"."league_participations" USING "btree" ("rank_position");



CREATE INDEX "idx_league_participations_user" ON "app"."league_participations" USING "btree" ("user_id");



CREATE INDEX "idx_leagues_active" ON "app"."leagues" USING "btree" ("is_active");



CREATE INDEX "idx_leagues_game_type" ON "app"."leagues" USING "btree" ("game_type");



CREATE INDEX "idx_leagues_season" ON "app"."leagues" USING "btree" ("season_number");



CREATE INDEX "idx_leagues_type_division" ON "app"."leagues" USING "btree" ("league_type", "division");



CREATE INDEX "idx_legacy_video_write_attempts_created_at" ON "app"."legacy_video_write_attempts" USING "btree" ("created_at");



CREATE INDEX "idx_marketplace_listings_category" ON "app"."marketplace_listings" USING "btree" ("category_id") WHERE ("category_id" IS NOT NULL);



CREATE INDEX "idx_marketplace_listings_merchant" ON "app"."marketplace_listings" USING "btree" ("merchant_id");



CREATE INDEX "idx_marketplace_listings_merchant_id" ON "app"."marketplace_listings" USING "btree" ("merchant_id");



CREATE INDEX "idx_marketplace_listings_rating" ON "app"."marketplace_listings" USING "btree" ("rating_avg" DESC, "rating_count" DESC);



CREATE INDEX "idx_marketplace_listings_review_status" ON "app"."marketplace_listings" USING "btree" ("review_status");



CREATE INDEX "idx_marketplace_listings_review_status_active" ON "app"."marketplace_listings" USING "btree" ("review_status", "is_active") WHERE (("review_status" = 'approved'::"text") AND ("is_active" = true));



CREATE INDEX "idx_marketplace_listings_sales" ON "app"."marketplace_listings" USING "btree" ("sales_count" DESC);



CREATE INDEX "idx_marketplace_listings_status_active" ON "app"."marketplace_listings" USING "btree" ("status", "is_active");



CREATE INDEX "idx_marketplace_payments_merchant" ON "app"."marketplace_payments" USING "btree" ("merchant_id", "status");



CREATE INDEX "idx_marketplace_payments_order" ON "app"."marketplace_payments" USING "btree" ("order_id");



CREATE INDEX "idx_marketplace_payments_status" ON "app"."marketplace_payments" USING "btree" ("status", "created_at" DESC);



CREATE INDEX "idx_marketplace_reviews_buyer" ON "app"."marketplace_reviews" USING "btree" ("buyer_id", "created_at" DESC);



CREATE INDEX "idx_marketplace_reviews_listing" ON "app"."marketplace_reviews" USING "btree" ("listing_id", "is_active", "created_at" DESC);



CREATE UNIQUE INDEX "idx_marketplace_reviews_unique" ON "app"."marketplace_reviews" USING "btree" ("listing_id", "buyer_id", "order_id") WHERE ("order_id" IS NOT NULL);



CREATE INDEX "idx_merchant_profiles_is_active" ON "app"."merchant_profiles" USING "btree" ("is_active");



CREATE INDEX "idx_merchant_profiles_verification" ON "app"."merchant_profiles" USING "btree" ("is_verified", "verification_level");



CREATE INDEX "idx_notification_events_pending" ON "app"."notification_events" USING "btree" ("created_at") WHERE ("processed_at" IS NULL);



CREATE INDEX "idx_official_announcements_published" ON "app"."official_announcements" USING "btree" ("is_published", "visible_from" DESC);



CREATE INDEX "idx_official_announcements_urgency" ON "app"."official_announcements" USING "btree" ("urgency_level");



CREATE INDEX "idx_online_course_live_sessions_replay_video_asset_id" ON "app"."online_course_live_sessions" USING "btree" ("replay_video_asset_id");



CREATE INDEX "idx_opportunities_merchant_id" ON "app"."opportunities" USING "btree" ("merchant_id");



CREATE INDEX "idx_opportunities_review_status" ON "app"."opportunities" USING "btree" ("review_status");



CREATE INDEX "idx_opportunity_bookmarks_listing" ON "app"."opportunity_bookmarks" USING "btree" ("listing_id") WHERE ("listing_id" IS NOT NULL);



CREATE INDEX "idx_opportunity_comments_created" ON "app"."opportunity_comments" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_opportunity_comments_listing" ON "app"."opportunity_comments" USING "btree" ("listing_id", "created_at" DESC) WHERE ("listing_id" IS NOT NULL);



CREATE INDEX "idx_opportunity_comments_opportunity" ON "app"."opportunity_comments" USING "btree" ("opportunity_id");



CREATE INDEX "idx_opportunity_comments_user" ON "app"."opportunity_comments" USING "btree" ("user_id");



CREATE INDEX "idx_opportunity_inquiries_buyer_id" ON "app"."opportunity_inquiries" USING "btree" ("buyer_id", "last_message_at" DESC);



CREATE INDEX "idx_opportunity_inquiries_listing_id" ON "app"."opportunity_inquiries" USING "btree" ("listing_id");



CREATE INDEX "idx_opportunity_inquiries_merchant_id" ON "app"."opportunity_inquiries" USING "btree" ("merchant_id", "status", "last_message_at" DESC);



CREATE INDEX "idx_opportunity_inquiries_opportunity_id" ON "app"."opportunity_inquiries" USING "btree" ("opportunity_id");



CREATE INDEX "idx_opportunity_inquiry_messages_inquiry_id" ON "app"."opportunity_inquiry_messages" USING "btree" ("inquiry_id", "created_at" DESC);



CREATE INDEX "idx_opportunity_reactions_listing" ON "app"."opportunity_reactions" USING "btree" ("listing_id", "reaction_type") WHERE ("listing_id" IS NOT NULL);



CREATE INDEX "idx_opportunity_reactions_opportunity" ON "app"."opportunity_reactions" USING "btree" ("opportunity_id");



CREATE INDEX "idx_opportunity_reactions_user" ON "app"."opportunity_reactions" USING "btree" ("user_id");



CREATE INDEX "idx_opportunity_views_user" ON "app"."opportunity_views" USING "btree" ("user_id");



CREATE INDEX "idx_payout_queue_beneficiary" ON "app"."payout_queue" USING "btree" ("beneficiary_user_id");



CREATE INDEX "idx_payout_queue_status" ON "app"."payout_queue" USING "btree" ("status");



CREATE INDEX "idx_platform_ledger_created" ON "app"."platform_ledger" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_platform_ledger_type" ON "app"."platform_ledger" USING "btree" ("transaction_type");



CREATE INDEX "idx_prep_doc_chunks_embedding" ON "app"."prep_doc_chunks" USING "hnsw" ("embedding" "extensions"."vector_cosine_ops");



CREATE INDEX "idx_prep_exam_blanc_attempts_user" ON "app"."prep_exam_blanc_attempts" USING "btree" ("user_id", "exam_blanc_id");



CREATE INDEX "idx_prep_exam_blancs_published" ON "app"."prep_exam_blancs" USING "btree" ("is_published", "concours_type");



CREATE INDEX "idx_prep_news_articles_injected" ON "app"."prep_news_articles" USING "btree" ("is_injected");



CREATE INDEX "idx_prep_news_articles_published" ON "app"."prep_news_articles" USING "btree" ("published_at" DESC);



CREATE INDEX "idx_prep_news_articles_source" ON "app"."prep_news_articles" USING "btree" ("source_id");



CREATE INDEX "idx_rsr_payment_reason" ON "app"."revenue_split_rules" USING "btree" ("payment_reason");



CREATE INDEX "idx_scan_logs_student" ON "app"."prep_scan_logs" USING "btree" ("student_id", "created_at" DESC);



CREATE INDEX "idx_short_training_messages_reg" ON "app"."short_training_messages" USING "btree" ("registration_id", "created_at");



CREATE INDEX "idx_student_home_slots_slot" ON "app"."student_home_slots" USING "btree" ("slot", "sort_order", "created_at");



CREATE INDEX "idx_student_home_videos_video_asset_id" ON "app"."student_home_videos" USING "btree" ("video_asset_id");



CREATE INDEX "idx_subscriptions_expires" ON "app"."subscriptions" USING "btree" ("expires_at") WHERE ("status" = 'active'::"text");



CREATE INDEX "idx_subscriptions_student_status" ON "app"."subscriptions" USING "btree" ("student_id", "status");



CREATE INDEX "idx_support_conv_requester" ON "app"."support_conversations" USING "btree" ("requester_user_id");



CREATE INDEX "idx_support_conv_status" ON "app"."support_conversations" USING "btree" ("status");



CREATE INDEX "idx_support_msg_conv" ON "app"."support_messages" USING "btree" ("conversation_id", "created_at" DESC);



CREATE INDEX "idx_td_collections_program" ON "app"."td_collections" USING "btree" ("program_id");



CREATE INDEX "idx_td_doc_chunks_embedding" ON "app"."td_doc_chunks" USING "hnsw" ("embedding" "extensions"."vector_cosine_ops");



CREATE INDEX "idx_td_enrollments_student" ON "app"."td_enrollments" USING "btree" ("student_id");



CREATE INDEX "idx_td_enrollments_teacher" ON "app"."td_enrollments" USING "btree" ("assigned_teacher_id");



CREATE INDEX "idx_td_gen_assign_field" ON "app"."td_generated_assignments" USING "btree" ("field");



CREATE INDEX "idx_td_gen_assign_student" ON "app"."td_generated_assignments" USING "btree" ("student_id");



CREATE INDEX "idx_td_gen_assign_subject" ON "app"."td_generated_assignments" USING "btree" ("subject");



CREATE INDEX "idx_td_messages_enrollment" ON "app"."td_messages" USING "btree" ("td_enrollment_id");



CREATE INDEX "idx_td_messages_student" ON "app"."td_messages" USING "btree" ("student_user_id");



CREATE INDEX "idx_td_messages_teacher" ON "app"."td_messages" USING "btree" ("teacher_user_id");



CREATE INDEX "idx_td_programs_field_level" ON "app"."td_programs" USING "btree" ("field_id", "level");



CREATE INDEX "idx_td_questions_field" ON "app"."td_questions" USING "btree" ("field");



CREATE INDEX "idx_td_questions_gen_mode" ON "app"."td_questions" USING "btree" ("generation_mode");



CREATE INDEX "idx_td_questions_semester" ON "app"."td_questions" USING "btree" ("semester");



CREATE INDEX "idx_td_questions_study_year" ON "app"."td_questions" USING "btree" ("study_year");



CREATE INDEX "idx_td_resources_collection" ON "app"."td_resources" USING "btree" ("collection_id");



CREATE INDEX "idx_td_resources_program" ON "app"."td_resources" USING "btree" ("program_id");



CREATE INDEX "idx_td_resources_session" ON "app"."td_resources" USING "btree" ("session_id");



CREATE INDEX "idx_td_scan_logs_student" ON "app"."td_scan_logs" USING "btree" ("student_id", "created_at" DESC);



CREATE INDEX "idx_td_session_occurrences_enrollment" ON "app"."td_session_occurrences" USING "btree" ("enrollment_id");



CREATE INDEX "idx_td_session_occurrences_schedule" ON "app"."td_session_occurrences" USING "btree" ("scheduled_at");



CREATE INDEX "idx_td_session_occurrences_teacher" ON "app"."td_session_occurrences" USING "btree" ("teacher_id");



CREATE INDEX "idx_td_sessions_collection" ON "app"."td_sessions" USING "btree" ("collection_id");



CREATE INDEX "idx_td_student_requests_status" ON "app"."td_student_requests" USING "btree" ("status");



CREATE INDEX "idx_td_student_requests_student" ON "app"."td_student_requests" USING "btree" ("student_id");



CREATE INDEX "idx_td_teacher_availability_teacher" ON "app"."td_teacher_availability" USING "btree" ("teacher_id", "weekday");



CREATE INDEX "idx_td_xp_log_student" ON "app"."td_xp_log" USING "btree" ("student_id", "created_at" DESC);



CREATE INDEX "idx_tournament_matches_participants" ON "app"."tournament_matches" USING "btree" ("participant1_id", "participant2_id");



CREATE INDEX "idx_tournament_matches_round" ON "app"."tournament_matches" USING "btree" ("round_number", "match_number");



CREATE INDEX "idx_tournament_matches_status" ON "app"."tournament_matches" USING "btree" ("status");



CREATE INDEX "idx_tournament_matches_tournament" ON "app"."tournament_matches" USING "btree" ("tournament_id");



CREATE INDEX "idx_tournament_participants_seed" ON "app"."tournament_participants" USING "btree" ("seed_number");



CREATE INDEX "idx_tournament_participants_status" ON "app"."tournament_participants" USING "btree" ("status");



CREATE INDEX "idx_tournament_participants_tournament" ON "app"."tournament_participants" USING "btree" ("tournament_id");



CREATE INDEX "idx_tournament_participants_user" ON "app"."tournament_participants" USING "btree" ("user_id");



CREATE INDEX "idx_tournament_rewards_league" ON "app"."tournament_rewards" USING "btree" ("league_id");



CREATE INDEX "idx_tournament_rewards_rank" ON "app"."tournament_rewards" USING "btree" ("rank_from", "rank_to");



CREATE INDEX "idx_tournament_rewards_tournament" ON "app"."tournament_rewards" USING "btree" ("tournament_id");



CREATE INDEX "idx_tournaments_created_by" ON "app"."tournaments" USING "btree" ("created_by");



CREATE INDEX "idx_tournaments_dates" ON "app"."tournaments" USING "btree" ("start_date", "end_date");



CREATE INDEX "idx_tournaments_featured" ON "app"."tournaments" USING "btree" ("is_featured");



CREATE INDEX "idx_tournaments_game_type" ON "app"."tournaments" USING "btree" ("game_type");



CREATE INDEX "idx_tournaments_status" ON "app"."tournaments" USING "btree" ("status");



CREATE INDEX "idx_university_media_video_asset_id" ON "app"."university_media" USING "btree" ("video_asset_id");



CREATE INDEX "idx_user_announcement_reads_announcement" ON "app"."user_announcement_reads" USING "btree" ("announcement_id");



CREATE INDEX "idx_user_announcement_reads_user" ON "app"."user_announcement_reads" USING "btree" ("user_id");



CREATE INDEX "idx_user_event_follows_event" ON "app"."user_event_follows" USING "btree" ("event_id");



CREATE INDEX "idx_user_event_follows_user" ON "app"."user_event_follows" USING "btree" ("user_id");



CREATE INDEX "idx_video_asset_contexts_asset" ON "app"."video_asset_contexts" USING "btree" ("video_asset_id");



CREATE INDEX "idx_video_asset_contexts_context" ON "app"."video_asset_contexts" USING "btree" ("context_type", "context_id");



CREATE INDEX "idx_video_asset_legacy_map_asset" ON "app"."video_asset_legacy_map" USING "btree" ("video_asset_id");



CREATE INDEX "idx_video_asset_legacy_map_ctx" ON "app"."video_asset_legacy_map" USING "btree" ("context_type", "context_id");



CREATE INDEX "idx_video_assets_origin" ON "app"."video_assets" USING "btree" ("origin");



CREATE INDEX "idx_video_assets_owner" ON "app"."video_assets" USING "btree" ("owner_user_id");



CREATE INDEX "idx_video_assets_status" ON "app"."video_assets" USING "btree" ("status");



CREATE INDEX "idx_video_comments_created_at" ON "app"."video_comments" USING "btree" ("created_at");



CREATE INDEX "idx_video_comments_user" ON "app"."video_comments" USING "btree" ("user_id");



CREATE INDEX "idx_video_comments_video" ON "app"."video_comments" USING "btree" ("video_type", "video_id");



CREATE INDEX "idx_video_engagement_daily_video" ON "app"."video_engagement_daily" USING "btree" ("video_id", "day");



CREATE INDEX "idx_video_favorites_user" ON "app"."video_favorites" USING "btree" ("user_id");



CREATE INDEX "idx_video_favorites_video" ON "app"."video_favorites" USING "btree" ("video_type", "video_id");



CREATE INDEX "idx_video_heatmap_video_id" ON "app"."video_heatmap_events" USING "btree" ("video_id");



CREATE INDEX "idx_video_likes_user" ON "app"."video_likes" USING "btree" ("user_id");



CREATE INDEX "idx_video_likes_video" ON "app"."video_likes" USING "btree" ("video_type", "video_id");



CREATE INDEX "idx_video_processing_jobs_asset" ON "app"."video_processing_jobs" USING "btree" ("video_asset_id");



CREATE INDEX "idx_video_processing_jobs_status" ON "app"."video_processing_jobs" USING "btree" ("status");



CREATE INDEX "idx_video_reactions_user" ON "app"."video_reactions" USING "btree" ("user_id");



CREATE INDEX "idx_video_reactions_video" ON "app"."video_reactions" USING "btree" ("video_id");



CREATE INDEX "idx_video_renditions_asset" ON "app"."video_renditions" USING "btree" ("video_asset_id");



CREATE INDEX "idx_video_renditions_kind" ON "app"."video_renditions" USING "btree" ("kind");



CREATE INDEX "idx_video_renditions_status" ON "app"."video_renditions" USING "btree" ("status");



CREATE INDEX "idx_video_reports_reporter" ON "app"."video_reports" USING "btree" ("reporter_id");



CREATE INDEX "idx_video_reports_status" ON "app"."video_reports" USING "btree" ("status");



CREATE INDEX "idx_video_reports_video" ON "app"."video_reports" USING "btree" ("video_type", "video_id");



CREATE INDEX "idx_video_shares_video" ON "app"."video_shares" USING "btree" ("video_id");



CREATE INDEX "idx_video_sources_asset" ON "app"."video_sources" USING "btree" ("video_asset_id");



CREATE INDEX "idx_video_views_created_at" ON "app"."video_views" USING "btree" ("created_at");



CREATE INDEX "idx_video_views_user_id" ON "app"."video_views" USING "btree" ("user_id");



CREATE INDEX "idx_video_views_video_id" ON "app"."video_views" USING "btree" ("video_id");



CREATE INDEX "idx_weaknesses_student_subject" ON "app"."prep_student_weaknesses" USING "btree" ("student_id", "subject_id");



CREATE INDEX "marketplace_cart_items_cart_id_idx" ON "app"."marketplace_cart_items" USING "btree" ("cart_id");



CREATE UNIQUE INDEX "marketplace_carts_one_open_per_user" ON "app"."marketplace_carts" USING "btree" ("user_id") WHERE ("status" = 'open'::"text");



CREATE UNIQUE INDEX "marketplace_categories_code_uq" ON "app"."marketplace_categories" USING "btree" ("lower"("code"));



CREATE INDEX "marketplace_categories_parent_idx" ON "app"."marketplace_categories" USING "btree" ("parent_id");



CREATE INDEX "marketplace_listing_bookmarks_listing_idx" ON "app"."marketplace_listing_bookmarks" USING "btree" ("listing_id");



CREATE INDEX "marketplace_listing_media_active_sort_idx" ON "app"."marketplace_listing_media" USING "btree" ("listing_id", "is_active", "sort_order");



CREATE INDEX "marketplace_listing_media_listing_id_idx" ON "app"."marketplace_listing_media" USING "btree" ("listing_id");



CREATE INDEX "marketplace_listings_category_id_idx" ON "app"."marketplace_listings" USING "btree" ("category_id");



CREATE INDEX "marketplace_listings_sub_category_id_idx" ON "app"."marketplace_listings" USING "btree" ("sub_category_id");



CREATE INDEX "marketplace_order_items_order_id_idx" ON "app"."marketplace_order_items" USING "btree" ("order_id");



CREATE INDEX "marketplace_orders_merchant_id_created_at_idx" ON "app"."marketplace_orders" USING "btree" ("merchant_id", "created_at" DESC);



CREATE INDEX "marketplace_orders_student_id_created_at_idx" ON "app"."marketplace_orders" USING "btree" ("student_id", "created_at" DESC);



CREATE INDEX "marketplace_products_merchant_id_idx" ON "app"."marketplace_products" USING "btree" ("merchant_id");



CREATE INDEX "payment_proofs_payment_id_idx" ON "app"."payment_proofs" USING "btree" ("payment_id");



CREATE INDEX "payment_receipts_payment_id_idx" ON "app"."payment_receipts" USING "btree" ("payment_id");



CREATE UNIQUE INDEX "payment_receipts_receipt_number_key" ON "app"."payment_receipts" USING "btree" ("receipt_number");



CREATE INDEX "referral_commissions_commercial_idx" ON "app"."referral_commissions" USING "btree" ("commercial_user_id");



CREATE UNIQUE INDEX "referral_commissions_commercial_payment_unique" ON "app"."referral_commissions" USING "btree" ("commercial_user_id", "payment_id");



CREATE INDEX "referral_commissions_payment_idx" ON "app"."referral_commissions" USING "btree" ("payment_id");



CREATE INDEX "referral_commissions_status_idx" ON "app"."referral_commissions" USING "btree" ("status");



CREATE INDEX "referral_commissions_student_idx" ON "app"."referral_commissions" USING "btree" ("student_id");



CREATE INDEX "university_events_university_id_start_at_idx" ON "app"."university_events" USING "btree" ("university_id", "start_at");



CREATE INDEX "university_media_university_id_idx" ON "app"."university_media" USING "btree" ("university_id");



CREATE INDEX "university_news_university_id_published_at_idx" ON "app"."university_news" USING "btree" ("university_id", "published_at");



CREATE INDEX "university_site_banners_university_id_idx" ON "app"."university_site_banners" USING "btree" ("university_id");



CREATE INDEX "university_site_blocks_university_id_idx" ON "app"."university_site_blocks" USING "btree" ("university_id");



CREATE INDEX "university_site_config_university_id_idx" ON "app"."university_site_config" USING "btree" ("university_id");



CREATE INDEX "university_staff_university_id_sort_order_idx" ON "app"."university_staff" USING "btree" ("university_id", "sort_order");



CREATE UNIQUE INDEX "uq_td_attendance_occurrence_student" ON "app"."td_attendance" USING "btree" ("occurrence_id", "student_id");



CREATE INDEX "user_referrals_commercial_idx" ON "app"."user_referrals" USING "btree" ("commercial_user_id");



CREATE INDEX "user_referrals_ref_code_idx" ON "app"."user_referrals" USING "btree" ("ref_code");



CREATE UNIQUE INDEX "user_referrals_student_unique" ON "app"."user_referrals" USING "btree" ("student_id");



CREATE OR REPLACE TRIGGER "payment_receipts_no_delete" BEFORE DELETE ON "app"."payment_receipts" FOR EACH ROW EXECUTE FUNCTION "app"."payment_receipts_block_changes"();



CREATE OR REPLACE TRIGGER "payment_receipts_no_update" BEFORE UPDATE ON "app"."payment_receipts" FOR EACH ROW EXECUTE FUNCTION "app"."payment_receipts_block_changes"();



CREATE OR REPLACE TRIGGER "tr_leagues_updated_at" BEFORE UPDATE ON "app"."leagues" FOR EACH ROW EXECUTE FUNCTION "app"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "tr_tournaments_updated_at" BEFORE UPDATE ON "app"."tournaments" FOR EACH ROW EXECUTE FUNCTION "app"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "tr_update_league_player_count" AFTER INSERT OR DELETE ON "app"."league_participations" FOR EACH ROW EXECUTE FUNCTION "app"."update_league_player_count"();



CREATE OR REPLACE TRIGGER "tr_update_tournament_participant_count" AFTER INSERT OR DELETE ON "app"."tournament_participants" FOR EACH ROW EXECUTE FUNCTION "app"."update_tournament_participant_count"();



CREATE OR REPLACE TRIGGER "trg_admin_application_message_notify" AFTER INSERT ON "app"."application_messages" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_admin_application_message"();



CREATE OR REPLACE TRIGGER "trg_admin_challenge_participation_notify" AFTER INSERT ON "app"."challenge_participations" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_admin_challenge_participation"();



CREATE OR REPLACE TRIGGER "trg_admin_community_join_notify" AFTER INSERT ON "app"."community_join_requests" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_admin_community_join"();



CREATE OR REPLACE TRIGGER "trg_admin_course_enrollment_notify" AFTER INSERT ON "app"."online_course_enrollments" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_admin_course_enrollment"();



CREATE OR REPLACE TRIGGER "trg_admin_marketplace_order_notify" AFTER INSERT ON "app"."marketplace_orders" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_admin_marketplace_order"();



CREATE OR REPLACE TRIGGER "trg_admin_new_application_notify" AFTER INSERT ON "app"."applications" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_admin_new_application"();



CREATE OR REPLACE TRIGGER "trg_admin_opportunity_application_notify" AFTER INSERT ON "app"."opportunity_applications" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_admin_opportunity_application"();



CREATE OR REPLACE TRIGGER "trg_admin_payment_declared_notify" AFTER INSERT OR UPDATE ON "app"."application_payments" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_admin_payment_declared"();



CREATE OR REPLACE TRIGGER "trg_admin_td_message_notify" AFTER INSERT ON "app"."td_messages" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_admin_td_message"();



CREATE OR REPLACE TRIGGER "trg_admin_td_request_notify" AFTER INSERT ON "app"."td_student_requests" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_admin_td_request"();



CREATE OR REPLACE TRIGGER "trg_admin_training_registration_notify" AFTER INSERT ON "app"."short_training_registrations" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_admin_training_registration"();



CREATE OR REPLACE TRIGGER "trg_app_application_messages_notify" AFTER INSERT ON "app"."application_messages" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_application_message"();



CREATE OR REPLACE TRIGGER "trg_app_application_payments_referral_commission" AFTER UPDATE ON "app"."application_payments" FOR EACH ROW EXECUTE FUNCTION "public"."app_on_payment_confirmed_generate_referral_commission"();

ALTER TABLE "app"."application_payments" DISABLE TRIGGER "trg_app_application_payments_referral_commission";



CREATE OR REPLACE TRIGGER "trg_app_bobodo_messages_notify" AFTER INSERT ON "app"."bobodo_messages" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_bobodo_message"();



CREATE OR REPLACE TRIGGER "trg_app_challenges_notify_students" AFTER INSERT ON "app"."challenges" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_challenge_created"();



CREATE OR REPLACE TRIGGER "trg_app_community_posts_notify" AFTER INSERT ON "app"."community_posts" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_community_post"();



CREATE OR REPLACE TRIGGER "trg_app_official_announcements_notify" AFTER INSERT ON "app"."official_announcements" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_official_announcement"();



CREATE OR REPLACE TRIGGER "trg_app_online_course_lessons_notify" AFTER INSERT ON "app"."online_course_lessons" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_online_course_lesson"();



CREATE OR REPLACE TRIGGER "trg_app_online_course_lives_notify" AFTER INSERT ON "app"."online_course_live_sessions" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_online_course_live"();



CREATE OR REPLACE TRIGGER "trg_app_online_courses_notify" AFTER INSERT ON "app"."online_courses" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_online_course_created"();



CREATE OR REPLACE TRIGGER "trg_app_opportunities_notify" AFTER INSERT OR UPDATE ON "app"."opportunities" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_opportunity_change"();



CREATE OR REPLACE TRIGGER "trg_app_opportunities_notify_students" AFTER INSERT ON "app"."opportunities" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_opportunity_to_students"();



CREATE OR REPLACE TRIGGER "trg_app_opportunity_comments_notify" AFTER INSERT ON "app"."opportunity_comments" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_opportunity_comment"();



CREATE OR REPLACE TRIGGER "trg_app_prep_chapters_notify" AFTER INSERT OR UPDATE ON "app"."prep_chapters" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_prep_concours_change"();



CREATE OR REPLACE TRIGGER "trg_app_prep_exams_notify" AFTER INSERT OR UPDATE ON "app"."prep_exams" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_prep_concours_change"();



CREATE OR REPLACE TRIGGER "trg_app_prep_questions_notify" AFTER INSERT OR UPDATE ON "app"."prep_questions" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_prep_concours_change"();



CREATE OR REPLACE TRIGGER "trg_app_prep_subjects_notify" AFTER INSERT OR UPDATE ON "app"."prep_subjects" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_prep_concours_change"();



CREATE OR REPLACE TRIGGER "trg_app_short_training_sessions_notify_students" AFTER INSERT ON "app"."short_training_sessions" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_short_training_session"();



CREATE OR REPLACE TRIGGER "trg_app_short_trainings_notify_students" AFTER INSERT ON "app"."short_trainings" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_short_training_created"();



CREATE OR REPLACE TRIGGER "trg_app_student_home_announcements_notify" AFTER INSERT ON "app"."student_home_announcements" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_student_home_content"();



CREATE OR REPLACE TRIGGER "trg_app_student_home_videos_notify" AFTER INSERT ON "app"."student_home_videos" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_student_home_content"();



CREATE OR REPLACE TRIGGER "trg_app_university_events_notify" AFTER INSERT ON "app"."university_events" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_university_events"();



CREATE OR REPLACE TRIGGER "trg_app_university_news_notify" AFTER INSERT ON "app"."university_news" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_university_news"();



CREATE OR REPLACE TRIGGER "trg_commercial_commission_notify" AFTER INSERT ON "app"."referral_commissions" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_commercial_commission"();



CREATE OR REPLACE TRIGGER "trg_commercial_payment_confirmed_notify" AFTER UPDATE ON "app"."application_payments" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_commercial_payment_confirmed"();



CREATE OR REPLACE TRIGGER "trg_commercial_prospect_payment_notify" AFTER INSERT OR UPDATE ON "app"."application_payments" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_commercial_prospect_payment"();



CREATE OR REPLACE TRIGGER "trg_commercial_referral_notify" AFTER INSERT ON "app"."user_referrals" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_commercial_referral"();



CREATE OR REPLACE TRIGGER "trg_hero_overlays_tv_set_updated_at" BEFORE UPDATE ON "app"."hero_overlays_tv" FOR EACH ROW EXECUTE FUNCTION "app"."tg_hero_overlays_tv_set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_hero_playlist_autofill_from_rendition" AFTER INSERT OR UPDATE OF "status", "public_url_hint" ON "app"."video_renditions" FOR EACH ROW EXECUTE FUNCTION "app"."fn_hero_playlist_autofill_base_video_url_from_rendition"();



CREATE OR REPLACE TRIGGER "trg_hero_renders_tv_set_updated_at" BEFORE UPDATE ON "app"."hero_renders_tv" FOR EACH ROW EXECUTE FUNCTION "app"."tg_hero_renders_tv_set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_instructor_course_enrollment_notify" AFTER INSERT ON "app"."online_course_enrollments" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_instructor_course_enrollment"();



CREATE OR REPLACE TRIGGER "trg_instructor_forum_message_notify" AFTER INSERT ON "app"."online_course_forum_messages" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_instructor_forum_message"();



CREATE OR REPLACE TRIGGER "trg_instructor_td_enrollment_notify" AFTER INSERT OR UPDATE ON "app"."td_enrollments" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_instructor_td_enrollment"();



CREATE OR REPLACE TRIGGER "trg_instructor_td_message_notify" AFTER INSERT ON "app"."td_messages" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_instructor_td_message"();



CREATE OR REPLACE TRIGGER "trg_marketplace_reviews_rating" AFTER INSERT OR DELETE OR UPDATE ON "app"."marketplace_reviews" FOR EACH ROW EXECUTE FUNCTION "public"."app_trigger_update_listing_rating"();



CREATE OR REPLACE TRIGGER "trg_notification_events_instant_push" AFTER INSERT ON "app"."notification_events" FOR EACH ROW EXECUTE FUNCTION "app"."trg_instant_push_notification"();



CREATE OR REPLACE TRIGGER "trg_notify_inquiry_message" AFTER INSERT ON "app"."opportunity_inquiry_messages" FOR EACH ROW EXECUTE FUNCTION "app"."trg_notify_inquiry_message"();



CREATE OR REPLACE TRIGGER "trg_notify_opportunity_review" AFTER UPDATE OF "review_status" ON "app"."opportunities" FOR EACH ROW EXECUTE FUNCTION "app"."trg_notify_opportunity_review"();



CREATE OR REPLACE TRIGGER "trg_student_payment_status_notify" AFTER UPDATE ON "app"."application_payments" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_student_payment_status"();



CREATE OR REPLACE TRIGGER "trg_td_group_member_joined" AFTER INSERT ON "app"."td_local_group_members" FOR EACH ROW EXECUTE FUNCTION "app"."app_notify_td_group_member_joined"();



CREATE OR REPLACE TRIGGER "trg_td_group_status_change" AFTER UPDATE ON "app"."td_local_groups" FOR EACH ROW EXECUTE FUNCTION "app"."app_notify_td_group_status_change"();



CREATE OR REPLACE TRIGGER "trg_td_group_teacher_assigned" AFTER UPDATE ON "app"."td_local_groups" FOR EACH ROW EXECUTE FUNCTION "app"."app_notify_td_group_teacher_assigned"();



CREATE OR REPLACE TRIGGER "trg_uni_application_message_notify" AFTER INSERT ON "app"."application_messages" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_university_application_message"();



CREATE OR REPLACE TRIGGER "trg_uni_new_application_notify" AFTER INSERT ON "app"."applications" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_university_new_application"();



CREATE OR REPLACE TRIGGER "trg_uni_payment_notify" AFTER INSERT OR UPDATE ON "app"."application_payments" FOR EACH ROW EXECUTE FUNCTION "public"."app_notify_university_payment"();



CREATE OR REPLACE TRIGGER "trg_update_commercial_tier" AFTER INSERT OR DELETE OR UPDATE ON "app"."referral_commissions" FOR EACH ROW EXECUTE FUNCTION "app"."fn_update_commercial_tier"();



CREATE OR REPLACE TRIGGER "trg_update_student_weaknesses" AFTER INSERT OR UPDATE ON "app"."prep_quiz_attempts" FOR EACH ROW EXECUTE FUNCTION "app"."update_student_weaknesses_from_attempt"();



CREATE OR REPLACE TRIGGER "trg_video_assets_set_updated_at" BEFORE UPDATE ON "app"."video_assets" FOR EACH ROW EXECUTE FUNCTION "app"."tg_video_assets_set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_video_processing_jobs_set_updated_at" BEFORE UPDATE ON "app"."video_processing_jobs" FOR EACH ROW EXECUTE FUNCTION "app"."tg_video_processing_jobs_set_updated_at"();



ALTER TABLE ONLY "app"."admin_user_action_logs"
    ADD CONSTRAINT "admin_user_action_logs_performed_by_fkey" FOREIGN KEY ("performed_by") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."admin_user_action_logs"
    ADD CONSTRAINT "admin_user_action_logs_target_user_fkey" FOREIGN KEY ("target_user") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."admin_users"
    ADD CONSTRAINT "admin_users_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."application_files"
    ADD CONSTRAINT "application_files_application_id_fkey" FOREIGN KEY ("application_id") REFERENCES "app"."applications"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."application_messages"
    ADD CONSTRAINT "application_messages_application_id_fkey" FOREIGN KEY ("application_id") REFERENCES "app"."applications"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."application_payments"
    ADD CONSTRAINT "application_payments_application_id_fkey" FOREIGN KEY ("application_id") REFERENCES "app"."applications"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."application_payments"
    ADD CONSTRAINT "application_payments_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "app"."students"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."application_payments"
    ADD CONSTRAINT "application_payments_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "app"."universities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."applications"
    ADD CONSTRAINT "applications_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "app"."students"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."bobodo_detected_needs"
    ADD CONSTRAINT "bobodo_detected_needs_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "app"."bobodo_sessions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."bobodo_feedback"
    ADD CONSTRAINT "bobodo_feedback_message_id_fkey" FOREIGN KEY ("message_id") REFERENCES "app"."bobodo_messages"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."bobodo_feedback"
    ADD CONSTRAINT "bobodo_feedback_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "app"."bobodo_sessions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."bobodo_feedback"
    ADD CONSTRAINT "bobodo_feedback_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "app"."students"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."bobodo_messages"
    ADD CONSTRAINT "bobodo_messages_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "app"."bobodo_sessions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."bobodo_sessions"
    ADD CONSTRAINT "bobodo_sessions_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "app"."students"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."bobodo_unanswered_questions"
    ADD CONSTRAINT "bobodo_unanswered_questions_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "app"."bobodo_sessions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."challenge_comments"
    ADD CONSTRAINT "challenge_comments_participation_id_fkey" FOREIGN KEY ("participation_id") REFERENCES "app"."challenge_participations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."challenge_comments"
    ADD CONSTRAINT "challenge_comments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."challenge_favorites"
    ADD CONSTRAINT "challenge_favorites_participation_id_fkey" FOREIGN KEY ("participation_id") REFERENCES "app"."challenge_participations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."challenge_favorites"
    ADD CONSTRAINT "challenge_favorites_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."challenge_likes"
    ADD CONSTRAINT "challenge_likes_participation_id_fkey" FOREIGN KEY ("participation_id") REFERENCES "app"."challenge_participations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."challenge_likes"
    ADD CONSTRAINT "challenge_likes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."challenge_participation_videos"
    ADD CONSTRAINT "challenge_participation_videos_participation_id_fkey" FOREIGN KEY ("participation_id") REFERENCES "app"."challenge_participations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."challenge_participation_videos"
    ADD CONSTRAINT "challenge_participation_videos_video_asset_id_fkey" FOREIGN KEY ("video_asset_id") REFERENCES "app"."video_assets"("id");



ALTER TABLE ONLY "app"."challenge_participations"
    ADD CONSTRAINT "challenge_participations_challenge_id_fkey" FOREIGN KEY ("challenge_id") REFERENCES "app"."challenges"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."challenge_participations"
    ADD CONSTRAINT "challenge_participations_moderated_by_admin_id_fkey" FOREIGN KEY ("moderated_by_admin_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."challenge_participations"
    ADD CONSTRAINT "challenge_participations_parent_participation_id_fkey" FOREIGN KEY ("parent_participation_id") REFERENCES "app"."challenge_participations"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."challenge_participations"
    ADD CONSTRAINT "challenge_participations_reviewed_by_user_id_fkey" FOREIGN KEY ("reviewed_by_user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."challenge_participations"
    ADD CONSTRAINT "challenge_participations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."challenge_participations"
    ADD CONSTRAINT "challenge_participations_video_asset_id_fkey" FOREIGN KEY ("video_asset_id") REFERENCES "app"."video_assets"("id");



ALTER TABLE ONLY "app"."challenge_reports"
    ADD CONSTRAINT "challenge_reports_handled_by_admin_id_fkey" FOREIGN KEY ("handled_by_admin_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."challenge_reports"
    ADD CONSTRAINT "challenge_reports_participation_id_fkey" FOREIGN KEY ("participation_id") REFERENCES "app"."challenge_participations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."challenge_reports"
    ADD CONSTRAINT "challenge_reports_reporter_id_fkey" FOREIGN KEY ("reporter_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."challenge_user_bans"
    ADD CONSTRAINT "challenge_user_bans_created_by_admin_id_fkey" FOREIGN KEY ("created_by_admin_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."challenge_user_bans"
    ADD CONSTRAINT "challenge_user_bans_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."challenge_video_overlays"
    ADD CONSTRAINT "challenge_video_overlays_participation_id_fkey" FOREIGN KEY ("participation_id") REFERENCES "app"."challenge_participations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."challenge_video_render_jobs"
    ADD CONSTRAINT "challenge_video_render_jobs_participation_id_fkey" FOREIGN KEY ("participation_id") REFERENCES "app"."challenge_participations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."challenges"
    ADD CONSTRAINT "challenges_created_by_user_id_fkey" FOREIGN KEY ("created_by_user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."commercial_milestone_claims"
    ADD CONSTRAINT "commercial_milestone_claims_commercial_user_id_fkey" FOREIGN KEY ("commercial_user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."commercial_milestone_claims"
    ADD CONSTRAINT "commercial_milestone_claims_milestone_id_fkey" FOREIGN KEY ("milestone_id") REFERENCES "app"."commercial_milestones"("id");



ALTER TABLE ONLY "app"."commercial_profiles"
    ADD CONSTRAINT "commercial_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."communities"
    ADD CONSTRAINT "communities_created_by_user_id_fkey" FOREIGN KEY ("created_by_user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."community_join_requests"
    ADD CONSTRAINT "community_join_requests_community_id_fkey" FOREIGN KEY ("community_id") REFERENCES "app"."communities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."community_join_requests"
    ADD CONSTRAINT "community_join_requests_handled_by_user_id_fkey" FOREIGN KEY ("handled_by_user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."community_join_requests"
    ADD CONSTRAINT "community_join_requests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."community_memberships"
    ADD CONSTRAINT "community_memberships_community_id_fkey" FOREIGN KEY ("community_id") REFERENCES "app"."communities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."community_memberships"
    ADD CONSTRAINT "community_memberships_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."community_poll_votes"
    ADD CONSTRAINT "community_poll_votes_poll_id_fkey" FOREIGN KEY ("poll_id") REFERENCES "app"."community_polls"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."community_poll_votes"
    ADD CONSTRAINT "community_poll_votes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."community_polls"
    ADD CONSTRAINT "community_polls_community_id_fkey" FOREIGN KEY ("community_id") REFERENCES "app"."communities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."community_polls"
    ADD CONSTRAINT "community_polls_created_by_user_id_fkey" FOREIGN KEY ("created_by_user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."community_post_reactions"
    ADD CONSTRAINT "community_post_reactions_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "app"."community_posts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."community_post_reactions"
    ADD CONSTRAINT "community_post_reactions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."community_posts"
    ADD CONSTRAINT "community_posts_author_id_fkey" FOREIGN KEY ("author_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."community_posts"
    ADD CONSTRAINT "community_posts_community_id_fkey" FOREIGN KEY ("community_id") REFERENCES "app"."communities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."community_posts"
    ADD CONSTRAINT "community_posts_reply_to_post_id_fkey" FOREIGN KEY ("reply_to_post_id") REFERENCES "app"."community_posts"("id");



ALTER TABLE ONLY "app"."community_read_states"
    ADD CONSTRAINT "community_read_states_community_id_fkey" FOREIGN KEY ("community_id") REFERENCES "app"."communities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."community_read_states"
    ADD CONSTRAINT "community_read_states_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."community_stories"
    ADD CONSTRAINT "community_stories_author_id_fkey" FOREIGN KEY ("author_id") REFERENCES "app"."students"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."community_stories"
    ADD CONSTRAINT "community_stories_community_id_fkey" FOREIGN KEY ("community_id") REFERENCES "app"."communities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."community_story_views"
    ADD CONSTRAINT "community_story_views_story_id_fkey" FOREIGN KEY ("story_id") REFERENCES "app"."community_stories"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."community_story_views"
    ADD CONSTRAINT "community_story_views_viewer_id_fkey" FOREIGN KEY ("viewer_id") REFERENCES "app"."students"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."competitive_events"
    ADD CONSTRAINT "competitive_events_league_id_fkey" FOREIGN KEY ("league_id") REFERENCES "app"."leagues"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."competitive_events"
    ADD CONSTRAINT "competitive_events_league_match_id_fkey" FOREIGN KEY ("league_match_id") REFERENCES "app"."league_matches"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."competitive_events"
    ADD CONSTRAINT "competitive_events_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "app"."tournament_matches"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."competitive_events"
    ADD CONSTRAINT "competitive_events_participant_id_fkey" FOREIGN KEY ("participant_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."competitive_events"
    ADD CONSTRAINT "competitive_events_tournament_id_fkey" FOREIGN KEY ("tournament_id") REFERENCES "app"."tournaments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."course_enrollments"
    ADD CONSTRAINT "course_enrollments_course_id_fkey" FOREIGN KEY ("course_id") REFERENCES "app"."courses"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."course_enrollments"
    ADD CONSTRAINT "course_enrollments_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "app"."students"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."course_resources"
    ADD CONSTRAINT "course_resources_unit_id_fkey" FOREIGN KEY ("unit_id") REFERENCES "app"."course_units"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."course_units"
    ADD CONSTRAINT "course_units_domain_id_fkey" FOREIGN KEY ("domain_id") REFERENCES "app"."course_domains"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."direct_conversations"
    ADD CONSTRAINT "direct_conversations_user_a_fkey" FOREIGN KEY ("user_a") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."direct_conversations"
    ADD CONSTRAINT "direct_conversations_user_b_fkey" FOREIGN KEY ("user_b") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."direct_message_read_states"
    ADD CONSTRAINT "direct_message_read_states_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "app"."direct_conversations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."direct_message_read_states"
    ADD CONSTRAINT "direct_message_read_states_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."direct_messages"
    ADD CONSTRAINT "direct_messages_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "app"."direct_conversations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."direct_messages"
    ADD CONSTRAINT "direct_messages_reply_to_message_id_fkey" FOREIGN KEY ("reply_to_message_id") REFERENCES "app"."direct_messages"("id");



ALTER TABLE ONLY "app"."direct_messages"
    ADD CONSTRAINT "direct_messages_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."exercises"
    ADD CONSTRAINT "exercises_course_id_fkey" FOREIGN KEY ("course_id") REFERENCES "app"."courses"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."free_video_overlays"
    ADD CONSTRAINT "free_video_overlays_free_video_id_fkey" FOREIGN KEY ("free_video_id") REFERENCES "app"."free_videos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."free_video_render_jobs"
    ADD CONSTRAINT "free_video_render_jobs_free_video_id_fkey" FOREIGN KEY ("free_video_id") REFERENCES "app"."free_videos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."free_videos"
    ADD CONSTRAINT "free_videos_moderated_by_admin_id_fkey" FOREIGN KEY ("moderated_by_admin_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."free_videos"
    ADD CONSTRAINT "free_videos_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."free_videos"
    ADD CONSTRAINT "free_videos_video_asset_id_fkey" FOREIGN KEY ("video_asset_id") REFERENCES "app"."video_assets"("id");



ALTER TABLE ONLY "app"."hero_overlays"
    ADD CONSTRAINT "hero_overlays_playlist_item_id_fkey" FOREIGN KEY ("playlist_item_id") REFERENCES "app"."hero_playlist"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."hero_overlays_tv"
    ADD CONSTRAINT "hero_overlays_tv_playlist_item_id_fkey" FOREIGN KEY ("playlist_item_id") REFERENCES "app"."hero_playlist"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."hero_playlist"
    ADD CONSTRAINT "hero_playlist_video_asset_id_fkey" FOREIGN KEY ("video_asset_id") REFERENCES "app"."video_assets"("id");



ALTER TABLE ONLY "app"."hero_renders"
    ADD CONSTRAINT "hero_renders_playlist_item_id_fkey" FOREIGN KEY ("playlist_item_id") REFERENCES "app"."hero_playlist"("id");



ALTER TABLE ONLY "app"."hero_renders_tv"
    ADD CONSTRAINT "hero_renders_tv_playlist_item_id_fkey" FOREIGN KEY ("playlist_item_id") REFERENCES "app"."hero_playlist"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."instructors"
    ADD CONSTRAINT "instructors_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."landing_config"
    ADD CONSTRAINT "landing_config_video_asset_id_fkey" FOREIGN KEY ("video_asset_id") REFERENCES "app"."video_assets"("id");



ALTER TABLE ONLY "app"."landing_videos"
    ADD CONSTRAINT "landing_videos_video_asset_id_fkey" FOREIGN KEY ("video_asset_id") REFERENCES "app"."video_assets"("id");



ALTER TABLE ONLY "app"."league_matches"
    ADD CONSTRAINT "league_matches_league_id_fkey" FOREIGN KEY ("league_id") REFERENCES "app"."leagues"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."league_matches"
    ADD CONSTRAINT "league_matches_participant1_id_fkey" FOREIGN KEY ("participant1_id") REFERENCES "app"."league_participations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."league_matches"
    ADD CONSTRAINT "league_matches_participant2_id_fkey" FOREIGN KEY ("participant2_id") REFERENCES "app"."league_participations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."league_matches"
    ADD CONSTRAINT "league_matches_winner_id_fkey" FOREIGN KEY ("winner_id") REFERENCES "app"."league_participations"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."league_participations"
    ADD CONSTRAINT "league_participations_league_id_fkey" FOREIGN KEY ("league_id") REFERENCES "app"."leagues"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."league_participations"
    ADD CONSTRAINT "league_participations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."leagues"
    ADD CONSTRAINT "leagues_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."marketplace_cart_items"
    ADD CONSTRAINT "marketplace_cart_items_cart_id_fkey" FOREIGN KEY ("cart_id") REFERENCES "app"."marketplace_carts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."marketplace_cart_items"
    ADD CONSTRAINT "marketplace_cart_items_listing_id_fkey" FOREIGN KEY ("listing_id") REFERENCES "app"."marketplace_listings"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "app"."marketplace_categories"
    ADD CONSTRAINT "marketplace_categories_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "app"."marketplace_categories"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."marketplace_listing_bookmarks"
    ADD CONSTRAINT "marketplace_listing_bookmarks_listing_id_fkey" FOREIGN KEY ("listing_id") REFERENCES "app"."marketplace_listings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."marketplace_listing_media"
    ADD CONSTRAINT "marketplace_listing_media_listing_id_fkey" FOREIGN KEY ("listing_id") REFERENCES "app"."marketplace_listings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."marketplace_listings"
    ADD CONSTRAINT "marketplace_listings_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "app"."marketplace_categories"("id");



ALTER TABLE ONLY "app"."marketplace_listings"
    ADD CONSTRAINT "marketplace_listings_sub_category_id_fkey" FOREIGN KEY ("sub_category_id") REFERENCES "app"."marketplace_categories"("id");



ALTER TABLE ONLY "app"."marketplace_merchant_balances"
    ADD CONSTRAINT "marketplace_merchant_balances_merchant_id_fkey" FOREIGN KEY ("merchant_id") REFERENCES "app"."marketplace_merchants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."marketplace_merchants"
    ADD CONSTRAINT "marketplace_merchants_owner_user_id_fkey" FOREIGN KEY ("owner_user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."marketplace_order_items"
    ADD CONSTRAINT "marketplace_order_items_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "app"."marketplace_orders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."marketplace_order_items"
    ADD CONSTRAINT "marketplace_order_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "app"."marketplace_listings"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "app"."marketplace_orders"
    ADD CONSTRAINT "marketplace_orders_merchant_id_fkey" FOREIGN KEY ("merchant_id") REFERENCES "app"."marketplace_merchants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."marketplace_orders"
    ADD CONSTRAINT "marketplace_orders_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "app"."students"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."marketplace_payments"
    ADD CONSTRAINT "marketplace_payments_buyer_id_fkey" FOREIGN KEY ("buyer_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."marketplace_payments"
    ADD CONSTRAINT "marketplace_payments_merchant_id_fkey" FOREIGN KEY ("merchant_id") REFERENCES "app"."marketplace_merchants"("id");



ALTER TABLE ONLY "app"."marketplace_payments"
    ADD CONSTRAINT "marketplace_payments_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "app"."marketplace_orders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."marketplace_products"
    ADD CONSTRAINT "marketplace_products_merchant_id_fkey" FOREIGN KEY ("merchant_id") REFERENCES "app"."marketplace_merchants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."marketplace_reviews"
    ADD CONSTRAINT "marketplace_reviews_buyer_id_fkey" FOREIGN KEY ("buyer_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."marketplace_reviews"
    ADD CONSTRAINT "marketplace_reviews_listing_id_fkey" FOREIGN KEY ("listing_id") REFERENCES "app"."marketplace_listings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."marketplace_reviews"
    ADD CONSTRAINT "marketplace_reviews_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "app"."marketplace_orders"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."moderation_events"
    ADD CONSTRAINT "moderation_events_created_by_user_id_fkey" FOREIGN KEY ("created_by_user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."moderation_events"
    ADD CONSTRAINT "moderation_events_resolved_by_user_id_fkey" FOREIGN KEY ("resolved_by_user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."notification_events"
    ADD CONSTRAINT "notification_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."online_course_certificates"
    ADD CONSTRAINT "online_course_certificates_enrollment_id_fkey" FOREIGN KEY ("enrollment_id") REFERENCES "app"."online_course_enrollments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."online_course_enrollment_messages"
    ADD CONSTRAINT "online_course_enrollment_messages_enrollment_id_fkey" FOREIGN KEY ("enrollment_id") REFERENCES "app"."online_course_enrollments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."online_course_enrollments"
    ADD CONSTRAINT "online_course_enrollments_course_id_fkey" FOREIGN KEY ("course_id") REFERENCES "app"."online_courses"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."online_course_enrollments"
    ADD CONSTRAINT "online_course_enrollments_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "app"."students"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."online_course_forum_messages"
    ADD CONSTRAINT "online_course_forum_messages_instructor_id_fkey" FOREIGN KEY ("instructor_id") REFERENCES "app"."instructors"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."online_course_forum_messages"
    ADD CONSTRAINT "online_course_forum_messages_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "app"."students"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."online_course_forum_messages"
    ADD CONSTRAINT "online_course_forum_messages_thread_id_fkey" FOREIGN KEY ("thread_id") REFERENCES "app"."online_course_forum_threads"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."online_course_forum_threads"
    ADD CONSTRAINT "online_course_forum_threads_course_id_fkey" FOREIGN KEY ("course_id") REFERENCES "app"."online_courses"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."online_course_forum_threads"
    ADD CONSTRAINT "online_course_forum_threads_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "app"."students"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."online_course_instructors"
    ADD CONSTRAINT "online_course_instructors_course_id_fkey" FOREIGN KEY ("course_id") REFERENCES "app"."online_courses"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."online_course_instructors"
    ADD CONSTRAINT "online_course_instructors_instructor_id_fkey" FOREIGN KEY ("instructor_id") REFERENCES "app"."instructors"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."online_course_lesson_media"
    ADD CONSTRAINT "online_course_lesson_media_lesson_id_fkey" FOREIGN KEY ("lesson_id") REFERENCES "app"."online_course_lessons"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."online_course_lesson_progress"
    ADD CONSTRAINT "online_course_lesson_progress_enrollment_id_fkey" FOREIGN KEY ("enrollment_id") REFERENCES "app"."online_course_enrollments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."online_course_lesson_progress"
    ADD CONSTRAINT "online_course_lesson_progress_lesson_id_fkey" FOREIGN KEY ("lesson_id") REFERENCES "app"."online_course_lessons"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."online_course_lessons"
    ADD CONSTRAINT "online_course_lessons_section_id_fkey" FOREIGN KEY ("section_id") REFERENCES "app"."online_course_sections"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."online_course_live_session_participants"
    ADD CONSTRAINT "online_course_live_session_participants_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "app"."online_course_live_sessions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."online_course_live_session_participants"
    ADD CONSTRAINT "online_course_live_session_participants_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."online_course_live_sessions"
    ADD CONSTRAINT "online_course_live_sessions_approved_by_admin_id_fkey" FOREIGN KEY ("approved_by_admin_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."online_course_live_sessions"
    ADD CONSTRAINT "online_course_live_sessions_course_id_fkey" FOREIGN KEY ("course_id") REFERENCES "app"."online_courses"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."online_course_live_sessions"
    ADD CONSTRAINT "online_course_live_sessions_host_id_fkey" FOREIGN KEY ("host_id") REFERENCES "app"."instructors"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."online_course_live_sessions"
    ADD CONSTRAINT "online_course_live_sessions_lesson_id_fkey" FOREIGN KEY ("lesson_id") REFERENCES "app"."online_course_lessons"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."online_course_live_sessions"
    ADD CONSTRAINT "online_course_live_sessions_replay_video_asset_id_fkey" FOREIGN KEY ("replay_video_asset_id") REFERENCES "app"."video_assets"("id");



ALTER TABLE ONLY "app"."online_course_sections"
    ADD CONSTRAINT "online_course_sections_course_id_fkey" FOREIGN KEY ("course_id") REFERENCES "app"."online_courses"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."online_courses"
    ADD CONSTRAINT "online_courses_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."opportunity_applications"
    ADD CONSTRAINT "opportunity_applications_opportunity_id_fkey" FOREIGN KEY ("opportunity_id") REFERENCES "app"."opportunities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."opportunity_applications"
    ADD CONSTRAINT "opportunity_applications_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "app"."students"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."opportunity_bookmarks"
    ADD CONSTRAINT "opportunity_bookmarks_listing_id_fkey" FOREIGN KEY ("listing_id") REFERENCES "app"."marketplace_listings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."opportunity_bookmarks"
    ADD CONSTRAINT "opportunity_bookmarks_opportunity_id_fkey" FOREIGN KEY ("opportunity_id") REFERENCES "app"."opportunities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."opportunity_comments"
    ADD CONSTRAINT "opportunity_comments_listing_id_fkey" FOREIGN KEY ("listing_id") REFERENCES "app"."marketplace_listings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."opportunity_comments"
    ADD CONSTRAINT "opportunity_comments_opportunity_id_fkey" FOREIGN KEY ("opportunity_id") REFERENCES "app"."opportunities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."opportunity_inquiries"
    ADD CONSTRAINT "opportunity_inquiries_listing_id_fkey" FOREIGN KEY ("listing_id") REFERENCES "app"."marketplace_listings"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."opportunity_inquiries"
    ADD CONSTRAINT "opportunity_inquiries_opportunity_id_fkey" FOREIGN KEY ("opportunity_id") REFERENCES "app"."opportunities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."opportunity_inquiry_messages"
    ADD CONSTRAINT "opportunity_inquiry_messages_inquiry_id_fkey" FOREIGN KEY ("inquiry_id") REFERENCES "app"."opportunity_inquiries"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."opportunity_reactions"
    ADD CONSTRAINT "opportunity_reactions_listing_id_fkey" FOREIGN KEY ("listing_id") REFERENCES "app"."marketplace_listings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."opportunity_reactions"
    ADD CONSTRAINT "opportunity_reactions_opportunity_id_fkey" FOREIGN KEY ("opportunity_id") REFERENCES "app"."opportunities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."payment_proofs"
    ADD CONSTRAINT "payment_proofs_payment_id_fkey" FOREIGN KEY ("payment_id") REFERENCES "app"."application_payments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."payment_receipts"
    ADD CONSTRAINT "payment_receipts_payment_id_fkey" FOREIGN KEY ("payment_id") REFERENCES "app"."application_payments"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "app"."payout_queue"
    ADD CONSTRAINT "payout_queue_source_payment_id_fkey" FOREIGN KEY ("source_payment_id") REFERENCES "app"."application_payments"("id");



ALTER TABLE ONLY "app"."prep_ai_config"
    ADD CONSTRAINT "prep_ai_config_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."prep_ai_conversations"
    ADD CONSTRAINT "prep_ai_conversations_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."prep_ai_corrections"
    ADD CONSTRAINT "prep_ai_corrections_question_id_fkey" FOREIGN KEY ("question_id") REFERENCES "app"."prep_questions"("id");



ALTER TABLE ONLY "app"."prep_ai_corrections"
    ADD CONSTRAINT "prep_ai_corrections_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."prep_ai_generations"
    ADD CONSTRAINT "prep_ai_generations_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."prep_ai_generations"
    ADD CONSTRAINT "prep_ai_generations_subject_id_fkey" FOREIGN KEY ("subject_id") REFERENCES "app"."prep_subjects"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."prep_ai_messages"
    ADD CONSTRAINT "prep_ai_messages_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "app"."prep_ai_conversations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."prep_ai_usage_logs"
    ADD CONSTRAINT "prep_ai_usage_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."prep_assignment_submissions"
    ADD CONSTRAINT "prep_assignment_submissions_assignment_id_fkey" FOREIGN KEY ("assignment_id") REFERENCES "app"."prep_assignments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."prep_assignment_submissions"
    ADD CONSTRAINT "prep_assignment_submissions_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."prep_assignments"
    ADD CONSTRAINT "prep_assignments_teacher_id_fkey" FOREIGN KEY ("teacher_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."prep_attempts"
    ADD CONSTRAINT "prep_attempts_question_id_fkey" FOREIGN KEY ("question_id") REFERENCES "app"."prep_questions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."prep_attempts"
    ADD CONSTRAINT "prep_attempts_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."prep_chapters"
    ADD CONSTRAINT "prep_chapters_subject_id_fkey" FOREIGN KEY ("subject_id") REFERENCES "app"."prep_subjects"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."prep_chunks"
    ADD CONSTRAINT "prep_chunks_subject_id_fkey" FOREIGN KEY ("subject_id") REFERENCES "app"."prep_subjects"("id");



ALTER TABLE ONLY "app"."prep_doc_chunks"
    ADD CONSTRAINT "prep_doc_chunks_source_document_id_fkey" FOREIGN KEY ("source_document_id") REFERENCES "app"."prep_source_documents"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."prep_exam_blanc_attempts"
    ADD CONSTRAINT "prep_exam_blanc_attempts_exam_blanc_id_fkey" FOREIGN KEY ("exam_blanc_id") REFERENCES "app"."prep_exam_blancs"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."prep_exam_items"
    ADD CONSTRAINT "prep_exam_items_exam_id_fkey" FOREIGN KEY ("exam_id") REFERENCES "app"."prep_exams"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."prep_exam_items"
    ADD CONSTRAINT "prep_exam_items_question_id_fkey" FOREIGN KEY ("question_id") REFERENCES "app"."prep_questions"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "app"."prep_exam_papers"
    ADD CONSTRAINT "prep_exam_papers_uploaded_by_fkey" FOREIGN KEY ("uploaded_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."prep_exams"
    ADD CONSTRAINT "prep_exams_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."prep_exams"
    ADD CONSTRAINT "prep_exams_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."prep_exams"
    ADD CONSTRAINT "prep_exams_subject_id_fkey" FOREIGN KEY ("subject_id") REFERENCES "app"."prep_subjects"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."prep_flashcard_decks"
    ADD CONSTRAINT "prep_flashcard_decks_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."prep_flashcard_progress"
    ADD CONSTRAINT "prep_flashcard_progress_flashcard_id_fkey" FOREIGN KEY ("flashcard_id") REFERENCES "app"."prep_flashcards"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."prep_flashcard_progress"
    ADD CONSTRAINT "prep_flashcard_progress_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."prep_flashcards"
    ADD CONSTRAINT "prep_flashcards_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."prep_flashcards"
    ADD CONSTRAINT "prep_flashcards_deck_id_fkey" FOREIGN KEY ("deck_id") REFERENCES "app"."prep_flashcard_decks"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."prep_live_participants"
    ADD CONSTRAINT "prep_live_participants_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "app"."prep_live_sessions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."prep_live_participants"
    ADD CONSTRAINT "prep_live_participants_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."prep_live_sessions"
    ADD CONSTRAINT "prep_live_sessions_quiz_template_id_fkey" FOREIGN KEY ("quiz_template_id") REFERENCES "app"."prep_quiz_templates"("id");



ALTER TABLE ONLY "app"."prep_live_sessions"
    ADD CONSTRAINT "prep_live_sessions_teacher_id_fkey" FOREIGN KEY ("teacher_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."prep_news_articles"
    ADD CONSTRAINT "prep_news_articles_source_id_fkey" FOREIGN KEY ("source_id") REFERENCES "app"."prep_news_sources"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."prep_psychotech_profiles"
    ADD CONSTRAINT "prep_psychotech_profiles_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."prep_psychotech_results"
    ADD CONSTRAINT "prep_psychotech_results_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."prep_question_banks"
    ADD CONSTRAINT "prep_question_banks_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."prep_question_choices"
    ADD CONSTRAINT "prep_question_choices_question_id_fkey" FOREIGN KEY ("question_id") REFERENCES "app"."prep_questions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."prep_question_topics"
    ADD CONSTRAINT "prep_question_topics_question_id_fkey" FOREIGN KEY ("question_id") REFERENCES "app"."prep_questions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."prep_question_topics"
    ADD CONSTRAINT "prep_question_topics_topic_id_fkey" FOREIGN KEY ("topic_id") REFERENCES "app"."prep_topics"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."prep_questions"
    ADD CONSTRAINT "prep_questions_bank_id_fkey" FOREIGN KEY ("bank_id") REFERENCES "app"."prep_question_banks"("id");



ALTER TABLE ONLY "app"."prep_questions"
    ADD CONSTRAINT "prep_questions_chapter_id_fkey" FOREIGN KEY ("chapter_id") REFERENCES "app"."prep_chapters"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."prep_questions"
    ADD CONSTRAINT "prep_questions_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."prep_questions"
    ADD CONSTRAINT "prep_questions_subject_id_fkey" FOREIGN KEY ("subject_id") REFERENCES "app"."prep_subjects"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."prep_quiz_attempts"
    ADD CONSTRAINT "prep_quiz_attempts_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."prep_quiz_attempts"
    ADD CONSTRAINT "prep_quiz_attempts_template_id_fkey" FOREIGN KEY ("template_id") REFERENCES "app"."prep_quiz_templates"("id");



ALTER TABLE ONLY "app"."prep_quiz_templates"
    ADD CONSTRAINT "prep_quiz_templates_bank_id_fkey" FOREIGN KEY ("bank_id") REFERENCES "app"."prep_question_banks"("id");



ALTER TABLE ONLY "app"."prep_quiz_templates"
    ADD CONSTRAINT "prep_quiz_templates_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."prep_scan_logs"
    ADD CONSTRAINT "prep_scan_logs_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."prep_source_documents"
    ADD CONSTRAINT "prep_source_documents_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."prep_source_documents"
    ADD CONSTRAINT "prep_source_documents_subject_id_fkey" FOREIGN KEY ("subject_id") REFERENCES "app"."prep_subjects"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."prep_student_badges"
    ADD CONSTRAINT "prep_student_badges_badge_id_fkey" FOREIGN KEY ("badge_id") REFERENCES "app"."prep_badges"("id");



ALTER TABLE ONLY "app"."prep_student_badges"
    ADD CONSTRAINT "prep_student_badges_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."prep_student_progress"
    ADD CONSTRAINT "prep_student_progress_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."prep_student_weaknesses"
    ADD CONSTRAINT "prep_student_weaknesses_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."prep_student_weaknesses"
    ADD CONSTRAINT "prep_student_weaknesses_subject_id_fkey" FOREIGN KEY ("subject_id") REFERENCES "app"."prep_subjects"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."prep_topic_predictions"
    ADD CONSTRAINT "prep_topic_predictions_topic_id_fkey" FOREIGN KEY ("topic_id") REFERENCES "app"."prep_topics"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."programs"
    ADD CONSTRAINT "programs_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "app"."universities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."referral_commissions"
    ADD CONSTRAINT "referral_commissions_commercial_user_id_fkey" FOREIGN KEY ("commercial_user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."referral_commissions"
    ADD CONSTRAINT "referral_commissions_payment_id_fkey" FOREIGN KEY ("payment_id") REFERENCES "app"."application_payments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."referral_commissions"
    ADD CONSTRAINT "referral_commissions_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "app"."students"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."short_training_messages"
    ADD CONSTRAINT "short_training_messages_registration_id_fkey" FOREIGN KEY ("registration_id") REFERENCES "app"."short_training_registrations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."short_training_messages"
    ADD CONSTRAINT "short_training_messages_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."short_training_registration_messages"
    ADD CONSTRAINT "short_training_registration_messages_registration_id_fkey" FOREIGN KEY ("registration_id") REFERENCES "app"."short_training_registrations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."short_training_registrations"
    ADD CONSTRAINT "short_training_registrations_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "app"."short_training_sessions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."short_training_registrations"
    ADD CONSTRAINT "short_training_registrations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."short_training_sessions"
    ADD CONSTRAINT "short_training_sessions_training_id_fkey" FOREIGN KEY ("training_id") REFERENCES "app"."short_trainings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."short_trainings"
    ADD CONSTRAINT "short_trainings_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."student_dossier_documents"
    ADD CONSTRAINT "student_dossier_documents_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "app"."students"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."student_home_videos"
    ADD CONSTRAINT "student_home_videos_video_asset_id_fkey" FOREIGN KEY ("video_asset_id") REFERENCES "app"."video_assets"("id");



ALTER TABLE ONLY "app"."students"
    ADD CONSTRAINT "students_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."subscriptions"
    ADD CONSTRAINT "subscriptions_payment_id_fkey" FOREIGN KEY ("payment_id") REFERENCES "app"."application_payments"("id");



ALTER TABLE ONLY "app"."subscriptions"
    ADD CONSTRAINT "subscriptions_plan_id_fkey" FOREIGN KEY ("plan_id") REFERENCES "app"."subscription_plans"("id");



ALTER TABLE ONLY "app"."subscriptions"
    ADD CONSTRAINT "subscriptions_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "app"."students"("id");



ALTER TABLE ONLY "app"."support_conversations"
    ADD CONSTRAINT "support_conversations_requester_user_id_fkey" FOREIGN KEY ("requester_user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."support_messages"
    ADD CONSTRAINT "support_messages_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "app"."support_conversations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."support_messages"
    ADD CONSTRAINT "support_messages_sender_user_id_fkey" FOREIGN KEY ("sender_user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."support_read_states"
    ADD CONSTRAINT "support_read_states_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "app"."support_conversations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."support_read_states"
    ADD CONSTRAINT "support_read_states_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."td_ai_config"
    ADD CONSTRAINT "td_ai_config_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."td_ai_conversations"
    ADD CONSTRAINT "td_ai_conversations_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."td_ai_messages"
    ADD CONSTRAINT "td_ai_messages_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "app"."td_ai_conversations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."td_assignment_submissions"
    ADD CONSTRAINT "td_assignment_submissions_assignment_id_fkey" FOREIGN KEY ("assignment_id") REFERENCES "app"."td_assignments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."td_assignment_submissions"
    ADD CONSTRAINT "td_assignment_submissions_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."td_assignments"
    ADD CONSTRAINT "td_assignments_enrollment_id_fkey" FOREIGN KEY ("enrollment_id") REFERENCES "app"."td_enrollments"("id");



ALTER TABLE ONLY "app"."td_assignments"
    ADD CONSTRAINT "td_assignments_teacher_id_fkey" FOREIGN KEY ("teacher_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."td_attendance"
    ADD CONSTRAINT "td_attendance_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."td_attendance"
    ADD CONSTRAINT "td_attendance_occurrence_id_fkey" FOREIGN KEY ("occurrence_id") REFERENCES "app"."td_session_occurrences"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."td_attendance"
    ADD CONSTRAINT "td_attendance_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."td_collections"
    ADD CONSTRAINT "td_collections_program_id_fkey" FOREIGN KEY ("program_id") REFERENCES "app"."td_programs"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."td_discipline_colors"
    ADD CONSTRAINT "td_discipline_colors_field_id_fkey" FOREIGN KEY ("field_id") REFERENCES "app"."td_fields"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."td_doc_chunks"
    ADD CONSTRAINT "td_doc_chunks_source_document_id_fkey" FOREIGN KEY ("source_document_id") REFERENCES "app"."td_source_documents"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."td_enrollments"
    ADD CONSTRAINT "td_enrollments_assigned_teacher_id_fkey" FOREIGN KEY ("assigned_teacher_id") REFERENCES "app"."td_teachers"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."td_enrollments"
    ADD CONSTRAINT "td_enrollments_collection_id_fkey" FOREIGN KEY ("collection_id") REFERENCES "app"."td_collections"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "app"."td_enrollments"
    ADD CONSTRAINT "td_enrollments_payment_id_fkey" FOREIGN KEY ("payment_id") REFERENCES "app"."application_payments"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."td_enrollments"
    ADD CONSTRAINT "td_enrollments_program_id_fkey" FOREIGN KEY ("program_id") REFERENCES "app"."td_programs"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "app"."td_enrollments"
    ADD CONSTRAINT "td_enrollments_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."td_exam_papers"
    ADD CONSTRAINT "td_exam_papers_uploaded_by_fkey" FOREIGN KEY ("uploaded_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."td_fields"
    ADD CONSTRAINT "td_fields_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."td_flashcard_decks"
    ADD CONSTRAINT "td_flashcard_decks_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."td_flashcard_progress"
    ADD CONSTRAINT "td_flashcard_progress_flashcard_id_fkey" FOREIGN KEY ("flashcard_id") REFERENCES "app"."td_flashcards"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."td_flashcard_progress"
    ADD CONSTRAINT "td_flashcard_progress_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."td_flashcards"
    ADD CONSTRAINT "td_flashcards_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."td_flashcards"
    ADD CONSTRAINT "td_flashcards_deck_id_fkey" FOREIGN KEY ("deck_id") REFERENCES "app"."td_flashcard_decks"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."td_local_group_members"
    ADD CONSTRAINT "td_local_group_members_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "app"."td_local_groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."td_local_group_members"
    ADD CONSTRAINT "td_local_group_members_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."td_local_groups"
    ADD CONSTRAINT "td_local_groups_assigned_teacher_id_fkey" FOREIGN KEY ("assigned_teacher_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."td_local_groups"
    ADD CONSTRAINT "td_local_groups_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."td_messages"
    ADD CONSTRAINT "td_messages_admin_user_id_fkey" FOREIGN KEY ("admin_user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."td_messages"
    ADD CONSTRAINT "td_messages_sender_user_id_fkey" FOREIGN KEY ("sender_user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."td_messages"
    ADD CONSTRAINT "td_messages_student_user_id_fkey" FOREIGN KEY ("student_user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."td_messages"
    ADD CONSTRAINT "td_messages_td_enrollment_id_fkey" FOREIGN KEY ("td_enrollment_id") REFERENCES "app"."td_enrollments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."td_messages"
    ADD CONSTRAINT "td_messages_teacher_user_id_fkey" FOREIGN KEY ("teacher_user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."td_physical_sessions"
    ADD CONSTRAINT "td_physical_sessions_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "app"."td_local_groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."td_physical_sessions"
    ADD CONSTRAINT "td_physical_sessions_teacher_id_fkey" FOREIGN KEY ("teacher_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."td_programs"
    ADD CONSTRAINT "td_programs_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."td_programs"
    ADD CONSTRAINT "td_programs_field_id_fkey" FOREIGN KEY ("field_id") REFERENCES "app"."td_fields"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "app"."td_question_banks"
    ADD CONSTRAINT "td_question_banks_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."td_questions"
    ADD CONSTRAINT "td_questions_bank_id_fkey" FOREIGN KEY ("bank_id") REFERENCES "app"."td_question_banks"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."td_questions"
    ADD CONSTRAINT "td_questions_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."td_quiz_attempts"
    ADD CONSTRAINT "td_quiz_attempts_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."td_quiz_attempts"
    ADD CONSTRAINT "td_quiz_attempts_template_id_fkey" FOREIGN KEY ("template_id") REFERENCES "app"."td_quiz_templates"("id");



ALTER TABLE ONLY "app"."td_quiz_templates"
    ADD CONSTRAINT "td_quiz_templates_bank_id_fkey" FOREIGN KEY ("bank_id") REFERENCES "app"."td_question_banks"("id");



ALTER TABLE ONLY "app"."td_quiz_templates"
    ADD CONSTRAINT "td_quiz_templates_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."td_resource_progress"
    ADD CONSTRAINT "td_resource_progress_resource_id_fkey" FOREIGN KEY ("resource_id") REFERENCES "app"."td_resources"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."td_resources"
    ADD CONSTRAINT "td_resources_collection_id_fkey" FOREIGN KEY ("collection_id") REFERENCES "app"."td_collections"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."td_resources"
    ADD CONSTRAINT "td_resources_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."td_resources"
    ADD CONSTRAINT "td_resources_program_id_fkey" FOREIGN KEY ("program_id") REFERENCES "app"."td_programs"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."td_resources"
    ADD CONSTRAINT "td_resources_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "app"."td_sessions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."td_scan_logs"
    ADD CONSTRAINT "td_scan_logs_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."td_session_occurrences"
    ADD CONSTRAINT "td_session_occurrences_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."td_session_occurrences"
    ADD CONSTRAINT "td_session_occurrences_enrollment_id_fkey" FOREIGN KEY ("enrollment_id") REFERENCES "app"."td_enrollments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."td_session_occurrences"
    ADD CONSTRAINT "td_session_occurrences_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "app"."td_sessions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."td_session_occurrences"
    ADD CONSTRAINT "td_session_occurrences_teacher_id_fkey" FOREIGN KEY ("teacher_id") REFERENCES "app"."td_teachers"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."td_sessions"
    ADD CONSTRAINT "td_sessions_collection_id_fkey" FOREIGN KEY ("collection_id") REFERENCES "app"."td_collections"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."td_source_documents"
    ADD CONSTRAINT "td_source_documents_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."td_student_badges"
    ADD CONSTRAINT "td_student_badges_badge_id_fkey" FOREIGN KEY ("badge_id") REFERENCES "app"."td_badges"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."td_student_badges"
    ADD CONSTRAINT "td_student_badges_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."td_student_profiles"
    ADD CONSTRAINT "td_student_profiles_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."td_student_progress"
    ADD CONSTRAINT "td_student_progress_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."td_student_requests"
    ADD CONSTRAINT "td_student_requests_created_program_id_fkey" FOREIGN KEY ("created_program_id") REFERENCES "app"."td_programs"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."td_student_requests"
    ADD CONSTRAINT "td_student_requests_field_id_fkey" FOREIGN KEY ("field_id") REFERENCES "app"."td_fields"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."td_student_requests"
    ADD CONSTRAINT "td_student_requests_handled_by_admin_id_fkey" FOREIGN KEY ("handled_by_admin_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."td_student_requests"
    ADD CONSTRAINT "td_student_requests_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."td_teacher_availability"
    ADD CONSTRAINT "td_teacher_availability_teacher_id_fkey" FOREIGN KEY ("teacher_id") REFERENCES "app"."td_teachers"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."td_teacher_profiles"
    ADD CONSTRAINT "td_teacher_profiles_teacher_id_fkey" FOREIGN KEY ("teacher_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "app"."td_teachers"
    ADD CONSTRAINT "td_teachers_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."tournament_matches"
    ADD CONSTRAINT "tournament_matches_next_match_id_fkey" FOREIGN KEY ("next_match_id") REFERENCES "app"."tournament_matches"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."tournament_matches"
    ADD CONSTRAINT "tournament_matches_participant1_id_fkey" FOREIGN KEY ("participant1_id") REFERENCES "app"."tournament_participants"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."tournament_matches"
    ADD CONSTRAINT "tournament_matches_participant2_id_fkey" FOREIGN KEY ("participant2_id") REFERENCES "app"."tournament_participants"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."tournament_matches"
    ADD CONSTRAINT "tournament_matches_participant3_id_fkey" FOREIGN KEY ("participant3_id") REFERENCES "app"."tournament_participants"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."tournament_matches"
    ADD CONSTRAINT "tournament_matches_participant4_id_fkey" FOREIGN KEY ("participant4_id") REFERENCES "app"."tournament_participants"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."tournament_matches"
    ADD CONSTRAINT "tournament_matches_tournament_id_fkey" FOREIGN KEY ("tournament_id") REFERENCES "app"."tournaments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."tournament_matches"
    ADD CONSTRAINT "tournament_matches_winner_id_fkey" FOREIGN KEY ("winner_id") REFERENCES "app"."tournament_participants"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."tournament_participants"
    ADD CONSTRAINT "tournament_participants_eliminated_by_fkey" FOREIGN KEY ("eliminated_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."tournament_participants"
    ADD CONSTRAINT "tournament_participants_tournament_id_fkey" FOREIGN KEY ("tournament_id") REFERENCES "app"."tournaments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."tournament_participants"
    ADD CONSTRAINT "tournament_participants_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."tournament_rewards"
    ADD CONSTRAINT "tournament_rewards_league_id_fkey" FOREIGN KEY ("league_id") REFERENCES "app"."leagues"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."tournament_rewards"
    ADD CONSTRAINT "tournament_rewards_tournament_id_fkey" FOREIGN KEY ("tournament_id") REFERENCES "app"."tournaments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."tournaments"
    ADD CONSTRAINT "tournaments_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."university_events"
    ADD CONSTRAINT "university_events_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "app"."universities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."university_media"
    ADD CONSTRAINT "university_media_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "app"."universities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."university_media"
    ADD CONSTRAINT "university_media_video_asset_id_fkey" FOREIGN KEY ("video_asset_id") REFERENCES "app"."video_assets"("id");



ALTER TABLE ONLY "app"."university_news"
    ADD CONSTRAINT "university_news_hero_media_id_fkey" FOREIGN KEY ("hero_media_id") REFERENCES "app"."university_media"("id");



ALTER TABLE ONLY "app"."university_news"
    ADD CONSTRAINT "university_news_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "app"."universities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."university_site_banners"
    ADD CONSTRAINT "university_site_banners_media_id_fkey" FOREIGN KEY ("media_id") REFERENCES "app"."university_media"("id");



ALTER TABLE ONLY "app"."university_site_banners"
    ADD CONSTRAINT "university_site_banners_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "app"."universities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."university_site_blocks"
    ADD CONSTRAINT "university_site_blocks_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "app"."universities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."university_site_config"
    ADD CONSTRAINT "university_site_config_hero_poster_media_id_fkey" FOREIGN KEY ("hero_poster_media_id") REFERENCES "app"."university_media"("id");



ALTER TABLE ONLY "app"."university_site_config"
    ADD CONSTRAINT "university_site_config_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "app"."universities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."university_staff"
    ADD CONSTRAINT "university_staff_photo_media_id_fkey" FOREIGN KEY ("photo_media_id") REFERENCES "app"."university_media"("id");



ALTER TABLE ONLY "app"."university_staff"
    ADD CONSTRAINT "university_staff_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "app"."universities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."user_admin_status"
    ADD CONSTRAINT "user_admin_status_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."user_announcement_reads"
    ADD CONSTRAINT "user_announcement_reads_announcement_id_fkey" FOREIGN KEY ("announcement_id") REFERENCES "app"."official_announcements"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."user_announcement_reads"
    ADD CONSTRAINT "user_announcement_reads_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."user_device_tokens"
    ADD CONSTRAINT "user_device_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."user_event_follows"
    ADD CONSTRAINT "user_event_follows_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "app"."academic_events"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."user_event_follows"
    ADD CONSTRAINT "user_event_follows_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."user_feature_entitlements"
    ADD CONSTRAINT "user_feature_entitlements_granted_by_fkey" FOREIGN KEY ("granted_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."user_feature_entitlements"
    ADD CONSTRAINT "user_feature_entitlements_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."user_invitations"
    ADD CONSTRAINT "user_invitations_created_by_admin_id_fkey" FOREIGN KEY ("created_by_admin_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."user_invitations"
    ADD CONSTRAINT "user_invitations_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "app"."universities"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."user_notification_state"
    ADD CONSTRAINT "user_notification_state_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."user_presence"
    ADD CONSTRAINT "user_presence_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."user_referrals"
    ADD CONSTRAINT "user_referrals_commercial_user_id_fkey" FOREIGN KEY ("commercial_user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."user_referrals"
    ADD CONSTRAINT "user_referrals_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "app"."students"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."video_asset_contexts"
    ADD CONSTRAINT "video_asset_contexts_video_asset_id_fkey" FOREIGN KEY ("video_asset_id") REFERENCES "app"."video_assets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."video_asset_legacy_map"
    ADD CONSTRAINT "video_asset_legacy_map_video_asset_id_fkey" FOREIGN KEY ("video_asset_id") REFERENCES "app"."video_assets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."video_moderation_history"
    ADD CONSTRAINT "video_moderation_history_moderated_by_admin_id_fkey" FOREIGN KEY ("moderated_by_admin_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."video_processing_jobs"
    ADD CONSTRAINT "video_processing_jobs_video_asset_id_fkey" FOREIGN KEY ("video_asset_id") REFERENCES "app"."video_assets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."video_renditions"
    ADD CONSTRAINT "video_renditions_video_asset_id_fkey" FOREIGN KEY ("video_asset_id") REFERENCES "app"."video_assets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."video_sources"
    ADD CONSTRAINT "video_sources_video_asset_id_fkey" FOREIGN KEY ("video_asset_id") REFERENCES "app"."video_assets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "app"."video_upload_events"
    ADD CONSTRAINT "video_upload_events_challenge_id_fkey" FOREIGN KEY ("challenge_id") REFERENCES "app"."challenges"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."video_upload_events"
    ADD CONSTRAINT "video_upload_events_participation_id_fkey" FOREIGN KEY ("participation_id") REFERENCES "app"."challenge_participations"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "app"."video_upload_events"
    ADD CONSTRAINT "video_upload_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Creators can delete their tournaments" ON "app"."tournaments" FOR DELETE USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Creators can update their tournaments" ON "app"."tournaments" FOR UPDATE USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Everyone can view leagues" ON "app"."leagues" FOR SELECT USING (("is_active" = true));



CREATE POLICY "Everyone can view rewards" ON "app"."tournament_rewards" FOR SELECT USING (true);



CREATE POLICY "League participants can manage their matches" ON "app"."league_matches" USING ((("participant1_id" IN ( SELECT "league_participations"."id"
   FROM "app"."league_participations"
  WHERE ("league_participations"."user_id" = "auth"."uid"()))) OR ("participant2_id" IN ( SELECT "league_participations"."id"
   FROM "app"."league_participations"
  WHERE ("league_participations"."user_id" = "auth"."uid"())))));



CREATE POLICY "Tournament creators can manage matches" ON "app"."tournament_matches" USING (("tournament_id" IN ( SELECT "tournaments"."id"
   FROM "app"."tournaments"
  WHERE ("tournaments"."created_by" = "auth"."uid"()))));



CREATE POLICY "Users can create tournaments" ON "app"."tournaments" FOR INSERT WITH CHECK (("created_by" = "auth"."uid"()));



CREATE POLICY "Users can manage their league participation" ON "app"."league_participations" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can manage their leagues" ON "app"."leagues" USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Users can manage their participation" ON "app"."tournament_participants" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can view competitive events" ON "app"."competitive_events" FOR SELECT USING ((("tournament_id" IN ( SELECT "tournaments"."id"
   FROM "app"."tournaments"
  WHERE (("tournaments"."is_private" = false) OR ("tournaments"."created_by" = "auth"."uid"())))) OR ("league_id" IN ( SELECT "leagues"."id"
   FROM "app"."leagues"
  WHERE ("leagues"."is_active" = true))) OR ("participant_id" = "auth"."uid"())));



CREATE POLICY "Users can view league matches" ON "app"."league_matches" FOR SELECT USING ((("participant1_id" IN ( SELECT "league_participations"."id"
   FROM "app"."league_participations"
  WHERE ("league_participations"."user_id" = "auth"."uid"()))) OR ("participant2_id" IN ( SELECT "league_participations"."id"
   FROM "app"."league_participations"
  WHERE ("league_participations"."user_id" = "auth"."uid"())))));



CREATE POLICY "Users can view league participations" ON "app"."league_participations" FOR SELECT USING ((("user_id" = "auth"."uid"()) OR ("league_id" IN ( SELECT "leagues"."id"
   FROM "app"."leagues"
  WHERE ("leagues"."is_active" = true)))));



CREATE POLICY "Users can view tournament matches" ON "app"."tournament_matches" FOR SELECT USING ((("tournament_id" IN ( SELECT "tournaments"."id"
   FROM "app"."tournaments"
  WHERE (("tournaments"."is_private" = false) OR ("tournaments"."created_by" = "auth"."uid"())))) OR ("id" IN ( SELECT "tournament_participants"."id"
   FROM "app"."tournament_participants"
  WHERE ("tournament_participants"."user_id" = "auth"."uid"())))));



CREATE POLICY "Users can view tournament participants" ON "app"."tournament_participants" FOR SELECT USING ((("user_id" = "auth"."uid"()) OR ("tournament_id" IN ( SELECT "tournaments"."id"
   FROM "app"."tournaments"
  WHERE (("tournaments"."is_private" = false) OR ("tournaments"."created_by" = "auth"."uid"()))))));



CREATE POLICY "Users can view tournaments" ON "app"."tournaments" FOR SELECT USING ((("is_private" = false) OR ("created_by" = "auth"."uid"()) OR ("id" IN ( SELECT "tournament_participants"."tournament_id"
   FROM "app"."tournament_participants"
  WHERE ("tournament_participants"."user_id" = "auth"."uid"())))));



CREATE POLICY "ab_admin_all" ON "app"."actor_balances" USING ((("auth"."jwt"() ? 'role'::"text") AND (("auth"."jwt"() ->> 'role'::"text") = 'admin'::"text")));



CREATE POLICY "ab_owner_select" ON "app"."actor_balances" FOR SELECT USING (("actor_id" = "auth"."uid"()));



ALTER TABLE "app"."academic_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."actor_balances" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "admin_all_challenge_participation_videos" ON "app"."challenge_participation_videos" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_challenge_reports" ON "app"."challenge_reports" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_challenge_user_bans" ON "app"."challenge_user_bans" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_challenge_video_assets" ON "app"."challenge_video_assets" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_challenge_video_overlays" ON "app"."challenge_video_overlays" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_challenge_video_render_jobs" ON "app"."challenge_video_render_jobs" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_free_video_overlays" ON "app"."free_video_overlays" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_free_video_render_jobs" ON "app"."free_video_render_jobs" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_hero_overlay_animations" ON "app"."hero_overlay_animations" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_hero_overlays" ON "app"."hero_overlays" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_hero_renders" ON "app"."hero_renders" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_hero_video_jobs" ON "app"."hero_video_jobs" USING ("app"."is_admin"()) WITH CHECK ("app"."is_admin"());



CREATE POLICY "admin_all_hero_videos" ON "app"."hero_videos" USING ("app"."is_admin"()) WITH CHECK ("app"."is_admin"());



CREATE POLICY "admin_all_moderation_events" ON "app"."moderation_events" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_online_course_live_session_participants" ON "app"."online_course_live_session_participants" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_prep_ai_config" ON "app"."prep_ai_config" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_prep_ai_generations" ON "app"."prep_ai_generations" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_prep_assignment_submissions" ON "app"."prep_assignment_submissions" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_prep_assignments" ON "app"."prep_assignments" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_prep_badges" ON "app"."prep_badges" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_prep_doc_chunks" ON "app"."prep_doc_chunks" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_prep_exam_papers" ON "app"."prep_exam_papers" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_prep_live_participants" ON "app"."prep_live_participants" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_prep_live_sessions" ON "app"."prep_live_sessions" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_prep_question_banks" ON "app"."prep_question_banks" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_prep_source_documents" ON "app"."prep_source_documents" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_prep_topic_predictions" ON "app"."prep_topic_predictions" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_prep_topics" ON "app"."prep_topics" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_psychotech_profiles" ON "app"."prep_psychotech_profiles" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_psychotech_results" ON "app"."prep_psychotech_results" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_td_assignment_subs" ON "app"."td_assignment_submissions" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_td_assignments" ON "app"."td_assignments" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_td_doc_chunks" ON "app"."td_doc_chunks" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_td_group_members" ON "app"."td_local_group_members" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_td_local_groups" ON "app"."td_local_groups" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_td_physical_sessions" ON "app"."td_physical_sessions" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_td_source_docs" ON "app"."td_source_documents" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_td_student_profiles" ON "app"."td_student_profiles" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_td_teacher_profiles" ON "app"."td_teacher_profiles" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_user_action_logs" ON "app"."admin_user_action_logs" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_user_invitations" ON "app"."user_invitations" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_all_video_playback_errors" ON "app"."video_playback_errors" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_manage_user_status" ON "app"."user_admin_status" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_select_all_payments" ON "app"."application_payments" FOR SELECT USING ((("auth"."jwt"() ? 'role'::"text") AND (("auth"."jwt"() ->> 'role'::"text") = 'admin'::"text")));



CREATE POLICY "admin_select_all_prep_attempts" ON "app"."prep_attempts" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



CREATE POLICY "admin_select_all_referral_commissions" ON "app"."referral_commissions" FOR SELECT USING ((("auth"."jwt"() ? 'role'::"text") AND (("auth"."jwt"() ->> 'role'::"text") = 'admin'::"text")));



CREATE POLICY "admin_select_all_user_referrals" ON "app"."user_referrals" FOR SELECT USING ((("auth"."jwt"() ? 'role'::"text") AND (("auth"."jwt"() ->> 'role'::"text") = 'admin'::"text")));



CREATE POLICY "admin_select_commercial_profiles" ON "app"."commercial_profiles" FOR SELECT USING ((("auth"."jwt"() ? 'role'::"text") AND (("auth"."jwt"() ->> 'role'::"text") = 'admin'::"text")));



CREATE POLICY "admin_select_legacy_video_write_attempts" ON "app"."legacy_video_write_attempts" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "auth"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."raw_user_meta_data" ->> 'role'::"text") = 'admin'::"text")))));



ALTER TABLE "app"."admin_user_action_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."application_files" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."application_messages" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."application_payments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."applications" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "auth_insert_own_corrections" ON "app"."prep_ai_corrections" FOR INSERT WITH CHECK (("student_id" = "auth"."uid"()));



CREATE POLICY "auth_insert_own_prep_aic" ON "app"."prep_ai_conversations" FOR INSERT WITH CHECK (("student_id" = "auth"."uid"()));



CREATE POLICY "auth_insert_own_prep_fp" ON "app"."prep_flashcard_progress" FOR INSERT WITH CHECK (("student_id" = "auth"."uid"()));



CREATE POLICY "auth_insert_own_prep_qa" ON "app"."prep_quiz_attempts" FOR INSERT WITH CHECK (("student_id" = "auth"."uid"()));



CREATE POLICY "auth_select_own_corrections" ON "app"."prep_ai_corrections" FOR SELECT USING (("student_id" = "auth"."uid"()));



CREATE POLICY "auth_select_own_prep_aic" ON "app"."prep_ai_conversations" FOR SELECT USING (("student_id" = "auth"."uid"()));



CREATE POLICY "auth_select_own_prep_aim" ON "app"."prep_ai_messages" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "app"."prep_ai_conversations" "c"
  WHERE (("c"."id" = "prep_ai_messages"."conversation_id") AND ("c"."student_id" = "auth"."uid"())))));



CREATE POLICY "auth_select_own_prep_fp" ON "app"."prep_flashcard_progress" FOR SELECT USING ((("student_id" = "auth"."uid"()) AND "public"."app_has_feature_access"('prep_concours'::"text")));



CREATE POLICY "auth_select_own_prep_qa" ON "app"."prep_quiz_attempts" FOR SELECT USING ((("student_id" = "auth"."uid"()) AND "public"."app_has_feature_access"('prep_concours'::"text")));



CREATE POLICY "auth_select_own_prep_sb" ON "app"."prep_student_badges" FOR SELECT USING (("student_id" = "auth"."uid"()));



CREATE POLICY "auth_select_own_prep_sp" ON "app"."prep_student_progress" FOR SELECT USING (("student_id" = "auth"."uid"()));



CREATE POLICY "auth_select_prep_ai_config" ON "app"."prep_ai_config" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "auth_select_prep_badges" ON "app"."prep_badges" FOR SELECT USING (("is_active" = true));



CREATE POLICY "auth_select_prep_exam_papers" ON "app"."prep_exam_papers" FOR SELECT USING ((("is_active" = true) AND "public"."app_has_feature_access"('prep_concours'::"text")));



CREATE POLICY "auth_select_prep_flashcard_decks" ON "app"."prep_flashcard_decks" FOR SELECT USING ((("is_active" = true) AND "public"."app_has_feature_access"('prep_concours'::"text")));



CREATE POLICY "auth_select_prep_flashcards" ON "app"."prep_flashcards" FOR SELECT USING ((("is_active" = true) AND "public"."app_has_feature_access"('prep_concours'::"text")));



CREATE POLICY "auth_select_prep_question_banks" ON "app"."prep_question_banks" FOR SELECT USING ((("is_active" = true) AND "public"."app_has_feature_access"('prep_concours'::"text")));



CREATE POLICY "auth_select_prep_question_topics" ON "app"."prep_question_topics" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "auth_select_prep_quiz_templates" ON "app"."prep_quiz_templates" FOR SELECT USING ((("is_active" = true) AND "public"."app_has_feature_access"('prep_concours'::"text")));



CREATE POLICY "auth_select_prep_topic_predictions" ON "app"."prep_topic_predictions" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "auth_select_prep_topics" ON "app"."prep_topics" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "auth_select_td_doc_chunks" ON "app"."td_doc_chunks" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "auth_select_td_source_documents" ON "app"."td_source_documents" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "auth_update_own_prep_fp" ON "app"."prep_flashcard_progress" FOR UPDATE USING (("student_id" = "auth"."uid"()));



CREATE POLICY "auth_update_own_prep_sp" ON "app"."prep_student_progress" FOR UPDATE USING (("student_id" = "auth"."uid"()));



CREATE POLICY "auth_upsert_own_prep_sp" ON "app"."prep_student_progress" FOR INSERT WITH CHECK (("student_id" = "auth"."uid"()));



CREATE POLICY "authenticated_insert_comments" ON "app"."opportunity_comments" FOR INSERT WITH CHECK ((("auth"."uid"() IS NOT NULL) AND ("user_id" = "auth"."uid"())));



CREATE POLICY "authenticated_select_payment_receipts" ON "app"."payment_receipts" FOR SELECT USING (true);



CREATE POLICY "authenticated_select_prep_ai_generations" ON "app"."prep_ai_generations" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "authenticated_select_prep_doc_chunks" ON "app"."prep_doc_chunks" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "authenticated_select_prep_source_documents" ON "app"."prep_source_documents" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



ALTER TABLE "app"."bobodo_answer_cache" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."bobodo_detected_needs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."bobodo_feedback" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."bobodo_knowledge" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."bobodo_messages" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."bobodo_sessions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."bobodo_unanswered_questions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "cache_select_authenticated" ON "app"."bobodo_answer_cache" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "app"."challenge_comments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."challenge_favorites" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."challenge_likes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."challenge_participation_videos" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."challenge_participations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."challenge_reports" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."challenge_user_bans" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."challenge_video_assets" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."challenge_video_overlays" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."challenge_video_render_jobs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."challenges" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."commercial_profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "commercial_select_own_profile" ON "app"."commercial_profiles" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "commercial_select_own_referral_commissions" ON "app"."referral_commissions" FOR SELECT USING (("commercial_user_id" = "auth"."uid"()));



CREATE POLICY "commercial_select_own_user_referrals" ON "app"."user_referrals" FOR SELECT USING (("commercial_user_id" = "auth"."uid"()));



ALTER TABLE "app"."communities" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."community_join_requests" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."community_memberships" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."community_poll_votes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."community_polls" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."community_post_reactions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."community_posts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."community_read_states" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."community_stories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."community_story_views" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."competitive_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."course_domains" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."course_enrollments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."course_resources" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."course_units" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."courses" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."direct_conversations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."direct_message_read_states" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."direct_messages" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "dm_conv_insert_own" ON "app"."direct_conversations" FOR INSERT WITH CHECK ((("user_a" = "auth"."uid"()) OR ("user_b" = "auth"."uid"())));



CREATE POLICY "dm_conv_select_own" ON "app"."direct_conversations" FOR SELECT USING ((("user_a" = "auth"."uid"()) OR ("user_b" = "auth"."uid"())));



CREATE POLICY "dm_msg_insert_own" ON "app"."direct_messages" FOR INSERT WITH CHECK (("sender_id" = "auth"."uid"()));



CREATE POLICY "dm_msg_select_own" ON "app"."direct_messages" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "app"."direct_conversations" "c"
  WHERE (("c"."id" = "direct_messages"."conversation_id") AND (("c"."user_a" = "auth"."uid"()) OR ("c"."user_b" = "auth"."uid"()))))));



CREATE POLICY "dm_read_select_own" ON "app"."direct_message_read_states" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "dm_read_update_own" ON "app"."direct_message_read_states" FOR UPDATE USING (("user_id" = "auth"."uid"()));



CREATE POLICY "dm_read_upsert_own" ON "app"."direct_message_read_states" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "app"."exercises" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."free_video_overlays" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."free_video_render_jobs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."free_videos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "heatmap_insert_own" ON "app"."video_heatmap_events" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "app"."hero_overlay_animations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."hero_overlays" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."hero_playlist" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."hero_renders" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."hero_video_jobs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."hero_videos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "instructor_insert_online_course_forum_threads" ON "app"."online_course_forum_threads" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "app"."online_course_instructors" "ci"
  WHERE (("ci"."course_id" = "online_course_forum_threads"."course_id") AND ("ci"."instructor_id" = "auth"."uid"())))));



CREATE POLICY "instructor_insert_own_course_links" ON "app"."online_course_instructors" FOR INSERT WITH CHECK (("instructor_id" = "auth"."uid"()));



CREATE POLICY "instructor_insert_self" ON "app"."instructors" FOR INSERT WITH CHECK (("id" = "auth"."uid"()));



CREATE POLICY "instructor_select_online_course_forum_threads" ON "app"."online_course_forum_threads" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "app"."online_course_instructors" "ci"
  WHERE (("ci"."course_id" = "online_course_forum_threads"."course_id") AND ("ci"."instructor_id" = "auth"."uid"())))));



CREATE POLICY "instructor_select_own_course_links" ON "app"."online_course_instructors" FOR SELECT USING (("instructor_id" = "auth"."uid"()));



CREATE POLICY "instructor_select_self" ON "app"."instructors" FOR SELECT USING (("id" = "auth"."uid"()));



CREATE POLICY "instructor_update_own_course_links" ON "app"."online_course_instructors" FOR UPDATE USING (("instructor_id" = "auth"."uid"()));



CREATE POLICY "instructor_update_self" ON "app"."instructors" FOR UPDATE USING (("id" = "auth"."uid"()));



ALTER TABLE "app"."instructors" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."landing_announcements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."landing_config" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."landing_partners" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."landing_videos" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."landing_why_cards" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."league_matches" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."league_participations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."leagues" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."legacy_video_write_attempts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."marketplace_cart_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."marketplace_carts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."marketplace_categories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."marketplace_listing_bookmarks" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."marketplace_listing_media" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."marketplace_listings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."marketplace_merchant_balances" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "marketplace_merchant_balances_select" ON "app"."marketplace_merchant_balances" FOR SELECT USING (("merchant_id" IN ( SELECT "marketplace_merchants"."id"
   FROM "app"."marketplace_merchants"
  WHERE ("marketplace_merchants"."owner_user_id" = "auth"."uid"()))));



ALTER TABLE "app"."marketplace_merchants" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."marketplace_order_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."marketplace_orders" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."marketplace_payments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "marketplace_payments_select" ON "app"."marketplace_payments" FOR SELECT USING ((("buyer_id" = "auth"."uid"()) OR ("merchant_id" IN ( SELECT "marketplace_merchants"."id"
   FROM "app"."marketplace_merchants"
  WHERE ("marketplace_merchants"."owner_user_id" = "auth"."uid"())))));



ALTER TABLE "app"."marketplace_products" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."marketplace_reviews" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "marketplace_reviews_insert" ON "app"."marketplace_reviews" FOR INSERT WITH CHECK (("buyer_id" = "auth"."uid"()));



CREATE POLICY "marketplace_reviews_select" ON "app"."marketplace_reviews" FOR SELECT USING (("is_active" = true));



CREATE POLICY "marketplace_reviews_update" ON "app"."marketplace_reviews" FOR UPDATE USING ((("buyer_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM ("app"."marketplace_listings" "ml"
     JOIN "app"."marketplace_merchants" "mm" ON (("mm"."id" = "ml"."merchant_id")))
  WHERE (("ml"."id" = "marketplace_reviews"."listing_id") AND ("mm"."owner_user_id" = "auth"."uid"()))))));



CREATE POLICY "member_insert_community_posts" ON "app"."community_posts" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "app"."community_memberships" "m"
  WHERE (("m"."community_id" = "community_posts"."community_id") AND ("m"."user_id" = "auth"."uid"()) AND ("m"."is_active" = true)))));



CREATE POLICY "member_select_community_posts" ON "app"."community_posts" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "app"."community_memberships" "m"
  WHERE (("m"."community_id" = "community_posts"."community_id") AND ("m"."user_id" = "auth"."uid"()) AND ("m"."is_active" = true)))));



CREATE POLICY "merchant_insert_own_marketplace_listings" ON "app"."marketplace_listings" FOR INSERT TO "authenticated" WITH CHECK (("merchant_id" = "auth"."uid"()));



CREATE POLICY "merchant_manage_own_marketplace_listing_media" ON "app"."marketplace_listing_media" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "app"."marketplace_listings" "l"
  WHERE (("l"."id" = "marketplace_listing_media"."listing_id") AND ("l"."merchant_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "app"."marketplace_listings" "l"
  WHERE (("l"."id" = "marketplace_listing_media"."listing_id") AND ("l"."merchant_id" = "auth"."uid"())))));



ALTER TABLE "app"."merchant_profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "merchant_profiles_public_select_verified" ON "app"."merchant_profiles" FOR SELECT USING ((("is_active" = true) AND ("is_verified" = true)));



CREATE POLICY "merchant_profiles_user_select_own" ON "app"."merchant_profiles" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "merchant_profiles_user_update_own" ON "app"."merchant_profiles" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "merchant_profiles_user_upsert_own" ON "app"."merchant_profiles" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "merchant_select_own_marketplace_listings" ON "app"."marketplace_listings" FOR SELECT TO "authenticated" USING (("merchant_id" = "auth"."uid"()));



CREATE POLICY "merchant_update_own_marketplace_listings" ON "app"."marketplace_listings" FOR UPDATE TO "authenticated" USING (("merchant_id" = "auth"."uid"())) WITH CHECK (("merchant_id" = "auth"."uid"()));



ALTER TABLE "app"."moderation_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."official_announcements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."online_course_certificates" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."online_course_enrollment_messages" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."online_course_enrollments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."online_course_forum_messages" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."online_course_forum_threads" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."online_course_instructors" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."online_course_lesson_media" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."online_course_lesson_progress" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."online_course_lessons" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."online_course_live_session_participants" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."online_course_live_sessions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."online_course_sections" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."online_courses" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."opportunities" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."opportunity_applications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."opportunity_bookmarks" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."opportunity_comments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."opportunity_inquiries" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "opportunity_inquiries_buyer_insert" ON "app"."opportunity_inquiries" FOR INSERT TO "authenticated" WITH CHECK (("buyer_id" = "auth"."uid"()));



CREATE POLICY "opportunity_inquiries_buyer_update_status_own" ON "app"."opportunity_inquiries" FOR UPDATE TO "authenticated" USING (("buyer_id" = "auth"."uid"())) WITH CHECK (("buyer_id" = "auth"."uid"()));



CREATE POLICY "opportunity_inquiries_merchant_update_status_own" ON "app"."opportunity_inquiries" FOR UPDATE TO "authenticated" USING (("merchant_id" = "auth"."uid"())) WITH CHECK (("merchant_id" = "auth"."uid"()));



CREATE POLICY "opportunity_inquiries_user_select_own" ON "app"."opportunity_inquiries" FOR SELECT TO "authenticated" USING ((("buyer_id" = "auth"."uid"()) OR ("merchant_id" = "auth"."uid"())));



ALTER TABLE "app"."opportunity_inquiry_messages" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "opportunity_inquiry_messages_insert_participants" ON "app"."opportunity_inquiry_messages" FOR INSERT TO "authenticated" WITH CHECK ((("sender_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1
   FROM "app"."opportunity_inquiries" "i"
  WHERE (("i"."id" = "opportunity_inquiry_messages"."inquiry_id") AND (("i"."buyer_id" = "auth"."uid"()) OR ("i"."merchant_id" = "auth"."uid"())))))));



CREATE POLICY "opportunity_inquiry_messages_select_participants" ON "app"."opportunity_inquiry_messages" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "app"."opportunity_inquiries" "i"
  WHERE (("i"."id" = "opportunity_inquiry_messages"."inquiry_id") AND (("i"."buyer_id" = "auth"."uid"()) OR ("i"."merchant_id" = "auth"."uid"()))))));



ALTER TABLE "app"."opportunity_reactions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."opportunity_types" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."opportunity_views" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "owner_insert_video_assets" ON "app"."video_assets" FOR INSERT WITH CHECK (("owner_user_id" = "auth"."uid"()));



CREATE POLICY "owner_insert_video_sources" ON "app"."video_sources" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "app"."video_assets" "a"
  WHERE (("a"."id" = "video_sources"."video_asset_id") AND ("a"."owner_user_id" = "auth"."uid"())))));



CREATE POLICY "owner_select_video_asset_contexts" ON "app"."video_asset_contexts" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "app"."video_assets" "a"
  WHERE (("a"."id" = "video_asset_contexts"."video_asset_id") AND ("a"."owner_user_id" = "auth"."uid"())))));



CREATE POLICY "owner_select_video_assets" ON "app"."video_assets" FOR SELECT USING (("owner_user_id" = "auth"."uid"()));



CREATE POLICY "owner_select_video_renditions" ON "app"."video_renditions" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "app"."video_assets" "a"
  WHERE (("a"."id" = "video_renditions"."video_asset_id") AND ("a"."owner_user_id" = "auth"."uid"())))));



CREATE POLICY "owner_select_video_sources" ON "app"."video_sources" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "app"."video_assets" "a"
  WHERE (("a"."id" = "video_sources"."video_asset_id") AND ("a"."owner_user_id" = "auth"."uid"())))));



CREATE POLICY "owner_update_video_assets" ON "app"."video_assets" FOR UPDATE USING (("owner_user_id" = "auth"."uid"())) WITH CHECK (("owner_user_id" = "auth"."uid"()));



ALTER TABLE "app"."payment_proofs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."payment_receipts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."payout_queue" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "payout_queue_admin_all" ON "app"."payout_queue" USING ((("auth"."jwt"() ? 'role'::"text") AND (("auth"."jwt"() ->> 'role'::"text") = 'admin'::"text")));



CREATE POLICY "payout_queue_beneficiary_select" ON "app"."payout_queue" FOR SELECT USING (("beneficiary_user_id" = "auth"."uid"()));



ALTER TABLE "app"."platform_ledger" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "platform_ledger_admin_select" ON "app"."platform_ledger" FOR SELECT USING ((("auth"."jwt"() ? 'role'::"text") AND (("auth"."jwt"() ->> 'role'::"text") = 'admin'::"text")));



ALTER TABLE "app"."prep_ai_config" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_ai_conversations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_ai_corrections" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_ai_generations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_ai_messages" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_ai_usage_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_assignment_submissions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_assignments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_attempts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_badges" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_chapters" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_doc_chunks" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_exam_blanc_attempts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_exam_blancs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_exam_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_exam_papers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_exams" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_flashcard_decks" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_flashcard_progress" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_flashcards" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_live_participants" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_live_sessions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_news_articles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_news_sources" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_psychotech_profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_psychotech_results" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_question_banks" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_question_choices" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_question_topics" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_quiz_attempts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_quiz_templates" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_scan_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_source_documents" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_student_badges" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_student_progress" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_student_weaknesses" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_subjects" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_topic_predictions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."prep_topics" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."programs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "public_select_active_bobodo_knowledge" ON "app"."bobodo_knowledge" FOR SELECT USING (("is_active" = true));



CREATE POLICY "public_select_active_challenge_video_assets" ON "app"."challenge_video_assets" FOR SELECT USING (("is_active" = true));



CREATE POLICY "public_select_active_challenges" ON "app"."challenges" FOR SELECT USING ((("is_active" = true) AND (("start_at" IS NULL) OR ("start_at" <= "now"())) AND (("end_at" IS NULL) OR ("end_at" >= "now"()))));



CREATE POLICY "public_select_active_courses" ON "app"."courses" FOR SELECT USING (("is_active" = true));



CREATE POLICY "public_select_active_hero_playlist" ON "app"."hero_playlist" FOR SELECT USING (("is_active" = true));



CREATE POLICY "public_select_active_landing_announcements" ON "app"."landing_announcements" FOR SELECT USING (("is_active" = true));



CREATE POLICY "public_select_active_landing_partners" ON "app"."landing_partners" FOR SELECT USING (("is_active" = true));



CREATE POLICY "public_select_active_landing_videos" ON "app"."landing_videos" FOR SELECT USING (("is_active" = true));



CREATE POLICY "public_select_active_landing_why_cards" ON "app"."landing_why_cards" FOR SELECT USING (("is_active" = true));



CREATE POLICY "public_select_active_marketplace_categories" ON "app"."marketplace_categories" FOR SELECT USING (("is_active" = true));



CREATE POLICY "public_select_active_marketplace_merchants" ON "app"."marketplace_merchants" FOR SELECT USING ((("status" = 'approved'::"text") AND ("is_active" = true)));



CREATE POLICY "public_select_active_opportunity_types" ON "app"."opportunity_types" FOR SELECT USING (("is_active" = true));



CREATE POLICY "public_select_active_prep_chapters" ON "app"."prep_chapters" FOR SELECT USING ((("is_active" = true) AND "public"."app_has_feature_access"('prep_concours'::"text")));



CREATE POLICY "public_select_active_prep_subjects" ON "app"."prep_subjects" FOR SELECT USING ((("is_active" = true) AND "public"."app_has_feature_access"('prep_concours'::"text")));



CREATE POLICY "public_select_active_programs" ON "app"."programs" FOR SELECT USING (("is_active" = true));



CREATE POLICY "public_select_active_public_communities" ON "app"."communities" FOR SELECT USING ((("is_active" = true) AND ("visibility" = 'public'::"text")));



CREATE POLICY "public_select_active_short_trainings" ON "app"."short_trainings" FOR SELECT USING (("is_active" = true));



CREATE POLICY "public_select_active_student_home_announcements" ON "app"."student_home_announcements" FOR SELECT USING (("is_active" = true));



CREATE POLICY "public_select_active_student_home_videos" ON "app"."student_home_videos" FOR SELECT USING (("is_active" = true));



CREATE POLICY "public_select_active_universities" ON "app"."universities" FOR SELECT USING (("is_active" = true));



CREATE POLICY "public_select_hero_overlay_animations" ON "app"."hero_overlay_animations" FOR SELECT USING (true);



CREATE POLICY "public_select_landing_config" ON "app"."landing_config" FOR SELECT USING (true);



CREATE POLICY "public_select_marketplace_listing_media" ON "app"."marketplace_listing_media" FOR SELECT TO "authenticated", "anon" USING ((("is_active" = true) AND (EXISTS ( SELECT 1
   FROM "app"."marketplace_listings" "l"
  WHERE (("l"."id" = "marketplace_listing_media"."listing_id") AND ("l"."is_active" = true) AND ("l"."review_status" = 'approved'::"text"))))));



CREATE POLICY "public_select_online_course_lesson_media" ON "app"."online_course_lesson_media" FOR SELECT USING ((("is_active" = true) AND (EXISTS ( SELECT 1
   FROM (("app"."online_course_lessons" "l"
     JOIN "app"."online_course_sections" "s" ON (("s"."id" = "l"."section_id")))
     JOIN "app"."online_courses" "c" ON (("c"."id" = "s"."course_id")))
  WHERE (("l"."id" = "online_course_lesson_media"."lesson_id") AND ("l"."is_published" = true) AND ("c"."is_published" = true))))));



CREATE POLICY "public_select_online_course_lessons" ON "app"."online_course_lessons" FOR SELECT USING ((("is_published" = true) AND (EXISTS ( SELECT 1
   FROM ("app"."online_course_sections" "s"
     JOIN "app"."online_courses" "c" ON (("c"."id" = "s"."course_id")))
  WHERE (("s"."id" = "online_course_lessons"."section_id") AND ("c"."is_published" = true))))));



CREATE POLICY "public_select_online_course_sections" ON "app"."online_course_sections" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "app"."online_courses" "c"
  WHERE (("c"."id" = "online_course_sections"."course_id") AND ("c"."is_published" = true)))));



CREATE POLICY "public_select_opportunity_comments" ON "app"."opportunity_comments" FOR SELECT USING (true);



CREATE POLICY "public_select_opportunity_reactions" ON "app"."opportunity_reactions" FOR SELECT USING (true);



CREATE POLICY "public_select_published_marketplace_listings" ON "app"."marketplace_listings" FOR SELECT USING ((("is_active" = true) AND ("status" = 'published'::"text") AND ("review_status" = 'approved'::"text")));



CREATE POLICY "public_select_published_marketplace_products" ON "app"."marketplace_products" FOR SELECT USING (("status" = 'published'::"text"));



CREATE POLICY "public_select_published_official_announcements" ON "app"."official_announcements" FOR SELECT USING ((("is_published" = true) AND (("visible_from" IS NULL) OR ("visible_from" <= "now"())) AND (("visible_until" IS NULL) OR ("visible_until" >= "now"()))));



CREATE POLICY "public_select_published_online_courses" ON "app"."online_courses" FOR SELECT USING (("is_published" = true));



CREATE POLICY "public_select_published_opportunities" ON "app"."opportunities" FOR SELECT USING ((("is_active" = true) AND ("status" = 'published'::"text") AND (("application_deadline" IS NULL) OR ("application_deadline" >= CURRENT_DATE))));



CREATE POLICY "public_select_published_prep_exam_items" ON "app"."prep_exam_items" FOR SELECT USING (("public"."app_has_feature_access"('prep_concours'::"text") AND (EXISTS ( SELECT 1
   FROM "app"."prep_exams" "e"
  WHERE (("e"."id" = "prep_exam_items"."exam_id") AND ("e"."is_published" = true))))));



CREATE POLICY "public_select_published_prep_exams" ON "app"."prep_exams" FOR SELECT USING ((("is_published" = true) AND "public"."app_has_feature_access"('prep_concours'::"text")));



CREATE POLICY "public_select_published_prep_question_choices" ON "app"."prep_question_choices" FOR SELECT USING (("public"."app_has_feature_access"('prep_concours'::"text") AND (EXISTS ( SELECT 1
   FROM "app"."prep_questions" "q"
  WHERE (("q"."id" = "prep_question_choices"."question_id") AND ("q"."is_published" = true))))));



CREATE POLICY "public_select_published_prep_questions" ON "app"."prep_questions" FOR SELECT USING ((("is_published" = true) AND "public"."app_has_feature_access"('prep_concours'::"text")));



CREATE POLICY "public_select_ready_video_assets" ON "app"."video_assets" FOR SELECT USING ((("status" = 'ready'::"text") AND ("deleted_at" IS NULL)));



CREATE POLICY "public_select_ready_video_renditions" ON "app"."video_renditions" FOR SELECT USING ((("status" = 'ready'::"text") AND (EXISTS ( SELECT 1
   FROM "app"."video_assets" "a"
  WHERE (("a"."id" = "video_renditions"."video_asset_id") AND ("a"."status" = 'ready'::"text") AND ("a"."deleted_at" IS NULL))))));



CREATE POLICY "public_select_university_events" ON "app"."university_events" FOR SELECT USING (("is_active" = true));



CREATE POLICY "public_select_university_media" ON "app"."university_media" FOR SELECT USING (("is_active" = true));



CREATE POLICY "public_select_university_news" ON "app"."university_news" FOR SELECT USING (("is_active" = true));



CREATE POLICY "public_select_university_site_banners" ON "app"."university_site_banners" FOR SELECT USING (("is_active" = true));



CREATE POLICY "public_select_university_site_blocks" ON "app"."university_site_blocks" FOR SELECT USING (("is_active" = true));



CREATE POLICY "public_select_university_site_config" ON "app"."university_site_config" FOR SELECT USING (true);



CREATE POLICY "public_select_university_staff" ON "app"."university_staff" FOR SELECT USING (("is_active" = true));



ALTER TABLE "app"."referral_commissions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."revenue_split_rules" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "rsr_admin_all" ON "app"."revenue_split_rules" USING ((("auth"."jwt"() ? 'role'::"text") AND (("auth"."jwt"() ->> 'role'::"text") = 'admin'::"text")));



CREATE POLICY "rsr_select_all" ON "app"."revenue_split_rules" FOR SELECT USING (true);



CREATE POLICY "service_role_all" ON "app"."td_ai_config" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all" ON "app"."td_ai_conversations" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all" ON "app"."td_ai_messages" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all" ON "app"."td_badges" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all" ON "app"."td_daily_goals" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all" ON "app"."td_discipline_colors" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all" ON "app"."td_exam_papers" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all" ON "app"."td_flashcard_decks" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all" ON "app"."td_flashcard_progress" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all" ON "app"."td_flashcards" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all" ON "app"."td_leaderboard_cache" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all" ON "app"."td_question_banks" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all" ON "app"."td_questions" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all" ON "app"."td_quiz_attempts" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all" ON "app"."td_quiz_templates" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all" ON "app"."td_resource_progress" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all" ON "app"."td_streaks" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all" ON "app"."td_student_badges" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all" ON "app"."td_student_progress" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all" ON "app"."td_xp_log" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all_exam_blanc_attempts" ON "app"."prep_exam_blanc_attempts" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all_exam_blancs" ON "app"."prep_exam_blancs" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all_hero_video_jobs" ON "app"."hero_video_jobs" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all_hero_videos" ON "app"."hero_videos" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all_legacy_video_write_attempts" ON "app"."legacy_video_write_attempts" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all_news_articles" ON "app"."prep_news_articles" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all_news_sources" ON "app"."prep_news_sources" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all_video_asset_contexts" ON "app"."video_asset_contexts" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all_video_asset_legacy_map" ON "app"."video_asset_legacy_map" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all_video_assets" ON "app"."video_assets" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all_video_processing_jobs" ON "app"."video_processing_jobs" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all_video_renditions" ON "app"."video_renditions" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "service_role_all_video_sources" ON "app"."video_sources" TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "app"."short_training_messages" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."short_training_registration_messages" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."short_training_registrations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."short_training_sessions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."short_trainings" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "sr_all_prep_ai_config" ON "app"."prep_ai_config" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "sr_all_prep_ai_conversations" ON "app"."prep_ai_conversations" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "sr_all_prep_ai_corrections" ON "app"."prep_ai_corrections" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "sr_all_prep_ai_messages" ON "app"."prep_ai_messages" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "sr_all_prep_assignment_submissions" ON "app"."prep_assignment_submissions" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "sr_all_prep_assignments" ON "app"."prep_assignments" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "sr_all_prep_badges" ON "app"."prep_badges" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "sr_all_prep_exam_papers" ON "app"."prep_exam_papers" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "sr_all_prep_flashcard_decks" ON "app"."prep_flashcard_decks" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "sr_all_prep_flashcard_progress" ON "app"."prep_flashcard_progress" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "sr_all_prep_flashcards" ON "app"."prep_flashcards" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "sr_all_prep_live_participants" ON "app"."prep_live_participants" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "sr_all_prep_live_sessions" ON "app"."prep_live_sessions" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "sr_all_prep_psychotech_profiles" ON "app"."prep_psychotech_profiles" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "sr_all_prep_psychotech_results" ON "app"."prep_psychotech_results" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "sr_all_prep_question_banks" ON "app"."prep_question_banks" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "sr_all_prep_question_topics" ON "app"."prep_question_topics" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "sr_all_prep_quiz_attempts" ON "app"."prep_quiz_attempts" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "sr_all_prep_quiz_templates" ON "app"."prep_quiz_templates" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "sr_all_prep_student_badges" ON "app"."prep_student_badges" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "sr_all_prep_student_progress" ON "app"."prep_student_progress" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "sr_all_prep_topic_predictions" ON "app"."prep_topic_predictions" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "sr_all_prep_topics" ON "app"."prep_topics" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "sr_all_td_assignment_subs" ON "app"."td_assignment_submissions" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "sr_all_td_assignments" ON "app"."td_assignments" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "sr_all_td_doc_chunks" ON "app"."td_doc_chunks" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "sr_all_td_local_group_members" ON "app"."td_local_group_members" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "sr_all_td_local_groups" ON "app"."td_local_groups" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "sr_all_td_physical_sessions" ON "app"."td_physical_sessions" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "sr_all_td_source_documents" ON "app"."td_source_documents" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "sr_all_td_student_profiles" ON "app"."td_student_profiles" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "sr_all_td_teacher_profiles" ON "app"."td_teacher_profiles" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "student_delete_community_poll_votes" ON "app"."community_poll_votes" FOR DELETE USING (("user_id" = "auth"."uid"()));



CREATE POLICY "student_delete_own_challenge_favorites" ON "app"."challenge_favorites" FOR DELETE USING (("user_id" = "auth"."uid"()));



CREATE POLICY "student_delete_own_challenge_likes" ON "app"."challenge_likes" FOR DELETE USING (("user_id" = "auth"."uid"()));



CREATE POLICY "student_delete_own_community_post_reactions" ON "app"."community_post_reactions" FOR DELETE USING (("user_id" = "auth"."uid"()));



CREATE POLICY "student_delete_own_community_stories" ON "app"."community_stories" FOR DELETE USING (("author_id" = "auth"."uid"()));



CREATE POLICY "student_delete_own_event_follows" ON "app"."user_event_follows" FOR DELETE USING (("user_id" = "auth"."uid"()));



ALTER TABLE "app"."student_dossier_documents" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."student_home_announcements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."student_home_slots" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."student_home_videos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "student_insert_community_poll_votes" ON "app"."community_poll_votes" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "student_insert_community_polls" ON "app"."community_polls" FOR INSERT WITH CHECK (("created_by_user_id" = "auth"."uid"()));



CREATE POLICY "student_insert_online_course_forum_messages" ON "app"."online_course_forum_messages" FOR INSERT WITH CHECK ((("sender_role" = 'student'::"text") AND (EXISTS ( SELECT 1
   FROM ("app"."online_course_forum_threads" "t"
     JOIN "app"."online_course_enrollments" "e" ON (("e"."course_id" = "t"."course_id")))
  WHERE (("t"."id" = "online_course_forum_messages"."thread_id") AND ("e"."student_id" = "auth"."uid"()))))));



CREATE POLICY "student_insert_online_course_forum_threads" ON "app"."online_course_forum_threads" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "app"."online_course_enrollments" "e"
  WHERE (("e"."course_id" = "online_course_forum_threads"."course_id") AND ("e"."student_id" = "auth"."uid"())))));



CREATE POLICY "student_insert_own_announcement_reads" ON "app"."user_announcement_reads" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "student_insert_own_application_files" ON "app"."application_files" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "app"."applications" "a"
  WHERE (("a"."id" = "application_files"."application_id") AND ("a"."student_id" = "auth"."uid"())))));



CREATE POLICY "student_insert_own_application_messages" ON "app"."application_messages" FOR INSERT WITH CHECK (((EXISTS ( SELECT 1
   FROM "app"."applications" "a"
  WHERE (("a"."id" = "application_messages"."application_id") AND ("a"."student_id" = "auth"."uid"())))) AND ("sender_role" = 'student'::"text")));



CREATE POLICY "student_insert_own_applications" ON "app"."applications" FOR INSERT WITH CHECK (("student_id" = "auth"."uid"()));



CREATE POLICY "student_insert_own_bobodo_feedback" ON "app"."bobodo_feedback" FOR INSERT WITH CHECK (("student_id" = "auth"."uid"()));



CREATE POLICY "student_insert_own_bobodo_messages" ON "app"."bobodo_messages" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "app"."bobodo_sessions" "s"
  WHERE (("s"."id" = "bobodo_messages"."session_id") AND ("s"."student_id" = "auth"."uid"())))));



CREATE POLICY "student_insert_own_bobodo_sessions" ON "app"."bobodo_sessions" FOR INSERT WITH CHECK (("student_id" = "auth"."uid"()));



CREATE POLICY "student_insert_own_challenge_comments" ON "app"."challenge_comments" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "student_insert_own_challenge_favorites" ON "app"."challenge_favorites" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "student_insert_own_challenge_participation_videos" ON "app"."challenge_participation_videos" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "app"."challenge_participations" "cp"
  WHERE (("cp"."id" = "challenge_participation_videos"."participation_id") AND ("cp"."user_id" = "auth"."uid"())))));



CREATE POLICY "student_insert_own_challenge_participations" ON "app"."challenge_participations" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "student_insert_own_challenge_reports" ON "app"."challenge_reports" FOR INSERT WITH CHECK (("reporter_id" = "auth"."uid"()));



CREATE POLICY "student_insert_own_community_join_requests" ON "app"."community_join_requests" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "student_insert_own_community_memberships" ON "app"."community_memberships" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "student_insert_own_community_post_reactions" ON "app"."community_post_reactions" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "student_insert_own_community_stories" ON "app"."community_stories" FOR INSERT WITH CHECK (("author_id" = "auth"."uid"()));



CREATE POLICY "student_insert_own_dossier_documents" ON "app"."student_dossier_documents" FOR INSERT WITH CHECK (("student_id" = "auth"."uid"()));



CREATE POLICY "student_insert_own_enrollments" ON "app"."course_enrollments" FOR INSERT WITH CHECK (("student_id" = "auth"."uid"()));



CREATE POLICY "student_insert_own_event_follows" ON "app"."user_event_follows" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "student_insert_own_marketplace_order_items" ON "app"."marketplace_order_items" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "app"."marketplace_orders" "o"
  WHERE (("o"."id" = "marketplace_order_items"."order_id") AND ("o"."student_id" = "auth"."uid"())))));



CREATE POLICY "student_insert_own_marketplace_orders" ON "app"."marketplace_orders" FOR INSERT WITH CHECK (("student_id" = "auth"."uid"()));



CREATE POLICY "student_insert_own_online_course_enrollment_messages" ON "app"."online_course_enrollment_messages" FOR INSERT WITH CHECK (((EXISTS ( SELECT 1
   FROM "app"."online_course_enrollments" "e"
  WHERE (("e"."id" = "online_course_enrollment_messages"."enrollment_id") AND ("e"."student_id" = "auth"."uid"())))) AND ("sender_role" = 'student'::"text")));



CREATE POLICY "student_insert_own_online_course_enrollments" ON "app"."online_course_enrollments" FOR INSERT WITH CHECK (("student_id" = "auth"."uid"()));



CREATE POLICY "student_insert_own_online_course_lesson_progress" ON "app"."online_course_lesson_progress" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "app"."online_course_enrollments" "e"
  WHERE (("e"."id" = "online_course_lesson_progress"."enrollment_id") AND ("e"."student_id" = "auth"."uid"())))));



CREATE POLICY "student_insert_own_opportunity_applications" ON "app"."opportunity_applications" FOR INSERT WITH CHECK (("student_id" = "auth"."uid"()));



CREATE POLICY "student_insert_own_prep_attempts" ON "app"."prep_attempts" FOR INSERT WITH CHECK ((("student_id" = "auth"."uid"()) AND "public"."app_has_feature_access"('prep_concours'::"text")));



CREATE POLICY "student_insert_own_read_states" ON "app"."community_read_states" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "student_insert_own_short_training_registration_messages" ON "app"."short_training_registration_messages" FOR INSERT WITH CHECK (((EXISTS ( SELECT 1
   FROM "app"."short_training_registrations" "r"
  WHERE (("r"."id" = "short_training_registration_messages"."registration_id") AND ("r"."user_id" = "auth"."uid"())))) AND ("sender_role" = 'student'::"text")));



CREATE POLICY "student_insert_own_short_training_registrations" ON "app"."short_training_registrations" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "student_insert_own_story_views" ON "app"."community_story_views" FOR INSERT WITH CHECK (("viewer_id" = "auth"."uid"()));



CREATE POLICY "student_insert_psychotech_results" ON "app"."prep_psychotech_results" FOR INSERT WITH CHECK (("student_id" = "auth"."uid"()));



CREATE POLICY "student_insert_submission" ON "app"."prep_assignment_submissions" FOR INSERT WITH CHECK (("student_id" = "auth"."uid"()));



CREATE POLICY "student_insert_td_submission" ON "app"."td_assignment_submissions" FOR INSERT WITH CHECK (("student_id" = "auth"."uid"()));



CREATE POLICY "student_join_group" ON "app"."td_local_group_members" FOR INSERT WITH CHECK (("student_id" = "auth"."uid"()));



CREATE POLICY "student_join_prep_live" ON "app"."prep_live_participants" FOR INSERT WITH CHECK (("student_id" = "auth"."uid"()));



CREATE POLICY "student_own_group_member" ON "app"."td_local_group_members" FOR SELECT USING (("student_id" = "auth"."uid"()));



CREATE POLICY "student_own_prep_live_part" ON "app"."prep_live_participants" FOR SELECT USING (("student_id" = "auth"."uid"()));



CREATE POLICY "student_own_psychotech_profile" ON "app"."prep_psychotech_profiles" FOR SELECT USING (("student_id" = "auth"."uid"()));



CREATE POLICY "student_own_psychotech_results" ON "app"."prep_psychotech_results" FOR SELECT USING (("student_id" = "auth"."uid"()));



CREATE POLICY "student_own_submissions" ON "app"."prep_assignment_submissions" FOR SELECT USING (("student_id" = "auth"."uid"()));



CREATE POLICY "student_own_td_profile" ON "app"."td_student_profiles" USING (("student_id" = "auth"."uid"())) WITH CHECK (("student_id" = "auth"."uid"()));



CREATE POLICY "student_own_td_submissions" ON "app"."td_assignment_submissions" FOR SELECT USING (("student_id" = "auth"."uid"()));



CREATE POLICY "student_see_sessions" ON "app"."td_physical_sessions" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "app"."td_local_group_members" "m"
  WHERE (("m"."group_id" = "td_physical_sessions"."group_id") AND ("m"."student_id" = "auth"."uid"())))));



CREATE POLICY "student_select_active_course_domains" ON "app"."course_domains" FOR SELECT USING (("is_active" = true));



CREATE POLICY "student_select_active_course_resources" ON "app"."course_resources" FOR SELECT USING ((("is_active" = true) AND (EXISTS ( SELECT 1
   FROM ("app"."course_units" "u"
     JOIN "app"."course_domains" "d" ON (("d"."id" = "u"."domain_id")))
  WHERE (("u"."id" = "course_resources"."unit_id") AND ("u"."is_active" = true) AND ("d"."is_active" = true))))));



CREATE POLICY "student_select_active_course_units" ON "app"."course_units" FOR SELECT USING ((("is_active" = true) AND (EXISTS ( SELECT 1
   FROM "app"."course_domains" "d"
  WHERE (("d"."id" = "course_units"."domain_id") AND ("d"."is_active" = true))))));



CREATE POLICY "student_select_active_free_videos" ON "app"."free_videos" FOR SELECT USING ((("is_active" = true) AND (COALESCE("moderation_status", 'published'::"text") <> ALL (ARRAY['blocked_ai'::"text", 'rejected'::"text"]))));



CREATE POLICY "student_select_active_prep_live" ON "app"."prep_live_sessions" FOR SELECT USING ((("is_active" = true) AND ("status" = ANY (ARRAY['approved'::"text", 'running'::"text"]))));



CREATE POLICY "student_select_challenge_comments" ON "app"."challenge_comments" FOR SELECT USING (("is_deleted" = false));



CREATE POLICY "student_select_challenge_favorites" ON "app"."challenge_favorites" FOR SELECT USING (true);



CREATE POLICY "student_select_challenge_likes" ON "app"."challenge_likes" FOR SELECT USING (true);



CREATE POLICY "student_select_community_poll_votes" ON "app"."community_poll_votes" FOR SELECT USING (true);



CREATE POLICY "student_select_community_polls" ON "app"."community_polls" FOR SELECT USING (true);



CREATE POLICY "student_select_community_post_reactions" ON "app"."community_post_reactions" FOR SELECT USING (true);



CREATE POLICY "student_select_community_stories" ON "app"."community_stories" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "app"."community_memberships" "m"
  WHERE (("m"."community_id" = "community_stories"."community_id") AND ("m"."user_id" = "auth"."uid"()) AND ("m"."is_active" = true)))));



CREATE POLICY "student_select_course_exercises" ON "app"."exercises" FOR SELECT USING (true);



CREATE POLICY "student_select_online_course_forum_messages" ON "app"."online_course_forum_messages" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM ("app"."online_course_forum_threads" "t"
     JOIN "app"."online_course_enrollments" "e" ON (("e"."course_id" = "t"."course_id")))
  WHERE (("t"."id" = "online_course_forum_messages"."thread_id") AND ("e"."student_id" = "auth"."uid"())))));



CREATE POLICY "student_select_online_course_forum_threads" ON "app"."online_course_forum_threads" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "app"."online_course_enrollments" "e"
  WHERE (("e"."course_id" = "online_course_forum_threads"."course_id") AND ("e"."student_id" = "auth"."uid"())))));



CREATE POLICY "student_select_online_course_live_sessions" ON "app"."online_course_live_sessions" FOR SELECT USING ((("is_active" = true) AND (EXISTS ( SELECT 1
   FROM "app"."online_course_enrollments" "e"
  WHERE (("e"."course_id" = "online_course_live_sessions"."course_id") AND ("e"."student_id" = "auth"."uid"()))))));



CREATE POLICY "student_select_own_announcement_reads" ON "app"."user_announcement_reads" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "student_select_own_application_files" ON "app"."application_files" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "app"."applications" "a"
  WHERE (("a"."id" = "application_files"."application_id") AND ("a"."student_id" = "auth"."uid"())))));



CREATE POLICY "student_select_own_application_messages" ON "app"."application_messages" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "app"."applications" "a"
  WHERE (("a"."id" = "application_messages"."application_id") AND ("a"."student_id" = "auth"."uid"())))));



CREATE POLICY "student_select_own_applications" ON "app"."applications" FOR SELECT USING (("student_id" = "auth"."uid"()));



CREATE POLICY "student_select_own_bobodo_feedback" ON "app"."bobodo_feedback" FOR SELECT USING (("student_id" = "auth"."uid"()));



CREATE POLICY "student_select_own_bobodo_messages" ON "app"."bobodo_messages" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "app"."bobodo_sessions" "s"
  WHERE (("s"."id" = "bobodo_messages"."session_id") AND ("s"."student_id" = "auth"."uid"())))));



CREATE POLICY "student_select_own_bobodo_sessions" ON "app"."bobodo_sessions" FOR SELECT USING (("student_id" = "auth"."uid"()));



CREATE POLICY "student_select_own_challenge_participation_videos" ON "app"."challenge_participation_videos" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "app"."challenge_participations" "cp"
  WHERE (("cp"."id" = "challenge_participation_videos"."participation_id") AND ("cp"."user_id" = "auth"."uid"())))));



CREATE POLICY "student_select_own_challenge_participations" ON "app"."challenge_participations" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "student_select_own_challenge_reports" ON "app"."challenge_reports" FOR SELECT USING (("reporter_id" = "auth"."uid"()));



CREATE POLICY "student_select_own_challenge_video_overlays" ON "app"."challenge_video_overlays" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "app"."challenge_participations" "cp"
  WHERE (("cp"."id" = "challenge_video_overlays"."participation_id") AND ("cp"."user_id" = "auth"."uid"())))));



CREATE POLICY "student_select_own_challenge_video_render_jobs" ON "app"."challenge_video_render_jobs" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "app"."challenge_participations" "cp"
  WHERE (("cp"."id" = "challenge_video_render_jobs"."participation_id") AND ("cp"."user_id" = "auth"."uid"())))));



CREATE POLICY "student_select_own_community_join_requests" ON "app"."community_join_requests" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "student_select_own_community_memberships" ON "app"."community_memberships" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "student_select_own_dossier_documents" ON "app"."student_dossier_documents" FOR SELECT USING (("student_id" = "auth"."uid"()));



CREATE POLICY "student_select_own_enrollments" ON "app"."course_enrollments" FOR SELECT USING (("student_id" = "auth"."uid"()));



CREATE POLICY "student_select_own_event_follows" ON "app"."user_event_follows" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "student_select_own_free_video_overlays" ON "app"."free_video_overlays" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "app"."free_videos" "fv"
  WHERE (("fv"."id" = "free_video_overlays"."free_video_id") AND ("fv"."user_id" = "auth"."uid"())))));



CREATE POLICY "student_select_own_free_video_render_jobs" ON "app"."free_video_render_jobs" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "app"."free_videos" "fv"
  WHERE (("fv"."id" = "free_video_render_jobs"."free_video_id") AND ("fv"."user_id" = "auth"."uid"())))));



CREATE POLICY "student_select_own_marketplace_order_items" ON "app"."marketplace_order_items" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "app"."marketplace_orders" "o"
  WHERE (("o"."id" = "marketplace_order_items"."order_id") AND ("o"."student_id" = "auth"."uid"())))));



CREATE POLICY "student_select_own_marketplace_orders" ON "app"."marketplace_orders" FOR SELECT USING (("student_id" = "auth"."uid"()));



CREATE POLICY "student_select_own_online_course_certificates" ON "app"."online_course_certificates" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "app"."online_course_enrollments" "e"
  WHERE (("e"."id" = "online_course_certificates"."enrollment_id") AND ("e"."student_id" = "auth"."uid"())))));



CREATE POLICY "student_select_own_online_course_enrollment_messages" ON "app"."online_course_enrollment_messages" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "app"."online_course_enrollments" "e"
  WHERE (("e"."id" = "online_course_enrollment_messages"."enrollment_id") AND ("e"."student_id" = "auth"."uid"())))));



CREATE POLICY "student_select_own_online_course_enrollments" ON "app"."online_course_enrollments" FOR SELECT USING (("student_id" = "auth"."uid"()));



CREATE POLICY "student_select_own_online_course_lesson_progress" ON "app"."online_course_lesson_progress" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "app"."online_course_enrollments" "e"
  WHERE (("e"."id" = "online_course_lesson_progress"."enrollment_id") AND ("e"."student_id" = "auth"."uid"())))));



CREATE POLICY "student_select_own_opportunity_applications" ON "app"."opportunity_applications" FOR SELECT USING (("student_id" = "auth"."uid"()));



CREATE POLICY "student_select_own_payment_proofs" ON "app"."payment_proofs" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "app"."application_payments" "p"
  WHERE (("p"."id" = "payment_proofs"."payment_id") AND ("p"."student_id" = "auth"."uid"())))));



CREATE POLICY "student_select_own_payments" ON "app"."application_payments" FOR SELECT USING (("student_id" = "auth"."uid"()));



CREATE POLICY "student_select_own_prep_attempts" ON "app"."prep_attempts" FOR SELECT USING ((("student_id" = "auth"."uid"()) AND "public"."app_has_feature_access"('prep_concours'::"text")));



CREATE POLICY "student_select_own_profile" ON "app"."students" FOR SELECT USING (("id" = "auth"."uid"()));



CREATE POLICY "student_select_own_read_states" ON "app"."community_read_states" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "student_select_own_short_training_registration_messages" ON "app"."short_training_registration_messages" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "app"."short_training_registrations" "r"
  WHERE (("r"."id" = "short_training_registration_messages"."registration_id") AND ("r"."user_id" = "auth"."uid"())))));



CREATE POLICY "student_select_own_short_training_registrations" ON "app"."short_training_registrations" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "student_select_own_story_views" ON "app"."community_story_views" FOR SELECT USING ((("viewer_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "app"."community_stories" "s"
  WHERE (("s"."id" = "community_story_views"."story_id") AND ("s"."author_id" = "auth"."uid"()))))));



CREATE POLICY "student_select_own_user_referral" ON "app"."user_referrals" FOR SELECT USING (("student_id" = "auth"."uid"()));



CREATE POLICY "student_select_public_short_training_sessions" ON "app"."short_training_sessions" FOR SELECT USING ((("is_active" = true) AND ("status" = 'open'::"text")));



CREATE POLICY "student_select_published_academic_events" ON "app"."academic_events" FOR SELECT USING (("is_published" = true));



CREATE POLICY "student_select_published_assignments" ON "app"."prep_assignments" FOR SELECT USING ((("is_published" = true) AND "public"."app_has_feature_access"('prep_concours'::"text")));



CREATE POLICY "student_select_published_td_assignments" ON "app"."td_assignments" FOR SELECT USING (("is_published" = true));



CREATE POLICY "student_select_td_groups" ON "app"."td_local_groups" FOR SELECT USING (("status" = ANY (ARRAY['forming'::"text", 'confirmed'::"text", 'active'::"text"])));



CREATE POLICY "student_update_community_poll_votes" ON "app"."community_poll_votes" FOR UPDATE USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "student_update_own_announcement_reads" ON "app"."user_announcement_reads" FOR UPDATE USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "student_update_own_applications" ON "app"."applications" FOR UPDATE USING (("student_id" = "auth"."uid"()));



CREATE POLICY "student_update_own_challenge_comments" ON "app"."challenge_comments" FOR UPDATE USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "student_update_own_challenge_participations" ON "app"."challenge_participations" FOR UPDATE USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "student_update_own_community_stories" ON "app"."community_stories" FOR UPDATE USING (("author_id" = "auth"."uid"()));



CREATE POLICY "student_update_own_dossier_documents" ON "app"."student_dossier_documents" FOR UPDATE USING (("student_id" = "auth"."uid"()));



CREATE POLICY "student_update_own_event_follows" ON "app"."user_event_follows" FOR UPDATE USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "student_update_own_marketplace_orders" ON "app"."marketplace_orders" FOR UPDATE USING (("student_id" = "auth"."uid"()));



CREATE POLICY "student_update_own_online_course_lesson_progress" ON "app"."online_course_lesson_progress" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "app"."online_course_enrollments" "e"
  WHERE (("e"."id" = "online_course_lesson_progress"."enrollment_id") AND ("e"."student_id" = "auth"."uid"())))));



CREATE POLICY "student_update_own_profile" ON "app"."students" FOR UPDATE USING (("id" = "auth"."uid"()));



CREATE POLICY "student_update_own_read_states" ON "app"."community_read_states" FOR UPDATE USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "student_update_psychotech_profile" ON "app"."prep_psychotech_profiles" FOR UPDATE USING (("student_id" = "auth"."uid"()));



CREATE POLICY "student_update_td_submission" ON "app"."td_assignment_submissions" FOR UPDATE USING (("student_id" = "auth"."uid"()));



CREATE POLICY "student_upsert_own_challenge_video_overlays_ins" ON "app"."challenge_video_overlays" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "app"."challenge_participations" "cp"
  WHERE (("cp"."id" = "challenge_video_overlays"."participation_id") AND ("cp"."user_id" = "auth"."uid"())))));



CREATE POLICY "student_upsert_own_challenge_video_overlays_upd" ON "app"."challenge_video_overlays" FOR UPDATE WITH CHECK ((EXISTS ( SELECT 1
   FROM "app"."challenge_participations" "cp"
  WHERE (("cp"."id" = "challenge_video_overlays"."participation_id") AND ("cp"."user_id" = "auth"."uid"())))));



CREATE POLICY "student_upsert_own_free_video_overlays_ins" ON "app"."free_video_overlays" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "app"."free_videos" "fv"
  WHERE (("fv"."id" = "free_video_overlays"."free_video_id") AND ("fv"."user_id" = "auth"."uid"())))));



CREATE POLICY "student_upsert_own_free_video_overlays_upd" ON "app"."free_video_overlays" FOR UPDATE WITH CHECK ((EXISTS ( SELECT 1
   FROM "app"."free_videos" "fv"
  WHERE (("fv"."id" = "free_video_overlays"."free_video_id") AND ("fv"."user_id" = "auth"."uid"())))));



CREATE POLICY "student_upsert_psychotech_profile" ON "app"."prep_psychotech_profiles" FOR INSERT WITH CHECK (("student_id" = "auth"."uid"()));



ALTER TABLE "app"."students" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "sub_plans_admin_all" ON "app"."subscription_plans" USING ((("auth"."jwt"() ? 'role'::"text") AND (("auth"."jwt"() ->> 'role'::"text") = 'admin'::"text")));



CREATE POLICY "sub_plans_select_all" ON "app"."subscription_plans" FOR SELECT USING (true);



ALTER TABLE "app"."subscription_plans" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."subscriptions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "subscriptions_admin_all" ON "app"."subscriptions" USING ((("auth"."jwt"() ? 'role'::"text") AND (("auth"."jwt"() ->> 'role'::"text") = 'admin'::"text")));



CREATE POLICY "subscriptions_student_select" ON "app"."subscriptions" FOR SELECT USING (("student_id" = "auth"."uid"()));



CREATE POLICY "support_conv_insert" ON "app"."support_conversations" FOR INSERT WITH CHECK (("requester_user_id" = "auth"."uid"()));



CREATE POLICY "support_conv_select" ON "app"."support_conversations" FOR SELECT USING ((("requester_user_id" = "auth"."uid"()) OR (( SELECT ("users"."raw_user_meta_data" ->> 'role'::"text")
   FROM "auth"."users"
  WHERE ("users"."id" = "auth"."uid"())) = 'admin'::"text")));



CREATE POLICY "support_conv_update" ON "app"."support_conversations" FOR UPDATE USING ((("requester_user_id" = "auth"."uid"()) OR (( SELECT ("users"."raw_user_meta_data" ->> 'role'::"text")
   FROM "auth"."users"
  WHERE ("users"."id" = "auth"."uid"())) = 'admin'::"text")));



ALTER TABLE "app"."support_conversations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."support_messages" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "support_msg_insert" ON "app"."support_messages" FOR INSERT WITH CHECK (("sender_user_id" = "auth"."uid"()));



CREATE POLICY "support_msg_select" ON "app"."support_messages" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "app"."support_conversations" "c"
  WHERE (("c"."id" = "support_messages"."conversation_id") AND (("c"."requester_user_id" = "auth"."uid"()) OR (( SELECT ("users"."raw_user_meta_data" ->> 'role'::"text")
           FROM "auth"."users"
          WHERE ("users"."id" = "auth"."uid"())) = 'admin'::"text"))))));



CREATE POLICY "support_read_select" ON "app"."support_read_states" FOR SELECT USING (("user_id" = "auth"."uid"()));



ALTER TABLE "app"."support_read_states" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "support_read_update" ON "app"."support_read_states" FOR UPDATE USING (("user_id" = "auth"."uid"()));



CREATE POLICY "support_read_upsert" ON "app"."support_read_states" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "app"."td_ai_config" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."td_ai_conversations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."td_ai_messages" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."td_assignment_submissions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."td_assignments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."td_attendance" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "td_attendance_admin_all" ON "app"."td_attendance" USING (("app"."app_td_get_current_role"() = 'admin'::"text")) WITH CHECK (("app"."app_td_get_current_role"() = 'admin'::"text"));



CREATE POLICY "td_attendance_student_select" ON "app"."td_attendance" FOR SELECT USING (("student_id" = "auth"."uid"()));



CREATE POLICY "td_attendance_teacher_select" ON "app"."td_attendance" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM ("app"."td_session_occurrences" "o"
     JOIN "app"."td_teachers" "t" ON (("t"."id" = "o"."teacher_id")))
  WHERE (("o"."id" = "td_attendance"."occurrence_id") AND ("t"."user_id" = "auth"."uid"())))));



ALTER TABLE "app"."td_badges" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."td_collections" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "td_collections_admin_all" ON "app"."td_collections" USING (("app"."app_td_get_current_role"() = 'admin'::"text")) WITH CHECK (("app"."app_td_get_current_role"() = 'admin'::"text"));



CREATE POLICY "td_collections_public_select" ON "app"."td_collections" FOR SELECT USING (true);



ALTER TABLE "app"."td_daily_goals" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "td_daily_goals_student_select" ON "app"."td_daily_goals" FOR SELECT USING (("student_id" = "auth"."uid"()));



ALTER TABLE "app"."td_discipline_colors" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "td_discipline_colors_public_select" ON "app"."td_discipline_colors" FOR SELECT USING (true);



ALTER TABLE "app"."td_doc_chunks" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."td_enrollments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "td_enrollments_admin_all" ON "app"."td_enrollments" USING (("app"."app_td_get_current_role"() = 'admin'::"text")) WITH CHECK (("app"."app_td_get_current_role"() = 'admin'::"text"));



CREATE POLICY "td_enrollments_student_select" ON "app"."td_enrollments" FOR SELECT USING (("student_id" = "auth"."uid"()));



CREATE POLICY "td_enrollments_teacher_select" ON "app"."td_enrollments" FOR SELECT USING ((("assigned_teacher_id" IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "app"."td_teachers" "t"
  WHERE (("t"."id" = "td_enrollments"."assigned_teacher_id") AND ("t"."user_id" = "auth"."uid"()))))));



ALTER TABLE "app"."td_exam_papers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."td_fields" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "td_fields_admin_all" ON "app"."td_fields" USING (("app"."app_td_get_current_role"() = 'admin'::"text")) WITH CHECK (("app"."app_td_get_current_role"() = 'admin'::"text"));



CREATE POLICY "td_fields_public_select" ON "app"."td_fields" FOR SELECT USING (("status" = 'active'::"text"));



ALTER TABLE "app"."td_flashcard_decks" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."td_flashcard_progress" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."td_flashcards" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "td_gen_assign_admin_all" ON "app"."td_generated_assignments" TO "service_role" USING (true);



CREATE POLICY "td_gen_assign_insert_own" ON "app"."td_generated_assignments" FOR INSERT TO "authenticated" WITH CHECK (("student_id" = "auth"."uid"()));



CREATE POLICY "td_gen_assign_select_own" ON "app"."td_generated_assignments" FOR SELECT TO "authenticated" USING ((("student_id" = "auth"."uid"()) OR ("student_id" IS NULL)));



ALTER TABLE "app"."td_generated_assignments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."td_leaderboard_cache" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "td_leaderboard_cache_public_select" ON "app"."td_leaderboard_cache" FOR SELECT USING (true);



ALTER TABLE "app"."td_local_group_members" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."td_local_groups" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."td_messages" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "td_messages_admin_all" ON "app"."td_messages" USING (("app"."app_td_get_current_role"() = 'admin'::"text")) WITH CHECK (("app"."app_td_get_current_role"() = 'admin'::"text"));



CREATE POLICY "td_messages_participants_insert" ON "app"."td_messages" FOR INSERT WITH CHECK (("sender_user_id" = "auth"."uid"()));



CREATE POLICY "td_messages_participants_select" ON "app"."td_messages" FOR SELECT USING ((("sender_user_id" = "auth"."uid"()) OR ("student_user_id" = "auth"."uid"()) OR ("teacher_user_id" = "auth"."uid"())));



ALTER TABLE "app"."td_physical_sessions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."td_programs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "td_programs_admin_all" ON "app"."td_programs" USING (("app"."app_td_get_current_role"() = 'admin'::"text")) WITH CHECK (("app"."app_td_get_current_role"() = 'admin'::"text"));



CREATE POLICY "td_programs_public_select" ON "app"."td_programs" FOR SELECT USING (("status" = 'published'::"public"."td_program_status"));



ALTER TABLE "app"."td_question_banks" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."td_questions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."td_quiz_attempts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."td_quiz_templates" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."td_resource_progress" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "td_resource_progress_student_select" ON "app"."td_resource_progress" FOR SELECT USING (("student_id" = "auth"."uid"()));



ALTER TABLE "app"."td_resources" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "td_resources_admin_all" ON "app"."td_resources" USING (("app"."app_td_get_current_role"() = 'admin'::"text")) WITH CHECK (("app"."app_td_get_current_role"() = 'admin'::"text"));



ALTER TABLE "app"."td_scan_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."td_session_occurrences" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "td_session_occurrences_admin_all" ON "app"."td_session_occurrences" USING (("app"."app_td_get_current_role"() = 'admin'::"text")) WITH CHECK (("app"."app_td_get_current_role"() = 'admin'::"text"));



CREATE POLICY "td_session_occurrences_student_select" ON "app"."td_session_occurrences" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "app"."td_enrollments" "e"
  WHERE (("e"."id" = "td_session_occurrences"."enrollment_id") AND ("e"."student_id" = "auth"."uid"())))));



CREATE POLICY "td_session_occurrences_teacher_select" ON "app"."td_session_occurrences" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "app"."td_teachers" "t"
  WHERE (("t"."id" = "td_session_occurrences"."teacher_id") AND ("t"."user_id" = "auth"."uid"())))));



ALTER TABLE "app"."td_sessions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "td_sessions_admin_all" ON "app"."td_sessions" USING (("app"."app_td_get_current_role"() = 'admin'::"text")) WITH CHECK (("app"."app_td_get_current_role"() = 'admin'::"text"));



CREATE POLICY "td_sessions_public_select" ON "app"."td_sessions" FOR SELECT USING (true);



ALTER TABLE "app"."td_source_documents" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."td_streaks" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "td_streaks_student_select" ON "app"."td_streaks" FOR SELECT USING (("student_id" = "auth"."uid"()));



ALTER TABLE "app"."td_student_badges" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."td_student_profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."td_student_progress" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."td_student_requests" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "td_student_requests_admin_all" ON "app"."td_student_requests" USING (("app"."app_td_get_current_role"() = 'admin'::"text")) WITH CHECK (("app"."app_td_get_current_role"() = 'admin'::"text"));



CREATE POLICY "td_student_requests_student_insert" ON "app"."td_student_requests" FOR INSERT WITH CHECK (("student_id" = "auth"."uid"()));



CREATE POLICY "td_student_requests_student_select" ON "app"."td_student_requests" FOR SELECT USING (("student_id" = "auth"."uid"()));



ALTER TABLE "app"."td_teacher_availability" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "td_teacher_availability_admin_all" ON "app"."td_teacher_availability" USING (("app"."app_td_get_current_role"() = 'admin'::"text")) WITH CHECK (("app"."app_td_get_current_role"() = 'admin'::"text"));



CREATE POLICY "td_teacher_availability_teacher_insert" ON "app"."td_teacher_availability" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "app"."td_teachers" "t"
  WHERE (("t"."id" = "td_teacher_availability"."teacher_id") AND ("t"."user_id" = "auth"."uid"())))));



CREATE POLICY "td_teacher_availability_teacher_select" ON "app"."td_teacher_availability" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "app"."td_teachers" "t"
  WHERE (("t"."id" = "td_teacher_availability"."teacher_id") AND ("t"."user_id" = "auth"."uid"())))));



CREATE POLICY "td_teacher_availability_teacher_update" ON "app"."td_teacher_availability" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "app"."td_teachers" "t"
  WHERE (("t"."id" = "td_teacher_availability"."teacher_id") AND ("t"."user_id" = "auth"."uid"())))));



ALTER TABLE "app"."td_teacher_profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."td_teachers" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "td_teachers_admin_all" ON "app"."td_teachers" USING (("app"."app_td_get_current_role"() = 'admin'::"text")) WITH CHECK (("app"."app_td_get_current_role"() = 'admin'::"text"));



CREATE POLICY "td_teachers_self_select" ON "app"."td_teachers" FOR SELECT USING (("user_id" = "auth"."uid"()));



ALTER TABLE "app"."td_xp_log" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "td_xp_log_student_select" ON "app"."td_xp_log" FOR SELECT USING (("student_id" = "auth"."uid"()));



CREATE POLICY "teacher_all_own_assignments" ON "app"."prep_assignments" USING (("teacher_id" = "auth"."uid"())) WITH CHECK (("teacher_id" = "auth"."uid"()));



CREATE POLICY "teacher_all_own_prep_live" ON "app"."prep_live_sessions" USING (("teacher_id" = "auth"."uid"())) WITH CHECK (("teacher_id" = "auth"."uid"()));



CREATE POLICY "teacher_all_own_td_assignments" ON "app"."td_assignments" USING (("teacher_id" = "auth"."uid"())) WITH CHECK (("teacher_id" = "auth"."uid"()));



CREATE POLICY "teacher_manage_sessions" ON "app"."td_physical_sessions" USING (("teacher_id" = "auth"."uid"())) WITH CHECK (("teacher_id" = "auth"."uid"()));



CREATE POLICY "teacher_own_td_profile" ON "app"."td_teacher_profiles" USING (("teacher_id" = "auth"."uid"())) WITH CHECK (("teacher_id" = "auth"."uid"()));



CREATE POLICY "teacher_see_assigned_groups" ON "app"."td_local_groups" FOR SELECT USING (("assigned_teacher_id" = "auth"."uid"()));



CREATE POLICY "teacher_see_prep_live_part" ON "app"."prep_live_participants" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "app"."prep_live_sessions" "s"
  WHERE (("s"."id" = "prep_live_participants"."session_id") AND ("s"."teacher_id" = "auth"."uid"())))));



CREATE POLICY "teacher_see_submissions" ON "app"."prep_assignment_submissions" USING ((EXISTS ( SELECT 1
   FROM "app"."prep_assignments" "a"
  WHERE (("a"."id" = "prep_assignment_submissions"."assignment_id") AND ("a"."teacher_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "app"."prep_assignments" "a"
  WHERE (("a"."id" = "prep_assignment_submissions"."assignment_id") AND ("a"."teacher_id" = "auth"."uid"())))));



CREATE POLICY "teacher_see_td_submissions" ON "app"."td_assignment_submissions" USING ((EXISTS ( SELECT 1
   FROM "app"."td_assignments" "a"
  WHERE (("a"."id" = "td_assignment_submissions"."assignment_id") AND ("a"."teacher_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "app"."td_assignments" "a"
  WHERE (("a"."id" = "td_assignment_submissions"."assignment_id") AND ("a"."teacher_id" = "auth"."uid"())))));



ALTER TABLE "app"."tournament_matches" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."tournament_participants" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."tournament_rewards" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."tournaments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."universities" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."university_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."university_media" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."university_news" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "university_select_own_payments" ON "app"."application_payments" FOR SELECT USING (
CASE
    WHEN (("auth"."jwt"() ? 'role'::"text") AND (("auth"."jwt"() ->> 'role'::"text") = 'university'::"text")) THEN ((("auth"."jwt"() ->> 'university_id'::"text"))::"uuid" = "university_id")
    ELSE false
END);



ALTER TABLE "app"."university_site_banners" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."university_site_blocks" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."university_site_config" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."university_staff" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."user_admin_status" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."user_announcement_reads" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "user_delete_own_comments" ON "app"."opportunity_comments" FOR DELETE USING (("user_id" = "auth"."uid"()));



ALTER TABLE "app"."user_device_tokens" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."user_event_follows" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."user_feature_entitlements" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "user_insert_own_prep_ai_usage_logs" ON "app"."prep_ai_usage_logs" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "app"."user_invitations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "user_manage_own_device_tokens" ON "app"."user_device_tokens" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "user_manage_own_marketplace_cart_items" ON "app"."marketplace_cart_items" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "app"."marketplace_carts" "c"
  WHERE (("c"."id" = "marketplace_cart_items"."cart_id") AND ("c"."user_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "app"."marketplace_carts" "c"
  WHERE (("c"."id" = "marketplace_cart_items"."cart_id") AND ("c"."user_id" = "auth"."uid"())))));



CREATE POLICY "user_manage_own_marketplace_carts" ON "app"."marketplace_carts" TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "user_manage_own_marketplace_listing_bookmarks" ON "app"."marketplace_listing_bookmarks" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "user_manage_own_opportunity_bookmarks" ON "app"."opportunity_bookmarks" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "user_manage_own_reactions" ON "app"."opportunity_reactions" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "user_manage_own_views" ON "app"."opportunity_views" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "app"."user_notification_state" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "user_notification_state_self" ON "app"."user_notification_state" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "app"."user_presence" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "user_presence_self" ON "app"."user_presence" FOR SELECT USING (("auth"."uid"() = "user_id"));



ALTER TABLE "app"."user_referrals" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "user_select_own_feature_entitlements" ON "app"."user_feature_entitlements" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "user_select_own_marketplace_order_items" ON "app"."marketplace_order_items" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "app"."marketplace_orders" "o"
  WHERE (("o"."id" = "marketplace_order_items"."order_id") AND ("o"."student_id" = "auth"."uid"())))));



CREATE POLICY "user_select_own_marketplace_orders" ON "app"."marketplace_orders" FOR SELECT TO "authenticated" USING (("student_id" = "auth"."uid"()));



CREATE POLICY "user_select_own_prep_ai_usage_logs" ON "app"."prep_ai_usage_logs" FOR SELECT USING (("user_id" = "auth"."uid"()));



ALTER TABLE "app"."video_asset_contexts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."video_asset_legacy_map" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."video_assets" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."video_heatmap_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."video_playback_errors" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."video_processing_jobs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."video_reactions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "video_reactions_own" ON "app"."video_reactions" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "app"."video_renditions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."video_shares" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."video_sources" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "app"."video_views" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "video_views_insert_own" ON "app"."video_views" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



GRANT USAGE ON SCHEMA "app" TO "anon";
GRANT USAGE ON SCHEMA "app" TO "authenticated";
GRANT ALL ON SCHEMA "app" TO "service_role";



GRANT ALL ON FUNCTION "app"."app_get_or_create_bobodo_session"("p_title" "text") TO "authenticated";
GRANT ALL ON FUNCTION "app"."app_get_or_create_bobodo_session"("p_title" "text") TO "service_role";



GRANT ALL ON FUNCTION "app"."app_get_or_create_bobodo_session_admin"("p_student_id" "uuid", "p_title" "text") TO "authenticated";
GRANT ALL ON FUNCTION "app"."app_get_or_create_bobodo_session_admin"("p_student_id" "uuid", "p_title" "text") TO "service_role";



REVOKE ALL ON FUNCTION "app"."app_run_send_push_notifications"() FROM PUBLIC;
GRANT ALL ON FUNCTION "app"."app_run_send_push_notifications"() TO "service_role";



REVOKE ALL ON FUNCTION "app"."app_td_get_current_role"() FROM PUBLIC;
GRANT ALL ON FUNCTION "app"."app_td_get_current_role"() TO "authenticated";
GRANT ALL ON FUNCTION "app"."app_td_get_current_role"() TO "service_role";



GRANT ALL ON FUNCTION "app"."fn_enqueue_notification_event"("p_user_id" "uuid", "p_domain" "text", "p_event_type" "text", "p_payload" "jsonb") TO "service_role";



GRANT SELECT ON TABLE "app"."hero_videos" TO "anon";
GRANT SELECT ON TABLE "app"."hero_videos" TO "authenticated";
GRANT INSERT,DELETE,UPDATE ON TABLE "app"."hero_videos" TO "service_role";



GRANT ALL ON FUNCTION "app"."hero_get_video"("p_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "app"."hero_get_video"("p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "app"."hero_get_video"("p_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "app"."hero_list_videos"("p_context" "text") TO "anon";
GRANT ALL ON FUNCTION "app"."hero_list_videos"("p_context" "text") TO "authenticated";
GRANT ALL ON FUNCTION "app"."hero_list_videos"("p_context" "text") TO "service_role";



REVOKE ALL ON FUNCTION "app"."is_admin"() FROM PUBLIC;
GRANT ALL ON FUNCTION "app"."is_admin"() TO "anon";
GRANT ALL ON FUNCTION "app"."is_admin"() TO "authenticated";
GRANT ALL ON FUNCTION "app"."is_admin"() TO "service_role";



GRANT SELECT ON TABLE "app"."academic_events" TO "authenticated";
GRANT ALL ON TABLE "app"."academic_events" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."admin_user_action_logs" TO "authenticated";
GRANT ALL ON TABLE "app"."admin_user_action_logs" TO "service_role";



GRANT ALL ON TABLE "app"."admin_users" TO "service_role";



GRANT SELECT,INSERT ON TABLE "app"."application_files" TO "authenticated";
GRANT ALL ON TABLE "app"."application_files" TO "service_role";



GRANT SELECT,INSERT ON TABLE "app"."application_messages" TO "authenticated";
GRANT ALL ON TABLE "app"."application_messages" TO "service_role";



GRANT SELECT ON TABLE "app"."application_payments" TO "authenticated";
GRANT ALL ON TABLE "app"."application_payments" TO "service_role";



GRANT SELECT,INSERT,UPDATE ON TABLE "app"."applications" TO "authenticated";
GRANT ALL ON TABLE "app"."applications" TO "service_role";



GRANT ALL ON TABLE "app"."bobodo_detected_needs" TO "service_role";



GRANT SELECT,INSERT ON TABLE "app"."bobodo_feedback" TO "authenticated";
GRANT ALL ON TABLE "app"."bobodo_feedback" TO "service_role";



GRANT SELECT ON TABLE "app"."bobodo_knowledge" TO "authenticated";
GRANT ALL ON TABLE "app"."bobodo_knowledge" TO "service_role";



GRANT SELECT,INSERT ON TABLE "app"."bobodo_messages" TO "authenticated";
GRANT ALL ON TABLE "app"."bobodo_messages" TO "service_role";



GRANT SELECT,INSERT ON TABLE "app"."bobodo_sessions" TO "authenticated";
GRANT ALL ON TABLE "app"."bobodo_sessions" TO "service_role";



GRANT ALL ON TABLE "app"."bobodo_unanswered_questions" TO "service_role";



GRANT SELECT,INSERT,UPDATE ON TABLE "app"."challenge_comments" TO "authenticated";
GRANT ALL ON TABLE "app"."challenge_comments" TO "service_role";



GRANT SELECT,INSERT,DELETE ON TABLE "app"."challenge_favorites" TO "authenticated";
GRANT ALL ON TABLE "app"."challenge_favorites" TO "service_role";



GRANT SELECT,INSERT,DELETE ON TABLE "app"."challenge_likes" TO "authenticated";
GRANT ALL ON TABLE "app"."challenge_likes" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."challenge_participation_videos" TO "authenticated";
GRANT ALL ON TABLE "app"."challenge_participation_videos" TO "service_role";



GRANT SELECT,INSERT,UPDATE ON TABLE "app"."challenge_participations" TO "authenticated";
GRANT ALL ON TABLE "app"."challenge_participations" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."challenge_reports" TO "authenticated";
GRANT ALL ON TABLE "app"."challenge_reports" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."challenge_user_bans" TO "authenticated";
GRANT ALL ON TABLE "app"."challenge_user_bans" TO "service_role";



GRANT SELECT ON TABLE "app"."challenge_video_assets" TO "anon";
GRANT SELECT ON TABLE "app"."challenge_video_assets" TO "authenticated";
GRANT ALL ON TABLE "app"."challenge_video_assets" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."challenge_video_overlays" TO "authenticated";
GRANT ALL ON TABLE "app"."challenge_video_overlays" TO "service_role";



GRANT SELECT ON TABLE "app"."challenge_video_render_jobs" TO "authenticated";
GRANT ALL ON TABLE "app"."challenge_video_render_jobs" TO "service_role";



GRANT SELECT ON TABLE "app"."challenges" TO "anon";
GRANT SELECT ON TABLE "app"."challenges" TO "authenticated";
GRANT ALL ON TABLE "app"."challenges" TO "service_role";



GRANT SELECT ON TABLE "app"."commercial_profiles" TO "authenticated";
GRANT ALL ON TABLE "app"."commercial_profiles" TO "service_role";



GRANT SELECT ON TABLE "app"."communities" TO "anon";
GRANT SELECT ON TABLE "app"."communities" TO "authenticated";
GRANT ALL ON TABLE "app"."communities" TO "service_role";



GRANT SELECT,INSERT ON TABLE "app"."community_join_requests" TO "authenticated";
GRANT ALL ON TABLE "app"."community_join_requests" TO "service_role";



GRANT SELECT,INSERT ON TABLE "app"."community_memberships" TO "authenticated";
GRANT ALL ON TABLE "app"."community_memberships" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."community_poll_votes" TO "authenticated";
GRANT ALL ON TABLE "app"."community_poll_votes" TO "service_role";



GRANT SELECT,INSERT ON TABLE "app"."community_polls" TO "authenticated";
GRANT ALL ON TABLE "app"."community_polls" TO "service_role";



GRANT SELECT,INSERT,DELETE ON TABLE "app"."community_post_reactions" TO "authenticated";
GRANT ALL ON TABLE "app"."community_post_reactions" TO "service_role";



GRANT SELECT,INSERT ON TABLE "app"."community_posts" TO "authenticated";
GRANT ALL ON TABLE "app"."community_posts" TO "service_role";



GRANT SELECT,INSERT,UPDATE ON TABLE "app"."community_read_states" TO "authenticated";
GRANT ALL ON TABLE "app"."community_read_states" TO "service_role";



GRANT SELECT ON TABLE "app"."course_domains" TO "anon";
GRANT SELECT ON TABLE "app"."course_domains" TO "authenticated";
GRANT ALL ON TABLE "app"."course_domains" TO "service_role";



GRANT SELECT,INSERT ON TABLE "app"."course_enrollments" TO "authenticated";
GRANT ALL ON TABLE "app"."course_enrollments" TO "service_role";



GRANT SELECT ON TABLE "app"."course_resources" TO "anon";
GRANT SELECT ON TABLE "app"."course_resources" TO "authenticated";
GRANT ALL ON TABLE "app"."course_resources" TO "service_role";



GRANT SELECT ON TABLE "app"."course_units" TO "anon";
GRANT SELECT ON TABLE "app"."course_units" TO "authenticated";
GRANT ALL ON TABLE "app"."course_units" TO "service_role";



GRANT SELECT ON TABLE "app"."courses" TO "anon";
GRANT SELECT ON TABLE "app"."courses" TO "authenticated";
GRANT ALL ON TABLE "app"."courses" TO "service_role";



GRANT SELECT ON TABLE "app"."exercises" TO "authenticated";
GRANT ALL ON TABLE "app"."exercises" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."free_video_overlays" TO "authenticated";
GRANT ALL ON TABLE "app"."free_video_overlays" TO "service_role";



GRANT SELECT ON TABLE "app"."free_video_render_jobs" TO "authenticated";
GRANT ALL ON TABLE "app"."free_video_render_jobs" TO "service_role";



GRANT SELECT ON TABLE "app"."free_videos" TO "authenticated";
GRANT ALL ON TABLE "app"."free_videos" TO "service_role";



GRANT SELECT ON TABLE "app"."hero_overlay_animations" TO "anon";
GRANT SELECT ON TABLE "app"."hero_overlay_animations" TO "authenticated";
GRANT ALL ON TABLE "app"."hero_overlay_animations" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."hero_overlays" TO "authenticated";
GRANT ALL ON TABLE "app"."hero_overlays" TO "service_role";



GRANT SELECT ON TABLE "app"."hero_playlist" TO "anon";
GRANT SELECT ON TABLE "app"."hero_playlist" TO "authenticated";
GRANT ALL ON TABLE "app"."hero_playlist" TO "service_role";



GRANT SELECT ON TABLE "app"."hero_renders" TO "authenticated";
GRANT ALL ON TABLE "app"."hero_renders" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."hero_video_jobs" TO "service_role";



GRANT SELECT,INSERT,UPDATE ON TABLE "app"."instructors" TO "authenticated";
GRANT ALL ON TABLE "app"."instructors" TO "service_role";



GRANT SELECT ON TABLE "app"."landing_announcements" TO "anon";
GRANT SELECT ON TABLE "app"."landing_announcements" TO "authenticated";
GRANT ALL ON TABLE "app"."landing_announcements" TO "service_role";



GRANT SELECT ON TABLE "app"."landing_config" TO "anon";
GRANT SELECT ON TABLE "app"."landing_config" TO "authenticated";
GRANT ALL ON TABLE "app"."landing_config" TO "service_role";



GRANT SELECT ON TABLE "app"."landing_partners" TO "anon";
GRANT SELECT ON TABLE "app"."landing_partners" TO "authenticated";
GRANT ALL ON TABLE "app"."landing_partners" TO "service_role";



GRANT SELECT ON TABLE "app"."landing_videos" TO "anon";
GRANT SELECT ON TABLE "app"."landing_videos" TO "authenticated";
GRANT ALL ON TABLE "app"."landing_videos" TO "service_role";



GRANT SELECT ON TABLE "app"."landing_why_cards" TO "anon";
GRANT SELECT ON TABLE "app"."landing_why_cards" TO "authenticated";
GRANT ALL ON TABLE "app"."landing_why_cards" TO "service_role";



GRANT SELECT ON TABLE "app"."legacy_video_write_attempts" TO "authenticated";
GRANT ALL ON TABLE "app"."legacy_video_write_attempts" TO "service_role";



GRANT SELECT ON TABLE "app"."marketplace_merchants" TO "anon";
GRANT SELECT ON TABLE "app"."marketplace_merchants" TO "authenticated";
GRANT ALL ON TABLE "app"."marketplace_merchants" TO "service_role";



GRANT SELECT,INSERT ON TABLE "app"."marketplace_order_items" TO "authenticated";
GRANT ALL ON TABLE "app"."marketplace_order_items" TO "service_role";



GRANT SELECT,INSERT,UPDATE ON TABLE "app"."marketplace_orders" TO "authenticated";
GRANT ALL ON TABLE "app"."marketplace_orders" TO "service_role";



GRANT SELECT ON TABLE "app"."marketplace_products" TO "anon";
GRANT SELECT ON TABLE "app"."marketplace_products" TO "authenticated";
GRANT ALL ON TABLE "app"."marketplace_products" TO "service_role";



GRANT SELECT,INSERT,UPDATE ON TABLE "app"."merchant_profiles" TO "authenticated";
GRANT ALL ON TABLE "app"."merchant_profiles" TO "service_role";



GRANT SELECT,INSERT,UPDATE ON TABLE "app"."moderation_events" TO "authenticated";
GRANT ALL ON TABLE "app"."moderation_events" TO "service_role";



GRANT SELECT,INSERT,UPDATE ON TABLE "app"."notification_events" TO "service_role";



GRANT SELECT ON TABLE "app"."official_announcements" TO "anon";
GRANT SELECT ON TABLE "app"."official_announcements" TO "authenticated";
GRANT ALL ON TABLE "app"."official_announcements" TO "service_role";



GRANT SELECT ON TABLE "app"."online_course_certificates" TO "authenticated";
GRANT ALL ON TABLE "app"."online_course_certificates" TO "service_role";



GRANT SELECT,INSERT ON TABLE "app"."online_course_enrollment_messages" TO "authenticated";
GRANT ALL ON TABLE "app"."online_course_enrollment_messages" TO "service_role";



GRANT SELECT,INSERT ON TABLE "app"."online_course_enrollments" TO "authenticated";
GRANT ALL ON TABLE "app"."online_course_enrollments" TO "service_role";



GRANT SELECT,INSERT ON TABLE "app"."online_course_forum_messages" TO "authenticated";
GRANT ALL ON TABLE "app"."online_course_forum_messages" TO "service_role";



GRANT SELECT,INSERT ON TABLE "app"."online_course_forum_threads" TO "authenticated";
GRANT ALL ON TABLE "app"."online_course_forum_threads" TO "service_role";



GRANT SELECT,INSERT,UPDATE ON TABLE "app"."online_course_instructors" TO "authenticated";
GRANT ALL ON TABLE "app"."online_course_instructors" TO "service_role";



GRANT SELECT ON TABLE "app"."online_course_lesson_media" TO "anon";
GRANT SELECT ON TABLE "app"."online_course_lesson_media" TO "authenticated";
GRANT ALL ON TABLE "app"."online_course_lesson_media" TO "service_role";



GRANT SELECT,INSERT,UPDATE ON TABLE "app"."online_course_lesson_progress" TO "authenticated";
GRANT ALL ON TABLE "app"."online_course_lesson_progress" TO "service_role";



GRANT SELECT ON TABLE "app"."online_course_lessons" TO "anon";
GRANT SELECT ON TABLE "app"."online_course_lessons" TO "authenticated";
GRANT ALL ON TABLE "app"."online_course_lessons" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."online_course_live_session_participants" TO "authenticated";
GRANT ALL ON TABLE "app"."online_course_live_session_participants" TO "service_role";



GRANT SELECT ON TABLE "app"."online_course_live_sessions" TO "authenticated";
GRANT ALL ON TABLE "app"."online_course_live_sessions" TO "service_role";



GRANT SELECT ON TABLE "app"."online_course_sections" TO "anon";
GRANT SELECT ON TABLE "app"."online_course_sections" TO "authenticated";
GRANT ALL ON TABLE "app"."online_course_sections" TO "service_role";



GRANT SELECT ON TABLE "app"."online_courses" TO "anon";
GRANT SELECT ON TABLE "app"."online_courses" TO "authenticated";
GRANT ALL ON TABLE "app"."online_courses" TO "service_role";



GRANT SELECT ON TABLE "app"."opportunities" TO "anon";
GRANT SELECT ON TABLE "app"."opportunities" TO "authenticated";
GRANT ALL ON TABLE "app"."opportunities" TO "service_role";



GRANT SELECT,INSERT ON TABLE "app"."opportunity_applications" TO "authenticated";
GRANT ALL ON TABLE "app"."opportunity_applications" TO "service_role";



GRANT SELECT,INSERT,UPDATE ON TABLE "app"."opportunity_inquiries" TO "authenticated";
GRANT ALL ON TABLE "app"."opportunity_inquiries" TO "service_role";



GRANT SELECT,INSERT ON TABLE "app"."opportunity_inquiry_messages" TO "authenticated";
GRANT ALL ON TABLE "app"."opportunity_inquiry_messages" TO "service_role";



GRANT SELECT ON TABLE "app"."opportunity_types" TO "anon";
GRANT SELECT ON TABLE "app"."opportunity_types" TO "authenticated";
GRANT ALL ON TABLE "app"."opportunity_types" TO "service_role";



GRANT SELECT ON TABLE "app"."payment_proofs" TO "authenticated";
GRANT ALL ON TABLE "app"."payment_proofs" TO "service_role";



GRANT SELECT ON TABLE "app"."payment_receipts" TO "authenticated";
GRANT ALL ON TABLE "app"."payment_receipts" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."prep_ai_generations" TO "authenticated";
GRANT ALL ON TABLE "app"."prep_ai_generations" TO "service_role";



GRANT SELECT,INSERT ON TABLE "app"."prep_ai_usage_logs" TO "authenticated";
GRANT ALL ON TABLE "app"."prep_ai_usage_logs" TO "service_role";



GRANT SELECT,INSERT ON TABLE "app"."prep_attempts" TO "authenticated";
GRANT ALL ON TABLE "app"."prep_attempts" TO "service_role";



GRANT SELECT ON TABLE "app"."prep_chapters" TO "anon";
GRANT SELECT ON TABLE "app"."prep_chapters" TO "authenticated";
GRANT ALL ON TABLE "app"."prep_chapters" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."prep_doc_chunks" TO "authenticated";
GRANT ALL ON TABLE "app"."prep_doc_chunks" TO "service_role";



GRANT SELECT ON TABLE "app"."prep_exam_items" TO "anon";
GRANT SELECT ON TABLE "app"."prep_exam_items" TO "authenticated";
GRANT ALL ON TABLE "app"."prep_exam_items" TO "service_role";



GRANT SELECT ON TABLE "app"."prep_exams" TO "anon";
GRANT SELECT ON TABLE "app"."prep_exams" TO "authenticated";
GRANT ALL ON TABLE "app"."prep_exams" TO "service_role";



GRANT SELECT ON TABLE "app"."prep_question_choices" TO "anon";
GRANT SELECT ON TABLE "app"."prep_question_choices" TO "authenticated";
GRANT ALL ON TABLE "app"."prep_question_choices" TO "service_role";



GRANT SELECT ON TABLE "app"."prep_questions" TO "anon";
GRANT SELECT ON TABLE "app"."prep_questions" TO "authenticated";
GRANT ALL ON TABLE "app"."prep_questions" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."prep_source_documents" TO "authenticated";
GRANT ALL ON TABLE "app"."prep_source_documents" TO "service_role";



GRANT SELECT ON TABLE "app"."prep_subjects" TO "anon";
GRANT SELECT ON TABLE "app"."prep_subjects" TO "authenticated";
GRANT ALL ON TABLE "app"."prep_subjects" TO "service_role";



GRANT SELECT ON TABLE "app"."programs" TO "anon";
GRANT SELECT ON TABLE "app"."programs" TO "authenticated";
GRANT ALL ON TABLE "app"."programs" TO "service_role";



GRANT SELECT ON TABLE "app"."referral_commissions" TO "authenticated";
GRANT ALL ON TABLE "app"."referral_commissions" TO "service_role";



GRANT SELECT,INSERT ON TABLE "app"."short_training_registration_messages" TO "authenticated";
GRANT ALL ON TABLE "app"."short_training_registration_messages" TO "service_role";



GRANT SELECT,INSERT ON TABLE "app"."short_training_registrations" TO "authenticated";
GRANT ALL ON TABLE "app"."short_training_registrations" TO "service_role";



GRANT SELECT ON TABLE "app"."short_training_sessions" TO "authenticated";
GRANT ALL ON TABLE "app"."short_training_sessions" TO "service_role";



GRANT SELECT ON TABLE "app"."short_trainings" TO "authenticated";
GRANT ALL ON TABLE "app"."short_trainings" TO "service_role";



GRANT SELECT,INSERT,UPDATE ON TABLE "app"."student_dossier_documents" TO "authenticated";
GRANT ALL ON TABLE "app"."student_dossier_documents" TO "service_role";



GRANT SELECT ON TABLE "app"."student_home_announcements" TO "anon";
GRANT SELECT ON TABLE "app"."student_home_announcements" TO "authenticated";
GRANT ALL ON TABLE "app"."student_home_announcements" TO "service_role";



GRANT ALL ON TABLE "app"."student_home_slots" TO "service_role";
GRANT SELECT ON TABLE "app"."student_home_slots" TO "authenticated";



GRANT SELECT ON TABLE "app"."student_home_videos" TO "anon";
GRANT SELECT ON TABLE "app"."student_home_videos" TO "authenticated";
GRANT ALL ON TABLE "app"."student_home_videos" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."students" TO "authenticated";
GRANT ALL ON TABLE "app"."students" TO "service_role";



GRANT SELECT,INSERT,UPDATE ON TABLE "app"."support_conversations" TO "authenticated";
GRANT ALL ON TABLE "app"."support_conversations" TO "service_role";



GRANT SELECT,INSERT ON TABLE "app"."support_messages" TO "authenticated";
GRANT ALL ON TABLE "app"."support_messages" TO "service_role";



GRANT SELECT,INSERT,UPDATE ON TABLE "app"."support_read_states" TO "authenticated";
GRANT ALL ON TABLE "app"."support_read_states" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."td_attendance" TO "authenticated";
GRANT ALL ON TABLE "app"."td_attendance" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."td_collections" TO "authenticated";
GRANT ALL ON TABLE "app"."td_collections" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."td_daily_goals" TO "service_role";
GRANT SELECT ON TABLE "app"."td_daily_goals" TO "anon";
GRANT SELECT ON TABLE "app"."td_daily_goals" TO "authenticated";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."td_discipline_colors" TO "service_role";
GRANT SELECT ON TABLE "app"."td_discipline_colors" TO "anon";
GRANT SELECT ON TABLE "app"."td_discipline_colors" TO "authenticated";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."td_enrollments" TO "authenticated";
GRANT ALL ON TABLE "app"."td_enrollments" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."td_fields" TO "authenticated";
GRANT ALL ON TABLE "app"."td_fields" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."td_leaderboard_cache" TO "service_role";
GRANT SELECT ON TABLE "app"."td_leaderboard_cache" TO "anon";
GRANT SELECT ON TABLE "app"."td_leaderboard_cache" TO "authenticated";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."td_messages" TO "authenticated";
GRANT ALL ON TABLE "app"."td_messages" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."td_programs" TO "authenticated";
GRANT ALL ON TABLE "app"."td_programs" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."td_resource_progress" TO "service_role";
GRANT SELECT ON TABLE "app"."td_resource_progress" TO "anon";
GRANT SELECT ON TABLE "app"."td_resource_progress" TO "authenticated";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."td_resources" TO "authenticated";
GRANT ALL ON TABLE "app"."td_resources" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."td_session_occurrences" TO "authenticated";
GRANT ALL ON TABLE "app"."td_session_occurrences" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."td_sessions" TO "authenticated";
GRANT ALL ON TABLE "app"."td_sessions" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."td_streaks" TO "service_role";
GRANT SELECT ON TABLE "app"."td_streaks" TO "anon";
GRANT SELECT ON TABLE "app"."td_streaks" TO "authenticated";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."td_student_requests" TO "authenticated";
GRANT ALL ON TABLE "app"."td_student_requests" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."td_teacher_availability" TO "authenticated";
GRANT ALL ON TABLE "app"."td_teacher_availability" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."td_teachers" TO "authenticated";
GRANT ALL ON TABLE "app"."td_teachers" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."td_xp_log" TO "service_role";
GRANT SELECT ON TABLE "app"."td_xp_log" TO "anon";
GRANT SELECT ON TABLE "app"."td_xp_log" TO "authenticated";



GRANT SELECT ON TABLE "app"."universities" TO "anon";
GRANT SELECT ON TABLE "app"."universities" TO "authenticated";
GRANT ALL ON TABLE "app"."universities" TO "service_role";



GRANT SELECT ON TABLE "app"."university_events" TO "anon";
GRANT SELECT ON TABLE "app"."university_events" TO "authenticated";
GRANT ALL ON TABLE "app"."university_events" TO "service_role";



GRANT SELECT ON TABLE "app"."university_media" TO "anon";
GRANT SELECT ON TABLE "app"."university_media" TO "authenticated";
GRANT ALL ON TABLE "app"."university_media" TO "service_role";



GRANT SELECT ON TABLE "app"."university_news" TO "anon";
GRANT SELECT ON TABLE "app"."university_news" TO "authenticated";
GRANT ALL ON TABLE "app"."university_news" TO "service_role";



GRANT SELECT ON TABLE "app"."university_site_banners" TO "anon";
GRANT SELECT ON TABLE "app"."university_site_banners" TO "authenticated";
GRANT ALL ON TABLE "app"."university_site_banners" TO "service_role";



GRANT SELECT ON TABLE "app"."university_site_blocks" TO "anon";
GRANT SELECT ON TABLE "app"."university_site_blocks" TO "authenticated";
GRANT ALL ON TABLE "app"."university_site_blocks" TO "service_role";



GRANT SELECT ON TABLE "app"."university_site_config" TO "anon";
GRANT SELECT ON TABLE "app"."university_site_config" TO "authenticated";
GRANT ALL ON TABLE "app"."university_site_config" TO "service_role";



GRANT SELECT ON TABLE "app"."university_staff" TO "anon";
GRANT SELECT ON TABLE "app"."university_staff" TO "authenticated";
GRANT ALL ON TABLE "app"."university_staff" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."user_admin_status" TO "authenticated";
GRANT ALL ON TABLE "app"."user_admin_status" TO "service_role";



GRANT SELECT,INSERT,UPDATE ON TABLE "app"."user_announcement_reads" TO "authenticated";
GRANT ALL ON TABLE "app"."user_announcement_reads" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."user_device_tokens" TO "authenticated";
GRANT ALL ON TABLE "app"."user_device_tokens" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."user_event_follows" TO "authenticated";
GRANT ALL ON TABLE "app"."user_event_follows" TO "service_role";



GRANT SELECT ON TABLE "app"."user_feature_entitlements" TO "authenticated";
GRANT ALL ON TABLE "app"."user_feature_entitlements" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."user_invitations" TO "authenticated";
GRANT ALL ON TABLE "app"."user_invitations" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."user_notification_state" TO "authenticated";
GRANT ALL ON TABLE "app"."user_notification_state" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "app"."user_presence" TO "service_role";
GRANT SELECT ON TABLE "app"."user_presence" TO "authenticated";



GRANT SELECT ON TABLE "app"."user_referrals" TO "authenticated";
GRANT ALL ON TABLE "app"."user_referrals" TO "service_role";



GRANT SELECT ON TABLE "app"."video_asset_contexts" TO "authenticated";
GRANT ALL ON TABLE "app"."video_asset_contexts" TO "service_role";



GRANT ALL ON TABLE "app"."video_asset_legacy_map" TO "service_role";



GRANT SELECT,INSERT,UPDATE ON TABLE "app"."video_assets" TO "authenticated";
GRANT SELECT ON TABLE "app"."video_assets" TO "anon";
GRANT ALL ON TABLE "app"."video_assets" TO "service_role";



GRANT SELECT,INSERT ON TABLE "app"."video_moderation_history" TO "service_role";



GRANT SELECT ON TABLE "app"."video_playback_errors" TO "authenticated";
GRANT ALL ON TABLE "app"."video_playback_errors" TO "service_role";



GRANT ALL ON TABLE "app"."video_processing_jobs" TO "service_role";



GRANT SELECT ON TABLE "app"."video_renditions" TO "anon";
GRANT SELECT ON TABLE "app"."video_renditions" TO "authenticated";
GRANT ALL ON TABLE "app"."video_renditions" TO "service_role";



GRANT SELECT,INSERT ON TABLE "app"."video_sources" TO "authenticated";
GRANT ALL ON TABLE "app"."video_sources" TO "service_role";



GRANT SELECT,INSERT ON TABLE "app"."video_upload_events" TO "service_role";




