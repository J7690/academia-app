#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Deploy the concours actuality scoring machine.
Steps:
1. Disable RTB source
2. Add relevance_score + is_concours_relevant columns to prep_news_articles
3. Create prep_actuality_preferences table (student opt-in)
4. Create scoring RPC (analyze article vs past questions patterns)
5. Create notification RPC for concours actuality
6. Create Edge Function prep-score-actuality
"""
import json
import sys
import pathlib
import requests

sys.stdout.reconfigure(encoding='utf-8')

from supabase_auto_manager import SupabaseAutoManager
m = SupabaseAutoManager()

def run_sql(label, sql_query, timeout=120):
    r = requests.post(
        f"{m.url}/rest/v1/rpc/admin_execute_sql",
        headers=m.headers,
        json={"p_sql": sql_query.strip()},
        timeout=timeout
    ).json()
    ok = r.get("ok", False)
    err = r.get("error")
    status = "OK" if ok else "FAIL"
    print(f"  [{status}] {label}" + (f" -- {err}" if err else ""))
    return r

def run_ddl(label, ddl_query, timeout=120):
    r = requests.post(
        f"{m.url}/rest/v1/rpc/execute_ddl",
        headers=m.headers,
        json={"ddl_query": ddl_query.strip()},
        timeout=timeout
    ).json()
    ok = not (isinstance(r, dict) and r.get("code"))
    err = r.get("message") if isinstance(r, dict) else None
    status = "OK" if ok else "FAIL"
    print(f"  [{status}] {label}" + (f" -- {err}" if err else ""))
    return r

results = {"steps": []}

# ═══════════════════════════════════════════════════════════════
# STEP 1: Disable RTB
# ═══════════════════════════════════════════════════════════════
print("=== STEP 1: Disable RTB ===")
r = run_sql("disable_rtb", "UPDATE app.prep_news_sources SET is_active = false, updated_at = now() WHERE slug = 'rtb'")
results["steps"].append({"step": "disable_rtb", "result": r})

# ═══════════════════════════════════════════════════════════════
# STEP 2: Add scoring columns to prep_news_articles
# ═══════════════════════════════════════════════════════════════
print("\n=== STEP 2: Add scoring columns ===")
ddl2 = """
ALTER TABLE app.prep_news_articles
    ADD COLUMN IF NOT EXISTS relevance_score real DEFAULT 0,
    ADD COLUMN IF NOT EXISTS is_concours_relevant boolean DEFAULT false,
    ADD COLUMN IF NOT EXISTS scoring_reason text,
    ADD COLUMN IF NOT EXISTS matched_subjects text[] DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS matched_keywords text[] DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS scored_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_prep_news_articles_relevant
    ON app.prep_news_articles(is_concours_relevant) WHERE is_concours_relevant = true;

CREATE INDEX IF NOT EXISTS idx_prep_news_articles_score
    ON app.prep_news_articles(relevance_score DESC);
"""
r2 = run_ddl("add_scoring_columns", ddl2)
results["steps"].append({"step": "add_scoring_columns", "result": r2})

# ═══════════════════════════════════════════════════════════════
# STEP 3: Create prep_actuality_preferences table
# ═══════════════════════════════════════════════════════════════
print("\n=== STEP 3: Create preferences table ===")
ddl3 = """
CREATE TABLE IF NOT EXISTS app.prep_actuality_preferences (
    user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    is_enabled boolean NOT NULL DEFAULT false,
    concours_types text[] DEFAULT '{}',
    subjects_filter text[] DEFAULT '{}',
    min_relevance_score real DEFAULT 0.6,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE app.prep_actuality_preferences ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='prep_actuality_preferences' AND policyname='student_own_prefs') THEN
        CREATE POLICY student_own_prefs ON app.prep_actuality_preferences
            FOR ALL TO authenticated
            USING (user_id = auth.uid())
            WITH CHECK (user_id = auth.uid());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='prep_actuality_preferences' AND policyname='service_role_all_prefs') THEN
        CREATE POLICY service_role_all_prefs ON app.prep_actuality_preferences
            FOR ALL TO service_role
            USING (true) WITH CHECK (true);
    END IF;
