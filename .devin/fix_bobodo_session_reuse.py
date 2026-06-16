#!/usr/bin/env python3
"""Créer une RPC 'app_get_or_create_bobodo_session' pour éviter les sessions multiples pour le même étudiant."""

import json
import requests
from auto_supabase_import import SUPABASE_URL, SUPABASE_SERVICE_KEY

HEADERS = {
    "apikey": SUPABASE_SERVICE_KEY,
    "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
    "Content-Type": "application/json",
}

def run_sql(label: str, sql: str) -> None:
    url = f"{SUPABASE_URL}/rest/v1/rpc/admin_execute_sql"
    print(f"\n=== {label} ===")
    print(sql)
    try:
        resp = requests.post(url, headers=HEADERS, json={"p_sql": sql}, timeout=30)
    except Exception as exc:
        print("[ERROR] Exception réseau:", exc)
        return

    print("STATUS", resp.status_code)
    try:
        body = resp.json()
        print("BODY", json.dumps(body, ensure_ascii=False, indent=2)[:4000])
    except Exception:
        print("BODY_RAW", resp.text[:4000])

def main() -> int:
    # Créer la RPC app_get_or_create_bobodo_session
    rpc_sql = """
CREATE OR REPLACE FUNCTION public.app_get_or_create_bobodo_session(p_title TEXT DEFAULT NULL)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_student_id UUID;
    v_existing_session_id UUID;
    v_new_session_id UUID;
BEGIN
    -- Récupérer l'étudiant connecté via RLS
    v_student_id := auth.uid();

    IF v_student_id IS NULL THEN
        RAISE EXCEPTION 'Utilisateur non authentifié';
    END IF;

    -- Chercher une session existante pour cet étudiant créée récemment (par ex. < 7 jours)
    SELECT s.id INTO v_existing_session_id
    FROM app.bobodo_sessions s
    WHERE s.student_id = v_student_id
      AND s.created_at >= NOW() - INTERVAL '7 days'
    ORDER BY s.created_at DESC
    LIMIT 1;

    IF v_existing_session_id IS NOT NULL THEN
        RETURN v_existing_session_id;
    END IF;

    -- Sinon, créer une nouvelle session
    INSERT INTO app.bobodo_sessions (student_id, title)
    VALUES (v_student_id, COALESCE(p_title, 'Conversation Bobodo'))
    RETURNING id INTO v_new_session_id;

    RETURN v_new_session_id;
END;
$$;
    """.strip()

    run_sql("Créer RPC app_get_or_create_bobodo_session", rpc_sql)

    # Donner les droits d'exécution
    grant_sql = """
GRANT EXECUTE ON FUNCTION public.app_get_or_create_bobodo_session(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_get_or_create_bobodo_session(TEXT) TO service_role;
    """.strip()

    run_sql("Droits d'exécution sur la RPC", grant_sql)

    return 0

if __name__ == "__main__":
    raise SystemExit(main())
