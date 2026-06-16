-- ================================================================
-- SYSTÈME D'APPRENTISSAGE ADAPTATIF - Prépa Concours
-- ================================================================
-- Ce système permet de:
-- 1. Détecter automatiquement les faiblesses par matière
-- 2. Générer des quiz adaptatifs ciblant les points faibles
-- 3. Suivre la progression et faire des recommandations
-- ================================================================

-- ────────────────────────────────────────────────────────────────
-- 1. TABLE DE SUIVI DES FAIBLESSES
-- ────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS app.prep_student_weaknesses (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    subject_id uuid NOT NULL REFERENCES app.prep_subjects(id) ON DELETE CASCADE,
    
    -- Métriques de performance
    total_questions integer DEFAULT 0,
    correct_answers integer DEFAULT 0,
    incorrect_answers integer DEFAULT 0,
    success_rate decimal(5,2) DEFAULT 0.00,  -- % de réussite
    
    -- Analyse des difficultés
    avg_difficulty_attempted decimal(3,2) DEFAULT 2.50,
    avg_difficulty_failed decimal(3,2) DEFAULT 2.50,
    weakness_score decimal(5,2) DEFAULT 50.00,  -- 0=fort, 100=faible
    
    -- Recommandations
    recommended_difficulty integer DEFAULT 2,
    priority_weight decimal(3,2) DEFAULT 1.00,  -- 1.0 à 3.0
    needs_practice boolean DEFAULT false,
    
    -- Timestamps
    updated_at timestamptz DEFAULT now(),
    created_at timestamptz DEFAULT now(),
    
    -- Contrainte d'unicité
    UNIQUE(student_id, subject_id)
);

-- Index pour performance
CREATE INDEX IF NOT EXISTS idx_weaknesses_student_subject 
ON app.prep_student_weaknesses(student_id, subject_id);

CREATE INDEX IF NOT EXISTS idx_weaknesses_priority 
ON app.prep_student_weaknesses(needs_practice, priority_weight DESC);

-- RLS Policy
ALTER TABLE app.prep_student_weaknesses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Students can view own weaknesses" ON app.prep_student_weaknesses
    FOR ALL USING (auth.uid() = student_id);

-- ────────────────────────────────────────────────────────────────
-- 2. FONCTION DE MISE À JOUR DES FAIBLESSES
-- ────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION app.update_student_weaknesses_from_attempt()
RETURNS trigger AS $$
DECLARE
    v_question_data jsonb;
    v_answer_data jsonb;
    v_is_correct boolean;
    v_subject_id uuid;
    v_difficulty integer;
    i integer;