END $$;
"""
r3 = run_ddl("create_preferences_table", ddl3)
results["steps"].append({"step": "create_preferences_table", "result": r3})

# ═══════════════════════════════════════════════════════════════
# STEP 4: RPC — toggle actuality notifications
# ═══════════════════════════════════════════════════════════════
print("\n=== STEP 4: RPC toggle preferences ===")
rpc4 = """
CREATE OR REPLACE FUNCTION public.app_student_toggle_actuality_notifications(
    p_enabled boolean DEFAULT true,
    p_concours_types text[] DEFAULT '{}',
    p_subjects_filter text[] DEFAULT '{}',
    p_min_score real DEFAULT 0.6
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $fn$
DECLARE
    v_uid uuid := auth.uid();
BEGIN
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object('error', 'not_authenticated');
    END IF;

    INSERT INTO app.prep_actuality_preferences (user_id, is_enabled, concours_types, subjects_filter, min_relevance_score, updated_at)
    VALUES (v_uid, p_enabled, p_concours_types, p_subjects_filter, p_min_score, now())
    ON CONFLICT (user_id) DO UPDATE SET
        is_enabled = p_enabled,
        concours_types = CASE WHEN array_length(p_concours_types, 1) > 0 THEN p_concours_types ELSE app.prep_actuality_preferences.concours_types END,
        subjects_filter = CASE WHEN array_length(p_subjects_filter, 1) > 0 THEN p_subjects_filter ELSE app.prep_actuality_preferences.subjects_filter END,
        min_relevance_score = p_min_score,
        updated_at = now();

    RETURN jsonb_build_object('success', true, 'is_enabled', p_enabled);
END;
$fn$;
"""
r4 = run_ddl("rpc_toggle_prefs", rpc4)
results["steps"].append({"step": "rpc_toggle_prefs", "result": r4})

# ═══════════════════════════════════════════════════════════════
# STEP 5: RPC — get actuality preferences
# ═══════════════════════════════════════════════════════════════
print("\n=== STEP 5: RPC get preferences ===")
rpc5 = """
CREATE OR REPLACE FUNCTION public.app_student_get_actuality_preferences()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $fn$
DECLARE
    v_uid uuid := auth.uid();
    v_row app.prep_actuality_preferences;
BEGIN
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object('error', 'not_authenticated');
    END IF;

    SELECT * INTO v_row FROM app.prep_actuality_preferences WHERE user_id = v_uid;

    IF v_row IS NULL THEN
        RETURN jsonb_build_object(
            'success', true,
            'is_enabled', false,
            'concours_types', '[]'::jsonb,
            'subjects_filter', '[]'::jsonb,
            'min_relevance_score', 0.6
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'is_enabled', v_row.is_enabled,
        'concours_types', to_jsonb(v_row.concours_types),
        'subjects_filter', to_jsonb(v_row.subjects_filter),
        'min_relevance_score', v_row.min_relevance_score
    );
END;
$fn$;
"""
r5 = run_ddl("rpc_get_prefs", rpc5)
results["steps"].append({"step": "rpc_get_prefs", "result": r5})

# ═══════════════════════════════════════════════════════════════
# STEP 6: RPC — score an article against past questions
# ═══════════════════════════════════════════════════════════════
print("\n=== STEP 6: RPC scoring engine ===")
rpc6 = """
CREATE OR REPLACE FUNCTION public.app_prep_score_article_relevance(
    p_title text,
    p_content text,
    p_categories text[] DEFAULT '{}'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $fn$
DECLARE
    v_score real := 0;
    v_matched_subjects text[] := '{}';
    v_matched_keywords text[] := '{}';
    v_reason text := '';
    v_content_lower text;
    v_title_lower text;
    v_subject_row RECORD;
    v_keyword text;
    v_keyword_score real;
    v_cat text;
BEGIN
    v_content_lower := LOWER(COALESCE(p_content, ''));
    v_title_lower := LOWER(COALESCE(p_title, ''));

    -- ══════════════════════════════════════════════════════
    -- PHASE 1: Match against prep_subjects (matières concours)
    -- Score +0.15 per matched subject
    -- ══════════════════════════════════════════════════════
    FOR v_subject_row IN
        SELECT title, slug FROM app.prep_subjects
    LOOP
        IF v_content_lower LIKE '%' || LOWER(v_subject_row.title) || '%'
           OR v_title_lower LIKE '%' || LOWER(v_subject_row.title) || '%' THEN
            v_score := v_score + 0.15;
            v_matched_subjects := array_append(v_matched_subjects, v_subject_row.title);
        END IF;
    END LOOP;

    -- ══════════════════════════════════════════════════════
    -- PHASE 2: Match against high-frequency keywords from past questions
    -- Extract top keywords from prep_questions content
    -- ══════════════════════════════════════════════════════
    -- Governance & institutions keywords (très fréquents aux concours)
    FOREACH v_keyword IN ARRAY ARRAY[
        'constitution', 'gouvernement', 'assemblee nationale', 'assemblee legislative',
        'president', 'premier ministre', 'conseil des ministres',
        'decret', 'loi', 'ordonnance', 'arrete',
        'transition', 'mpsr', 'capitaine ibrahim traore',
        'fonction publique', 'concours', 'recrutement',
        'budget', 'finances publiques', 'tresor', 'impot', 'fiscalite',
        'douane', 'commerce', 'exportation', 'importation',
        'education', 'enseignement', 'universite', 'ecole',
        'sante', 'hopital', 'epidemie', 'vaccination',
        'securite', 'defense', 'armee', 'terrorisme', 'fdp', 'vdp',
        'aes', 'cedeao', 'uemoa', 'ua', 'sahel',
        'mine', 'or', 'coton', 'agriculture', 'elevage',
        'justice', 'tribunal', 'cour', 'magistrat',
        'election', 'referendum', 'scrutin',
        'decentralisation', 'commune', 'region', 'province',
        'droits humains', 'droits de homme',
        'environnement', 'changement climatique', 'eau', 'assainissement',
        'demographie', 'recensement', 'population',
        'cooperation', 'diplomatie', 'ambassade',
        'economie', 'pib', 'croissance', 'inflation', 'dette',
        'secteur prive', 'entreprise', 'investissement',
        'culture', 'patrimoine', 'snc', 'fespaco',
        'sport', 'etalons', 'can',
        'femme', 'genre', 'egalite',
        'jeunesse', 'emploi', 'formation professionnelle',
        'numerique', 'digital', 'telecoms', 'internet',
        'transport', 'route', 'rail', 'aeroport',
        'energie', 'electricite', 'solaire', 'barrage'
    ] LOOP
        IF v_content_lower LIKE '%' || v_keyword || '%'
           OR v_title_lower LIKE '%' || v_keyword || '%' THEN
            -- Weight based on keyword category
            CASE
                WHEN v_keyword IN ('constitution','gouvernement','assemblee nationale','assemblee legislative','president','premier ministre','conseil des ministres','transition','mpsr','capitaine ibrahim traore') THEN
                    v_keyword_score := 0.12;
                WHEN v_keyword IN ('fonction publique','concours','recrutement','budget','finances publiques','impot','fiscalite','douane') THEN
                    v_keyword_score := 0.15;
                WHEN v_keyword IN ('loi','decret','ordonnance','arrete','justice','tribunal','cour','magistrat') THEN
                    v_keyword_score := 0.10;
                WHEN v_keyword IN ('aes','cedeao','uemoa','ua','sahel','cooperation','diplomatie') THEN
                    v_keyword_score := 0.08;
                ELSE
                    v_keyword_score := 0.05;
            END CASE;

            v_score := v_score + v_keyword_score;
            v_matched_keywords := array_append(v_matched_keywords, v_keyword);
        END IF;
    END LOOP;

    -- ══════════════════════════════════════════════════════
    -- PHASE 3: Category bonus
    -- ══════════════════════════════════════════════════════
    IF p_categories IS NOT NULL THEN
        FOREACH v_cat IN ARRAY p_categories LOOP
            CASE LOWER(TRIM(v_cat))
                WHEN 'politique', 'politique nationale' THEN v_score := v_score + 0.10;
                WHEN 'economie', 'économie' THEN v_score := v_score + 0.08;
                WHEN 'societe', 'société' THEN v_score := v_score + 0.06;
                WHEN 'education', 'éducation' THEN v_score := v_score + 0.10;
                WHEN 'sante', 'santé' THEN v_score := v_score + 0.06;
                WHEN 'justice', 'droit' THEN v_score := v_score + 0.10;
                WHEN 'securite', 'sécurité', 'defense', 'défense' THEN v_score := v_score + 0.08;
                WHEN 'international' THEN v_score := v_score + 0.05;
                ELSE NULL;
            END CASE;
        END LOOP;
    END IF;

    -- ══════════════════════════════════════════════════════
    -- PHASE 4: Title-in-past-questions bonus
    -- If the article title mentions something found in past questions
    -- ══════════════════════════════════════════════════════
    IF EXISTS (
        SELECT 1 FROM app.prep_questions pq
        WHERE pq.subject = 'Culture Generale' OR pq.subject = 'Actualites BF'
        AND (
            v_title_lower LIKE '%' || LOWER(LEFT(pq.content, 30)) || '%'
            OR LOWER(pq.content) LIKE '%' || LEFT(v_title_lower, 40) || '%'
        )
        LIMIT 1
    ) THEN
        v_score := v_score + 0.20;
        v_reason := v_reason || 'Title matches past question pattern. ';
    END IF;

    -- ══════════════════════════════════════════════════════
    -- PHASE 5: prep_topics frequency bonus
    -- ══════════════════════════════════════════════════════
    FOR v_subject_row IN
        SELECT name, frequency_score FROM app.prep_topics WHERE frequency_score > 0
    LOOP
        IF v_content_lower LIKE '%' || LOWER(v_subject_row.name) || '%' THEN
            v_score := v_score + (v_subject_row.frequency_score::real / 100.0);
            v_reason := v_reason || 'Matches topic: ' || v_subject_row.name || '. ';
        END IF;
    END LOOP;

    -- Cap score at 1.0
    v_score := LEAST(v_score, 1.0);

    -- Build reason summary
    IF array_length(v_matched_subjects, 1) > 0 THEN
        v_reason := v_reason || 'Matieres: ' || array_to_string(v_matched_subjects, ', ') || '. ';
    END IF;
    IF array_length(v_matched_keywords, 1) > 3 THEN
        v_reason := v_reason || 'Keywords (' || array_length(v_matched_keywords, 1)::text || '): ' || array_to_string(v_matched_keywords[1:5], ', ') || '...';
    END IF;

    RETURN jsonb_build_object(
        'score', round(v_score::numeric, 3),
        'is_relevant', (v_score >= 0.3),
        'matched_subjects', to_jsonb(v_matched_subjects),
        'matched_keywords', to_jsonb(v_matched_keywords),
        'reason', v_reason
    );
END;
$fn$;
"""
r6 = run_ddl("rpc_score_article", rpc6)
results["steps"].append({"step": "rpc_score_article", "result": r6})

# ═══════════════════════════════════════════════════════════════
# STEP 7: RPC — notify opted-in students about relevant articles
# ═══════════════════════════════════════════════════════════════
print("\n=== STEP 7: RPC notify relevant article ===")
rpc7 = """
CREATE OR REPLACE FUNCTION public.app_prep_notify_relevant_article(
    p_article_id uuid,
    p_title text,
    p_score real,
    p_matched_subjects text[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $fn$
DECLARE
    v_user RECORD;
    v_notified integer := 0;
    v_subjects_text text;
BEGIN
    v_subjects_text := COALESCE(array_to_string(p_matched_subjects, ', '), 'Actualite');

    -- Find opted-in students with sufficient score threshold
    FOR v_user IN
        SELECT pap.user_id
        FROM app.prep_actuality_preferences pap
        WHERE pap.is_enabled = true
          AND p_score >= pap.min_relevance_score
    LOOP
        -- Queue push notification
        PERFORM public.app_queue_notification_event(
            v_user.user_id,
            'prep_concours',
            'concours_actuality',
            jsonb_build_object(
                'title', 'Actualite Concours',
                'body', LEFT(p_title, 150),
                'article_id', p_article_id,
                'score', p_score,
                'subjects', v_subjects_text,
                'icon', 'newspaper'
            )
        );
        v_notified := v_notified + 1;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'notified_count', v_notified);
END;
$fn$;
"""
r7 = run_ddl("rpc_notify_article", rpc7)
results["steps"].append({"step": "rpc_notify_article", "result": r7})

# ═══════════════════════════════════════════════════════════════
# STEP 8: RPC — get relevant articles for student (feed)
# ═══════════════════════════════════════════════════════════════
print("\n=== STEP 8: RPC list relevant articles ===")
rpc8 = """
CREATE OR REPLACE FUNCTION public.app_student_list_concours_actualities(
    p_limit integer DEFAULT 20,
    p_min_score real DEFAULT 0.3
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $fn$
DECLARE
    v_result jsonb;
BEGIN
    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT a.id, a.title, a.summary,
               a.relevance_score, a.matched_subjects, a.scoring_reason,
               a.published_at, a.article_url,
               s.name AS source_name
        FROM app.prep_news_articles a
        JOIN app.prep_news_sources s ON s.id = a.source_id
        WHERE a.is_concours_relevant = true
          AND a.relevance_score >= p_min_score
        ORDER BY a.relevance_score DESC, a.published_at DESC
        LIMIT GREATEST(1, LEAST(p_limit, 50))
    ) t;

    RETURN jsonb_build_object('success', true, 'articles', v_result);
END;
$fn$;
"""
r8 = run_ddl("rpc_list_relevant", rpc8)
results["steps"].append({"step": "rpc_list_relevant", "result": r8})

# ═══════════════════════════════════════════════════════════════
# VERIFY
# ═══════════════════════════════════════════════════════════════
print("\n=== VERIFICATION ===")
v1 = run_sql("verify_rtb", "SELECT name, is_active FROM app.prep_news_sources WHERE slug = 'rtb'")
print(f"  RTB: {v1.get('rows',[{}])[0] if v1.get('rows') else 'ERR'}")

v2 = run_sql("verify_columns", "SELECT column_name FROM information_schema.columns WHERE table_schema='app' AND table_name='prep_news_articles' AND column_name IN ('relevance_score','is_concours_relevant','scoring_reason','matched_subjects','matched_keywords','scored_at') ORDER BY column_name")
print(f"  New columns: {[r['column_name'] for r in v2.get('rows',[])]}")

v3 = run_sql("verify_prefs_table", "SELECT tablename FROM pg_tables WHERE schemaname='app' AND tablename='prep_actuality_preferences'")
print(f"  Prefs table: {bool(v3.get('rows'))}")

v4 = run_sql("verify_rpcs", "SELECT proname FROM pg_proc WHERE proname IN ('app_student_toggle_actuality_notifications','app_student_get_actuality_preferences','app_prep_score_article_relevance','app_prep_notify_relevant_article','app_student_list_concours_actualities') AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname='public') ORDER BY proname")
print(f"  RPCs: {[r['proname'] for r in v4.get('rows',[])]}")

# Test scoring on a real article
print("\n=== TEST SCORING ===")
test_score = run_sql("test_score", """
SELECT public.app_prep_score_article_relevance(
    'Le gouvernement adopte un decret portant organisation du concours de la fonction publique 2026',
    'Le conseil des ministres a adopte ce mercredi un decret portant organisation des concours directs de la fonction publique au titre de annee 2026. Le premier ministre a souligne importance du recrutement dans les secteurs de education, de la sante et de la securite. Le budget alloue aux concours est en hausse de 15 pourcent par rapport a annee precedente. Les epreuves porteront sur la culture generale, le droit constitutionnel, economie generale et les finances publiques.',
    ARRAY['Politique','DEPECHES']
) AS score
""")
if test_score.get("rows"):
    print(f"  Score result: {json.dumps(test_score['rows'][0], ensure_ascii=False, indent=2)[:800]}")

# Save
out = pathlib.Path("logs/deploy_scoring_machine.json")
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(results, ensure_ascii=False, indent=2, default=str), encoding="utf-8")
print(f"\n[OK] Log: {out}")
