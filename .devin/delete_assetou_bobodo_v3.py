"""Suppression conversations Bobodo d'Assetou Yanogo — V3 via temp functions."""
import requests, json, time

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"}

def exec_sql(sql):
    return requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": sql}).json()

def run_fn(body):
    fname = f"_tmp_ay_{int(time.time()*1000) % 999999999}"
    exec_sql(f"""CREATE OR REPLACE FUNCTION public.{fname}() RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $fn$
    DECLARE v JSONB; BEGIN {body} RETURN v; END; $fn$;""")
    time.sleep(2)
    # Notify PostgREST to reload schema
    exec_sql("NOTIFY pgrst, 'reload schema';")
    time.sleep(2)
    r = requests.post(f"{URL}/rest/v1/rpc/{fname}", headers=H, json={})
    result = r.json()
    exec_sql(f"DROP FUNCTION IF EXISTS public.{fname}();")
    return result

# 1. Find users matching Assetou/Yanogo
print("=== ÉTAPE 1: Trouver Assetou ===")
r = run_fn("""
  SELECT jsonb_agg(jsonb_build_object('id', u.id, 'email', u.email, 
    'name', COALESCE(u.raw_user_meta_data->>'full_name', u.raw_user_meta_data->>'display_name', u.email)))
  INTO v
  FROM auth.users u
  WHERE LOWER(COALESCE(u.raw_user_meta_data->>'full_name','')) LIKE '%yanogo%'
     OR LOWER(COALESCE(u.raw_user_meta_data->>'full_name','')) LIKE '%assetou%'
     OR LOWER(COALESCE(u.raw_user_meta_data->>'full_name','')) LIKE '%assétou%'
     OR LOWER(COALESCE(u.raw_user_meta_data->>'full_name','')) LIKE '%asetou%'
     OR LOWER(u.email) LIKE '%yanogo%'
     OR LOWER(u.email) LIKE '%assetou%';
""")
print(f"  {json.dumps(r, default=str, ensure_ascii=False)[:500]}")

if isinstance(r, list) and len(r) > 0:
    user_id = r[0]['id']
    user_name = r[0]['name']
    print(f"  Trouvée: {user_name} (id={user_id})")
elif isinstance(r, dict) and 'code' in r:
    # PostgREST cache issue, try listing recent sessions instead
    print("  Erreur PostgREST, fallback sur sessions récentes...")
    r = run_fn("""
      SELECT jsonb_agg(jsonb_build_object(
        'sid', s.id, 'uid', s.student_id, 'title', s.title, 'at', s.created_at,
        'name', COALESCE(u.raw_user_meta_data->>'full_name', u.email)
      ) ORDER BY s.created_at DESC)
      INTO v FROM app.bobodo_sessions s JOIN auth.users u ON u.id = s.student_id;
    """)
    print(f"  Sessions: {json.dumps(r, default=str, ensure_ascii=False)[:800]}")
    
    if isinstance(r, list):
        for s in r:
            name = (s.get('name','') or '').lower()
            if 'yanogo' in name or 'assetou' in name or 'assétou' in name or 'asetou' in name:
                user_id = s['uid']
                user_name = s['name']
                print(f"  Trouvée via sessions: {user_name} (id={user_id})")
                break
        else:
            print("\n  Utilisateurs avec sessions Bobodo:")
            seen = set()
            for s in r:
                uid = s['uid']
                if uid not in seen:
                    seen.add(uid)
                    print(f"    {s['name']} (id={uid}) — {s.get('title','')} — {s.get('at','')}")
            print("\n  ⚠️ Assetou Yanogo non trouvée. Vérifier les noms ci-dessus.")
            exit()
    else:
        print(f"  Erreur: {r}")
        exit()