BEGIN
    -- Parcourir chaque question/réponse du quiz
    FOR i IN 0..jsonb_array_length(NEW.questions_json)-1 LOOP
        v_question_data := NEW.questions_json->i;
        v_answer_data := NEW.answers_json->i;
        
        -- Extraire les données
        v_is_correct := COALESCE((v_answer_data->>'is_correct')::boolean, false);
        v_subject_id := (v_question_data->>'subject_id')::uuid;
        v_difficulty := COALESCE((v_question_data->>'difficulty')::integer, 3);
        
        -- Skip si pas de subject_id
        CONTINUE WHEN v_subject_id IS NULL;
        
        -- Insérer ou mettre à jour les statistiques
        INSERT INTO app.prep_student_weaknesses (
            student_id, 
            subject_id, 
            total_questions,
            correct_answers, 
            incorrect_answers,
            avg_difficulty_attempted
        ) VALUES (
            NEW.student_id, 
            v_subject_id,
            1,
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
            -- Moyenne pondérée de la difficulté
            avg_difficulty_attempted = (
                (prep_student_weaknesses.avg_difficulty_attempted * prep_student_weaknesses.total_questions + v_difficulty) 
                / (prep_student_weaknesses.total_questions + 1)
            ),
            -- Moyenne de la difficulté des échecs
            avg_difficulty_failed = CASE 
                WHEN NOT v_is_correct THEN
                    CASE 
                        WHEN prep_student_weaknesses.incorrect_answers = 0 THEN v_difficulty::decimal
                        ELSE (
                            (prep_student_weaknesses.avg_difficulty_failed * prep_student_weaknesses.incorrect_answers + v_difficulty) 
                            / (prep_student_weaknesses.incorrect_answers + 1)
                        )
                    END
                ELSE prep_student_weaknesses.avg_difficulty_failed
            END,
            updated_at = now();
    END LOOP;
    
    -- Recalculer les métriques dérivées pour cet étudiant
    UPDATE app.prep_student_weaknesses
    SET 
        success_rate = CASE 
            WHEN total_questions > 0 THEN (correct_answers::decimal / total_questions * 100)
            ELSE 0 
        END,
        weakness_score = GREATEST(0, LEAST(100, 
            CASE 
                WHEN total_questions = 0 THEN 50
                ELSE 100 - (correct_answers::decimal / total_questions * 100) + 
                     (avg_difficulty_failed * 10) - 15
            END
        )),
        priority_weight = CASE 
            WHEN (correct_answers::decimal / NULLIF(total_questions, 0) * 100) < 40 OR total_questions < 5 THEN 3.0
            WHEN (correct_answers::decimal / NULLIF(total_questions, 0) * 100) < 60 THEN 2.0
            WHEN (correct_answers::decimal / NULLIF(total_questions, 0) * 100) < 80 THEN 1.5
            ELSE 1.0
        END,
        needs_practice = CASE
            WHEN total_questions < 5 THEN true  -- Pas assez de données
            WHEN (correct_answers::decimal / total_questions * 100) < 70 THEN true
            ELSE false
        END,
        recommended_difficulty = CASE
            WHEN (correct_answers::decimal / NULLIF(total_questions, 0) * 100) < 40 THEN 
                GREATEST(1, LEAST(2, FLOOR(avg_difficulty_attempted)::integer))
            WHEN (correct_answers::decimal / NULLIF(total_questions, 0) * 100) < 60 THEN 
                GREATEST(1, LEAST(3, CEIL(avg_difficulty_attempted)::integer))
            WHEN (correct_answers::decimal / NULLIF(total_questions, 0) * 100) < 80 THEN 
                GREATEST(2, LEAST(4, CEIL(avg_difficulty_attempted)::integer))
            ELSE 
                LEAST(5, CEIL(avg_difficulty_attempted)::integer + 1)
        END
    WHERE student_id = NEW.student_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Créer le trigger
DROP TRIGGER IF EXISTS trg_update_student_weaknesses ON app.prep_quiz_attempts;

CREATE TRIGGER trg_update_student_weaknesses
    AFTER INSERT OR UPDATE ON app.prep_quiz_attempts
    FOR EACH ROW
    EXECUTE FUNCTION app.update_student_weaknesses_from_attempt();

-- ────────────────────────────────────────────────────────────────
-- 3. RPC POUR QUIZ ADAPTATIF
-- ────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION app.app_prep_get_adaptive_quiz(
    p_count integer DEFAULT 10,
    p_concours_type text DEFAULT NULL
)
RETURNS jsonb 
SECURITY DEFINER
SET search_path = app, public
AS $$
DECLARE
    v_student_id uuid;
    v_questions jsonb := '[]'::jsonb;
    v_weakness_questions integer;
    v_regular_questions integer;
    v_has_weaknesses boolean;
BEGIN
    -- Récupérer l'ID de l'étudiant
    v_student_id := auth.uid();
    
    IF v_student_id IS NULL THEN
        RAISE EXCEPTION 'Non authentifié';
    END IF;
    
    -- Vérifier si l'étudiant a des faiblesses identifiées
    SELECT EXISTS(
        SELECT 1 FROM app.prep_student_weaknesses 
        WHERE student_id = v_student_id AND needs_practice = true
    ) INTO v_has_weaknesses;
    
    IF v_has_weaknesses THEN
        -- Mode adaptatif: 70% faiblesses, 30% général
        v_weakness_questions := GREATEST(1, CEIL(p_count * 0.7));
        v_regular_questions := p_count - v_weakness_questions;
    ELSE
        -- Mode découverte: 100% questions générales
        v_weakness_questions := 0;
        v_regular_questions := p_count;
    END IF;
    
    -- 1. Sélectionner questions des matières faibles (si applicable)
    IF v_weakness_questions > 0 THEN
        WITH weak_subjects AS (
            SELECT subject_id, priority_weight, recommended_difficulty
            FROM app.prep_student_weaknesses
            WHERE student_id = v_student_id
              AND needs_practice = true
            ORDER BY priority_weight DESC, weakness_score DESC
            LIMIT 5
        ),
        weakness_pool AS (
            SELECT DISTINCT ON (q.id)
                q.id, 
                q.question, 
                jsonb_build_array(
                    q.choice_a, q.choice_b, q.choice_c, q.choice_d
                ) AS options,
                q.correct_answer - 1 AS correct_index,  -- Convertir 1-4 en 0-3
                q.explanation, 
                q.difficulty, 
                s.title AS subject,
                q.subject_id,
                w.priority_weight,
                -- Favoriser les questions du niveau approprié
                CASE 
                    WHEN q.difficulty = w.recommended_difficulty THEN 3
                    WHEN ABS(q.difficulty - w.recommended_difficulty) = 1 THEN 2
                    ELSE 1
                END AS difficulty_match,
                RANDOM() AS rand
            FROM app.prep_questions q
            JOIN app.prep_subjects s ON s.id = q.subject_id
            JOIN weak_subjects w ON w.subject_id = q.subject_id
            WHERE q.is_published = true
              AND (p_concours_type IS NULL OR q.concours_type = p_concours_type)
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
                'subject_id', subject_id,
                'is_weakness_targeted', true
            )
            ORDER BY priority_weight DESC, difficulty_match DESC, rand
        ) INTO v_questions
        FROM (
            SELECT * FROM weakness_pool
            LIMIT v_weakness_questions
        ) t;
    END IF;
    
    -- 2. Compléter avec des questions générales
    IF v_regular_questions > 0 THEN
        WITH excluded_ids AS (
            SELECT (value->>'id')::uuid AS id 
            FROM jsonb_array_elements(COALESCE(v_questions, '[]'::jsonb))
        ),
        regular_pool AS (
            SELECT 
                q.id, 
                q.question, 
                jsonb_build_array(
                    q.choice_a, q.choice_b, q.choice_c, q.choice_d
                ) AS options,
                q.correct_answer - 1 AS correct_index,
                q.explanation, 
                q.difficulty, 
                s.title AS subject,
                q.subject_id
            FROM app.prep_questions q
            JOIN app.prep_subjects s ON s.id = q.subject_id
            WHERE q.is_published = true
              AND (p_concours_type IS NULL OR q.concours_type = p_concours_type)
              AND q.id NOT IN (SELECT id FROM excluded_ids)
            ORDER BY RANDOM()
            LIMIT v_regular_questions
        )
        SELECT COALESCE(v_questions, '[]'::jsonb) || jsonb_agg(
            jsonb_build_object(
                'id', id,
                'question', question,
                'options', options,
                'correct_index', correct_index,
                'explanation', explanation,
                'difficulty', difficulty,
                'subject', subject,
                'subject_id', subject_id,
                'is_weakness_targeted', false
            )
        ) INTO v_questions
        FROM regular_pool;
    END IF;
    
    -- Mélanger les questions
    WITH shuffled AS (
        SELECT value FROM jsonb_array_elements(COALESCE(v_questions, '[]'::jsonb)) AS value
        ORDER BY RANDOM()
    )
    SELECT jsonb_agg(value) INTO v_questions FROM shuffled;
    
    -- Retourner avec métadonnées
    RETURN jsonb_build_object(
        'adaptive_mode', v_has_weaknesses,
        'weakness_ratio', CASE 
            WHEN p_count > 0 THEN v_weakness_questions::decimal / p_count 
            ELSE 0 
        END,
        'total_questions', jsonb_array_length(COALESCE(v_questions, '[]'::jsonb)),
        'questions', COALESCE(v_questions, '[]'::jsonb)
    );
