"""Suppression exceptionnelle des conversations Bobodo d'Assetou Yanogo."""
import requests, json, time

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"}

def sql_fn(query):
    fname = f"_tmp_del_{abs(hash(query)) % 99999999}"
    requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": f"""CREATE OR REPLACE FUNCTION public.{fname}() RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $fn$
    DECLARE v JSONB; BEGIN {query} RETURN v; END; $fn$;"""})
    time.sleep(1.5)
    r = requests.post(f"{URL}/rest/v1/rpc/{fname}", headers=H, json={})
    requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": f"DROP FUNCTION IF EXISTS public.{fname}();"})
    return r.json()

# 1. Trouver Assetou Yanogo
print("=== ÉTAPE 1: Identifier Assetou Yanogo ===")
r = sql_fn("""
  SELECT jsonb_agg(jsonb_build_object(
    'id', id, 'email', email,
    'name', COALESCE(raw_user_meta_data->>'full_name', raw_user_meta_data->>'display_name', ''),
    'role', raw_user_meta_data->>'role'
  ))
  INTO v FROM auth.users
  WHERE LOWER(COALESCE(raw_user_meta_data->>'full_name', '')) LIKE '%yanogo%'
     OR LOWER(COALESCE(raw_user_meta_data->>'full_name', '')) LIKE '%yannoug%'
     OR LOWER(COALESCE(raw_user_meta_data->>'full_name', '')) LIKE '%assetou%'
     OR LOWER(COALESCE(raw_user_meta_data->>'full_name', '')) LIKE '%asetou%'
     OR LOWER(COALESCE(raw_user_meta_data->>'display_name', '')) LIKE '%yanogo%'
     OR LOWER(COALESCE(raw_user_meta_data->>'display_name', '')) LIKE '%assetou%'
     OR LOWER(email) LIKE '%yanogo%'
     OR LOWER(email) LIKE '%assetou%';
""")
print(f"  Résultats: {json.dumps(r, default=str, ensure_ascii=False)}")

if not isinstance(r, list) or len(r) == 0:
    print("  Utilisatrice non trouvée par nom. Cherchons les dernières sessions Bobodo...")
    r2 = sql_fn("""
      SELECT jsonb_agg(jsonb_build_object(
        'session_id', s.id,
        'student_id', s.student_id,
        'title', s.title,
        'created_at', s.created_at,
        'name', COALESCE(u.raw_user_meta_data->>'full_name', u.raw_user_meta_data->>'display_name', u.email)
      ) ORDER BY s.created_at DESC)
      INTO v FROM app.bobodo_sessions s
      JOIN auth.users u ON u.id = s.student_id
      ORDER BY s.created_at DESC
      LIMIT 10;
    """)
    print(f"  Dernières sessions: {json.dumps(r2, default=str, ensure_ascii=False)[:600]}")
else:
    user = r[0]
    user_id = user['id']
    user_name = user['name']
    print(f"  Trouvée: {user_name} (id={user_id})")
    
    # 2. Lister ses sessions Bobodo
    print(f"\n=== ÉTAPE 2: Sessions Bobodo de {user_name} ===")
    sessions = sql_fn(f"""
      SELECT jsonb_agg(jsonb_build_object(
        'id', id, 'title', title, 'created_at', created_at
      ) ORDER BY created_at DESC)
      INTO v FROM app.bobodo_sessions WHERE student_id = '{user_id}';
    """)
    print(f"  Sessions: {json.dumps(sessions, default=str, ensure_ascii=False)[:500]}")
    
    if not isinstance(sessions, list) or len(sessions) == 0:
        print("  Aucune session trouvée.")
    else:
        session_ids = [s['id'] for s in sessions]
        print(f"  {len(session_ids)} session(s) trouvée(s)")
        
        # 3. Compter les messages
        print(f"\n=== ÉTAPE 3: Messages à supprimer ===")
        for sid in session_ids:
            msgs = sql_fn(f"""
              SELECT jsonb_build_object('count', COUNT(*))
              INTO v FROM app.bobodo_messages WHERE session_id = '{sid}';
            """)
            print(f"  Session {sid}: {msgs.get('count', '?')} messages")
        
        # 4. Supprimer les données liées
        print(f"\n=== ÉTAPE 4: Suppression ===")
        
        ids_sql = "'" + "','".join(session_ids) + "'"
        
        # 4a. Feedback
        r = sql_fn(f"""
          SELECT jsonb_build_object('deleted', COUNT(*))
          INTO v FROM app.bobodo_feedback WHERE session_id IN ({ids_sql});
        """)
        print(f"  Feedback à supprimer: {r}")
        sql_fn(f"DELETE FROM app.bobodo_feedback WHERE session_id IN ({ids_sql}); SELECT jsonb_build_object('ok', true) INTO v;")
        print(f"  ✅ Feedback supprimé")
        
        # 4b. Detected needs
        r = sql_fn(f"""
          SELECT jsonb_build_object('deleted', COUNT(*))
          INTO v FROM app.bobodo_detected_needs WHERE session_id IN ({ids_sql});
        """)
        print(f"  Besoins détectés à supprimer: {r}")
        sql_fn(f"DELETE FROM app.bobodo_detected_needs WHERE session_id IN ({ids_sql}); SELECT jsonb_build_object('ok', true) INTO v;")
        print(f"  ✅ Besoins détectés supprimés")
        
        # 4c. Unanswered questions
        r = sql_fn(f"""
          SELECT jsonb_build_object('deleted', COUNT(*))
          INTO v FROM app.bobodo_unanswered_questions WHERE session_id IN ({ids_sql});
        """)
        print(f"  Questions sans réponse à supprimer: {r}")
        sql_fn(f"DELETE FROM app.bobodo_unanswered_questions WHERE session_id IN ({ids_sql}); SELECT jsonb_build_object('ok', true) INTO v;")
        print(f"  ✅ Questions sans réponse supprimées")
        
        # 4d. Messages
        r = sql_fn(f"""
          SELECT jsonb_build_object('deleted', COUNT(*))
          INTO v FROM app.bobodo_messages WHERE session_id IN ({ids_sql});
        """)
        print(f"  Messages à supprimer: {r}")
        sql_fn(f"DELETE FROM app.bobodo_messages WHERE session_id IN ({ids_sql}); SELECT jsonb_build_object('ok', true) INTO v;")
        print(f"  ✅ Messages supprimés")
        
        # 4e. Sessions
        sql_fn(f"DELETE FROM app.bobodo_sessions WHERE id IN ({ids_sql}); SELECT jsonb_build_object('ok', true) INTO v;")
        print(f"  ✅ Sessions supprimées")
        
        # 5. Vérification
        print(f"\n=== ÉTAPE 5: Vérification ===")
        check = sql_fn(f"""
          SELECT jsonb_build_object(
            'sessions', (SELECT COUNT(*) FROM app.bobodo_sessions WHERE student_id = '{user_id}'),
            'messages', (SELECT COUNT(*) FROM app.bobodo_messages WHERE session_id IN ({ids_sql}))
          ) INTO v;
        """)
        print(f"  Restant: {check}")
        
        if isinstance(check, dict) and check.get('sessions', -1) == 0 and check.get('messages', -1) == 0:
            print(f"\n  ✅ TOUT EST SUPPRIMÉ — {user_name} n'a plus aucune conversation Bobodo.")
        else:
            print(f"\n  ⚠️ Vérifier manuellement.")

print("\n=== FIN ===")
