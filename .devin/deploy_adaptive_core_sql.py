#!/usr/bin/env python3
"""Déployer uniquement les parties essentielles du système adaptatif."""
from __future__ import annotations
import requests
import time
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    print("\n🚀 DÉPLOIEMENT SYSTÈME ADAPTATIF - Core Components\n")
    
    # Définir les composants essentiels
    sql_components = [
        # 1. Table prep_student_weaknesses
        {
            "name": "Table prep_student_weaknesses",
            "type": "ddl",
            "sql": """
CREATE TABLE IF NOT EXISTS app.prep_student_weaknesses (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    subject_id uuid NOT NULL REFERENCES app.prep_subjects(id) ON DELETE CASCADE,
    total_questions integer DEFAULT 0,
    correct_answers integer DEFAULT 0,
    incorrect_answers integer DEFAULT 0,
    success_rate decimal(5,2) DEFAULT 0.00,
    avg_difficulty_attempted decimal(3,2) DEFAULT 2.50,
    avg_difficulty_failed decimal(3,2) DEFAULT 2.50,
    weakness_score decimal(5,2) DEFAULT 50.00,
    recommended_difficulty integer DEFAULT 2,
    priority_weight decimal(3,2) DEFAULT 1.00,
    needs_practice boolean DEFAULT false,
    updated_at timestamptz DEFAULT now(),
    created_at timestamptz DEFAULT now(),
    UNIQUE(student_id, subject_id)
)
            """
        },
        # 2. Index pour performance
        {
            "name": "Index student_subject",
            "type": "ddl",
            "sql": "CREATE INDEX IF NOT EXISTS idx_weaknesses_student_subject ON app.prep_student_weaknesses(student_id, subject_id)"
        },
        # 3. RLS Policy
        {
            "name": "RLS Policy",
            "type": "ddl", 
            "sql": "ALTER TABLE app.prep_student_weaknesses ENABLE ROW LEVEL SECURITY"
        },
        # 4. Fonction de mise à jour
        {
            "name": "Function update_student_weaknesses",
            "type": "ddl",
            "sql": """
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
$$ LANGUAGE plpgsql
            """
        },
        # 5. RPC app_prep_get_adaptive_quiz
        {
            "name": "RPC app_prep_get_adaptive_quiz",
            "type": "ddl",
            "sql": """
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
BEGIN
    v_student_id := auth.uid();
    IF v_student_id IS NULL THEN
        RAISE EXCEPTION 'Non authentifié';
    END IF;
    
    -- Version simplifiée pour le test initial
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
$$ LANGUAGE plpgsql
            """
        },
        # 6. RPC app_prep_get_weakness_analysis 
        {
            "name": "RPC app_prep_get_weakness_analysis",
            "type": "ddl",
            "sql": """
CREATE OR REPLACE FUNCTION app.app_prep_get_weakness_analysis()
RETURNS jsonb 
SECURITY DEFINER
SET search_path = app, public
AS $$
DECLARE
    v_student_id uuid;
BEGIN
    v_student_id := auth.uid();
    IF v_student_id IS NULL THEN
        RAISE EXCEPTION 'Non authentifié';
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
$$ LANGUAGE plpgsql
            """
        }
    ]
    
    success_count = 0
    error_count = 0
    
    for component in sql_components:
        print(f"\n📦 {component['name']}...")
        
        try:
            if component['type'] == 'ddl':
                response = requests.post(
                    f"{m.url}/rest/v1/rpc/execute_ddl",
                    headers=m.headers,
                    json={"ddl_query": component['sql']},
                    timeout=30
                )
            else:
                response = requests.post(
                    f"{m.url}/rest/v1/rpc/execute_sql",
                    headers=m.headers,
                    json={"sql_query": component['sql']},
                    timeout=30
                )
            
            if response.status_code == 200:
                print(f"   ✅ Succès")
                success_count += 1
            else:
                error_text = response.text
                if 'already exists' in error_text.lower():
                    print(f"   ⚠️  Existe déjà (ignoré)")
                    success_count += 1
                else:
                    print(f"   ❌ Erreur: {error_text[:150]}")
                    error_count += 1
                    
            time.sleep(0.2)
            
        except Exception as e:
            print(f"   ❌ Exception: {str(e)[:150]}")
            error_count += 1
    
    print("\n" + "="*60)
    print(f"RÉSUMÉ: {success_count}/{len(sql_components)} composants déployés")
    print("="*60)
    
    if success_count == len(sql_components):
        print("\n✅ Déploiement complet réussi!")
    else:
        print("\n⚠️  Déploiement partiel - vérifier les erreurs")
        print("\n💡 Conseil: Exécuter manuellement dans Supabase SQL Editor")

if __name__ == "__main__":
    main()