END;
$$ LANGUAGE plpgsql;

-- ────────────────────────────────────────────────────────────────
-- 4. RPC POUR ANALYSE DES FAIBLESSES
-- ────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION app.app_prep_get_weakness_analysis()
RETURNS jsonb 
SECURITY DEFINER
SET search_path = app, public
AS $$
DECLARE
    v_student_id uuid;
    v_result jsonb;
BEGIN
    v_student_id := auth.uid();
    
    IF v_student_id IS NULL THEN
        RAISE EXCEPTION 'Non authentifié';
    END IF;
    
    SELECT jsonb_build_object(
        'weakest_subjects', (
            SELECT COALESCE(jsonb_agg(
                jsonb_build_object(
                    'subject_id', w.subject_id,
                    'subject_name', s.title,
                    'success_rate', ROUND(w.success_rate, 1),
                    'total_questions', w.total_questions,
                    'correct_answers', w.correct_answers,
                    'incorrect_answers', w.incorrect_answers,
                    'weakness_score', ROUND(w.weakness_score, 1),
                    'needs_practice', w.needs_practice,
                    'recommended_difficulty', w.recommended_difficulty,
                    'priority', CASE
                        WHEN w.priority_weight >= 3 THEN 'high'
                        WHEN w.priority_weight >= 2 THEN 'medium'
                        ELSE 'low'
                    END
                ) ORDER BY w.weakness_score DESC
            ), '[]'::jsonb)
            FROM app.prep_student_weaknesses w
            JOIN app.prep_subjects s ON s.id = w.subject_id
            WHERE w.student_id = v_student_id
              AND w.needs_practice = true
            LIMIT 5
        ),
        'progress_summary', (
            SELECT jsonb_build_object(
                'total_subjects_practiced', COUNT(DISTINCT subject_id),
                'subjects_needing_practice', COUNT(*) FILTER (WHERE needs_practice),
                'overall_success_rate', ROUND(AVG(success_rate), 1),
                'total_questions_answered', SUM(total_questions),
                'total_correct_answers', SUM(correct_answers)
            )
            FROM app.prep_student_weaknesses
            WHERE student_id = v_student_id
        ),
        'recommendations', (
            SELECT COALESCE(jsonb_agg(
                jsonb_build_object(
                    'subject', s.title,
                    'subject_id', w.subject_id,
                    'message', CASE
                        WHEN w.success_rate < 40 OR w.total_questions < 5 THEN 
                            'Besoin urgent de révision. Commencez par les concepts de base et les questions faciles.'
                        WHEN w.success_rate < 60 THEN 
                            'Progrès nécessaire. Pratiquez régulièrement avec des questions de niveau moyen.'
                        WHEN w.success_rate < 80 THEN 
                            'Bon progrès! Essayez des questions plus difficiles pour vous perfectionner.'
                        ELSE 
                            'Excellent niveau! Maintenez votre pratique et explorez des sujets avancés.'
                    END,
                    'suggested_difficulty', w.recommended_difficulty,
                    'suggested_practice_count', CASE
                        WHEN w.total_questions < 10 THEN 20
                        WHEN w.success_rate < 50 THEN 15
                        WHEN w.success_rate < 70 THEN 10
                        ELSE 5
                    END,
                    'practice_priority', CASE
                        WHEN w.priority_weight >= 3 THEN 'Haute'
                        WHEN w.priority_weight >= 2 THEN 'Moyenne'
                        ELSE 'Faible'
                    END
                ) ORDER BY w.priority_weight DESC, w.weakness_score DESC
            ), '[]'::jsonb)
            FROM app.prep_student_weaknesses w
            JOIN app.prep_subjects s ON s.id = w.subject_id
            WHERE w.student_id = v_student_id
            LIMIT 3
        ),
        'recent_performance', (
            SELECT jsonb_build_object(
                'last_7_days', (
                    SELECT COALESCE(jsonb_agg(
                        jsonb_build_object(
                            'date', DATE(created_at),
                            'score', score,
                            'total_questions', total_questions
                        ) ORDER BY created_at DESC
                    ), '[]'::jsonb)
                    FROM app.prep_quiz_attempts
                    WHERE student_id = v_student_id
                      AND created_at >= CURRENT_DATE - INTERVAL '7 days'
                    LIMIT 10
                ),
                'average_score_trend', (
                    SELECT ROUND(AVG(score), 1)
                    FROM app.prep_quiz_attempts
                    WHERE student_id = v_student_id
                      AND created_at >= CURRENT_DATE - INTERVAL '7 days'
                )
            )
        )
    ) INTO v_result;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ────────────────────────────────────────────────────────────────
