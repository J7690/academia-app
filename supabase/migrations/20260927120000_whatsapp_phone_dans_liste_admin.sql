-- Migration du 27/09/2026
-- Ajoute le numero WhatsApp de l'etudiant dans la reponse de
-- app_list_admin_applications, pour que l'ecran administrateur puisse
-- ouvrir une conversation WhatsApp directe via un lien wa.me.
--
-- Modifications (le reste est identique a la definition de production
-- relevee le 28/09, elle-meme identique a 20260921200000) :
--   1. ajout de 'student_phone' et 'student_whatsapp_phone' ;
--   2. le role admin est lu dans raw_app_meta_data (protege) et non plus
--      dans raw_user_meta_data, que l'utilisateur peut modifier lui-meme.
--      Exposer des numeros de telephone derriere un controle falsifiable
--      aurait permis a un etudiant de lister ceux de tous les candidats.
--      Mesure avant application : 7 comptes admin, 7 avec
--      raw_app_meta_data.role = 'admin' -> aucun admin ne perd l'acces.

CREATE OR REPLACE FUNCTION public.app_list_admin_applications()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT raw_app_meta_data->>'role'
    INTO v_role
    FROM auth.users
    WHERE id = v_user_id;

    IF v_role IS DISTINCT FROM 'admin' THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', a.id,
                'status', a.status,
                'motivation_text', a.motivation_text,
                'submitted_at', a.submitted_at,
                'created_at', a.created_at,
                'updated_at', a.updated_at,
                'last_message_at', a.last_message_at,
                'last_student_read_at', a.last_student_read_at,
                'last_admin_read_at', a.last_admin_read_at,
                'last_university_read_at', a.last_university_read_at,
                'requested_degree_level', a.requested_degree_level,
                'requested_study_mode', a.requested_study_mode,
                'requested_schedule', a.requested_schedule,
                'discount_requested', a.discount_requested,
                'discount_details', a.discount_details,
                'discount_rate', a.discount_rate,
                'discount_validated_at', a.discount_validated_at,
                'payment_deadline_at', a.payment_deadline_at,
                'student_comment', a.student_comment,
                'sent_to_university', a.sent_to_university,
                'sent_to_university_at', a.sent_to_university_at,
                'admin_seen_at', a.admin_seen_at,
                'has_unseen_for_admin',
                    CASE
                        WHEN a.admin_seen_at IS NULL THEN TRUE
                        ELSE FALSE
                    END,
                'student_id', s.id,
                'student_full_name', s.full_name,
                'student_phone', s.phone,
                'student_whatsapp_phone', s.whatsapp_phone,
                'program_id', p.id,
                'program_title', p.title,
                'degree_level', p.degree_level,
                'university_id', u.id,
                'university_name', u.name,
                'last_activity_at', GREATEST(a.updated_at, COALESCE(a.last_message_at, a.updated_at)),
                'has_unread_for_admin',
                    CASE
                        WHEN a.last_message_at IS NULL THEN FALSE
                        WHEN a.last_admin_read_at IS NULL THEN TRUE
                        ELSE a.last_message_at > a.last_admin_read_at
                    END
            )
            ORDER BY GREATEST(a.updated_at, COALESCE(a.last_message_at, a.updated_at)) DESC
        ),
        '[]'::JSONB
    )
    INTO v_result
    FROM app.applications a
    JOIN app.students s ON s.id = a.student_id
    JOIN app.programs p ON p.id = a.program_id
    JOIN app.universities u ON u.id = p.university_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'applications', v_result
    );
END;
$function$;
