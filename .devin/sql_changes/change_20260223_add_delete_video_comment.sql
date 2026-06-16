-- ============================================================
-- RPC: app_student_delete_video_comment
-- Allows a student to delete their own comment on a video.
-- Only the comment owner can delete it.
-- ============================================================

CREATE OR REPLACE FUNCTION public.app_student_delete_video_comment(
  p_comment_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_owner_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Non authentifié');
  END IF;

  -- Check ownership
  SELECT user_id INTO v_owner_id
    FROM video_comments
   WHERE id = p_comment_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Commentaire introuvable');
  END IF;

  IF v_owner_id != v_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Vous ne pouvez supprimer que vos propres commentaires');
  END IF;

  DELETE FROM video_comments WHERE id = p_comment_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_delete_video_comment(UUID) TO authenticated;