-- 5. MIGRATION DES DONNÉES EXISTANTES
-- ────────────────────────────────────────────────────────────────

-- Initialiser les weaknesses basées sur les quiz attempts existants
INSERT INTO app.prep_student_weaknesses (student_id, subject_id, total_questions, correct_answers, incorrect_answers)
SELECT 
    qa.student_id,
    (q_data.value->>'subject_id')::uuid AS subject_id,
    COUNT(*) AS total_questions,
    SUM(CASE WHEN (a_data.value->>'is_correct')::boolean THEN 1 ELSE 0 END) AS correct_answers,
    SUM(CASE WHEN NOT (a_data.value->>'is_correct')::boolean THEN 1 ELSE 0 END) AS incorrect_answers
FROM app.prep_quiz_attempts qa
CROSS JOIN LATERAL jsonb_array_elements(qa.questions_json) WITH ORDINALITY q_data(value, idx)
CROSS JOIN LATERAL jsonb_array_elements(qa.answers_json) WITH ORDINALITY a_data(value, idx2)
WHERE q_data.idx = a_data.idx2
  AND (q_data.value->>'subject_id') IS NOT NULL
GROUP BY qa.student_id, (q_data.value->>'subject_id')::uuid
ON CONFLICT (student_id, subject_id) DO NOTHING;

