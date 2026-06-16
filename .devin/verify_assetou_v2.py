import requests, json, time
URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"}

def run_fn(body):
    fname = f"_tmp_vfy_{int(time.time()*1000) % 999999999}"
    requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": f"""CREATE OR REPLACE FUNCTION public.{fname}() RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $fn$
    DECLARE v JSONB; BEGIN {body} RETURN v; END; $fn$;"""})
    time.sleep(2)
    requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": "NOTIFY pgrst, 'reload schema';"})
    time.sleep(2)
    r = requests.post(f"{URL}/rest/v1/rpc/{fname}", headers=H, json={})
    result = r.json()
    requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": f"DROP FUNCTION IF EXISTS public.{fname}();"})
    return result

uid = "208cfab4-2c31-4f31-ab01-c6baa8ecbbc2"
sid = "a728d457-f60c-4f1e-9edb-6c7e4bcaef8d"

print("=== Vérification nettoyage Amssetou Yanogo ===")
r = run_fn(f"""
  SELECT jsonb_build_object(
    'sessions', (SELECT COUNT(*) FROM app.bobodo_sessions WHERE student_id = '{uid}'),
    'messages', (SELECT COUNT(*) FROM app.bobodo_messages WHERE session_id = '{sid}'),
    'needs', (SELECT COUNT(*) FROM app.bobodo_detected_needs WHERE session_id = '{sid}'),
    'feedback', (SELECT COUNT(*) FROM app.bobodo_feedback WHERE session_id = '{sid}'),
    'unanswered', (SELECT COUNT(*) FROM app.bobodo_unanswered_questions WHERE session_id = '{sid}')
  ) INTO v;
""")
print(f"  {json.dumps(r, indent=2)}")

if isinstance(r, dict) and all(r.get(k, -1) == 0 for k in ['sessions','messages','needs','feedback','unanswered']):
    print("\n  ✅ TOUT EST NETTOYÉ — Amssetou Yanogo n'a plus aucune conversation Bobodo.")
elif isinstance(r, dict) and 'code' in r:
    print(f"\n  ⚠️ Erreur PostgREST: {r}")
else:
    print(f"\n  Résultat: {r}")
