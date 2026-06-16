#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Fix scoring RPC - check prep_topics columns and fix frequency_score reference."""
import sys, json, requests
sys.stdout.reconfigure(encoding='utf-8')
from supabase_auto_manager import SupabaseAutoManager
m = SupabaseAutoManager()

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

def run_sql(label, sql_query, timeout=60):
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

# 1. Check prep_topics columns
print("=== 1. Check prep_topics columns ===")
r1 = run_sql("check_cols", """
    SELECT column_name, data_type
    FROM information_schema.columns
    WHERE table_schema = 'app' AND table_name = 'prep_topics'
    ORDER BY ordinal_position
""")
if r1.get("rows"):
    for row in r1["rows"]:
        print(f"    {row['column_name']} ({row['data_type']})")

# 2. Check prep_topics data
print("\n=== 2. Check prep_topics data ===")
r2 = run_sql("check_data", "SELECT * FROM app.prep_topics LIMIT 5")
if r2.get("rows"):
    for row in r2["rows"]:
        print(f"    {json.dumps(row, ensure_ascii=False)[:200]}")

# 3. Fix RPC - remove frequency_score reference, use a simpler topic matching
print("\n=== 3. Fix scoring RPC ===")
fix_rpc = """
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
    v_topic_name text;
BEGIN
    v_content_lower := LOWER(COALESCE(p_content, ''));
    v_title_lower := LOWER(COALESCE(p_title, ''));

    -- PHASE 1: Match against prep_subjects (matieres concours)
    FOR v_subject_row IN
        SELECT title, slug FROM app.prep_subjects
    LOOP
        IF v_content_lower LIKE '%' || LOWER(v_subject_row.title) || '%'
           OR v_title_lower LIKE '%' || LOWER(v_subject_row.title) || '%' THEN
            v_score := v_score + 0.15;
            v_matched_subjects := array_append(v_matched_subjects, v_subject_row.title);
        END IF;
    END LOOP;

    -- PHASE 2: Match against concours keywords
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
        'droits humains',
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

    -- PHASE 3: Category bonus
    IF p_categories IS NOT NULL THEN
        FOREACH v_cat IN ARRAY p_categories LOOP
            CASE LOWER(TRIM(v_cat))
                WHEN 'politique', 'politique nationale' THEN v_score := v_score + 0.10;
                WHEN 'economie' THEN v_score := v_score + 0.08;
                WHEN 'societe' THEN v_score := v_score + 0.06;
                WHEN 'education' THEN v_score := v_score + 0.10;
                WHEN 'sante' THEN v_score := v_score + 0.06;
                WHEN 'justice', 'droit' THEN v_score := v_score + 0.10;
                WHEN 'securite', 'defense' THEN v_score := v_score + 0.08;
                WHEN 'international' THEN v_score := v_score + 0.05;
                WHEN 'depeches', 'flash infos', 'la une aib' THEN v_score := v_score + 0.03;
                ELSE NULL;
            END CASE;
        END LOOP;
    END IF;

    -- PHASE 4: Past questions content match
    IF EXISTS (
        SELECT 1 FROM app.prep_questions pq
        WHERE (pq.subject IN ('Culture Generale', 'Actualites BF'))
          AND (
            v_title_lower LIKE '%' || LOWER(LEFT(pq.content, 30)) || '%'
            OR LOWER(pq.content) LIKE '%' || LEFT(v_title_lower, 40) || '%'
          )
        LIMIT 1
    ) THEN
        v_score := v_score + 0.20;
        v_reason := v_reason || 'Correspond a une question passee. ';
    END IF;

    -- PHASE 5: prep_topics name match (simple name match, no frequency_score)
    FOR v_subject_row IN
        SELECT name FROM app.prep_topics
    LOOP
        IF v_content_lower LIKE '%' || LOWER(v_subject_row.name) || '%' THEN
            v_score := v_score + 0.08;
            v_reason := v_reason || 'Topic: ' || v_subject_row.name || '. ';
        END IF;
    END LOOP;

    -- Cap at 1.0
    v_score := LEAST(v_score, 1.0);

    -- Build reason
    IF array_length(v_matched_subjects, 1) > 0 THEN
        v_reason := v_reason || 'Matieres: ' || array_to_string(v_matched_subjects, ', ') || '. ';
    END IF;
    IF array_length(v_matched_keywords, 1) > 3 THEN
        v_reason := v_reason || 'Mots-cles (' || array_length(v_matched_keywords, 1)::text || '): ' || array_to_string(v_matched_keywords[1:5], ', ') || '...';
    ELSIF array_length(v_matched_keywords, 1) > 0 THEN
        v_reason := v_reason || 'Mots-cles: ' || array_to_string(v_matched_keywords, ', ') || '. ';
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
r3 = run_ddl("fix_scoring_rpc", fix_rpc)

# 4. Test scoring
print("\n=== 4. Test scoring ===")
test1 = run_sql("test_governance", """
    SELECT public.app_prep_score_article_relevance(
        'Le gouvernement adopte un decret portant organisation du concours de la fonction publique 2026',
        'Le conseil des ministres a adopte ce mercredi un decret portant organisation des concours directs de la fonction publique au titre de annee 2026. Le premier ministre a souligne importance du recrutement dans les secteurs de education, de la sante et de la securite. Le budget alloue aux concours est en hausse de 15 pourcent par rapport a annee precedente. Les epreuves porteront sur la culture generale, le droit constitutionnel, economie generale et les finances publiques.',
        ARRAY['Politique','DEPECHES']
    ) AS result
""")
if test1.get("rows"):
    print(f"    Governance article: {json.dumps(test1['rows'][0], ensure_ascii=False, indent=2)[:500]}")

test2 = run_sql("test_sport", """
    SELECT public.app_prep_score_article_relevance(
        'Les Etalons battent le Mali 2-0 en match amical',
        'equipe nationale de football du Burkina Faso les Etalons a remporte une victoire 2-0 face au Mali lors un match amical dispute au stade du 4 aout de Ouagadougou.',
        ARRAY['Sport']
    ) AS result
""")
if test2.get("rows"):
    print(f"    Sport article: {json.dumps(test2['rows'][0], ensure_ascii=False, indent=2)[:500]}")

test3 = run_sql("test_aes", """
    SELECT public.app_prep_score_article_relevance(
        'Sommet de AES a Niamey: les chefs Etat adoptent la charte de la Confederation',
        'Les presidents du Burkina Faso, du Mali et du Niger se sont reunis a Niamey pour le sommet de Alliance des Etats du Sahel AES. Ils ont adopte la charte fondatrice de la Confederation du Sahel qui prevoit une cooperation renforcee en matiere de defense, de securite, de diplomatie et economie. Le capitaine Ibrahim Traore a souligne importance de la souverainete et de la cooperation sud-sud.',
        ARRAY['Politique','International']
    ) AS result
""")
if test3.get("rows"):
    print(f"    AES article: {json.dumps(test3['rows'][0], ensure_ascii=False, indent=2)[:500]}")

print("\n[OK] Done")
