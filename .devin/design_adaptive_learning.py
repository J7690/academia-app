#!/usr/bin/env python3
"""Concevoir et implémenter l'apprentissage adaptatif pour Prépa Concours."""
from __future__ import annotations

def main():
    print("\n🎯 CONCEPTION SYSTÈME ADAPTATIF — Prépa Concours\n")
    
    print("D'après l'audit précédent:")
    print("- ✅ Les structures existent (attempts, progress, stats)")
    print("- ✅ Les RPCs de stats existent")  
    print("- ❌ Sélection aléatoire des questions (pas adaptative)")
    print("- ❌ Pas de tracking des faiblesses par matière")
    print("- ❌ Pas de pondération selon les performances\n")
    
    print("="*60)
    print("ARCHITECTURE PROPOSÉE - APPRENTISSAGE ADAPTATIF")
    print("="*60)
    
    print("\n1. NOUVELLE TABLE: prep_student_weaknesses")
    print("-" * 40)
    print("""
CREATE TABLE app.prep_student_weaknesses (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id uuid NOT NULL REFERENCES auth.users(id),
    subject_id uuid NOT NULL REFERENCES app.prep_subjects(id),
    
    -- Métriques de performance
    total_questions integer DEFAULT 0,
    correct_answers integer DEFAULT 0,
    incorrect_answers integer DEFAULT 0,
    success_rate decimal(5,2) DEFAULT 0,  -- % de réussite
    
    -- Analyse des difficultés
    avg_difficulty_attempted decimal(3,2) DEFAULT 2.5,
    avg_difficulty_failed decimal(3,2) DEFAULT 2.5,
    weakness_score decimal(5,2) DEFAULT 50,  -- 0=fort, 100=faible
    
    -- Recommandations
    recommended_difficulty integer DEFAULT 2,
    priority_weight decimal(3,2) DEFAULT 1.0,  -- 1.0 à 3.0
    needs_practice boolean DEFAULT false,
    
    updated_at timestamptz DEFAULT now(),
    created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_weaknesses_student_subject ON app.prep_student_weaknesses(student_id, subject_id);
CREATE INDEX idx_weaknesses_priority ON app.prep_student_weaknesses(needs_practice, priority_weight DESC);
    """)
    
    print("\n2. TRIGGERS POUR MISE À JOUR AUTOMATIQUE")
    print("-" * 40)
    print("""
-- Trigger après chaque quiz attempt
CREATE OR REPLACE FUNCTION app.update_student_weaknesses()
RETURNS trigger AS $$
DECLARE
    v_question record;
    v_answer jsonb;
    v_is_correct boolean;
BEGIN
    -- Pour chaque question du quiz
    FOR i IN 0..jsonb_array_length(NEW.questions_json)-1 LOOP
        v_question := (NEW.questions_json->i);
        v_answer := (NEW.answers_json->i);
        v_is_correct := (v_answer->>'is_correct')::boolean;
        
        -- Mettre à jour ou créer l'entrée weakness
        INSERT INTO app.prep_student_weaknesses (
            student_id, subject_id, total_questions,
            correct_answers, incorrect_answers
        ) VALUES (
            NEW.student_id, 
            (v_question->>'subject_id')::uuid,
            1,
            CASE WHEN v_is_correct THEN 1 ELSE 0 END,
            CASE WHEN v_is_correct THEN 0 ELSE 1 END
        )
        ON CONFLICT (student_id, subject_id) DO UPDATE SET
            total_questions = prep_student_weaknesses.total_questions + 1,
            correct_answers = prep_student_weaknesses.correct_answers + 
                CASE WHEN v_is_correct THEN 1 ELSE 0 END,
            incorrect_answers = prep_student_weaknesses.incorrect_answers + 
                CASE WHEN v_is_correct THEN 0 ELSE 1 END,
            success_rate = (prep_student_weaknesses.correct_answers + 
                CASE WHEN v_is_correct THEN 1 ELSE 0 END)::decimal / 
                (prep_student_weaknesses.total_questions + 1) * 100,
            updated_at = now();
    END LOOP;
    
    -- Recalculer les scores de faiblesse
    UPDATE app.prep_student_weaknesses
    SET 
        weakness_score = GREATEST(0, LEAST(100, 
            100 - success_rate + (avg_difficulty_failed * 10)
        )),
        priority_weight = CASE 
            WHEN success_rate < 40 THEN 3.0  -- Priorité haute
            WHEN success_rate < 60 THEN 2.0  -- Priorité moyenne
            WHEN success_rate < 80 THEN 1.5  -- Priorité faible
            ELSE 1.0
        END,
        needs_practice = (success_rate < 70)
    WHERE student_id = NEW.student_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
    """)
    
    print("\n3. RPC ADAPTATIVE: app_prep_get_adaptive_quiz")
    print("-" * 40)
    print("""
CREATE OR REPLACE FUNCTION app.app_prep_get_adaptive_quiz(
    p_count integer DEFAULT 10,
    p_concours_type text DEFAULT NULL
)
RETURNS jsonb AS $$
DECLARE
    v_student_id uuid;
    v_questions jsonb := '[]'::jsonb;
    v_weakness_questions integer;
    v_regular_questions integer;
BEGIN
    -- Récupérer l'ID de l'étudiant
    v_student_id := auth.uid();
    
    -- 70% questions sur les faiblesses, 30% général
    v_weakness_questions := CEIL(p_count * 0.7);
    v_regular_questions := p_count - v_weakness_questions;
    
    -- 1. Sélectionner questions des matières faibles
    WITH weak_subjects AS (
        SELECT subject_id, priority_weight
        FROM app.prep_student_weaknesses
        WHERE student_id = v_student_id
          AND needs_practice = true
        ORDER BY priority_weight DESC, weakness_score DESC
        LIMIT 5
    ),
    weakness_pool AS (
        SELECT 
            q.id, q.question, q.options, q.correct_index,
            q.explanation, q.difficulty, q.subject,
            w.priority_weight,
            -- Favoriser les questions du niveau approprié
            CASE 
                WHEN q.difficulty = sw.recommended_difficulty THEN 3
                WHEN ABS(q.difficulty - sw.recommended_difficulty) = 1 THEN 2
                ELSE 1
            END AS difficulty_match,
            RANDOM() AS rand
        FROM app.prep_questions q
        JOIN weak_subjects w ON w.subject_id = q.subject_id
        LEFT JOIN app.prep_student_weaknesses sw 
            ON sw.student_id = v_student_id AND sw.subject_id = q.subject_id
        WHERE q.is_published = true
          AND (p_concours_type IS NULL OR q.concours_type = p_concours_type)
        ORDER BY 
            w.priority_weight DESC,
            difficulty_match DESC,
            rand
        LIMIT v_weakness_questions
    )
    SELECT jsonb_agg(row_to_json(weakness_pool.*)) INTO v_questions
    FROM weakness_pool;
    
    -- 2. Compléter avec des questions générales
    IF jsonb_array_length(COALESCE(v_questions, '[]'::jsonb)) < p_count THEN
        WITH regular_pool AS (
            SELECT 
                q.id, q.question, q.options, q.correct_index,
                q.explanation, q.difficulty, q.subject
            FROM app.prep_questions q
            WHERE q.is_published = true
              AND (p_concours_type IS NULL OR q.concours_type = p_concours_type)
              AND q.id NOT IN (
                  SELECT (value->>'id')::uuid 
                  FROM jsonb_array_elements(v_questions)
              )
            ORDER BY RANDOM()
            LIMIT v_regular_questions
        )
        SELECT v_questions || jsonb_agg(row_to_json(regular_pool.*))
        INTO v_questions
        FROM regular_pool;
    END IF;
    
    -- Retourner avec métadonnées
    RETURN jsonb_build_object(
        'adaptive_mode', true,
        'weakness_ratio', v_weakness_questions::decimal / p_count,
        'questions', COALESCE(v_questions, '[]'::jsonb)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
    """)
    
    print("\n4. DASHBOARD DE PROGRESSION")
    print("-" * 40)
    print("""
CREATE OR REPLACE FUNCTION app.app_prep_get_weakness_analysis()
RETURNS jsonb AS $$
BEGIN
    RETURN jsonb_build_object(
        'weakest_subjects', (
            SELECT jsonb_agg(jsonb_build_object(
                'subject_id', w.subject_id,
                'subject_name', s.title,
                'success_rate', w.success_rate,
                'total_questions', w.total_questions,
                'weakness_score', w.weakness_score,
                'needs_practice', w.needs_practice,
                'recommended_difficulty', w.recommended_difficulty
            ) ORDER BY w.weakness_score DESC)
            FROM app.prep_student_weaknesses w
            JOIN app.prep_subjects s ON s.id = w.subject_id
            WHERE w.student_id = auth.uid()
              AND w.needs_practice = true
            LIMIT 5
        ),
        'progress_summary', (
            SELECT jsonb_build_object(
                'total_subjects_practiced', COUNT(DISTINCT subject_id),
                'subjects_needing_practice', COUNT(*) FILTER (WHERE needs_practice),
                'overall_success_rate', AVG(success_rate),
                'total_questions_answered', SUM(total_questions)
            )
            FROM app.prep_student_weaknesses
            WHERE student_id = auth.uid()
        ),
        'recommendations', (
            SELECT jsonb_agg(jsonb_build_object(
                'subject', s.title,
                'message', CASE
                    WHEN w.success_rate < 40 THEN 
                        'Besoin urgent de révision. Commencez par les questions faciles.'
                    WHEN w.success_rate < 60 THEN 
                        'Continuez à pratiquer régulièrement pour progresser.'
                    WHEN w.success_rate < 80 THEN 
                        'Bon progrès! Essayez des questions plus difficiles.'
                    ELSE 
                        'Excellent! Maintenez ce niveau.'
                END,
                'suggested_difficulty', w.recommended_difficulty,
                'practice_priority', CASE
                    WHEN w.priority_weight >= 3 THEN 'Haute'
                    WHEN w.priority_weight >= 2 THEN 'Moyenne'
                    ELSE 'Faible'
                END
            ) ORDER BY w.priority_weight DESC)
            FROM app.prep_student_weaknesses w
            JOIN app.prep_subjects s ON s.id = w.subject_id
            WHERE w.student_id = auth.uid()
            LIMIT 3
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
    """)
    
    print("\n5. INTÉGRATION AVEC GÉNÉRATION IA")
    print("-" * 40)
    print("""
-- Modification de prep-generate-questions pour tenir compte des faiblesses
-- Dans le body.mode === 'adaptive':

const weaknessData = await supabase.rpc('app_prep_get_weakness_analysis');
const weakestSubjects = weaknessData.data?.weakest_subjects || [];

if (mode === 'adaptive' && weakestSubjects.length > 0) {
    // Générer 80% sur les matières faibles
    const weakSubject = weakestSubjects[0];
    userPrompt = `L'étudiant a des difficultés en "${weakSubject.subject_name}" 
        (taux de réussite: ${weakSubject.success_rate}%).
        Génère ${count} questions adaptées à son niveau:
        - Difficulté recommandée: ${weakSubject.recommended_difficulty}/5
        - Commencer par des questions accessibles pour renforcer la confiance
        - Progression graduelle vers plus difficile
        - Explications détaillées pour l'apprentissage`;
}
    """)
    
    print("\n" + "="*60)
    print("BÉNÉFICES DU SYSTÈME ADAPTATIF")
    print("="*60)
    print("""
    1. DÉTECTION AUTOMATIQUE des faiblesses par matière
    2. GÉNÉRATION CIBLÉE sur les points faibles (70% du quiz)
    3. DIFFICULTÉ ADAPTÉE au niveau réel de l'étudiant
    4. PROGRESSION MESURABLE avec dashboard détaillé
    5. RECOMMANDATIONS PERSONNALISÉES par matière
    6. INTÉGRATION IA pour générer des questions sur mesure
    """)
    
    print("\n✅ Conception terminée.\n")

if __name__ == "__main__":
    main()