else:
    print(f"  Réponse inattendue: {r}")
    # Fallback
    r = run_fn("""
      SELECT jsonb_agg(jsonb_build_object(
        'sid', s.id, 'uid', s.student_id, 'title', s.title, 'at', s.created_at,
        'name', COALESCE(u.raw_user_meta_data->>'full_name', u.email)
      ) ORDER BY s.created_at DESC)
      INTO v FROM app.bobodo_sessions s JOIN auth.users u ON u.id = s.student_id;
    """)
    print(f"  Toutes sessions: {json.dumps(r, default=str, ensure_ascii=False)[:800]}")
    if isinstance(r, list):
        seen = set()
        for s in r:
            uid = s['uid']
            name = (s.get('name','') or '').lower()
            if uid not in seen:
                seen.add(uid)
                if 'yanogo' in name or 'assetou' in name or 'assétou' in name:
                    user_id = s['uid']
                    user_name = s['name']
                    print(f"  ✅ Trouvée: {user_name} (id={user_id})")
                    break
        else:
            print("  Utilisateurs:")
            seen2 = set()
            for s in r:
                uid = s['uid']
                if uid not in seen2:
                    seen2.add(uid)
                    print(f"    {s['name']} (id={uid})")
            exit()
    else:
        exit()

# 2. List sessions
print(f"\n=== ÉTAPE 2: Sessions Bobodo de {user_name} ===")
sessions = run_fn(f"""
  SELECT jsonb_agg(jsonb_build_object('id', id, 'title', title, 'at', created_at) ORDER BY created_at DESC)
  INTO v FROM app.bobodo_sessions WHERE student_id = '{user_id}';
""")
print(f"  {json.dumps(sessions, default=str, ensure_ascii=False)[:500]}")

if not isinstance(sessions, list) or len(sessions) == 0:
    print("  Aucune session.")
    exit()

session_ids = [s['id'] for s in sessions]
ids_sql = "'" + "','".join(session_ids) + "'"
print(f"  {len(session_ids)} session(s)")

# 3. Count messages  
print(f"\n=== ÉTAPE 3: Comptage ===")
counts = run_fn(f"""
  SELECT jsonb_build_object(
    'messages', (SELECT COUNT(*) FROM app.bobodo_messages WHERE session_id IN ({ids_sql})),
    'feedback', (SELECT COUNT(*) FROM app.bobodo_feedback WHERE session_id IN ({ids_sql})),
    'needs', (SELECT COUNT(*) FROM app.bobodo_detected_needs WHERE session_id IN ({ids_sql})),
    'unanswered', (SELECT COUNT(*) FROM app.bobodo_unanswered_questions WHERE session_id IN ({ids_sql}))
  ) INTO v;
""")
print(f"  {json.dumps(counts, default=str)}")

# 4. DELETE all
print(f"\n=== ÉTAPE 4: SUPPRESSION ===")
for table, label in [
    ('bobodo_feedback', 'Feedback'),
    ('bobodo_detected_needs', 'Besoins détectés'),
    ('bobodo_unanswered_questions', 'Questions sans réponse'),
    ('bobodo_messages', 'Messages'),
    ('bobodo_sessions', 'Sessions'),
]:
    if table == 'bobodo_sessions':
        where = f"id IN ({ids_sql})"
    else:
        where = f"session_id IN ({ids_sql})"
    
    r = run_fn(f"""
      DELETE FROM app.{table} WHERE {where};
      SELECT jsonb_build_object('ok', true) INTO v;
    """)
    print(f"  ✅ {label} supprimé(s)")

# 5. Verify
print(f"\n=== ÉTAPE 5: Vérification ===")
check = run_fn(f"""
  SELECT jsonb_build_object(
    'sessions', (SELECT COUNT(*) FROM app.bobodo_sessions WHERE student_id = '{user_id}'),
    'msgs_orphans', (SELECT COUNT(*) FROM app.bobodo_messages WHERE session_id IN ({ids_sql}))
  ) INTO v;
""")
print(f"  Restant: {json.dumps(check, default=str)}")

if isinstance(check, dict) and check.get('sessions', -1) == 0 and check.get('msgs_orphans', -1) == 0:
    print(f"\n  ✅ TOUT EST NETTOYÉ — {user_name} n'a plus aucune conversation Bobodo.")
else:
    print(f"\n  ⚠️ Vérifier manuellement.")

print("\n=== FIN ===")
