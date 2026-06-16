#!/usr/bin/env python3
"""Migrer les RPCs adaptatives de schema 'app' vers 'public' pour qu'elles soient accessibles via PostgREST."""
import requests
import time
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    print("\n🔧 MIGRATION RPCs → schema PUBLIC\n")

    rpcs = [
        # 1. app_prep_get_adaptive_quiz
        {
            "name": "app_prep_get_adaptive_quiz",
            "sql": """
CREATE OR REPLACE FUNCTION public.app_prep_get_adaptive_quiz(
    p_count integer DEFAULT 10,
    p_concours_type text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_student_id uuid;
    v_questions jsonb := '[]'::jsonb;
    v_has_weaknesses boolean;
    v_weakness_questions integer;
    v_regular_questions integer;
BEGIN
    v_student_id := auth.uid();
    IF v_student_id IS NULL THEN
        RAISE EXCEPTION 'Non authentifié';
    END IF;

    SELECT EXISTS(
        SELECT 1 FROM app.prep_student_weaknesses
        WHERE student_id = v_student_id AND needs_practice = true
    ) INTO v_has_weaknesses;

    IF v_has_weaknesses THEN
        v_weakness_questions := GREATEST(1, CEIL(p_count * 0.7));
        v_regular_questions := p_count - v_weakness_questions;
    ELSE
        v_weakness_questions := 0;
        v_regular_questions := p_count;
    END IF;

    -- Questions ciblées sur les faiblesses
    IF v_weakness_questions > 0 THEN
        WITH weak_subjects AS (
            SELECT subject_id, priority_weight, recommended_difficulty
            FROM app.prep_student_weaknesses
            WHERE student_id = v_student_id AND needs_practice = true
            ORDER BY priority_weight DESC, weakness_score DESC
            LIMIT 5
        ),
        weakness_pool AS (
            SELECT DISTINCT ON (q.id)
                q.id, q.question, q.content, q.options,
                q.correct_index, q.explanation, q.difficulty,
                q.subject, q.subject_id, q.image_url,
                w.priority_weight,
                RANDOM() AS rand
            FROM app.prep_questions q
            JOIN weak_subjects w ON w.subject_id = q.subject_id
            WHERE q.is_published = true AND q.is_active = true
              AND (p_concours_type IS NULL OR q.concours_type = p_concours_type)
        )
        SELECT COALESCE(jsonb_agg(
            jsonb_build_object(
                'id', id, 'question', question, 'content', content,
                'options', options, 'correct_index', correct_index,
                'explanation', explanation, 'difficulty', difficulty,
                'subject', subject, 'subject_id', subject_id,
                'image_url', image_url, 'is_weakness_targeted', true
            ) ORDER BY priority_weight DESC, rand
        ), '[]'::jsonb) INTO v_questions
        FROM (SELECT * FROM weakness_pool LIMIT v_weakness_questions) t;
    END IF;

    -- Compléter avec questions générales
    IF v_regular_questions > 0 THEN
        WITH excluded_ids AS (
            SELECT (value->>'id')::uuid AS id
            FROM jsonb_array_elements(COALESCE(v_questions, '[]'::jsonb))
        ),
        regular_pool AS (
            SELECT q.id, q.question, q.content, q.options,
                   q.correct_index, q.explanation, q.difficulty,
                   q.subject, q.subject_id, q.image_url
            FROM app.prep_questions q
            WHERE q.is_published = true AND q.is_active = true
              AND (p_concours_type IS NULL OR q.concours_type = p_concours_type)
              AND q.id NOT IN (SELECT id FROM excluded_ids)
            ORDER BY RANDOM()
            LIMIT v_regular_questions
        )
        SELECT COALESCE(v_questions, '[]'::jsonb) || COALESCE(jsonb_agg(
            jsonb_build_object(
                'id', id, 'question', question, 'content', content,
                'options', options, 'correct_index', correct_index,
                'explanation', explanation, 'difficulty', difficulty,
                'subject', subject, 'subject_id', subject_id,
                'image_url', image_url, 'is_weakness_targeted', false
            )
        ), '[]'::jsonb) INTO v_questions
        FROM regular_pool;
    END IF;

    -- Mélanger
    WITH shuffled AS (
        SELECT value FROM jsonb_array_elements(COALESCE(v_questions, '[]'::jsonb)) AS value
        ORDER BY RANDOM()
    )
    SELECT COALESCE(jsonb_agg(value), '[]'::jsonb) INTO v_questions FROM shuffled;

    RETURN jsonb_build_object(
        'adaptive_mode', v_has_weaknesses,
        'weakness_ratio', CASE WHEN p_count > 0 THEN v_weakness_questions::decimal / p_count ELSE 0 END,
        'total_questions', jsonb_array_length(COALESCE(v_questions, '[]'::jsonb)),
        'questions', COALESCE(v_questions, '[]'::jsonb)
    );
END;
$$
            """
        },
        # 2. app_prep_get_weakness_analysis
        {
            "name": "app_prep_get_weakness_analysis",
            "sql": """
CREATE OR REPLACE FUNCTION public.app_prep_get_weakness_analysis()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
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
            )
            FROM app.prep_student_weaknesses w
            JOIN app.prep_subjects s ON s.id = w.subject_id
            WHERE w.student_id = v_student_id AND w.needs_practice = true
            LIMIT 5
        ), '[]'::jsonb),
        'progress_summary', (
            SELECT jsonb_build_object(
                'total_subjects_practiced', COUNT(DISTINCT subject_id),
                'subjects_needing_practice', COUNT(*) FILTER (WHERE needs_practice),
                'overall_success_rate', ROUND(COALESCE(AVG(success_rate), 0), 1),
                'total_questions_answered', COALESCE(SUM(total_questions), 0),
                'total_correct_answers', COALESCE(SUM(correct_answers), 0)
            )
            FROM app.prep_student_weaknesses
            WHERE student_id = v_student_id
        ),
        'recommendations', COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object(
                    'subject', s.title,
                    'subject_id', w.subject_id,
                    'message', CASE
                        WHEN w.success_rate < 40 THEN 'Besoin urgent de révision. Commencez par les bases.'
                        WHEN w.success_rate < 60 THEN 'Pratiquez régulièrement avec des questions de niveau moyen.'
                        WHEN w.success_rate < 80 THEN 'Bon progrès! Essayez des questions plus difficiles.'
                        ELSE 'Excellent! Maintenez votre pratique.'
                    END,
                    'suggested_difficulty', w.recommended_difficulty,
                    'suggested_practice_count', CASE
                        WHEN w.total_questions < 10 THEN 20
                        WHEN w.success_rate < 50 THEN 15
                        ELSE 10
                    END,
                    'practice_priority', CASE
                        WHEN w.priority_weight >= 3 THEN 'Haute'
                        WHEN w.priority_weight >= 2 THEN 'Moyenne'
                        ELSE 'Faible'
                    END
                ) ORDER BY w.priority_weight DESC
            )
            FROM app.prep_student_weaknesses w
            JOIN app.prep_subjects s ON s.id = w.subject_id
            WHERE w.student_id = v_student_id
            LIMIT 3
        ), '[]'::jsonb)
    );
END;
$$
            """
        },
        # 3. Permissions
        {
            "name": "GRANT adaptive_quiz",
            "sql": "GRANT EXECUTE ON FUNCTION public.app_prep_get_adaptive_quiz TO authenticated"
        },
        {
            "name": "GRANT weakness_analysis",
            "sql": "GRANT EXECUTE ON FUNCTION public.app_prep_get_weakness_analysis TO authenticated"
        },
    ]

    success = 0
    for rpc in rpcs:
        print(f"📦 {rpc['name']}...")
        try:
            r = requests.post(
                f"{m.url}/rest/v1/rpc/execute_ddl",
                headers=m.headers,
                json={"ddl_query": rpc['sql']},
                timeout=30
            )
            if r.status_code == 200:
                print(f"   ✅ OK")
                success += 1
            else:
                txt = r.text[:150]
                if 'already exists' in txt.lower():
                    print(f"   ⚠️  Existe déjà")
                    success += 1
                else:
                    print(f"   ❌ {txt}")
        except Exception as e:
            print(f"   ❌ {str(e)[:100]}")
        time.sleep(0.2)

    # Vérifier l'accessibilité
    print("\n🔍 Vérification API REST...")
    for rpc_name in ['app_prep_get_adaptive_quiz', 'app_prep_get_weakness_analysis']:
        try:
            resp = requests.post(
                f"{m.url}/rest/v1/rpc/{rpc_name}",
                headers=m.headers,
                json={},
                timeout=10
            )
            if resp.status_code == 200:
                print(f"  ✅ {rpc_name} → 200 OK")
            else:
                print(f"  ❌ {rpc_name} → {resp.status_code}")
        except Exception as e:
            print(f"  ❌ {rpc_name} → {str(e)[:50]}")

    print(f"\n✅ Migration terminée: {success}/{len(rpcs)} composants.\n")

if __name__ == "__main__":
    main()
