#!/usr/bin/env python3
"""Deploy tables + RPCs for the 'Sujets Blancs' (mock exams) system."""
import json, requests
from pathlib import Path
from datetime import datetime
from supabase_auto_manager import SupabaseAutoManager


def run_sql(m, label, sql, timeout=180):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    resp = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=timeout)
    try:
        data = resp.json()
    except Exception:
        return {"label": label, "ok": False, "raw": (resp.text or "")[:2000]}
    if isinstance(data, dict):
        return {"label": label, "ok": bool(data.get("ok")),
                "rows": data.get("rows", []), "error": data.get("error")}
    return {"label": label, "ok": False, "error": "unexpected"}


SQL_TABLE = """
-- Sujets blancs: complete self-contained mock exams
CREATE TABLE IF NOT EXISTS app.prep_exam_blancs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    title text NOT NULL,
    description text,
    concours_type text NOT NULL DEFAULT 'TOUS',
    total_questions integer NOT NULL DEFAULT 50,
    duration_minutes integer NOT NULL DEFAULT 120,
    -- sections: array of { subject_name, questions_count, questions: [{question, explanation, choices: [{label, text, is_correct}]}] }
    sections jsonb NOT NULL DEFAULT '[]'::jsonb,
    is_published boolean NOT NULL DEFAULT false,
    generation_status text NOT NULL DEFAULT 'ready',  -- ready, generating, failed
    generated_by text DEFAULT 'system',
    times_taken integer NOT NULL DEFAULT 0,
    avg_score numeric(5,2),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Tracking: which user took which exam blanc and their score
CREATE TABLE IF NOT EXISTS app.prep_exam_blanc_attempts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    exam_blanc_id uuid NOT NULL REFERENCES app.prep_exam_blancs(id) ON DELETE CASCADE,
    user_id uuid NOT NULL,
    score integer,
    total_questions integer,
    percentage numeric(5,2),
    answers jsonb DEFAULT '[]'::jsonb,
    started_at timestamptz NOT NULL DEFAULT now(),
    finished_at timestamptz,
    duration_seconds integer
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_prep_exam_blancs_published ON app.prep_exam_blancs(is_published, concours_type);
CREATE INDEX IF NOT EXISTS idx_prep_exam_blanc_attempts_user ON app.prep_exam_blanc_attempts(user_id, exam_blanc_id);

-- RLS
ALTER TABLE app.prep_exam_blancs ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.prep_exam_blanc_attempts ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='prep_exam_blancs' AND policyname='service_role_all_exam_blancs') THEN
        CREATE POLICY service_role_all_exam_blancs ON app.prep_exam_blancs FOR ALL TO service_role USING (true) WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='prep_exam_blanc_attempts' AND policyname='service_role_all_exam_blanc_attempts') THEN
        CREATE POLICY service_role_all_exam_blanc_attempts ON app.prep_exam_blanc_attempts FOR ALL TO service_role USING (true) WITH CHECK (true);
    END IF;
END $$;
"""

SQL_RPC_LIST = """
CREATE OR REPLACE FUNCTION public.app_prep_list_exam_blancs(
    p_concours_type text DEFAULT NULL,
    p_user_id uuid DEFAULT NULL,
    p_limit integer DEFAULT 20
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_result jsonb;
BEGIN
    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at DESC), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT e.id, e.title, e.description, e.concours_type,
               e.total_questions, e.duration_minutes,
               e.times_taken, e.avg_score,
               e.is_published, e.created_at,
               -- has user already taken this exam?
               CASE WHEN p_user_id IS NOT NULL THEN
                   EXISTS(SELECT 1 FROM app.prep_exam_blanc_attempts a
                          WHERE a.exam_blanc_id = e.id AND a.user_id = p_user_id AND a.finished_at IS NOT NULL)
               ELSE false END AS already_taken,
               -- user's best score
               (SELECT max(a.percentage) FROM app.prep_exam_blanc_attempts a
                WHERE a.exam_blanc_id = e.id AND a.user_id = p_user_id) AS user_best_score
        FROM app.prep_exam_blancs e
        WHERE e.is_published = true
          AND e.generation_status = 'ready'
          AND (p_concours_type IS NULL OR e.concours_type = p_concours_type OR e.concours_type = 'TOUS')
        LIMIT GREATEST(1, LEAST(p_limit, 50))
    ) t;

    RETURN jsonb_build_object('success', true, 'exams', v_result);
END;
$function$;
"""

SQL_RPC_GET = """
CREATE OR REPLACE FUNCTION public.app_prep_get_exam_blanc(
    p_exam_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_exam jsonb;
BEGIN
    SELECT row_to_json(e)::jsonb INTO v_exam
    FROM (
        SELECT id, title, description, concours_type,
               total_questions, duration_minutes, sections,
               times_taken, avg_score, created_at
        FROM app.prep_exam_blancs
        WHERE id = p_exam_id AND is_published = true
    ) e;

    IF v_exam IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Sujet introuvable');
    END IF;

    -- Increment times_taken
    UPDATE app.prep_exam_blancs SET times_taken = times_taken + 1, updated_at = now()
    WHERE id = p_exam_id;

    RETURN jsonb_build_object('success', true, 'exam', v_exam);
END;
$function$;
"""

SQL_RPC_SUBMIT = """
CREATE OR REPLACE FUNCTION public.app_prep_submit_exam_blanc(
    p_exam_id uuid,
    p_user_id uuid,
    p_score integer,
    p_total integer,
    p_answers jsonb DEFAULT '[]'::jsonb,
    p_duration_seconds integer DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_pct numeric(5,2);
    v_attempt_id uuid;
BEGIN
    v_pct := CASE WHEN p_total > 0 THEN ROUND((p_score::numeric / p_total) * 100, 2) ELSE 0 END;

    INSERT INTO app.prep_exam_blanc_attempts (
        exam_blanc_id, user_id, score, total_questions, percentage,
        answers, finished_at, duration_seconds
    ) VALUES (
        p_exam_id, p_user_id, p_score, p_total, v_pct,
        p_answers, now(), p_duration_seconds
    ) RETURNING id INTO v_attempt_id;

    -- Update average score on the exam
    UPDATE app.prep_exam_blancs SET
        avg_score = (SELECT ROUND(AVG(percentage), 2) FROM app.prep_exam_blanc_attempts WHERE exam_blanc_id = p_exam_id AND finished_at IS NOT NULL),
        updated_at = now()
    WHERE id = p_exam_id;

    RETURN jsonb_build_object(
        'success', true,
        'attempt_id', v_attempt_id,
        'score', p_score,
        'total', p_total,
        'percentage', v_pct
    );
END;
$function$;
"""


def main():
    m = SupabaseAutoManager()
    results = {"timestamp": datetime.utcnow().isoformat() + "Z", "steps": []}

    steps = [
        ("create_tables", SQL_TABLE),
        ("rpc_list_exam_blancs", SQL_RPC_LIST),
        ("rpc_get_exam_blanc", SQL_RPC_GET),
        ("rpc_submit_exam_blanc", SQL_RPC_SUBMIT),
    ]

    for label, sql in steps:
        r = run_sql(m, label, sql)
        results["steps"].append(r)
        s = "✅" if r.get("ok") else "❌"
        err = f" — {r.get('error')}" if r.get("error") else ""
        print(f"  {s} {label}{err}")

    out = Path(".windsurf/logs/deploy_exam_blancs_tables.json")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\n[OK] Saved {out.as_posix()}")


if __name__ == "__main__":
    main()