-- Recalculer toutes les métriques
UPDATE app.prep_student_weaknesses
SET 
    success_rate = CASE 
        WHEN total_questions > 0 THEN (correct_answers::decimal / total_questions * 100)
        ELSE 0 
    END,
    weakness_score = GREATEST(0, LEAST(100, 
        100 - CASE 
            WHEN total_questions > 0 THEN (correct_answers::decimal / total_questions * 100)
            ELSE 50
        END
    )),
    priority_weight = CASE 
        WHEN total_questions = 0 OR (correct_answers::decimal / total_questions * 100) < 40 THEN 3.0
        WHEN (correct_answers::decimal / total_questions * 100) < 60 THEN 2.0
        WHEN (correct_answers::decimal / total_questions * 100) < 80 THEN 1.5
        ELSE 1.0
    END,
    needs_practice = CASE
        WHEN total_questions < 5 THEN true
        WHEN total_questions > 0 AND (correct_answers::decimal / total_questions * 100) < 70 THEN true
        ELSE false
    END,
    recommended_difficulty = 3;  -- Par défaut moyen

-- ────────────────────────────────────────────────────────────────
-- 6. PERMISSIONS ET COMMENTAIRES
-- ────────────────────────────────────────────────────────────────

-- Ajouter les permissions pour les nouvelles RPCs
GRANT EXECUTE ON FUNCTION app.app_prep_get_adaptive_quiz TO authenticated;
GRANT EXECUTE ON FUNCTION app.app_prep_get_weakness_analysis TO authenticated;

-- Commentaires
COMMENT ON TABLE app.prep_student_weaknesses IS 'Suivi des faiblesses par matière pour apprentissage adaptatif';
COMMENT ON FUNCTION app.app_prep_get_adaptive_quiz IS 'Génère un quiz adaptatif ciblant les faiblesses de l''étudiant';
COMMENT ON FUNCTION app.app_prep_get_weakness_analysis IS 'Analyse détaillée des faiblesses et recommandations personnalisées';

-- ================================================================
-- FIN DE LA MIGRATION - SYSTÈME ADAPTATIF OPÉRATIONNEL
-- ================================================================
