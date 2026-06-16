#!/usr/bin/env python3
"""Migrer les RPCs manquantes vers public + créer l'import JSON sans token."""
import requests
import time
from supabase_auto_manager import SupabaseAutoManager

def deploy(m, name, sql):
    print(f"📦 {name}...")
    try:
        r = requests.post(f"{m.url}/rest/v1/rpc/execute_ddl",
            headers=m.headers, json={"ddl_query": sql}, timeout=30)
        if r.status_code == 200:
            print(f"   ✅ OK")
            return True
        elif 'already exists' in r.text.lower():
            print(f"   ⚠️  Existe déjà")
            return True
        else:
            print(f"   ❌ {r.text[:150]}")
            return False
    except Exception as e:
        print(f"   ❌ {str(e)[:100]}")
        return False

def main():
    m = SupabaseAutoManager()
    print("\n🔧 DÉPLOIEMENT — RPCs manquantes + Import sans token\n")

    # ═══ 1. app_prep_get_student_progress dans public ═══
    deploy(m, "app_prep_get_student_progress (public)", """
CREATE OR REPLACE FUNCTION public.app_prep_get_student_progress()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result jsonb;
    v_uid uuid;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object('total_xp', 0, 'current_streak', 0, 'longest_streak', 0, 'total_correct', 0, 'total_answered', 0);
    END IF;
    
    SELECT jsonb_build_object(
        'total_xp', COALESCE(p.total_xp, 0),
        'current_streak', COALESCE(p.current_streak, 0),
        'longest_streak', COALESCE(p.longest_streak, 0),
        'total_correct', COALESCE(p.total_correct, 0),
        'total_answered', COALESCE(p.total_answered, 0),
        'last_activity_date', p.last_activity_date
    ) INTO v_result
    FROM app.prep_student_progress p
    WHERE p.student_id = v_uid;
    
    IF v_result IS NULL THEN
        RETURN jsonb_build_object('total_xp', 0, 'current_streak', 0, 'longest_streak', 0, 'total_correct', 0, 'total_answered', 0);
    END IF;
    RETURN v_result;
END;
$$
    """)
    time.sleep(0.2)

    # ═══ 2. app_prep_get_subject_stats dans public ═══
    deploy(m, "app_prep_get_subject_stats (public)", """
CREATE OR REPLACE FUNCTION public.app_prep_get_subject_stats()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result jsonb;
BEGIN
    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb) INTO v_result
    FROM (
        SELECT q.subject,
               COUNT(a.id) AS total,
               SUM(CASE WHEN a.is_correct THEN 1 ELSE 0 END) AS correct,
               CASE WHEN COUNT(a.id) > 0 
                    THEN ROUND((SUM(CASE WHEN a.is_correct THEN 1 ELSE 0 END)::numeric / COUNT(a.id)) * 100, 1)
                    ELSE 0 END AS accuracy
        FROM app.prep_attempts a
        JOIN app.prep_questions q ON q.id = a.question_id
        WHERE a.student_id = auth.uid()
        GROUP BY q.subject
        ORDER BY total DESC
    ) t;
    RETURN v_result;
END;
$$
    """)
    time.sleep(0.2)

    # ═══ 3. RPC d'import JSON sans token — insertion directe ═══
    deploy(m, "app_admin_prep_import_questions_json (public)", """
CREATE OR REPLACE FUNCTION public.app_admin_prep_import_questions_json(
    p_questions jsonb,
    p_concours_type text DEFAULT NULL,
    p_subject_name text DEFAULT NULL,
    p_subject_id uuid DEFAULT NULL,
    p_source text DEFAULT 'admin_import'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_uid uuid;
    v_count integer := 0;
    v_q jsonb;
    v_subject_id uuid;
    v_question_id uuid;
    v_options jsonb;
    v_correct_index integer;
    i integer;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Non authentifié';
    END IF;

    -- Résoudre le subject_id si subject_name fourni
    IF p_subject_id IS NULL AND p_subject_name IS NOT NULL THEN
        SELECT id INTO v_subject_id
        FROM app.prep_subjects
        WHERE LOWER(title) = LOWER(p_subject_name)
        LIMIT 1;
    ELSE
        v_subject_id := p_subject_id;
    END IF;

    -- Parcourir chaque question du JSON
    FOR i IN 0..jsonb_array_length(p_questions) - 1 LOOP
        v_q := p_questions->i;
        
        v_options := v_q->'options';
        v_correct_index := COALESCE((v_q->>'correct_index')::integer, 0);

        INSERT INTO app.prep_questions (
            subject_id, question, content, options, correct_index,
            explanation, difficulty, subject, concours_type,
            source, is_published, is_active, question_type
        ) VALUES (
            v_subject_id,
            COALESCE(v_q->>'question', ''),
            COALESCE(v_q->>'question', ''),
            v_options,
            v_correct_index,
            v_q->>'explanation',
            COALESCE((v_q->>'difficulty')::integer, 2),
            COALESCE(p_subject_name, v_q->>'subject', 'Culture Générale'),
            p_concours_type,
            p_source,
            true,  -- Publié immédiatement
            true,  -- Actif immédiatement
            'mcq'
        ) RETURNING id INTO v_question_id;

        -- Insérer les choix dans prep_question_choices si options présentes
        IF v_options IS NOT NULL AND jsonb_array_length(v_options) > 0 THEN
            FOR j IN 0..jsonb_array_length(v_options) - 1 LOOP
                INSERT INTO app.prep_question_choices (
                    question_id, choice_label, choice_text, is_correct, sort_order
                ) VALUES (
                    v_question_id,
                    CHR(65 + j),  -- A, B, C, D
                    v_options->>j,
                    j = v_correct_index,
                    j
                );
            END LOOP;
        END IF;

        v_count := v_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'imported_count', v_count,
        'subject_id', v_subject_id,
        'source', p_source
    );
END;
$$
    """)
    time.sleep(0.2)

    # ═══ 4. RPC d'import texte brut sans token ═══
    deploy(m, "app_admin_prep_import_text_bulk (public)", """
CREATE OR REPLACE FUNCTION public.app_admin_prep_import_text_bulk(
    p_text text,
    p_concours_type text DEFAULT NULL,
    p_subject_name text DEFAULT NULL,
    p_doc_type text DEFAULT 'sujet'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_uid uuid;
    v_subject_id uuid;
    v_doc_id uuid;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Non authentifié';
    END IF;

    -- Résoudre le subject_id
    IF p_subject_name IS NOT NULL THEN
        SELECT id INTO v_subject_id
        FROM app.prep_subjects
        WHERE LOWER(title) = LOWER(p_subject_name)
        LIMIT 1;
    END IF;

    -- Créer un document source avec le texte brut
    INSERT INTO app.prep_source_documents (
        uploaded_by, subject_id, year, doc_type,
        source_type, extracted_text, concours_type, status
    ) VALUES (
        v_uid, v_subject_id, EXTRACT(YEAR FROM now())::integer,
        p_doc_type, 'text_paste', p_text, p_concours_type, 'indexed'
    ) RETURNING id INTO v_doc_id;

    -- Créer un chunk unique pour le RAG (sans embedding pour l'instant)
    INSERT INTO app.prep_doc_chunks (
        source_document_id, chunk_index, content,
        chunk_type, concours_type, subject_name,
        token_count
    ) VALUES (
        v_doc_id, 0, LEFT(p_text, 4000),
        p_doc_type, p_concours_type, p_subject_name,
        CEIL(LENGTH(p_text) / 4.0)::integer
    );

    -- Si texte long, créer des chunks supplémentaires
    IF LENGTH(p_text) > 4000 THEN
        DECLARE
            v_offset integer := 4000;
            v_idx integer := 1;
        BEGIN
            WHILE v_offset < LENGTH(p_text) LOOP
                INSERT INTO app.prep_doc_chunks (
                    source_document_id, chunk_index, content,
                    chunk_type, concours_type, subject_name,
                    token_count
                ) VALUES (
                    v_doc_id, v_idx, SUBSTR(p_text, v_offset + 1, 4000),
                    p_doc_type, p_concours_type, p_subject_name,
                    LEAST(CEIL(4000 / 4.0), CEIL((LENGTH(p_text) - v_offset) / 4.0))::integer
                );
                v_offset := v_offset + 4000;
                v_idx := v_idx + 1;
            END LOOP;
        END;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'document_id', v_doc_id,
        'text_length', LENGTH(p_text),
        'doc_type', p_doc_type,
        'note', 'Texte indexé. Les embeddings seront générés ultérieurement pour le RAG sémantique.'
    );
END;
$$
    """)
    time.sleep(0.2)

    # ═══ 5. Permissions ═══
    for rpc in ['app_prep_get_student_progress', 'app_prep_get_subject_stats',
                'app_admin_prep_import_questions_json', 'app_admin_prep_import_text_bulk']:
        deploy(m, f"GRANT {rpc}", f"GRANT EXECUTE ON FUNCTION public.{rpc} TO authenticated")
        time.sleep(0.1)

    # ═══ 6. Vérification finale ═══
    print("\n🔍 Vérification API REST...")
    for rpc in ['app_prep_get_quiz_questions', 'app_prep_get_adaptive_quiz',
                'app_prep_get_weakness_analysis', 'app_prep_get_student_progress',
                'app_prep_get_subject_stats', 'app_admin_prep_import_questions_json']:
        try:
            resp = requests.post(f"{m.url}/rest/v1/rpc/{rpc}",
                headers=m.headers, json={}, timeout=10)
            code = resp.status_code
            icon = "✅" if code in [200, 400] else "❌"
            label = "OK" if code == 200 else "AUTH REQ" if code == 400 else "NOT FOUND"
            print(f"  {icon} {rpc} → {code} ({label})")
        except:
            print(f"  ❌ {rpc} → ERREUR")

    print("\n✅ Déploiement terminé.\n")

if __name__ == "__main__":
    main()
